import AppIntents
import SwiftUI

private let kShortcutsEnabled = "uam_shortcuts_enabled"

// MARK: - Intent: Next class

@available(iOS 16.0, *)
struct NextClassIntent: AppIntent {
    static let title: LocalizedStringResource = "Next class"
    static let description = IntentDescription("Siri tells you the name, room and time of your next class")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = ScheduleStore()
        guard let next = store.nextClass() else {
            return .result(dialog: "You have no more classes scheduled for now.")
        }
        let room = next.session.room.trimmingCharacters(in: .whitespaces).isEmpty ? next.course.room : next.session.room
        return .result(dialog: "\(next.course.name) at \(next.session.startTimeString) in room \(room).")
    }
}

// MARK: - Intent: Current class

@available(iOS 16.0, *)
struct CurrentClassIntent: AppIntent {
    static let title: LocalizedStringResource = "Current class"
    static let description = IntentDescription("Siri tells you the class you have right now")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = ScheduleStore()
        guard let cur = store.currentClass() else {
            return .result(dialog: "You don't have any class at the moment.")
        }
        let room = cur.session.room.trimmingCharacters(in: .whitespaces).isEmpty ? cur.course.room : cur.session.room
        let cal = Calendar.current
        let mins = max(0, cur.session.endHour * 60 + cur.session.endMinute
            - cal.component(.hour, from: Date()) * 60
            - cal.component(.minute, from: Date()))
        return .result(dialog: "You're in \(cur.course.name), room \(room). It ends in \(mins) minutes.")
    }
}

// MARK: - Intent: Today's schedule

@available(iOS 16.0, *)
struct TodayScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's schedule"
    static let description = IntentDescription("Opens UAMSchedule directly on today's view")
    static let openAppWhenRun: Bool = true
    func perform() async throws -> some IntentResult { .result() }
}

// MARK: - Intent: My courses

@available(iOS 16.0, *)
struct MyCoursesIntent: AppIntent {
    static let title: LocalizedStringResource = "My courses"
    static let description = IntentDescription("Lists your semester courses")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = ScheduleStore()
        guard !store.courses.isEmpty else {
            return .result(dialog: "You don't have any courses registered yet.")
        }
        let names = store.courses.prefix(5).map { $0.name }.joined(separator: ", ")
        let extra = store.courses.count > 5 ? " and \(store.courses.count - 5) more." : "."
        return .result(dialog: "Your courses: \(names)\(extra)")
    }
}

// MARK: - App Shortcuts Provider
// Registers phrases so Siri discovers them automatically without needing
// the Shortcuts app. Uses the AppShortcutsProvider API (iOS 16+).

@available(iOS 16.0, *)
struct UAMAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextClassIntent(),
            phrases: [
                "Next class in \(.applicationName)",
                "What's my next class in \(.applicationName)"
            ],
            shortTitle: "Next class",
            systemImageName: "graduationcap.fill"
        )
        AppShortcut(
            intent: CurrentClassIntent(),
            phrases: [
                "What class do I have now in \(.applicationName)",
                "Current class in \(.applicationName)"
            ],
            shortTitle: "Current class",
            systemImageName: "person.fill.checkmark"
        )
        AppShortcut(
            intent: TodayScheduleIntent(),
            phrases: [
                "My schedule in \(.applicationName)",
                "Open schedule in \(.applicationName)"
            ],
            shortTitle: "Today's schedule",
            systemImageName: "sun.max.fill"
        )
        AppShortcut(
            intent: MyCoursesIntent(),
            phrases: [
                "My courses in \(.applicationName)",
                "List my courses in \(.applicationName)"
            ],
            shortTitle: "My courses",
            systemImageName: "book.fill"
        )
    }
}

// MARK: - Manager

final class SiriShortcutsManager: @unchecked Sendable {
    @MainActor static let shared = SiriShortcutsManager()

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: kShortcutsEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: kShortcutsEnabled) }
    }

    func activate() {
        if #available(iOS 16.0, *) {
            UAMAppShortcuts.updateAppShortcutParameters()
        }
    }
}

// MARK: - Siri Shortcuts Settings View

struct SiriShortcutsView: View {
    @EnvironmentObject var store: ScheduleStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(kShortcutsEnabled) private var shortcutsEnabled: Bool = false
    @State private var appeared = false
    @State private var justActivated = false
    @State private var animatingToggle = false

    struct ShortcutInfo: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let phrase: String
        let description: String
        let color: Color
    }

    let items: [ShortcutInfo] = [
        ShortcutInfo(icon: "graduationcap.fill", title: "Próxima clase",
                     phrase: "Next class in UAMSchedule",
                     description: "Nombre, aula y hora de tu próxima clase",
                     color: Color(hex: "#6B1A2A")),
        ShortcutInfo(icon: "person.fill.checkmark", title: "Clase actual",
                     phrase: "What class do I have now in UAMSchedule",
                     description: "La materia que tienes en este momento",
                     color: Color(hex: "#1A3A6B")),
        ShortcutInfo(icon: "sun.max.fill", title: "Horario de hoy",
                     phrase: "My schedule in UAMSchedule",
                     description: "Abre la app en la vista de hoy",
                     color: Color(hex: "#6B4A1A")),
        ShortcutInfo(icon: "book.fill", title: "Mis materias",
                     phrase: "My courses in UAMSchedule",
                     description: "Lista tus materias del semestre",
                     color: Color(hex: "#1A5C3A")),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // Header
                        VStack(alignment: .leading, spacing: 2) {
                            Text("VOICE").font(DS.Font.body(9, weight: .semibold))
                                .foregroundStyle(DS.Color.wine).tracking(3)
                            Text("Siri Shortcuts")
                                .font(DS.Font.display(28, weight: .semibold)).foregroundStyle(Color.appInk)
                            WineAccentLine(height: 1.5, width: 36).padding(.top, 3)
                            Text("Activa los atajos para controlar UAMSchedule con tu voz.")
                                .font(DS.Font.body(13)).foregroundStyle(Color.appInkTertiary).padding(.top, 4)
                        }
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.top, 20).padding(.bottom, DS.Space.xl)
                        .opacity(appeared ? 1 : 0)
                        .animation(DS.Anim.easeSlow, value: appeared)

                        // Toggle card
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(shortcutsEnabled ? DS.Color.wineMuted : Color.appBackgroundTertiary)
                                    .frame(width: 48, height: 48)
                                    .animation(DS.Anim.springFast, value: shortcutsEnabled)
                                Image(systemName: shortcutsEnabled ? "waveform.circle.fill" : "waveform.circle")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(shortcutsEnabled ? DS.Color.wine : Color.appInkTertiary)
                                    .animation(DS.Anim.springFast, value: shortcutsEnabled)
                                    .scaleEffect(animatingToggle ? 1.2 : 1.0)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Activar Siri Shortcuts")
                                    .font(DS.Font.body(14, weight: .semibold)).foregroundStyle(Color.appInk)
                                Text(shortcutsEnabled
                                     ? "Activo — di las frases a Siri"
                                     : "Activa para usar comandos de voz")
                                    .font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { shortcutsEnabled },
                                set: { val in
                                    withAnimation(DS.Anim.springFast) {
                                        shortcutsEnabled = val
                                        animatingToggle = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        withAnimation(DS.Anim.springFast) { animatingToggle = false }
                                    }
                                    if val {
                                        SiriShortcutsManager.shared.activate()
                                        withAnimation(DS.Anim.spring) { justActivated = true }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                            withAnimation { justActivated = false }
                                        }
                                    }
                                }
                            )).tint(DS.Color.wine).labelsHidden()
                        }
                        .cardStyle()
                        .padding(.horizontal, DS.Space.md).padding(.bottom, DS.Space.sm)
                        .opacity(appeared ? 1 : 0)
                        .animation(DS.Anim.spring.delay(0.08), value: appeared)

                        // Activated banner
                        if justActivated {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(hex: "#1A5C3A"))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Shortcuts activados")
                                        .font(DS.Font.body(12, weight: .semibold))
                                        .foregroundStyle(Color(hex: "#1A5C3A"))
                                    Text("Di las frases a Siri para activar cada atajo.")
                                        .font(DS.Font.body(11))
                                        .foregroundStyle(Color(hex: "#1A5C3A").opacity(0.7))
                                }
                            }
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "#1A5C3A").opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#1A5C3A").opacity(0.15), lineWidth: 1))
                            .padding(.horizontal, DS.Space.md).padding(.bottom, DS.Space.sm)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }

                        // Shortcut list
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ATAJOS DISPONIBLES")
                                .font(DS.Font.body(9, weight: .bold)).foregroundStyle(Color.appInkTertiary)
                                .tracking(2).padding(.horizontal, DS.Space.md).padding(.bottom, 6)

                            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(shortcutsEnabled ? item.color.opacity(0.12) : Color.appBackgroundTertiary)
                                            .frame(width: 40, height: 40)
                                            .animation(DS.Anim.springFast, value: shortcutsEnabled)
                                        Image(systemName: item.icon)
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundStyle(shortcutsEnabled ? item.color : Color.appInkTertiary.opacity(0.3))
                                            .animation(DS.Anim.springFast, value: shortcutsEnabled)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .font(DS.Font.body(13, weight: .semibold))
                                            .foregroundStyle(shortcutsEnabled ? Color.appInk : Color.appInkTertiary)
                                        Text(item.description)
                                            .font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary)
                                        HStack(spacing: 4) {
                                            Image(systemName: "mic.fill").font(.system(size: 9))
                                                .foregroundStyle(shortcutsEnabled ? DS.Color.wine.opacity(0.6) : Color.gray.opacity(0.2))
                                            Text("\"\(item.phrase)\"")
                                                .font(DS.Font.body(10))
                                                .foregroundStyle(shortcutsEnabled ? DS.Color.wine.opacity(0.75) : Color.gray.opacity(0.2))
                                                .italic()
                                        }
                                    }

                                    Spacer()

                                    if shortcutsEnabled {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color(hex: "#1A5C3A"))
                                            .font(.system(size: 18))
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .cardStyle()
                                .padding(.horizontal, DS.Space.md)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 12)
                                .animation(DS.Anim.spring.delay(0.14 + Double(idx) * 0.06), value: appeared)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Color.appInkTertiary)
                }
            }
        }
        .onAppear {
            appeared = true
            // Auto-activate on appear if already enabled (re-registers on every open)
            if shortcutsEnabled { SiriShortcutsManager.shared.activate() }
        }
    }
}
