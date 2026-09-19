import AppIntents
import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity Widget

struct UAMClassLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClassActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color(hex: "#0D0A09"))
                .activitySystemActionForegroundColor(Color(hex: "#6B1A2A"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: context.state.colorHex))
                            .frame(width: 4, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.room)
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(Color(hex: context.state.colorHex))
                                .tracking(1)
                            Text(context.state.courseName)
                                .font(.system(size: 13, weight: .bold, design: .serif))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.minutesLeft)m")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: context.state.colorHex))
                        Text("restantes")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: context.state.colorHex))
                                    .frame(
                                        width: geo.size.width * context.state.progressPercent,
                                        height: 6
                                    )
                            }
                        }
                        .frame(height: 6)

                        HStack {
                            Text(formatTime(context.state.startTime))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            Spacer()
                            if let mark = context.state.attendanceMark {
                                HStack(spacing: 4) {
                                    Image(systemName: mark == "Presente" ? "checkmark.circle.fill" : mark == "Tardanza" ? "clock.badge.checkmark.fill" : "xmark.circle.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(mark == "Presente" ? Color(hex: "#1A5C3A") : mark == "Tardanza" ? Color(hex: "#8B5A1A") : Color(hex: "#CC1A1A"))
                                    Text(mark)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                            Spacer()
                            Text(formatTime(context.state.endTime))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: context.state.colorHex))
                        .frame(width: 8, height: 8)
                    Text(context.state.room)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            } compactTrailing: {
                Text("\(context.state.minutesLeft)m")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: context.state.colorHex))
            } minimal: {
                Circle()
                    .fill(Color(hex: context.state.colorHex))
                    .frame(width: 10, height: 10)
            }
            .widgetURL(URL(string: "uamschedule://today"))
            .keylineTint(Color(hex: context.state.colorHex))
        }
    }

    private func formatTime(_ date: Date) -> String {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        let hour = h > 12 ? h - 12 : (h == 0 ? 12 : h)
        let ampm = h >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", hour, m, ampm)
    }
}

// MARK: - Intent factories

private func makePresentIntent(courseID: String) -> MarkPresentIntent {
    let i = MarkPresentIntent()
    i.courseID = courseID
    i.weekday = Calendar.current.component(.weekday, from: Date())
    return i
}

private func makeLateIntent(courseID: String) -> MarkLateIntent {
    let i = MarkLateIntent()
    i.courseID = courseID
    i.weekday = Calendar.current.component(.weekday, from: Date())
    return i
}

private func makeAbsentIntent(courseID: String) -> MarkAbsentIntent {
    let i = MarkAbsentIntent()
    i.courseID = courseID
    i.weekday = Calendar.current.component(.weekday, from: Date())
    return i
}

// MARK: - Attendance Badge (reemplaza botones cuando ya se marco)

private struct AttendanceBadge: View {
    let mark: String
    let color: Color
    private var badgeColor: Color {
        switch mark {
        case "Presente": return Color(hex: "#1A5C3A")
        case "Tardanza": return Color(hex: "#8B5A1A")
        default:         return Color(hex: "#CC1A1A")
        }
    }
    private var icon: String {
        switch mark {
        case "Presente": return "checkmark.circle.fill"
        case "Tardanza": return "clock.badge.checkmark.fill"
        default:         return "xmark.circle.fill"
        }
    }
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(badgeColor)
            Text("\(mark) registrado")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 12))
                .foregroundStyle(badgeColor.opacity(0.7))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(badgeColor.opacity(0.18))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(badgeColor.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Lock Screen View

// Bug 2 fix: botones debajo del contenido en VStack externo, no al lado en HStack

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<ClassActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Contenido principal ──────────────────────────
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: context.state.colorHex))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("EN CLASE · UAM")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color(hex: context.state.colorHex))
                            .tracking(1.5)
                        Spacer()
                        Text("\(context.state.minutesLeft) min")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Text(context.state.courseName)
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Label(context.state.room, systemImage: "mappin.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .symbolRenderingMode(.hierarchical)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: context.state.colorHex))
                                .frame(
                                    width: geo.size.width * context.state.progressPercent,
                                    height: 4
                                )
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 2)
                }
            }

            // ── Asistencia info (sin botones) ────────────────
            if let mark = context.state.attendanceMark {
                HStack(spacing: 8) {
                    let markColor: Color = mark == "Presente" ? Color(hex: "#1A5C3A") : mark == "Tardanza" ? Color(hex: "#8B5A1A") : Color(hex: "#CC1A1A")
                    let markIcon: String = mark == "Presente" ? "checkmark.circle.fill" : mark == "Tardanza" ? "clock.badge.checkmark.fill" : "xmark.circle.fill"
                    Image(systemName: markIcon).font(.system(size: 13, weight: .semibold)).foregroundStyle(markColor)
                    Text("\(mark) registrado").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundStyle(markColor.opacity(0.7))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
        }
        .padding(16)
    }
}
