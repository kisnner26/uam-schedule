import SwiftUI
import UserNotifications
import WidgetKit

@main
struct UAMScheduleApp: App {
    @StateObject private var store      = ScheduleStore()
    @StateObject private var attendance = AttendanceStore()
    @StateObject private var profile    = UserProfile()
    @AppStorage("colorScheme")    private var colorSchemeRaw: String = "system"
    @AppStorage("onboardingDone") private var onboardingDone: Bool = false

    @State private var splashDone: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var colorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Persistent background — prevents black bars during transitions
                Color(red: 250/255, green: 248/255, blue: 245/255)
                    .ignoresSafeArea(.all)

            Group {
                if !splashDone {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.35)) { splashDone = true }
                    }
                } else if !onboardingDone {
                    OnboardingView(onboardingDone: $onboardingDone)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal:   .opacity
                        ))
                } else if !profile.isLoggedIn {
                    LoginView()
                        .environmentObject(profile)
                        .transition(.opacity)
                } else {
                    ContentView()
                        .environmentObject(store)
                        .environmentObject(profile)
                        .environmentObject(attendance)
                        .transition(.opacity)
                        .onReceive(
                            NotificationCenter.default.publisher(
                                for: UIApplication.willEnterForegroundNotification
                            )
                        ) { @MainActor _ in
                            attendance.reload()
                            LiveActivityManager.shared.checkAndAutoStart(store: store)
                            WidgetCenter.shared.reloadAllTimelines()
                            MoodleStore.shared.syncIfConnected()
                        }
                        .onReceive(store.$courses) { @MainActor courses in
                            // Bug fix: mark closure @MainActor to silence Sendable warnings
                            // for MainActor-isolated NotificationManager.shared and store.
                            let snapshot = courses
                            NotificationManager.shared.requestPermission { granted in
                                if granted {
                                    NotificationManager.shared.scheduleAll(courses: snapshot)
                                }
                            }
                        }
                        .task { @MainActor in
                            // Bug fix: annotate task @MainActor so AppDelegate.shared
                            // (MainActor-isolated) and store (ObservableObject on MainActor)
                            // can be accessed without Sendable warnings.
                            AppDelegate.shared.attendance = attendance
                            // Vincular ScheduleStore con MoodleStore para importacion automatica
                            MoodleStore.shared.scheduleStore = store

                            // Registrar observer para nunca re-agregar cursos eliminados por el usuario
                            NotificationCenter.default.addObserver(
                                forName: Notification.Name("uam.moodleCourseDeleted"),
                                object: nil,
                                queue: .main
                            ) { notification in
                                if let moodleId = notification.object as? Int {
                                    MoodleStore.shared.markDeleted(moodleCourseId: moodleId)
                                }
                            }
                            // Si ya habia sesion activa, sincronizar al arrancar
                            if MoodleStore.shared.isConnected {
                                await MoodleStore.shared.sync()
                            }
                            let coursesSnapshot = store.courses
                            NotificationManager.shared.requestPermission { granted in
                                if granted {
                                    NotificationManager.shared.scheduleAll(courses: coursesSnapshot)
                                }
                            }
                            SiriShortcutsManager.shared.activate()

                            // Handle file opened while app was cold-launched
                            if let data = AppDelegate.pendingImportData {
                                AppDelegate.pendingImportData = nil
                                NotificationCenter.default.post(
                                    name: .uamScheduleFileImport,
                                    object: data
                                )
                            }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.35), value: splashDone)
            .animation(.easeInOut(duration: 0.35), value: onboardingDone)
            }
            .preferredColorScheme(colorScheme)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Force a state refresh: maybe the user dismissed the activity
                // from outside the app, or maybe the app was suspended for hours.
                LiveActivityManager.shared.rehydrateFromSystem()
                LiveActivityManager.shared.checkAndAutoStart(store: store)
            }
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: - Notification name
// ─────────────────────────────────────────────────

extension Notification.Name {
    /// Posted when a .uamschedule file is opened from Files / AirDrop.
    /// `object` is the raw `Data` of the file.
    static let uamScheduleFileImport = Notification.Name("UAMScheduleFileImport")
}

// ─────────────────────────────────────────────────
// MARK: - App Delegate
// ─────────────────────────────────────────────────

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    static var shared = AppDelegate()

    /// Stores import data when the app cold-launches via a file open.
    static var pendingImportData: Data?

    var attendance: AttendanceStore?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Self.shared = self
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.registerCategories()
        // Fix black bars: set the window background so transitions never expose black
        DispatchQueue.main.async {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .forEach { $0.backgroundColor = UIColor(red: 250/255, green: 248/255, blue: 245/255, alpha: 1) }
        }
        return true
    }

    // MARK: Handle .uamschedule files opened from Files app / AirDrop / Mail
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        let ext = url.pathExtension.lowercased()

        // Handle .uamschedule and .json backup files
        if ext == "uamschedule" || ext == "json" {
            let gotAccess = url.startAccessingSecurityScopedResource()
            defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url) else { return false }

            // If ContentView is already alive, post directly
            if NotificationCenter.default.hasObservers(for: .uamScheduleFileImport) {
                NotificationCenter.default.post(name: .uamScheduleFileImport, object: data)
            } else {
                // Cold-launch: store until ContentView is ready
                Self.pendingImportData = data
            }
            return true
        }

        return false  // let other handlers (Auth0, etc.) process it
    }

    // MARK: Notification delegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info     = response.notification.request.content.userInfo
        let actionId = response.actionIdentifier
        if let att = attendance {
            NotificationManager.shared.handleAction(identifier: actionId, userInfo: info, attendance: att)
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// ─────────────────────────────────────────────────
// MARK: - Helper: check if anyone is observing a name
// ─────────────────────────────────────────────────

private extension NotificationCenter {
    func hasObservers(for name: Notification.Name) -> Bool {
        // We just always post and let the ContentView decide.
        // This is a best-effort check; always returns true at runtime.
        return true
    }
}
