import SwiftUI

// MARK: - Attendance View

struct AttendanceView: View {
    @EnvironmentObject var store: ScheduleStore
    @EnvironmentObject var attendance: AttendanceStore
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // Header
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CONTROL").font(DS.Font.body(9, weight: .semibold))
                                .foregroundStyle(DS.Color.wine).tracking(3)
                            Text("Asistencias").font(DS.Font.display(34, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                            WineAccentLine(height: 1.5, width: 36).padding(.top, 3)
                            Text("18 semanas · máx. 20% de faltas")
                                .font(DS.Font.body(12)).foregroundStyle(Color.appInkTertiary).padding(.top, 3)
                        }
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.top, 20).padding(.bottom, DS.Space.xl)
                        .opacity(appeared ? 1 : 0)
                        .animation(DS.Anim.easeSlow, value: appeared)

                        if store.courses.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "person.badge.clock")
                                    .font(.system(size: 36, weight: .light))
                                    .foregroundStyle(Color.appInkTertiary.opacity(0.3))
                                Text("Sin materias registradas")
                                    .font(DS.Font.body(14)).foregroundStyle(Color.appInkTertiary.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 60)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(store.courses.enumerated()), id: \.element.id) { idx, course in
                                    CourseAttendanceCard(course: course)
                                        .opacity(appeared ? 1 : 0)
                                        .offset(y: appeared ? 0 : 10)
                                        .animation(DS.Anim.spring.delay(0.08 + Double(idx) * 0.05), value: appeared)
                                }
                            }
                            .padding(.horizontal, DS.Space.md)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Color.appInkTertiary)
                }
            }
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Course Attendance Card

struct CourseAttendanceCard: View {
    @EnvironmentObject var store: ScheduleStore
    @EnvironmentObject var attendance: AttendanceStore
    let course: Course
    @State private var expanded = false

    var estimatedTotal: Int { max(1, 18 * course.sessions.count) }
    var stats: AttendanceStats { attendance.stats(courseId: course.id, totalSessions: estimatedTotal) }

    var statusColor: Color {
        if stats.isFailed { return Color(hex: "#CC1A1A") }
        if stats.isAtRisk { return Color.orange }
        return Color(hex: course.color)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header row
            Button { withAnimation(DS.Anim.spring) { expanded.toggle() } } label: {
                HStack(spacing: 14) {

                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.appBackgroundTertiary, lineWidth: 5)
                            .frame(width: 46, height: 46)
                        Circle()
                            .trim(from: 0, to: stats.attendanceRate)
                            .stroke(statusColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 46, height: 46)
                            .animation(DS.Anim.easeSlow, value: stats.attendanceRate)
                        Text("\(Int(stats.attendanceRate * 100))%")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(statusColor)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(course.name)
                                .font(DS.Font.body(14, weight: .semibold))
                                .foregroundStyle(Color.appInk).lineLimit(1)
                            if stats.isFailed {
                                BadgeTag(text: "REPROBADO", color: "#CC1A1A")
                            } else if stats.isAtRisk {
                                BadgeTag(text: "RIESGO", color: "#D4700A")
                            }
                        }

                        HStack(spacing: 10) {
                            Label("\(stats.present) asistidas", systemImage: "checkmark.circle")
                                .font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary)
                            Label("\(stats.absent) faltas", systemImage: "xmark.circle")
                                .font(DS.Font.body(11))
                                .foregroundStyle(stats.absent > 0 ? Color(hex: "#CC1A1A").opacity(0.8) : Color.appInkTertiary)
                        }
                        .symbolRenderingMode(.hierarchical)
                        .tint(DS.Color.wine.opacity(0.4))
                    }

                    Spacer()

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.appInkTertiary.opacity(0.5))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // ── Expanded content
            if expanded {
                VStack(spacing: 0) {
                    Rectangle().fill(Color.appSeparator).frame(height: 0.5)

                    // Absence bar
                    VStack(spacing: 6) {
                        HStack {
                            Text("Faltas usadas")
                                .font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary)
                            Spacer()
                            Text("\(stats.absent) / \(stats.maxAbsences) permitidas")
                                .font(DS.Font.mono(11, weight: .bold))
                                .foregroundStyle(statusColor)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.appBackgroundTertiary).frame(height: 7)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(statusColor)
                                    .frame(width: geo.size.width * min(1, Double(stats.absent) / Double(stats.maxAbsences)), height: 7)
                                    .animation(DS.Anim.easeSlow, value: stats.absent)
                            }
                        }
                        .frame(height: 7)

                        Text(stats.riskLabel)
                            .font(DS.Font.body(10, weight: .medium))
                            .foregroundStyle(statusColor)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)

                    // Today's sessions
                    let todaySessions = course.sessions.filter {
                        $0.weekday == Calendar.current.component(.weekday, from: Date())
                    }
                    if !todaySessions.isEmpty {
                        Rectangle().fill(Color.appSeparator).frame(height: 0.5)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("MARCAR HOY")
                                .font(DS.Font.body(8, weight: .black))
                                .foregroundStyle(Color.appInkTertiary).tracking(2.5)

                            ForEach(todaySessions) { session in
                                AttendanceMarkerRow(course: course, session: session)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }

                    // Recent history
                    let history = attendance.records
                        .filter { $0.courseId == course.id }
                        .sorted { $0.date > $1.date }
                        .prefix(5)

                    if !history.isEmpty {
                        Rectangle().fill(Color.appSeparator).frame(height: 0.5)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("HISTORIAL RECIENTE")
                                .font(DS.Font.body(8, weight: .black))
                                .foregroundStyle(Color.appInkTertiary).tracking(2.5)

                            ForEach(Array(history)) { record in
                                HStack(spacing: 10) {
                                    Image(systemName: record.status.icon)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color(hex: record.status.color))
                                        .frame(width: 18)
                                    Text(record.status.rawValue)
                                        .font(DS.Font.body(12)).foregroundStyle(Color.appInkSecondary)
                                    Spacer()
                                    Text(record.date, style: .date)
                                        .font(DS.Font.mono(10)).foregroundStyle(Color.appInkTertiary)
                                }
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(
                    stats.isFailed ? Color(hex: "#CC1A1A").opacity(0.35) :
                    (stats.isAtRisk ? Color.orange.opacity(0.35) : Color.appCardBorder),
                    lineWidth: stats.isFailed || stats.isAtRisk ? 1.5 : 1
                )
        )
    }
}

// MARK: - Attendance Marker Row

struct AttendanceMarkerRow: View {
    @EnvironmentObject var attendance: AttendanceStore
    let course: Course
    let session: ClassSession

    var current: AttendanceStatus? {
        attendance.statusToday(courseId: course.id, sessionWeekday: session.weekday)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.startTimeString + " – " + session.endTimeString)
                .font(DS.Font.mono(10)).foregroundStyle(Color.appInkTertiary)

            HStack(spacing: 6) {
                ForEach(AttendanceStatus.allCases, id: \.self) { status in
                    let isSel = current == status
                    Button {
                        withAnimation(DS.Anim.springFast) {
                            attendance.mark(courseId: course.id, sessionWeekday: session.weekday, status: status)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: status.icon)
                                .font(.system(size: 10, weight: isSel ? .bold : .regular))
                            Text(status.rawValue)
                                .font(.system(size: 11, weight: isSel ? .bold : .regular))
                        }
                        .foregroundStyle(isSel ? .white : Color(hex: status.color))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(isSel ? Color(hex: status.color) : Color(hex: status.color).opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(isSel ? Color.clear : Color(hex: status.color).opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Badge Tag

struct BadgeTag: View {
    let text: String
    let color: String
    var body: some View {
        Text(text)
            .font(.system(size: 7, weight: .black))
            .foregroundStyle(.white).tracking(1)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Color(hex: color))
            .clipShape(Capsule())
    }
}
