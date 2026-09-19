import SwiftUI

// MARK: - Today View inline section (used in TodayView)

struct MoodleTodaySection: View {
    @ObservedObject private var moodle = MoodleStore.shared
    @State private var showLogin = false

    // Assignments that are not yet submitted and are upcoming, today, tomorrow, or overdue
    // Sorted: soonest deadline first (upcoming before overdue)
    private var urgent: [MoodleAssignment] {
        let future = moodle.assignments.filter {
            guard let d = $0.dueDate else { return false }
            guard !$0.noSubmissions && !$0.isSubmitted else { return false }
            return d > Date()
        }.sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }

        let overdueList = moodle.overdueAssignments
            .sorted { ($0.dueDate ?? Date.distantPast) > ($1.dueDate ?? Date.distantPast) }

        let combined = future + overdueList
        var seen = Set<Int>()
        return combined.filter { seen.insert($0.id).inserted }
    }

    // All upcoming (not submitted) ordered by due date ascending
    private var allPending: [MoodleAssignment] {
        moodle.assignments.filter {
            guard !$0.noSubmissions && !$0.isSubmitted else { return false }
            return true
        }.sorted {
            let d0 = $0.dueDate ?? Date.distantFuture
            let d1 = $1.dueDate ?? Date.distantFuture
            return d0 < d1
        }
    }

    var body: some View {
        let hasToken = !(UserDefaults.standard.string(forKey: "moodle_token") ?? "").isEmpty
        let connected = moodle.isConnected || hasToken
        return Group {
            if connected {
                if moodle.isLoading && urgent.isEmpty {
                    HStack(spacing: DS.Space.sm) {
                        ProgressView().scaleEffect(0.75).tint(DS.Color.wine)
                        Text("Sincronizando Moodle...")
                            .font(DS.Font.body(12))
                            .foregroundStyle(Color.appInkTertiary)
                    }
                    .padding(DS.Space.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
                } else if urgent.isEmpty {
                    HStack(spacing: DS.Space.md) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(hex: "#1A5C3A"))
                        Text("Sin entregas urgentes en Moodle")
                            .font(DS.Font.body(13, weight: .medium))
                            .foregroundStyle(Color.appInkSecondary)
                        Spacer()
                    }
                    .padding(DS.Space.md)
                    .background(Color(hex: "#1A5C3A").opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "#1A5C3A").opacity(0.12), lineWidth: 1))
                } else {
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        HStack(spacing: DS.Space.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: "#CC1A1A"))
                            Text("MOODLE · \(urgent.count) PENDIENTE\(urgent.count > 1 ? "S" : "")")
                                .font(DS.Font.body(9, weight: .semibold))
                                .foregroundStyle(Color(hex: "#CC1A1A"))
                                .tracking(1.5)
                            Spacer()
                            Text(moodle.lastSyncString)
                                .font(DS.Font.body(9))
                                .foregroundStyle(Color.appInkTertiary)
                        }

                        ForEach(urgent.prefix(4)) { a in
                            MoodleUrgentRow(assignment: a)
                        }

                        if urgent.count > 4 {
                            Text("+ \(urgent.count - 4) más en la pestaña Moodle")
                                .font(DS.Font.body(11))
                                .foregroundStyle(DS.Color.wine)
                                .padding(.top, 2)
                        }
                    }
                    .padding(DS.Space.md)
                    .background(Color(hex: "#CC1A1A").opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(hex: "#CC1A1A").opacity(0.12), lineWidth: 1)
                    )
                }
            } else {
                // Subtle connect prompt
                HStack(spacing: DS.Space.md) {
                    Image(systemName: "graduationcap")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DS.Color.wine)
                    Text("Conecta Moodle para ver tus tareas aquí")
                        .font(DS.Font.body(12))
                        .foregroundStyle(Color.appInkSecondary)
                    Spacer()
                    Button { showLogin = true } label: {
                        Text("Conectar")
                            .font(DS.Font.body(11, weight: .semibold))
                            .foregroundStyle(DS.Color.wine)
                    }
                    .buttonStyle(.plain)
                }
                .padding(DS.Space.md)
                .background(DS.Color.wineMuted)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DS.Color.wine.opacity(0.15), lineWidth: 1))
                .sheet(isPresented: $showLogin) { MoodleLoginView() }
            }
        }
        .task {
            if moodle.isConnected || !(UserDefaults.standard.string(forKey: "moodle_token") ?? "").isEmpty {
                await moodle.sync()
            }
        }
    }
}

struct MoodleUrgentRow: View {
    let assignment: MoodleAssignment

    var rowColor: Color {
        if assignment.isOverdue  { return Color(hex: "#CC1A1A") }
        if assignment.isDueSoon  { return Color(hex: "#8B5A1A") }
        return DS.Color.wine
    }

    var body: some View {
        HStack(spacing: DS.Space.sm) {
            Circle()
                .fill(rowColor)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(assignment.name)
                    .font(DS.Font.body(12, weight: .medium))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                Text(assignment.courseName)
                    .font(DS.Font.body(10))
                    .foregroundStyle(Color.appInkTertiary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(assignment.dueDateString)
                    .font(DS.Font.mono(10))
                    .foregroundStyle(rowColor)
                if assignment.isOverdue {
                    Text("VENCIDA")
                        .font(DS.Font.body(8, weight: .bold))
                        .foregroundStyle(Color(hex: "#CC1A1A"))
                        .tracking(0.5)
                }
            }
        }
    }
}
