import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ScheduleStore
    @EnvironmentObject var profile: UserProfile
    @State private var selectedTab      = 0
    @State private var showMoodPrompt   = false
    @State private var pendingImportData: Data? = nil
    @State private var showImportConfirm = false
    @State private var importToast: String? = nil
    @State private var importToastOK = true

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                TodayView()
                    .tag(0).tabItem { Label("Hoy",      systemImage: selectedTab == 0 ? AppIcons.todayActive    : AppIcons.today) }
                WeekView()
                    .tag(1).tabItem { Label("Semana",   systemImage: selectedTab == 1 ? AppIcons.scheduleActive : AppIcons.schedule) }
                CoursesView()
                    .tag(2).tabItem { Label("Materias", systemImage: selectedTab == 2 ? AppIcons.coursesActive  : AppIcons.courses) }
                MoodleDashboardView()
                    .tag(3).tabItem { Label("Moodle",   systemImage: selectedTab == 3 ? "graduationcap.fill"   : "graduationcap") }
                SettingsView()
                    .tag(4).tabItem { Label("Ajustes",  systemImage: selectedTab == 4 ? AppIcons.settingsActive : AppIcons.settings) }
            }
            .tint(DS.Color.wine)
            .onAppear { styleTabBar() }
            .onChange(of: selectedTab) { _, _ in Soft.haptic(.selection); Soft.sound(.tabSwitch) }

            // Toast
            if let msg = importToast {
                HStack(spacing: 10) {
                    Image(systemName: importToastOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(importToastOK ? Color(hex: "1A5C3A") : .red)
                    Text(msg)
                        .font(DS.Font.body(13, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(Color.appBackgroundSecondary)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
                .padding(.bottom, 100)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(20)
            }
        }
        .sheet(isPresented: $showMoodPrompt) { MoodTrackerView().environmentObject(store) }
        .alert("Importar horario?", isPresented: $showImportConfirm) {
            Button("Cancelar", role: .cancel) { pendingImportData = nil }
            Button("Importar", role: .destructive) {
                guard let data = pendingImportData else { return }
                pendingImportData = nil
                do {
                    try ScheduleBackupManager.import(data: data, into: store)
                    showToast("Horario importado", ok: true)
                } catch { showToast("Archivo invalido o corrupto", ok: false) }
            }
        } message: { Text("Esto reemplazara tus materias actuales. Los moods se combinaran.") }
        .onReceive(NotificationCenter.default.publisher(for: .uamScheduleFileImport)) { n in
            guard let data = n.object as? Data else { return }
            pendingImportData = data
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showImportConfirm = true }
        }
        .onAppear {
            if store.todayMood() == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { showMoodPrompt = true }
            }
        }
    }

    private func showToast(_ msg: String, ok: Bool) {
        withAnimation(DS.Anim.spring) { importToast = msg; importToastOK = ok }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { importToast = nil } }
    }

    private func styleTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.appBackgroundSecondary)
        appearance.shadowColor = UIColor(Color.appSeparator)

        let item = UITabBarItemAppearance()
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor(Color.appInkTertiary)
        ]
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor(DS.Color.wine)
        ]
        item.normal.titleTextAttributes   = normalAttrs
        item.selected.titleTextAttributes = selectedAttrs
        item.normal.iconColor   = UIColor(Color.appInkTertiary)
        item.selected.iconColor = UIColor(DS.Color.wine)

        appearance.stackedLayoutAppearance = item
        UITabBar.appearance().standardAppearance   = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
