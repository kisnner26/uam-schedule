import SwiftUI
import PhotosUI

// MARK: - SettingsView (Rediseño completo)
// Layout: Header con perfil hero compacto, luego secciones en grids/cards visuales.
// Cada sección agrupa ítems relacionados en bloques compactos con íconos de color.

struct SettingsView: View {
    @EnvironmentObject var profile: UserProfile
    @EnvironmentObject var store: ScheduleStore
    @StateObject private var attendance  = AttendanceStore()
    @ObservedObject private var liveActivity = LiveActivityManager.shared

    @AppStorage("colorScheme")             private var colorSchemeRaw: String = "system"
    @AppStorage("onboardingDone")          private var onboardingDone: Bool   = true
    @AppStorage("liveActivity_smartMode")  private var smartMode: Bool        = false
    @AppStorage("soundsEnabled")           private var soundsEnabled: Bool    = true
    @AppStorage("hapticsEnabled")          private var hapticsEnabled: Bool   = true

    @State private var appeared           = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var showResetConfirm   = false
    @State private var showLogoutConfirm  = false
    @State private var selectedPreviewCourse: Course? = nil
    @State private var showSiri           = false
    @State private var showScanner        = false
    @State private var showAttendance     = false
    @State private var focusActive        = false
    @State private var showShareSheet     = false
    @State private var shareText          = ""
    @State private var showBackup         = false
    @State private var showCampusMap      = false
    @State private var expandedSection: SettingsSection? = nil

    enum SettingsSection: String, CaseIterable {
        case profile, apariencia, herramientas, campus, moodle, acercaDe
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // ── Hero Header ──────────────────────────────────
                settingsHeader
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(DS.Anim.easeSlow, value: appeared)

                // ── Quick Stats Grid ─────────────────────────────
                quickStatsGrid
                    .padding(.horizontal, DS.Space.md)
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(DS.Anim.spring.delay(0.06), value: appeared)

                // ── Apariencia (barra compacta de 3 opciones) ────
                SectionLabel(text: "APARIENCIA Y PERSONALIZACIÓN")
                appearanceAndPersonalizationCard
                    .padding(.horizontal, DS.Space.md)
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.spring.delay(0.08), value: appeared)

                // ── Dynamic Island ────────────────────────────────
                SectionLabel(text: "DYNAMIC ISLAND")
                dynamicIslandCard
                    .padding(.horizontal, DS.Space.md)
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.spring.delay(0.10), value: appeared)

                // ── Herramientas 2×3 Grid ────────────────────────
                SectionLabel(text: "HERRAMIENTAS")
                toolsGrid
                    .padding(.horizontal, DS.Space.md)
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.spring.delay(0.12), value: appeared)

                // ── Campus Map ───────────────────────────────────
                SectionLabel(text: "CAMPUS UAM")
                campusCard
                    .padding(.horizontal, DS.Space.md)
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.spring.delay(0.14), value: appeared)

                // ── Moodle ───────────────────────────────────────
                SectionLabel(text: "MOODLE")
                MoodleSettingsSection()
                    .padding(.horizontal, DS.Space.md)
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.spring.delay(0.15), value: appeared)

                // ── Acerca de ────────────────────────────────────
                SectionLabel(text: "ACERCA DE")
                aboutCard
                    .padding(.horizontal, DS.Space.md)
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.spring.delay(0.16), value: appeared)

                // ── Acciones ─────────────────────────────────────
                accountActions
                    .padding(.horizontal, DS.Space.md)
                    .padding(.bottom, 110)
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.spring.delay(0.18), value: appeared)
            }
        }
        .background(Color.appBackground)
        .onAppear { appeared = true }
        .sheet(isPresented: $showAttendance) {
            AttendanceView()
                .environmentObject(store)
                .environmentObject(attendance)
        }
        .sheet(isPresented: $showSiri)     { SiriShortcutsView().environmentObject(store) }
        .sheet(isPresented: $showScanner)  { ScheduleScannerView().environmentObject(store) }
        .sheet(isPresented: $showBackup)   { ScheduleBackupView().environmentObject(store) }
        .sheet(isPresented: $showCampusMap) { UAMRouteView().environmentObject(store) }
        .sheet(isPresented: $showShareSheet) { ShareSheet(text: shareText) }
    }

    // MARK: - Settings Header (Perfil Hero)

    var settingsHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Fondo degradado sutil con textura
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [DS.Color.wine.opacity(0.12), Color.appBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 160)

            HStack(alignment: .bottom, spacing: DS.Space.md) {
                // Avatar con botón de edición
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        ProfileAvatar(size: 66)
                            .shadow(color: DS.Color.wine.opacity(0.25), radius: 12, x: 0, y: 4)
                        Circle()
                            .fill(DS.Color.wine)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 2, y: 2)
                    }
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            profile.profileImageData = data
                            profile.hasPhoto = true
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.name.isEmpty ? "Sin nombre" : profile.name)
                        .font(DS.Font.display(22, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    if !profile.career.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(DS.Color.wine.opacity(0.7))
                            Text(profile.career)
                                .font(DS.Font.body(12))
                                .foregroundStyle(Color.appInkTertiary)
                        }
                    }
                    if !profile.semester.isEmpty {
                        Text(profile.semester)
                            .font(DS.Font.body(11, weight: .medium))
                            .foregroundStyle(DS.Color.wine.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(DS.Color.wineMuted)
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, DS.Space.md)
        }
        .padding(.bottom, DS.Space.sm)
    }

    // MARK: - Quick Stats Grid (2×2)

    var quickStatsGrid: some View {
        VStack(spacing: 10) {
            // Campos editables compactos en grid 2 col
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                CompactEditField(icon: "person.text.rectangle", label: "Nombre", text: $profile.name)
                CompactEditField(icon: "building.columns", label: "Universidad", text: $profile.university)
                CompactEditField(icon: "graduationcap", label: "Carrera", text: $profile.career)
                CompactEditField(icon: "number.square", label: "Semestre", text: $profile.semester)
            }
        }
    }

    // MARK: - Apariencia + Personalización unificados

    var appearanceAndPersonalizationCard: some View {
        VStack(spacing: 0) {
            // Selector de tema — tres botones compactos horizontales
            HStack(spacing: 8) {
                ForEach([("system", "Sistema", "circle.lefthalf.filled"),
                         ("light",  "Claro",   "sun.max.fill"),
                         ("dark",   "Oscuro",  "moon.fill")], id: \.0) { mode, label, icon in
                    let isSelected = colorSchemeRaw == mode
                    Button {
                        withAnimation(DS.Anim.spring) { colorSchemeRaw = mode }
                        Soft.haptic(.light)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(isSelected ? .white : Color.appInkTertiary)
                            Text(label)
                                .font(DS.Font.body(10, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : Color.appInkTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSelected ? DS.Color.wine : Color.appBackgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .animation(DS.Anim.spring, value: isSelected)
                }
            }
            .padding(DS.Space.md)

            Divider().padding(.horizontal, DS.Space.md)

            // Toggles de personalización en 2 columnas
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                MiniToggleCell(icon: "hand.wave", label: "Saludo",
                               color: DS.Color.wine, value: $profile.showGreeting)
                MiniToggleCell(icon: "chart.bar.fill", label: "Progreso día",
                               color: Color(hex: "#1A5C3A"), value: $profile.showProgressBar)
                MiniToggleCell(icon: "rectangle.compress.vertical", label: "Compacto",
                               color: Color(hex: "#1A3A6B"), value: $profile.compactMode)
                // Sonidos
                MiniToggleCell(icon: "speaker.wave.2.fill", label: "Sonidos",
                               color: Color(hex: "#6B4A1A"),
                               value: Binding(
                                get: { soundsEnabled },
                                set: { v in soundsEnabled = v; Soft.haptic(.light); if v { Soft.sound(.toggle) } }
                               ))
            }
            .padding(.bottom, 4)

            // Haptics (ancho completo para el test)
            Divider().padding(.horizontal, DS.Space.md)
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#3A1A6B"))
                    .frame(width: 26, height: 26)
                    .background(Color(hex: "#3A1A6B").opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Text("Vibración (haptics)")
                    .font(DS.Font.body(13))
                    .foregroundStyle(Color.appInk)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { hapticsEnabled },
                    set: { v in hapticsEnabled = v; if v { Soft.haptic(.medium) } }
                ))
                .tint(DS.Color.wine)
                .labelsHidden()
                .scaleEffect(0.85)
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, 11)
        }
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Dynamic Island Card (compacto)

    var dynamicIslandCard: some View {
        VStack(spacing: 0) {
            // Course picker horizontal
            if !store.courses.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(store.courses) { course in
                            let isSel = selectedPreviewCourse?.id == course.id
                            Button {
                                withAnimation(DS.Anim.springFast) {
                                    selectedPreviewCourse = isSel ? nil : course
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color(hex: course.color))
                                        .frame(width: 6, height: 6)
                                    Text(course.code)
                                        .font(DS.Font.body(11, weight: .semibold))
                                        .foregroundStyle(isSel ? .white : Color.appInk)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(isSel ? DS.Color.wine : Color.appBackgroundTertiary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DS.Space.md)
                }
                .padding(.vertical, 10)
                Divider()
            }

            // Preview de la isla
            DynamicIslandPreviewCard(overrideCourse: selectedPreviewCourse)
                .padding(DS.Space.md)

            Divider()

            // Toggles en fila 2 col
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                // Toggle: activar isla
                IslandToggleCell(
                    icon: AppIcons.dynamicIsland,
                    label: "Activar isla",
                    isOn: Binding(
                        get: { liveActivity.isActive },
                        set: { newValue in
                            Soft.haptic(.light); Soft.sound(.toggle)
                            if newValue {
                                let course = selectedPreviewCourse
                                    ?? store.currentClass()?.course
                                    ?? store.nextClass()?.course
                                    ?? store.courses.first
                                guard let c = course else { Soft.sound(.error); return }
                                LiveActivityManager.shared.endAllStale()
                                let session = store.currentClass()?.session
                                    ?? store.nextClass()?.session
                                    ?? c.sessions.first
                                    ?? ClassSession(weekday: Calendar.current.component(.weekday, from: Date()),
                                                    startHour: Calendar.current.component(.hour, from: Date()),
                                                    startMinute: 0,
                                                    endHour: Calendar.current.component(.hour, from: Date()) + 2,
                                                    endMinute: 0)
                                LiveActivityManager.shared.startActivity(for: c, session: session)
                            } else {
                                LiveActivityManager.shared.endActivity()
                            }
                        }
                    ),
                    enabled: liveActivity.areActivitiesPermitted
                )
                // Toggle: modo automático
                IslandToggleCell(
                    icon: AppIcons.smartMode,
                    label: "Modo auto",
                    isOn: Binding(
                        get: { smartMode },
                        set: { v in
                            Soft.haptic(.light); Soft.sound(.toggle)
                            smartMode = v
                            if v { LiveActivityManager.shared.checkAndAutoStart(store: store) }
                        }
                    ),
                    enabled: true
                )
            }

            // Nota
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appInkTertiary)
                Text("El pill negro superior en iPhone 14 Pro y posterior expande la isla.")
                    .font(DS.Font.body(10))
                    .foregroundStyle(Color.appInkTertiary)
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, 9)
        }
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Herramientas Grid (3×2)

    var toolsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ToolGridCell(icon: AppIcons.toolAttendance, label: "Asistencias",
                         color: DS.Color.wine) { showAttendance = true }
            ToolGridCell(icon: AppIcons.toolSiri, label: "Siri",
                         color: Color(hex: "#1A3A6B")) { showSiri = true }
            ToolGridCell(icon: AppIcons.toolBackup, label: "Backup",
                         color: Color(hex: "#1A5C3A")) { showBackup = true }
            ToolGridCell(icon: AppIcons.toolScanner, label: "Escáner",
                         color: Color(hex: "#6B4A1A")) { showScanner = true }
            ToolGridCell(icon: AppIcons.toolShare, label: "Compartir",
                         color: Color(hex: "#3A1A6B")) {
                shareText = buildShareText()
                showShareSheet = true
            }
            // Focus Mode como celda de grid con toggle integrado
            FocusToolCell(isActive: $focusActive)
        }
    }

    // MARK: - Campus Card

    var campusCard: some View {
        Button { showCampusMap = true } label: {
            HStack(spacing: DS.Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(DS.Color.wine.opacity(0.08))
                        .frame(width: 52, height: 52)
                    Image(systemName: "map.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(DS.Color.wine)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Mapa del Campus")
                        .font(DS.Font.body(15, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    Text("Traza y guarda rutas entre puntos del campus UAM")
                        .font(DS.Font.body(12))
                        .foregroundStyle(Color.appInkTertiary)
                        .lineLimit(2)

                    // Preview de rutas guardadas
                    HStack(spacing: 4) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 9))
                            .foregroundStyle(DS.Color.wine.opacity(0.6))
                        Text("Toca para mapear el campus")
                            .font(DS.Font.body(10, weight: .medium))
                            .foregroundStyle(DS.Color.wine.opacity(0.8))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appInkTertiary.opacity(0.4))
            }
            .padding(DS.Space.md)
            .background(Color.appBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(Color.appCardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - About Card (compacto en fila)

    var aboutCard: some View {
        HStack(spacing: 0) {
            AboutChip(label: "App", value: "UAMSchedule")
            Divider().frame(height: 36)
            AboutChip(label: "Versión", value: "2.0")
            Divider().frame(height: 36)
            AboutChip(label: "Build", value: "patch6")
        }
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Account Actions

    var accountActions: some View {
        VStack(spacing: 8) {
            Button { showResetConfirm = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13))
                    Text("Ver introducción de nuevo")
                        .font(DS.Font.body(13, weight: .medium))
                }
                .foregroundStyle(Color.appInkTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.appBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
            .confirmationDialog("¿Ver la introducción de nuevo?", isPresented: $showResetConfirm) {
                Button("Ver introducción") { onboardingDone = false }
                Button("Cancelar", role: .cancel) {}
            }

            Button { showLogoutConfirm = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 13))
                    Text("Cerrar sesión")
                        .font(DS.Font.body(13, weight: .semibold))
                }
                .foregroundStyle(.red.opacity(0.75))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .stroke(Color.red.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .confirmationDialog("Cerrar sesión", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Cerrar sesión", role: .destructive) { profile.logOut() }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }

    // MARK: - Build Share Text (sin cambios)

    func buildShareText() -> String {
        // Genera un enlace de invitacion para compartir la app
        let appStoreURL = "https://apps.apple.com/app/uamschedule"
        let name = profile.name.isEmpty ? "Un estudiante de UAM" : profile.name
        let uniLine = profile.university.isEmpty ? "UAM" : profile.university
        _ = uniLine
        _ = name
        return appStoreURL
    }

    func buildShareTextLegacy() -> String {
        let uniLine = profile.university.isEmpty ? "UAM" : profile.university
        let carLine = profile.career.isEmpty ? "Carrera" : profile.career
        let semLine = profile.semester.isEmpty ? "" : " · \(profile.semester)"
        let days = ["Dom","Lun","Mar","Mie","Jue","Vie","Sab"]
        let colW = (time: 11, code: 10, name: 26, room: 8)
        let totalW = colW.time + colW.code + colW.name + colW.room + 7
        func pad(_ s: String, _ w: Int) -> String {
            s.count < w ? s + String(repeating: " ", count: w - s.count) : String(s.prefix(w))
        }
        func rule(_ w: Int) -> String { String(repeating: "-", count: w) }
        func row(_ t: String, _ c: String, _ n: String, _ r: String) -> String {
            "| \(pad(t,colW.time)) | \(pad(c,colW.code)) | \(pad(n,colW.name)) | \(pad(r,colW.room)) |"
        }
        var lines = ["HORARIO ACADEMICO", "\(uniLine) · \(carLine)\(semLine)", rule(totalW), ""]
        var hasAny = false
        for day in 1...7 {
            let sessions: [(Course, ClassSession)] = store.courses
                .flatMap { c in c.sessions.filter { $0.weekday == day }.map { (c, $0) } }
                .sorted { $0.1.startHour * 60 + $0.1.startMinute < $1.1.startHour * 60 + $1.1.startMinute }
            guard !sessions.isEmpty else { continue }
            hasAny = true
            lines += [days[day-1].uppercased(), rule(totalW), row("HORA","CODIGO","MATERIA","AULA"), rule(totalW)]
            for (c, s) in sessions {
                let room = s.room.trimmingCharacters(in: .whitespaces).isEmpty ? c.room : s.room
                lines.append(row("\(s.startTimeString)-\(s.endTimeString)", c.code, c.name, room))
            }
            lines += [rule(totalW), ""]
        }
        if !hasAny { lines += ["Sin materias registradas.", ""] }
        lines += [rule(totalW), "Generado con UAMSchedule"]
        return lines.joined(separator: "\n")
    }
}

// MARK: - Sub-components del rediseño

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(DS.Font.body(9, weight: .semibold))
            .foregroundStyle(Color.appInkTertiary)
            .tracking(2)
            .padding(.horizontal, DS.Space.md + 4)
            .padding(.bottom, 6)
    }
}

/// Campo editable compacto para la grid de perfil
struct CompactEditField: View {
    let icon: String
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Color.wine.opacity(0.7))
                Text(label.uppercased())
                    .font(DS.Font.body(8, weight: .semibold))
                    .foregroundStyle(Color.appInkTertiary)
                    .tracking(0.8)
            }
            TextField(label, text: $text)
                .font(DS.Font.body(13, weight: .medium))
                .foregroundStyle(Color.appInk)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }
}

/// Toggle celda mini para grid de personalización
struct MiniToggleCell: View {
    let icon: String
    let label: String
    let color: Color
    @Binding var value: Bool

    var body: some View {
        Button {
            withAnimation(DS.Anim.springFast) { value.toggle() }
            Soft.haptic(.light)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(value ? .white : color)
                    .frame(width: 28, height: 28)
                    .background(value ? color : color.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(DS.Font.body(12, weight: .medium))
                        .foregroundStyle(Color.appInk)
                    Text(value ? "Activo" : "Inactivo")
                        .font(DS.Font.body(9))
                        .foregroundStyle(value ? color : Color.appInkTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
    }
}

/// Toggle celda para la sección de Dynamic Island
struct IslandToggleCell: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool
    let enabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isOn ? DS.Color.wine : Color.appInkTertiary)
                .frame(width: 26, height: 26)
                .background(isOn ? DS.Color.wineMuted : Color.appBackgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            Text(label)
                .font(DS.Font.body(12))
                .foregroundStyle(enabled ? Color.appInk : Color.appInkTertiary)
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(DS.Color.wine)
                .labelsHidden()
                .scaleEffect(0.8)
                .disabled(!enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

/// Celda de herramienta en grid 3×N
struct ToolGridCell: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(label)
                    .font(DS.Font.body(11, weight: .medium))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.appBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .stroke(Color.appCardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Celda de Focus Mode (toggle en grid)
struct FocusToolCell: View {
    @Binding var isActive: Bool

    var body: some View {
        Button {
            withAnimation(DS.Anim.springFast) { isActive.toggle() }
            if isActive { FocusModeManager.shared.enableBreakthrough() }
            else        { FocusModeManager.shared.disableBreakthrough() }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: isActive ? "moon.fill" : "moon")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isActive ? .white : Color(hex: "#1A5A6B"))
                    .frame(width: 44, height: 44)
                    .background(isActive ? Color(hex: "#1A5A6B") : Color(hex: "#1A5A6B").opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("Enfoque")
                    .font(DS.Font.body(11, weight: .medium))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.appBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .stroke(isActive ? Color(hex: "#1A5A6B").opacity(0.3) : Color.appCardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Chip de info para la fila "Acerca de"
struct AboutChip: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(DS.Font.body(13, weight: .semibold))
                .foregroundStyle(Color.appInk)
            Text(label)
                .font(DS.Font.body(9))
                .foregroundStyle(Color.appInkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - Componentes no modificados (compartidos con la versión anterior)

struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct DynamicIslandPreviewCard: View {
    @EnvironmentObject var store: ScheduleStore
    let overrideCourse: Course?
    @State private var expanded = false
    @State private var pulse    = false

    var activeCourse: Course? { overrideCourse ?? store.currentClass()?.course ?? store.nextClass()?.course ?? store.courses.first }
    var activeSession: ClassSession? {
        overrideCourse.flatMap { $0.sessions.first }
            ?? store.currentClass()?.session ?? store.nextClass()?.session ?? store.courses.first?.sessions.first
    }
    var courseName:  String { activeCourse?.name  ?? "Sin materias" }
    var courseRoom:  String { activeCourse?.room  ?? "" }
    var courseColor: String { activeCourse?.color ?? "#6B1A2A" }
    var startTime:   String { activeSession?.startTimeString ?? "8:00 AM" }
    var endTime:     String { activeSession?.endTimeString   ?? "10:00 AM" }
    var minutesLeft: Int {
        guard let s = activeSession else { return 45 }
        let cal = Calendar.current; let now = Date()
        let nowMin = cal.component(.hour, from: now)*60+cal.component(.minute, from: now)
        let left = s.endHour*60+s.endMinute - nowMin
        return left > 0 ? left : max(1, s.durationMinutes)
    }
    var progress: Double {
        guard let s = activeSession else { return 0.35 }
        let cal = Calendar.current; let now = Date()
        let nowMin = cal.component(.hour, from: now)*60+cal.component(.minute, from: now)
        let start = s.startHour*60+s.startMinute; let end = s.endHour*60+s.endMinute
        let p = Double(nowMin-start)/Double(max(1,end-start))
        return p>0&&p<1 ? p : 0.35
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("PREVISUALIZACIÓN").font(DS.Font.body(8, weight: .bold)).foregroundStyle(Color.appInkTertiary).tracking(2)
                Spacer()
                HStack(spacing: 4) {
                    Text("Toca la isla").font(DS.Font.body(9)).foregroundStyle(Color.appInkTertiary)
                    Image(systemName: "hand.tap").font(.system(size: 9)).foregroundStyle(Color.appInkTertiary)
                }
            }
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "#111111"))
                    .frame(height: expanded ? 160 : 100)
                    .animation(DS.Anim.spring, value: expanded)
                VStack(spacing: 0) {
                    HStack {
                        Text("9:41").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "wifi").font(.system(size: 9))
                            Image(systemName: "battery.100").font(.system(size: 9))
                        }.foregroundStyle(.white)
                    }.padding(.horizontal, 18).padding(.top, 10)
                    Button { withAnimation(DS.Anim.spring) { expanded.toggle() } } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: expanded ? 26 : 34, style: .continuous)
                                .fill(Color.black)
                                .frame(width: expanded ? 260 : 120, height: expanded ? 88 : 32)
                                .animation(DS.Anim.spring, value: expanded)
                                .shadow(color: .black.opacity(0.5), radius: 8)
                            if expanded {
                                VStack(spacing: 5) {
                                    HStack(spacing: 8) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(courseRoom).font(.system(size: 8, weight: .black)).foregroundStyle(Color(hex: courseColor)).tracking(1.5)
                                            Text(courseName).font(.system(size: 12, weight: .bold, design: .serif)).foregroundStyle(.white).lineLimit(1)
                                            Text(startTime+" – "+endTime).font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                        VStack(alignment: .trailing, spacing: 1) {
                                            Text("\(minutesLeft)m").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(Color(hex: courseColor))
                                            Text("restantes").font(.system(size: 7)).foregroundStyle(.white.opacity(0.35))
                                        }
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.white.opacity(0.1)).frame(height: 3)
                                            Capsule().fill(Color(hex: courseColor)).frame(width: geo.size.width * progress, height: 3)
                                        }
                                    }.frame(height: 3)
                                }.padding(.horizontal, 14).padding(.vertical, 10).transition(.opacity.combined(with: .scale(scale: 0.95)))
                            } else {
                                HStack(spacing: 7) {
                                    Circle().fill(Color(hex: courseColor)).frame(width: 7, height: 7)
                                        .scaleEffect(pulse ? 1.3 : 1.0)
                                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                                    Text(courseName).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white).lineLimit(1).frame(maxWidth: 72)
                                    Spacer()
                                    Text("\(minutesLeft)m").font(.system(size: 12, weight: .black, design: .rounded)).foregroundStyle(Color(hex: courseColor))
                                }.padding(.horizontal, 12).frame(width: 120).transition(.opacity)
                            }
                        }.animation(DS.Anim.spring, value: expanded)
                    }.buttonStyle(.plain).padding(.top, 6)
                    Spacer()
                }
            }
            Text(expanded ? "Toca para contraer" : "Toca para ver la vista expandida")
                .font(DS.Font.body(9)).foregroundStyle(Color.appInkTertiary).animation(DS.Anim.ease, value: expanded)
        }
        .onAppear { pulse = true }
        .onChange(of: activeCourse?.id) { _, _ in withAnimation(DS.Anim.springFast) { expanded = false } }
    }
}

struct MoodleSettingsSection: View {
    @ObservedObject private var moodle = MoodleStore.shared
    @State private var showLogin  = false
    @State private var showLogout = false
    var body: some View {
        VStack(spacing: 0) {
            if moodle.isConnected {
                HStack(spacing: DS.Space.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .fill(Color(hex: "#1A5C3A").opacity(0.07)).frame(width: 38, height: 38)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color(hex: "#1A5C3A"))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Moodle conectado").font(DS.Font.body(14, weight: .semibold)).foregroundStyle(Color.appInk)
                        Text("CIF \(moodle.cif)  ·  \(moodle.lastSyncString)").font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary)
                        if let result = moodle.lastImportResult {
                            Text(result.summary).font(DS.Font.body(10)).foregroundStyle(Color(hex: "#1A5C3A"))
                        }
                    }
                    Spacer()
                    if moodle.isLoading {
                        ProgressView().scaleEffect(0.8).tint(DS.Color.wine)
                    } else {
                        Button { Task { await moodle.sync() } } label: {
                            Image(systemName: "arrow.clockwise").font(.system(size: 14, weight: .semibold)).foregroundStyle(DS.Color.wine)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.md)
                Divider().padding(.leading, DS.Space.md)
                Button { showLogout = true } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 14)).foregroundStyle(.red.opacity(0.75)).frame(width: 20)
                        Text("Desconectar Moodle").font(DS.Font.body(14)).foregroundStyle(.red.opacity(0.75))
                        Spacer()
                    }.padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.md)
                }
                .buttonStyle(.plain)
                .confirmationDialog("¿Desconectar Moodle?", isPresented: $showLogout) {
                    Button("Desconectar", role: .destructive) { moodle.logout() }
                    Button("Cancelar", role: .cancel) {}
                } message: { Text("Se eliminarán el token y tus datos de Moodle del dispositivo.") }
            } else {
                HStack(spacing: DS.Space.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .fill(DS.Color.wineMuted).frame(width: 38, height: 38)
                        Image(systemName: "graduationcap").font(.system(size: 17, weight: .medium)).foregroundStyle(DS.Color.wine)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Moodle no conectado").font(DS.Font.body(14, weight: .semibold)).foregroundStyle(Color.appInk)
                        Text("Conecta para ver tareas y calificaciones").font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary)
                    }
                    Spacer()
                    Button { showLogin = true } label: {
                        Text("Conectar").font(DS.Font.body(12, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, DS.Space.md).padding(.vertical, 7)
                            .background(DS.Color.wine).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.md)
            }
        }
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
        .sheet(isPresented: $showLogin) { MoodleLoginView() }
    }
}
