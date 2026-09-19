import SwiftUI

// MARK: - Moodle Assignments Tab

struct MoodleAssignmentsTab: View {
    @ObservedObject private var moodle = MoodleStore.shared
    let courseName: String
    @State private var appeared      = false
    @State private var activeFilter: AssignmentFilter = .todas

    enum AssignmentFilter: String, CaseIterable {
        case todas    = "Todas"
        case proximas = "Próximas"
        case vencidas = "Vencidas"
        case enviadas = "Enviadas"
    }

    private var all: [MoodleAssignment] {
        moodle.assignments(for: courseName)
    }

    private var filtered: [MoodleAssignment] {
        switch activeFilter {
        case .todas:    return all
        case .proximas: return all.filter { !$0.isOverdue && !$0.isSubmitted && $0.dueDate != nil && !$0.noSubmissions }.sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
        case .vencidas: return all.filter { $0.isOverdue && !$0.isSubmitted }.sorted { ($0.dueDate ?? Date.distantPast) > ($1.dueDate ?? Date.distantPast) }
        case .enviadas: return all.filter { $0.isSubmitted || $0.noSubmissions }.sorted { ($0.dueDate ?? Date.distantFuture) > ($1.dueDate ?? Date.distantFuture) }
        }
    }

    private func count(for filter: AssignmentFilter) -> Int {
        switch filter {
        case .todas:    return all.count
        case .proximas: return all.filter { !$0.isOverdue && !$0.isSubmitted && $0.dueDate != nil && !$0.noSubmissions }.sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }.count
        case .vencidas: return all.filter { $0.isOverdue && !$0.isSubmitted }.sorted { ($0.dueDate ?? Date.distantPast) > ($1.dueDate ?? Date.distantPast) }.count
        case .enviadas: return all.filter { $0.isSubmitted || $0.noSubmissions }.sorted { ($0.dueDate ?? Date.distantFuture) > ($1.dueDate ?? Date.distantFuture) }.count
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Filtros ───────────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Space.sm) {
                    ForEach(AssignmentFilter.allCases, id: \.self) { f in
                        MoodleFilterChip(
                            label: f.rawValue,
                            count: count(for: f),
                            isActive: activeFilter == f,
                            badgeColor: f == .vencidas ? Color(hex: "#CC1A1A") : DS.Color.wine
                        ) {
                            withAnimation(DS.Anim.springFast) { activeFilter = f }
                        }
                    }
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, DS.Space.sm)
            }
            .background(Color.appBackground)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.appSeparator)
                    .frame(height: 0.5)
            }

            // ── Contenido ─────────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Space.sm) {

                    if !moodle.isConnected {
                        MoodleNotConnectedBanner()
                            .padding(.top, DS.Space.md)
                            .opacity(appeared ? 1 : 0)
                            .animation(DS.Anim.easeSlow.delay(0.10), value: appeared)
                    }

                    else if moodle.isLoading && all.isEmpty {
                        VStack(spacing: DS.Space.md) {
                            ProgressView()
                            Text("Cargando tareas...")
                                .font(DS.Font.body(13))
                                .foregroundStyle(Color.appInkTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }

                    else if all.isEmpty {
                        VStack(spacing: DS.Space.sm) {
                            Image(systemName: "tray")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.appInkTertiary.opacity(0.5))
                            Text("Sin tareas en Moodle")
                                .font(DS.Font.body(14, weight: .semibold))
                                .foregroundStyle(Color.appInkSecondary)
                            Text("No se encontraron entregas para esta materia.")
                                .font(DS.Font.body(12))
                                .foregroundStyle(Color.appInkTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }

                    else {
                        // ── Sync bar ─────────────────────────────
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.appInkTertiary)
                            Text("Sync: \(moodle.lastSyncString)")
                                .font(DS.Font.body(11))
                                .foregroundStyle(Color.appInkTertiary)
                            Spacer()
                            if moodle.isLoading {
                                ProgressView().scaleEffect(0.75)
                            } else {
                                Button {
                                    Task { await moodle.sync() }
                                } label: {
                                    Text("Actualizar")
                                        .font(DS.Font.body(11, weight: .semibold))
                                        .foregroundStyle(DS.Color.wine)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, DS.Space.sm)
                        .opacity(appeared ? 1 : 0)
                        .animation(DS.Anim.easeSlow.delay(0.08), value: appeared)

                        // ── Lista filtrada ────────────────────────
                        if filtered.isEmpty {
                            FilterEmptyState(filter: activeFilter)
                                .padding(.top, 40)
                                .opacity(appeared ? 1 : 0)
                                .animation(DS.Anim.easeSlow.delay(0.12), value: appeared)
                        } else {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { i, a in
                                MoodleAssignmentCard(assignment: a)
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 6)
                                    .animation(DS.Anim.easeSlow.delay(0.12 + Double(i) * 0.04), value: appeared)
                            }
                        }
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.top, DS.Space.sm)
            }
        }
        .onAppear {
            appeared = true
            if moodle.isConnected && all.isEmpty {
                Task { await moodle.sync() }
            }
        }
    }
}

// MARK: - Filter Chip

private struct MoodleFilterChip: View {
    let label: String
    let count: Int
    let isActive: Bool
    let badgeColor: Color
    let action: () -> Void

    var activeColor: Color {
        label == "Vencidas" ? Color(hex: "#CC1A1A") : DS.Color.wine
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label)
                    .font(DS.Font.body(12, weight: isActive ? .bold : .regular))
                    .foregroundStyle(isActive ? .white : Color.appInkSecondary)
                if count > 0 {
                    Text("\(count)")
                        .font(DS.Font.mono(10, weight: .semibold))
                        .foregroundStyle(isActive ? .white.opacity(0.85) : badgeColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            isActive
                                ? Color.white.opacity(0.20)
                                : badgeColor.opacity(0.12)
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, 8)
            .background(isActive ? activeColor : Color.appBackgroundSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isActive ? Color.clear : Color.appCardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Empty State

private struct FilterEmptyState: View {
    let filter: MoodleAssignmentsTab.AssignmentFilter

    var icon: String {
        switch filter {
        case .vencidas: return "checkmark.seal.fill"
        case .proximas: return "calendar.badge.checkmark"
        case .enviadas: return "tray"
        case .todas:    return "tray"
        }
    }

    var message: String {
        switch filter {
        case .vencidas: return "Sin tareas vencidas"
        case .proximas: return "Sin tareas próximas"
        case .enviadas: return "Sin entregas registradas"
        case .todas:    return "Sin tareas"
        }
    }

    var sub: String {
        switch filter {
        case .vencidas: return "Todo al dia con esta materia."
        case .proximas: return "No hay entregas pendientes próximas."
        case .enviadas: return "Moodle aun no registra entregas tuyas."
        case .todas:    return "No se encontraron tareas."
        }
    }

    var iconColor: Color {
        filter == .vencidas ? Color(hex: "#1A5C3A") : Color.appInkTertiary.opacity(0.5)
    }

    var body: some View {
        VStack(spacing: DS.Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(iconColor)
            Text(message)
                .font(DS.Font.body(14, weight: .semibold))
                .foregroundStyle(Color.appInkSecondary)
            Text(sub)
                .font(DS.Font.body(12))
                .foregroundStyle(Color.appInkTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Assignment Card

struct MoodleAssignmentCard: View {
    let assignment: MoodleAssignment

    var statusColor: Color {
        if assignment.isSubmitted    { return Color(hex: "#1A5C3A") }
        if assignment.noSubmissions  { return Color.appInkTertiary }
        if assignment.isOverdue      { return Color(hex: "#CC1A1A") }
        if assignment.isDueSoon      { return Color(hex: "#8B5A1A") }
        return DS.Color.wine.opacity(0.8)
    }

    var statusLabel: String {
        if assignment.isSubmitted    { return "Enviada" }
        if assignment.noSubmissions  { return "Solo lectura" }
        if assignment.isOverdue      { return "Vencida" }
        if assignment.isDueSoon      { return "Próxima" }
        return "Pendiente"
    }

    var statusIcon: String {
        if assignment.isSubmitted    { return "checkmark.circle.fill" }
        if assignment.isOverdue      { return "exclamationmark.circle.fill" }
        if assignment.isDueSoon      { return "clock.fill" }
        if assignment.noSubmissions  { return "eye.fill" }
        return "circle"
    }

    var borderColor: Color {
        if assignment.isSubmitted   { return Color(hex: "#1A5C3A").opacity(0.20) }
        if assignment.isOverdue     { return Color(hex: "#CC1A1A").opacity(0.25) }
        if assignment.isDueSoon     { return Color(hex: "#8B5A1A").opacity(0.20) }
        return Color.appCardBorder
    }

    var cardBackground: Color {
        if assignment.isSubmitted   { return Color(hex: "#1A5C3A").opacity(0.04) }
        if assignment.isOverdue     { return Color(hex: "#CC1A1A").opacity(0.03) }
        return Color.appBackgroundSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {

            HStack(alignment: .top, spacing: DS.Space.sm) {
                Image(systemName: statusIcon)
                    .font(.system(size: 13))
                    .foregroundStyle(statusColor)
                    .frame(width: 18)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.name)
                        .font(DS.Font.body(14, weight: .semibold))
                        .foregroundStyle(
                            assignment.isSubmitted ? Color.appInkTertiary : Color.appInk
                        )
                        .strikethrough(assignment.isSubmitted, color: Color.appInkTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: DS.Space.xs) {
                        Text(statusLabel)
                            .font(DS.Font.body(10, weight: .semibold))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(statusColor.opacity(0.10))
                            .clipShape(Capsule())

                        if assignment.dueDate != nil && !assignment.noSubmissions {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                                .foregroundStyle(statusColor)
                            Text(assignment.dueDateString)
                                .font(DS.Font.mono(11))
                                .foregroundStyle(statusColor)
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            if !assignment.intro.isEmpty {
                Text(assignment.intro)
                    .font(DS.Font.body(12))
                    .foregroundStyle(Color.appInkTertiary)
                    .lineLimit(2)
                    .lineSpacing(2)
                    .padding(.leading, 26)
            }
        }
        .padding(DS.Space.md)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Not Connected Banner

struct MoodleNotConnectedBanner: View {
    @State private var showLogin = false

    var body: some View {
        HStack(spacing: DS.Space.md) {
            Image(systemName: "graduationcap")
                .font(.system(size: 20))
                .foregroundStyle(DS.Color.wine)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text("Moodle no conectado")
                    .font(DS.Font.body(13, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                Text("Conecta tu cuenta para ver las tareas de esta materia.")
                    .font(DS.Font.body(11))
                    .foregroundStyle(Color.appInkTertiary)
                    .lineSpacing(2)
            }

            Spacer()

            Button {
                showLogin = true
            } label: {
                Text("Conectar")
                    .font(DS.Font.body(12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Space.md)
                    .padding(.vertical, DS.Space.sm)
                    .background(DS.Color.wine)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Space.md)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .sheet(isPresented: $showLogin) { MoodleLoginView() }
    }
}
