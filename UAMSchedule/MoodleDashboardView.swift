import SwiftUI

// ─────────────────────────────────────────────────
// MARK: - Assignment view helpers (capa de vista)
// ─────────────────────────────────────────────────

extension MoodleAssignment {

    /// Color de acento segun estado.
    var accentColor: Color {
        if isSubmitted   { return Color(hex: "#1A5C3A") }
        if noSubmissions { return Color.appInkTertiary }
        if isOverdue     { return Color(hex: "#CC1A1A") }
        if isDueSoon     { return Color(hex: "#8B5A1A") }
        return DS.Color.wine
    }

    var statusIcon: String {
        if isSubmitted   { return "checkmark.circle.fill" }
        if noSubmissions { return "eye.fill" }
        if isOverdue     { return "exclamationmark.triangle.fill" }
        if isDueSoon     { return "clock.fill" }
        return "doc.text.fill"
    }

    var statusLabel: String {
        if isSubmitted   { return "Enviada" }
        if noSubmissions { return "Solo ver" }
        if isOverdue     { return "Vencida" }
        if isDueSoon     { return "Proxima" }
        return "Pendiente"
    }

    /// Fecha relativa compacta: Hoy / Manana / En 3 d / Hace 2 d / Sin fecha.
    var relativeDue: String {
        guard let d = dueDate else { return "Sin fecha" }
        let cal = Calendar.current
        if cal.isDateInToday(d)    { return "Hoy" }
        if cal.isDateInTomorrow(d) { return "Manana" }
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: Date()),
            to: cal.startOfDay(for: d)
        ).day ?? 0
        if days < 0 { return "Hace \(-days) d" }
        return "En \(days) d"
    }
}

// ─────────────────────────────────────────────────
// MARK: - Moodle Dashboard
// ─────────────────────────────────────────────────

struct MoodleDashboardView: View {
    @ObservedObject private var moodle    = MoodleStore.shared
    @ObservedObject private var messaging = MoodleMessagingStore.shared
    @State private var appeared    = false
    @State private var showLogin   = false
    @State private var activeFilter: DashboardFilter = .resumen

    enum DashboardFilter: String, CaseIterable {
        case resumen  = "Resumen"
        case proximas = "Proximas"
        case vencidas = "Vencidas"
        case tareas   = "Tareas"
        case cursos   = "Cursos"
        case mensajes = "Mensajes"
    }

    // ── Listas derivadas ──────────────────────────

    private var overdueList: [MoodleAssignment] {
        moodle.assignments.filter { $0.isOverdue }
    }
    private var upcomingList: [MoodleAssignment] {
        moodle.assignments
            .filter { !$0.isOverdue && !$0.isSubmitted && !$0.noSubmissions && $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }
    private var allTasksList: [MoodleAssignment] {
        moodle.assignments
            .filter { !$0.noSubmissions }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }
    private var dueTodayCount: Int {
        moodle.assignments.filter {
            guard let d = $0.dueDate else { return false }
            return Calendar.current.isDateInToday(d) && !$0.noSubmissions && !$0.isSubmitted
        }.count
    }
    private var submittedCount: Int {
        moodle.assignments.filter { $0.isSubmitted }.count
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Header fijo ───────────────────────────
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, DS.Space.lg)
                    .padding(.top, 18)
                    .padding(.bottom, DS.Space.md)
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.easeSlow, value: appeared)

                if moodle.isConnected {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Space.sm) {
                            ForEach(DashboardFilter.allCases, id: \.self) { f in
                                DashPill(
                                    filter: f,
                                    isActive: activeFilter == f,
                                    moodle: moodle,
                                    messaging: messaging
                                ) {
                                    withAnimation(DS.Anim.springFast) { activeFilter = f }
                                }
                            }
                        }
                        .padding(.horizontal, DS.Space.md)
                        .padding(.bottom, DS.Space.sm)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.easeSlow.delay(0.06), value: appeared)
                }

                Rectangle().fill(Color.appSeparator).frame(height: 0.5)
            }
            .background(Color.appBackground)

            // ── Contenido ─────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    if !moodle.isConnected {
                        MoodleConnectCTA()
                            .padding(.horizontal, DS.Space.md)
                            .padding(.top, DS.Space.xl)
                            .opacity(appeared ? 1 : 0)
                            .animation(DS.Anim.easeSlow.delay(0.1), value: appeared)

                    } else if moodle.isLoading && moodle.assignments.isEmpty {
                        LoadingBlock(text: "Sincronizando con Moodle...")

                    } else if moodle.assignments.isEmpty && !moodle.isLoading {
                        EmptyBlock(
                            icon: "tray",
                            title: "Sin entregas en Moodle",
                            sub: "Sincroniza para obtener los datos mas recientes."
                        )
                        .opacity(appeared ? 1 : 0)
                        .animation(DS.Anim.easeSlow.delay(0.12), value: appeared)

                    } else {
                        switch activeFilter {
                        case .resumen:
                            ResumenView(
                                moodle: moodle,
                                overdue: overdueList.count,
                                dueToday: dueTodayCount,
                                upcoming: upcomingList.count,
                                submitted: submittedCount,
                                nextUp: Array((overdueList + upcomingList).prefix(6)),
                                appeared: appeared,
                                onJump: { f in withAnimation(DS.Anim.springFast) { activeFilter = f } }
                            )
                        case .proximas:
                            FilteredListView(
                                assignments: upcomingList,
                                emptyIcon: "calendar.badge.checkmark",
                                emptyTitle: "Sin entregas proximas",
                                emptySub: "No hay tareas pendientes con fecha futura.",
                                appeared: appeared
                            )
                        case .vencidas:
                            FilteredListView(
                                assignments: overdueList,
                                emptyIcon: "checkmark.seal.fill",
                                emptyTitle: "Sin tareas vencidas",
                                emptySub: "Todo al dia. No tienes entregas sin enviar.",
                                emptyIconColor: Color(hex: "#1A5C3A"),
                                appeared: appeared
                            )
                        case .tareas:
                            FilteredListView(
                                assignments: allTasksList,
                                emptyIcon: "doc.text",
                                emptyTitle: "Sin tareas registradas",
                                emptySub: "No hay entregas en ningun curso.",
                                appeared: appeared
                            )
                        case .cursos:
                            CursosFilterView(moodle: moodle, appeared: appeared)
                        case .mensajes:
                            MoodleInboxView(messaging: messaging, appeared: appeared)
                        }
                    }

                    Spacer().frame(height: 120)
                }
            }
        }
        .background(Color.appBackground)
        .onAppear {
            appeared = true
            if moodle.isConnected {
                moodle.syncIfConnected()
                Task {
                    if let tok = UserDefaults.standard.string(forKey: "moodle_token") {
                        await messaging.sync(token: tok)
                    }
                }
            }
        }
        .sheet(isPresented: $showLogin) { MoodleLoginView() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("UAM VIRTUAL")
                    .font(DS.Font.body(9, weight: .semibold))
                    .foregroundStyle(DS.Color.wine)
                    .tracking(3)
                Text("Moodle")
                    .font(DS.Font.display(34, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                WineAccentLine(height: 1.5, width: 36).padding(.top, 3)

                HStack(spacing: 6) {
                    Circle()
                        .fill(moodle.isConnected ? Color(hex: "#1A5C3A") : Color.appInkTertiary)
                        .frame(width: 6, height: 6)
                    if moodle.isConnected {
                        Text("CIF \(moodle.cif)  ·  \(moodle.lastSyncString)")
                            .font(DS.Font.body(11))
                            .foregroundStyle(Color.appInkTertiary)
                    } else {
                        Text("No conectado")
                            .font(DS.Font.body(11))
                            .foregroundStyle(Color.appInkTertiary)
                    }
                }
                .padding(.top, 4)
            }

            Spacer()

            if moodle.isConnected {
                Button { Task { await moodle.sync() } } label: {
                    ZStack {
                        Circle().fill(DS.Color.wineMuted).frame(width: 42, height: 42)
                        if moodle.isLoading {
                            ProgressView().tint(DS.Color.wine).scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(DS.Color.wine)
                        }
                    }
                    .overlay(Circle().stroke(DS.Color.wine.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(moodle.isLoading)
            } else {
                Button { showLogin = true } label: {
                    Text("Conectar")
                        .font(DS.Font.body(13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Space.md)
                        .padding(.vertical, 10)
                        .background(DS.Color.wine)
                        .clipShape(Capsule())
                        .shadow(color: DS.Color.wine.opacity(0.3), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: - Shared blocks (loading / empty)
// ─────────────────────────────────────────────────

private struct LoadingBlock: View {
    let text: String
    var body: some View {
        VStack(spacing: DS.Space.md) {
            ProgressView().tint(DS.Color.wine)
            Text(text)
                .font(DS.Font.body(13))
                .foregroundStyle(Color.appInkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }
}

private struct EmptyBlock: View {
    let icon: String
    let title: String
    let sub: String
    var iconColor: Color = Color.appInkTertiary.opacity(0.4)
    var body: some View {
        VStack(spacing: DS.Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(iconColor)
            Text(title)
                .font(DS.Font.body(15, weight: .semibold))
                .foregroundStyle(Color.appInkSecondary)
            Text(sub)
                .font(DS.Font.body(12))
                .foregroundStyle(Color.appInkTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
        .padding(.horizontal, DS.Space.lg)
    }
}

// ─────────────────────────────────────────────────
// MARK: - Dashboard Filter Pill
// ─────────────────────────────────────────────────

private struct DashPill: View {
    let filter: MoodleDashboardView.DashboardFilter
    let isActive: Bool
    @ObservedObject var moodle: MoodleStore
    @ObservedObject var messaging: MoodleMessagingStore
    let action: () -> Void

    private var icon: String {
        switch filter {
        case .resumen:  return "square.grid.2x2.fill"
        case .proximas: return "clock.fill"
        case .vencidas: return "exclamationmark.triangle.fill"
        case .tareas:   return "doc.text.fill"
        case .cursos:   return "books.vertical.fill"
        case .mensajes: return "bubble.left.fill"
        }
    }

    private var badge: Int? {
        switch filter {
        case .resumen:  return nil
        case .proximas: return moodle.dueSoonAssignments.count > 0 ? moodle.dueSoonAssignments.count : nil
        case .vencidas: return moodle.overdueAssignments.count > 0 ? moodle.overdueAssignments.count : nil
        case .tareas:   return moodle.assignments.filter { !$0.noSubmissions }.count
        case .cursos:   return moodle.moodleCourses.count > 0 ? moodle.moodleCourses.count : nil
        case .mensajes: return messaging.totalUnread > 0 ? messaging.totalUnread : nil
        }
    }

    private var isAlert: Bool {
        filter == .vencidas && moodle.overdueAssignments.count > 0
    }
    private var activeColor: Color { isAlert ? Color(hex: "#CC1A1A") : DS.Color.wine }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActive ? .white : (isAlert ? Color(hex: "#CC1A1A") : DS.Color.wine.opacity(0.75)))
                Text(filter.rawValue)
                    .font(DS.Font.body(12, weight: isActive ? .bold : .medium))
                    .foregroundStyle(isActive ? .white : Color.appInkSecondary)
                if let b = badge {
                    Text("\(b)")
                        .font(DS.Font.mono(10, weight: .semibold))
                        .foregroundStyle(isActive ? .white.opacity(0.85) : (isAlert ? Color(hex: "#CC1A1A") : DS.Color.wine))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            isActive
                                ? Color.white.opacity(0.22)
                                : (isAlert ? Color(hex: "#CC1A1A").opacity(0.12) : DS.Color.wine.opacity(0.10))
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, 8)
            .background(isActive ? activeColor : Color.appBackgroundSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    isActive ? Color.clear : (isAlert ? Color(hex: "#CC1A1A").opacity(0.25) : Color.appCardBorder),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────
// MARK: - Resumen View
// ─────────────────────────────────────────────────

private struct ResumenView: View {
    @ObservedObject var moodle: MoodleStore
    let overdue: Int
    let dueToday: Int
    let upcoming: Int
    let submitted: Int
    let nextUp: [MoodleAssignment]
    let appeared: Bool
    let onJump: (MoodleDashboardView.DashboardFilter) -> Void

    private var totalSubmittable: Int {
        moodle.assignments.filter { !$0.noSubmissions }.count
    }
    private var progress: Double {
        totalSubmittable == 0 ? 0 : Double(submitted) / Double(totalSubmittable)
    }
    private var allClear: Bool { overdue == 0 && dueToday == 0 && upcoming == 0 }

    private let cols = [GridItem(.flexible(), spacing: DS.Space.sm),
                        GridItem(.flexible(), spacing: DS.Space.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {

            // ── Tiles de metricas ─────────────────────
            LazyVGrid(columns: cols, spacing: DS.Space.sm) {
                DashboardStatTile(value: overdue, label: "Vencidas",
                         icon: "exclamationmark.triangle.fill",
                         tint: Color(hex: "#CC1A1A")) { onJump(.vencidas) }
                DashboardStatTile(value: dueToday, label: "Para hoy",
                         icon: "calendar.badge.exclamationmark",
                         tint: Color(hex: "#8B5A1A")) { onJump(.tareas) }
                DashboardStatTile(value: upcoming, label: "Proximas",
                         icon: "clock.fill",
                         tint: DS.Color.wine) { onJump(.proximas) }
                DashboardStatTile(value: submitted, label: "Entregadas",
                         icon: "checkmark.circle.fill",
                         tint: Color(hex: "#1A5C3A")) { onJump(.tareas) }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(DS.Anim.easeSlow.delay(0.08), value: appeared)

            // ── Progreso del semestre ─────────────────
            if totalSubmittable > 0 {
                ProgressCard(done: submitted, total: totalSubmittable, progress: progress)
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.spring.delay(0.14), value: appeared)
            }

            // ── Al dia ────────────────────────────────
            if allClear {
                MoodleAllGoodBanner()
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.easeSlow.delay(0.16), value: appeared)
            }

            // ── Lo siguiente ──────────────────────────
            if !nextUp.isEmpty {
                CompactSection(
                    title: "LO SIGUIENTE",
                    icon: "arrow.forward.circle.fill",
                    color: DS.Color.wine,
                    count: nextUp.count,
                    assignments: nextUp,
                    appeared: appeared,
                    startDelay: 0.18
                )
                Button { onJump(.tareas) } label: {
                    HStack(spacing: 5) {
                        Text("Ver todas las tareas")
                            .font(DS.Font.body(12, weight: .semibold))
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(DS.Color.wine)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(DS.Color.wineMuted)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .animation(DS.Anim.easeSlow.delay(0.24), value: appeared)
            }

            // ── Sin fecha / solo ver ──────────────────
            let infoOnly = moodle.assignments.filter { $0.dueDate == nil || $0.noSubmissions }
            if !infoOnly.isEmpty {
                CompactSection(
                    title: "SIN FECHA · SOLO VER",
                    icon: "eye.fill",
                    color: Color.appInkTertiary,
                    count: infoOnly.count,
                    assignments: infoOnly,
                    appeared: appeared,
                    startDelay: 0.26,
                    collapsedByDefault: true
                )
            }
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.top, DS.Space.md)
    }
}

// MARK: - DashboardStatTile

private struct DashboardStatTile: View {
    let value: Int
    let label: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(tint.opacity(0.12))
                            .frame(width: 30, height: 30)
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.appInkTertiary.opacity(0.5))
                }
                Text("\(value)")
                    .font(DS.Font.mono(28, weight: .semibold))
                    .foregroundStyle(value > 0 ? tint : Color.appInk)
                Text(label.uppercased())
                    .font(DS.Font.body(9, weight: .semibold))
                    .foregroundStyle(Color.appInkTertiary)
                    .tracking(1.5)
            }
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(value > 0 ? tint.opacity(0.20) : Color.appCardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Progress Card

private struct ProgressCard: View {
    let done: Int
    let total: Int
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Color.wine)
                    Text("AVANCE DEL SEMESTRE")
                        .font(DS.Font.body(9, weight: .semibold))
                        .foregroundStyle(Color.appInkTertiary)
                        .tracking(2)
                }
                Spacer()
                Text("\(done) / \(total)")
                    .font(DS.Font.mono(12, weight: .semibold))
                    .foregroundStyle(Color.appInk)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appBackgroundTertiary)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [DS.Color.wine, DS.Color.wineLight],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * progress), height: 8)
                        .animation(DS.Anim.easeSlow, value: progress)
                }
            }
            .frame(height: 8)

            Text("\(Int(progress * 100))% de las entregas completadas")
                .font(DS.Font.body(11))
                .foregroundStyle(Color.appInkTertiary)
        }
        .padding(DS.Space.md)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }
}

// ─────────────────────────────────────────────────
// MARK: - Compact Assignment Row
// ─────────────────────────────────────────────────

struct CompactAssignmentRow: View {
    let assignment: MoodleAssignment
    @State private var expanded = false

    private var hasIntro: Bool {
        !assignment.intro.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if hasIntro { withAnimation(DS.Anim.springFast) { expanded.toggle() } }
            } label: {
                HStack(spacing: DS.Space.sm) {
                    // Icono de estado
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(assignment.accentColor.opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: assignment.statusIcon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(assignment.accentColor)
                    }

                    // Titulo + meta
                    VStack(alignment: .leading, spacing: 3) {
                        Text(assignment.name)
                            .font(DS.Font.body(13.5, weight: .semibold))
                            .foregroundStyle(assignment.isSubmitted ? Color.appInkTertiary : Color.appInk)
                            .strikethrough(assignment.isSubmitted, color: Color.appInkTertiary)
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            Text(assignment.courseName)
                                .font(DS.Font.body(10))
                                .foregroundStyle(Color.appInkTertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: DS.Space.sm)

                    // Estado + fecha
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(assignment.statusLabel.uppercased())
                            .font(DS.Font.body(8, weight: .bold))
                            .foregroundStyle(assignment.accentColor)
                            .tracking(0.5)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(assignment.accentColor.opacity(0.10))
                            .clipShape(Capsule())

                        if assignment.dueDate != nil && !assignment.noSubmissions {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 8))
                                Text(assignment.relativeDue)
                                    .font(DS.Font.mono(10, weight: .medium))
                            }
                            .foregroundStyle(assignment.accentColor)
                        }
                    }

                    if hasIntro {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.appInkTertiary.opacity(0.5))
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                }
                .padding(DS.Space.sm + 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded && hasIntro {
                Text(assignment.intro)
                    .font(DS.Font.body(12))
                    .foregroundStyle(Color.appInkSecondary)
                    .lineSpacing(3)
                    .padding(.horizontal, DS.Space.sm + 2)
                    .padding(.bottom, DS.Space.sm + 2)
                    .padding(.leading, 34 + DS.Space.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            assignment.isOverdue ? Color(hex: "#CC1A1A").opacity(0.035)
            : (assignment.isSubmitted ? Color(hex: "#1A5C3A").opacity(0.04) : Color.appBackgroundSecondary)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .stroke(
                    assignment.isOverdue ? Color(hex: "#CC1A1A").opacity(0.22) : Color.appCardBorder,
                    lineWidth: 1
                )
        )
    }
}

// ─────────────────────────────────────────────────
// MARK: - Compact Section (header + filas)
// ─────────────────────────────────────────────────

private struct CompactSection: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int
    let assignments: [MoodleAssignment]
    let appeared: Bool
    var startDelay: Double = 0.10
    var collapsedByDefault: Bool = false

    @State private var expanded: Bool

    init(title: String, icon: String, color: Color, count: Int,
         assignments: [MoodleAssignment], appeared: Bool,
         startDelay: Double = 0.10, collapsedByDefault: Bool = false) {
        self.title = title; self.icon = icon; self.color = color
        self.count = count; self.assignments = assignments
        self.appeared = appeared; self.startDelay = startDelay
        self.collapsedByDefault = collapsedByDefault
        _expanded = State(initialValue: !collapsedByDefault)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Button {
                withAnimation(DS.Anim.springFast) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(color)
                    Text(title)
                        .font(DS.Font.body(9, weight: .bold))
                        .foregroundStyle(color)
                        .tracking(2)
                    Text("\(count)")
                        .font(DS.Font.mono(9, weight: .semibold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.appInkTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 6) {
                    ForEach(Array(assignments.enumerated()), id: \.element.id) { i, a in
                        CompactAssignmentRow(assignment: a)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 6)
                            .animation(DS.Anim.easeSlow.delay(startDelay + Double(i) * 0.025), value: appeared)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DS.Space.sm + 2)
        .background(color.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(color.opacity(0.12), lineWidth: 1)
        )
    }
}

// Conservado para compatibilidad externa (mismo nombre, version compacta).
struct MoodleDueSection: View {
    let title: String
    let icon: String
    let color: Color
    let assignments: [MoodleAssignment]

    var body: some View {
        CompactSection(
            title: title, icon: icon, color: color,
            count: assignments.count, assignments: assignments,
            appeared: true
        )
    }
}

// ─────────────────────────────────────────────────
// MARK: - Filtered List (Proximas / Vencidas / Tareas)
// ─────────────────────────────────────────────────

private struct FilteredListView: View {
    let assignments: [MoodleAssignment]
    let emptyIcon: String
    let emptyTitle: String
    let emptySub: String
    var emptyIconColor: Color = Color.appInkTertiary.opacity(0.5)
    let appeared: Bool

    var body: some View {
        VStack(spacing: 6) {
            if assignments.isEmpty {
                EmptyBlock(icon: emptyIcon, title: emptyTitle, sub: emptySub, iconColor: emptyIconColor)
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.easeSlow.delay(0.10), value: appeared)
            } else {
                ForEach(Array(assignments.enumerated()), id: \.element.id) { i, a in
                    CompactAssignmentRow(assignment: a)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 6)
                        .animation(DS.Anim.easeSlow.delay(0.08 + Double(i) * 0.025), value: appeared)
                }
            }
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.top, DS.Space.md)
    }
}

// ─────────────────────────────────────────────────
// MARK: - Cursos
// ─────────────────────────────────────────────────

private struct CursosFilterView: View {
    @ObservedObject var moodle: MoodleStore
    let appeared: Bool
    @State private var selectedCourse: MoodleCourse? = nil

    private let cols = [GridItem(.flexible(), spacing: DS.Space.sm),
                        GridItem(.flexible(), spacing: DS.Space.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            if moodle.moodleCourses.isEmpty {
                EmptyBlock(
                    icon: "books.vertical",
                    title: "Sin cursos registrados",
                    sub: "Sincroniza para cargar tus materias."
                )
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Color.wine)
                    Text("MATERIAS INSCRITAS")
                        .font(DS.Font.body(9, weight: .bold))
                        .foregroundStyle(Color.appInkTertiary)
                        .tracking(2)
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.top, DS.Space.md)

                LazyVGrid(columns: cols, spacing: DS.Space.sm) {
                    ForEach(Array(moodle.moodleCourses.enumerated()), id: \.element.id) { i, course in
                        MoodleCourseCard(course: course, moodle: moodle)
                            .onTapGesture { selectedCourse = course }
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 8)
                            .animation(DS.Anim.easeSlow.delay(0.08 + Double(i) * 0.03), value: appeared)
                    }
                }
                .padding(.horizontal, DS.Space.md)
            }
        }
        .sheet(item: $selectedCourse) { course in
            MoodleCourseDetailView(course: course)
        }
    }
}

private struct MoodleCourseCard: View {
    let course: MoodleCourse
    @ObservedObject var moodle: MoodleStore

    private var courseAssignments: [MoodleAssignment] {
        moodle.assignments.filter { $0.courseId == course.id }
    }
    private var overdue: Int   { courseAssignments.filter { $0.isOverdue }.count }
    private var upcoming: Int  { courseAssignments.filter { $0.isDueSoon && !$0.isOverdue }.count }
    private var submitted: Int { courseAssignments.filter { $0.isSubmitted }.count }
    private var submittable: Int { courseAssignments.filter { !$0.noSubmissions }.count }
    private var progress: Double {
        submittable == 0 ? 0 : Double(submitted) / Double(submittable)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(DS.Color.wine.opacity(0.10))
                        .frame(width: 32, height: 32)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.Color.wine)
                }
                Spacer()
                if overdue > 0 {
                    statChip("\(overdue)", "exclamationmark.triangle.fill", Color(hex: "#CC1A1A"))
                } else if upcoming > 0 {
                    statChip("\(upcoming)", "clock.fill", Color(hex: "#8B5A1A"))
                } else if submittable > 0 {
                    statChip("\(submitted)/\(submittable)", "checkmark.circle.fill", Color(hex: "#1A5C3A"))
                }
            }

            Text(course.shortname.uppercased())
                .font(DS.Font.body(8, weight: .bold))
                .foregroundStyle(DS.Color.wine.opacity(0.7))
                .tracking(1)
                .lineLimit(1)

            Text(course.fullname)
                .font(DS.Font.body(13, weight: .semibold))
                .foregroundStyle(Color.appInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            if submittable > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.appBackgroundTertiary).frame(height: 5)
                        Capsule()
                            .fill(DS.Color.wine)
                            .frame(width: max(5, geo.size.width * progress), height: 5)
                    }
                }
                .frame(height: 5)
                Text("\(submittable) tarea\(submittable == 1 ? "" : "s")")
                    .font(DS.Font.body(9))
                    .foregroundStyle(Color.appInkTertiary)
            } else {
                Text("Sin tareas")
                    .font(DS.Font.body(9))
                    .foregroundStyle(Color.appInkTertiary)
            }
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(overdue > 0 ? Color(hex: "#CC1A1A").opacity(0.18) : Color.appCardBorder, lineWidth: 1)
        )
    }

    private func statChip(_ text: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
            Text(text).font(DS.Font.mono(10, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// ─────────────────────────────────────────────────
// MARK: - Inbox (Mensajes)
// ─────────────────────────────────────────────────

private struct MoodleInboxView: View {
    @ObservedObject var messaging: MoodleMessagingStore
    let appeared: Bool
    @State private var segment = 0

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack(spacing: 0) {
                InboxSegBtn(label: "Mensajes", icon: "bubble.left.fill",
                            badge: messaging.unreadMessages, active: segment == 0) { segment = 0 }
                InboxSegBtn(label: "Avisos", icon: "bell.fill",
                            badge: messaging.unreadNotifications, active: segment == 1) { segment = 1 }
            }
            .padding(.horizontal, DS.Space.md).padding(.top, DS.Space.md)

            if messaging.isLoading {
                LoadingBlock(text: "Cargando mensajes...")
            } else if segment == 0 {
                if messaging.messages.isEmpty {
                    EmptyBlock(icon: "tray", title: "Sin mensajes directos",
                               sub: "No tienes mensajes sin leer.")
                } else {
                    VStack(spacing: 6) {
                        ForEach(Array(messaging.messages.enumerated()), id: \.element.id) { i, msg in
                            MsgCard(msg: msg) { messaging.markMessageRead(msg.id) }
                                .opacity(appeared ? 1 : 0)
                                .animation(DS.Anim.easeSlow.delay(0.06 + Double(i) * 0.025), value: appeared)
                        }
                    }.padding(.horizontal, DS.Space.md)
                }
            } else {
                if messaging.notifications.isEmpty {
                    EmptyBlock(icon: "bell.slash", title: "Sin avisos",
                               sub: "No tienes notificaciones pendientes.")
                } else {
                    VStack(spacing: 6) {
                        ForEach(Array(messaging.notifications.enumerated()), id: \.element.id) { i, n in
                            NotiCard(noti: n) { messaging.markNotificationRead(n.id) }
                                .opacity(appeared ? 1 : 0)
                                .animation(DS.Anim.easeSlow.delay(0.06 + Double(i) * 0.025), value: appeared)
                        }
                    }.padding(.horizontal, DS.Space.md)
                }
            }
        }
    }
}

private struct InboxSegBtn: View {
    let label: String; let icon: String; let badge: Int; let active: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(active ? DS.Color.wine : Color.appInkTertiary)
                    Text(label)
                        .font(DS.Font.body(13, weight: active ? .bold : .regular))
                        .foregroundStyle(active ? DS.Color.wine : Color.appInkTertiary)
                    if badge > 0 {
                        Text("\(badge)").font(DS.Font.mono(9, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color(hex: "#CC1A1A")).clipShape(Capsule())
                    }
                }
                Rectangle()
                    .fill(active ? DS.Color.wine : Color.clear)
                    .frame(height: 2).clipShape(Capsule())
            }
        }.buttonStyle(.plain).frame(maxWidth: .infinity)
    }
}

private struct MsgCard: View {
    let msg: MoodleMessage
    let onTap: () -> Void
    @State private var showReply = false

    var body: some View {
        Button { showReply = true; onTap() } label: {
            HStack(alignment: .top, spacing: DS.Space.sm) {
                ZStack {
                    Circle().fill(DS.Color.wine.opacity(0.10)).frame(width: 38, height: 38)
                    Text(String(msg.fromName.prefix(1)).uppercased())
                        .font(DS.Font.display(15, weight: .semibold))
                        .foregroundStyle(DS.Color.wine)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(msg.fromName)
                            .font(DS.Font.body(13, weight: msg.isRead ? .medium : .bold))
                            .foregroundStyle(Color.appInk)
                            .lineLimit(1)
                        Spacer()
                        Text(msg.timeString)
                            .font(DS.Font.mono(10))
                            .foregroundStyle(Color.appInkTertiary)
                        if !msg.isRead {
                            Circle().fill(DS.Color.wine).frame(width: 7, height: 7)
                        }
                    }
                    Text(msg.previewText.isEmpty ? "(sin contenido)" : msg.previewText)
                        .font(DS.Font.body(12))
                        .foregroundStyle(msg.isRead ? Color.appInkTertiary : Color.appInkSecondary)
                        .lineLimit(2)
                }
            }
            .padding(DS.Space.sm + 2)
            .background(msg.isRead ? Color.appBackgroundSecondary : DS.Color.wine.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .stroke(msg.isRead ? Color.appCardBorder : DS.Color.wine.opacity(0.18), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showReply) { MoodleMessageThreadView(msg: msg) }
    }
}

private struct NotiCard: View {
    let noti: MoodleNotification; let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: DS.Space.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(DS.Color.wine.opacity(0.10)).frame(width: 34, height: 34)
                    Image(systemName: noti.sfIcon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Color.wine)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(noti.typeLabel)
                            .font(DS.Font.body(8, weight: .bold))
                            .foregroundStyle(DS.Color.wine).tracking(1)
                        Spacer()
                        Text(noti.timeString)
                            .font(DS.Font.mono(10)).foregroundStyle(Color.appInkTertiary)
                        if !noti.isRead { Circle().fill(DS.Color.wine).frame(width: 7, height: 7) }
                    }
                    Text(noti.subject)
                        .font(DS.Font.body(12.5, weight: noti.isRead ? .regular : .semibold))
                        .foregroundStyle(Color.appInk).lineLimit(2)
                    if !noti.previewText.isEmpty {
                        Text(noti.previewText)
                            .font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary).lineLimit(2)
                    }
                }
            }
            .padding(DS.Space.sm + 2)
            .background(noti.isRead ? Color.appBackgroundSecondary : DS.Color.wine.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .stroke(noti.isRead ? Color.appCardBorder : DS.Color.wine.opacity(0.18), lineWidth: 1)
            )
        }.buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────
// MARK: - Message Thread View
// ─────────────────────────────────────────────────

struct MoodleMessageThreadView: View {
    let msg: MoodleMessage
    @State private var replyText = ""
    @State private var isSending = false
    @State private var sent      = false
    @State private var errorMsg: String? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Space.lg) {
                        HStack(alignment: .bottom, spacing: 8) {
                            ZStack {
                                Circle().fill(DS.Color.wine.opacity(0.10)).frame(width: 34, height: 34)
                                Text(String(msg.fromName.prefix(1)).uppercased())
                                    .font(DS.Font.body(13, weight: .semibold))
                                    .foregroundStyle(DS.Color.wine)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(msg.fromName)
                                    .font(DS.Font.body(11, weight: .semibold))
                                    .foregroundStyle(Color.appInkTertiary)
                                Text(msg.text.isEmpty ? msg.previewText : msg.text)
                                    .font(DS.Font.body(15))
                                    .foregroundStyle(Color.appInk)
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(Color.appBackgroundSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color.appCardBorder, lineWidth: 1)
                                    )
                                Text(msg.timeString)
                                    .font(DS.Font.mono(10))
                                    .foregroundStyle(Color.appInkTertiary)
                            }
                            Spacer()
                        }

                        if sent {
                            HStack {
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(replyText)
                                        .font(DS.Font.body(15))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                        .background(DS.Color.wine)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    Text("Enviado")
                                        .font(DS.Font.mono(10))
                                        .foregroundStyle(Color.appInkTertiary)
                                }
                            }
                        }
                    }
                    .padding(DS.Space.md)
                    .padding(.top, DS.Space.sm)
                }

                Divider()

                if !sent {
                    VStack(spacing: 0) {
                        if let err = errorMsg {
                            Text(err)
                                .font(DS.Font.body(11))
                                .foregroundStyle(Color(hex: "#CC1A1A"))
                                .padding(.horizontal, DS.Space.md)
                                .padding(.top, 8)
                        }
                        HStack(spacing: DS.Space.sm) {
                            TextField("Responder...", text: $replyText, axis: .vertical)
                                .font(DS.Font.body(15))
                                .foregroundStyle(Color.appInk)
                                .lineLimit(1...4)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.appBackgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color.appCardBorder, lineWidth: 1)
                                )

                            Button { sendReply() } label: {
                                ZStack {
                                    Circle()
                                        .fill(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                              ? Color.appBackgroundTertiary : DS.Color.wine)
                                        .frame(width: 38, height: 38)
                                    if isSending {
                                        ProgressView().scaleEffect(0.7).tint(.white)
                                    } else {
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                                             ? Color.appInkTertiary : .white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                        }
                        .padding(.horizontal, DS.Space.md)
                        .padding(.vertical, DS.Space.sm)
                    }
                    .background(Color.appBackground)
                }
            }
            .background(Color.appBackground)
            .navigationTitle(msg.fromName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(DS.Color.wine)
                }
            }
        }
    }

    private func sendReply() {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let token = UserDefaults.standard.string(forKey: "moodle_token"),
              !token.isEmpty else { return }
        isSending = true
        errorMsg  = nil
        Task {
            do {
                try await MoodleMessagingStore.shared.sendMessage(
                    token: token,
                    toUserId: msg.fromUserId,
                    text: text
                )
                await MainActor.run { isSending = false; sent = true }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMsg  = "No se pudo enviar: \(error.localizedDescription)"
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: - All Good Banner
// ─────────────────────────────────────────────────

private struct MoodleAllGoodBanner: View {
    var body: some View {
        HStack(spacing: DS.Space.md) {
            ZStack {
                Circle().fill(Color(hex: "#1A5C3A").opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A5C3A"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Al dia con Moodle")
                    .font(DS.Font.body(14, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                Text("Sin entregas urgentes ni vencidas.")
                    .font(DS.Font.body(11))
                    .foregroundStyle(Color.appInkTertiary)
            }
            Spacer()
        }
        .padding(DS.Space.md)
        .background(Color(hex: "#1A5C3A").opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(Color(hex: "#1A5C3A").opacity(0.15), lineWidth: 1)
        )
    }
}

// ─────────────────────────────────────────────────
// MARK: - Connect CTA
// ─────────────────────────────────────────────────

private struct MoodleConnectCTA: View {
    @State private var showLogin = false

    var body: some View {
        VStack(spacing: DS.Space.xl) {
            ZStack {
                Circle().fill(DS.Color.wine.opacity(0.08)).frame(width: 96, height: 96)
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(DS.Color.wine.opacity(0.5))
            }

            VStack(spacing: DS.Space.sm) {
                Text("Conecta UAM Virtual")
                    .font(DS.Font.display(24, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                Text("Importa tus tareas, entregas y fechas de todas tus materias del semestre.")
                    .font(DS.Font.body(14))
                    .foregroundStyle(Color.appInkTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(spacing: DS.Space.sm) {
                FeatureRow(icon: "doc.text.fill",    text: "Tareas y entregas de todos los cursos")
                FeatureRow(icon: "clock.fill",        text: "Alertas de fechas de entrega")
                FeatureRow(icon: "exclamationmark.triangle.fill", text: "Deteccion de tareas vencidas")
                FeatureRow(icon: "arrow.clockwise",   text: "Sincronizacion automatica")
            }
            .padding(DS.Space.md)
            .background(Color.appBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(Color.appCardBorder, lineWidth: 1)
            )

            Button { showLogin = true } label: {
                HStack(spacing: DS.Space.sm) {
                    Image(systemName: "link").font(.system(size: 15, weight: .semibold))
                    Text("Conectar con Moodle")
                        .font(DS.Font.body(15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(DS.Color.wine)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .shadow(color: DS.Color.wine.opacity(0.3), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Space.lg)
        .sheet(isPresented: $showLogin) { MoodleLoginView() }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: DS.Space.md) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(DS.Color.wine)
                .frame(width: 20)
            Text(text)
                .font(DS.Font.body(13))
                .foregroundStyle(Color.appInkSecondary)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// ─────────────────────────────────────────────────
// MARK: - Course Badge (usado en CoursesView)
// ─────────────────────────────────────────────────

struct MoodleCourseBadge: View {
    let courseName: String
    @ObservedObject private var moodle = MoodleStore.shared

    private var assignments: [MoodleAssignment] { moodle.assignments(for: courseName) }
    private var overdue:  Int { assignments.filter { $0.isOverdue }.count }
    private var upcoming: Int { assignments.filter { $0.isDueSoon && !$0.isOverdue }.count }
    private var total:    Int { assignments.filter { !$0.noSubmissions }.count }

    var body: some View {
        Group {
            if moodle.isConnected && total > 0 {
                HStack(spacing: 4) {
                    if overdue > 0 {
                        Label("\(overdue)", systemImage: "exclamationmark.triangle.fill")
                            .font(DS.Font.body(9, weight: .bold))
                            .foregroundStyle(Color(hex: "#CC1A1A"))
                    } else if upcoming > 0 {
                        Label("\(upcoming)", systemImage: "clock.fill")
                            .font(DS.Font.body(9, weight: .semibold))
                            .foregroundStyle(Color(hex: "#8B5A1A"))
                    } else {
                        Label("\(total)", systemImage: "graduationcap")
                            .font(DS.Font.body(9, weight: .semibold))
                            .foregroundStyle(DS.Color.wine)
                    }
                }
            }
        }
    }
}
