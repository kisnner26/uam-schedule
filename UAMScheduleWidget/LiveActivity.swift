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
                    VStack(spacing: 10) {
                        // Progress bar
                        VStack(spacing: 4) {
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
                                Text(formatTime(context.state.endTime))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }

                        // Botones — muestran badge si ya se marco asistencia
                        if let mark = context.state.attendanceMark {
                            AttendanceBadge(mark: mark,
                                            color: Color(hex: context.state.colorHex))
                        } else {
                            HStack(spacing: 6) {
                                Button(intent: makePresentIntent(courseID: context.attributes.courseID)) {
                                    Label("Presente", systemImage: "checkmark.circle.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.capsule)
                                .tint(Color(hex: context.state.colorHex))
                                .controlSize(.small)

                                Button(intent: makeLateIntent(courseID: context.attributes.courseID)) {
                                    Label("Tarde", systemImage: "clock.badge.exclamationmark")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .tint(Color.white.opacity(0.6))
                                .controlSize(.small)

                                Button(intent: makeAbsentIntent(courseID: context.attributes.courseID)) {
                                    Label("Falta", systemImage: "xmark.circle")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .tint(Color.white.opacity(0.4))
                                .controlSize(.small)

                                Spacer()

                                Button(intent: EndClassIntent()) {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .buttonStyle(.borderless)
                                .tint(.white)
                            }
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

            // ── Botones / badge asistencia ───────────────────
            if let mark = context.state.attendanceMark {
                AttendanceBadge(mark: mark, color: Color(hex: context.state.colorHex))
            } else {
                HStack(spacing: 8) {
                    Button(intent: makePresentIntent(courseID: context.attributes.courseID)) {
                        Label("Presente", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Color(hex: context.state.colorHex))
                    .controlSize(.regular)

                    Button(intent: makeLateIntent(courseID: context.attributes.courseID)) {
                        Label("Tarde", systemImage: "clock.badge.exclamationmark")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(Color.white.opacity(0.6))
                    .controlSize(.regular)

                    Button(intent: makeAbsentIntent(courseID: context.attributes.courseID)) {
                        Label("Falta", systemImage: "xmark.circle")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(Color.white.opacity(0.4))
                    .controlSize(.regular)

                    Spacer()

                    Button(intent: EndClassIntent()) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 22))
                    }
                    .buttonStyle(.borderless)
                    .tint(.white.opacity(0.4))
                }
            }
        }
        .padding(16)
    }
}
