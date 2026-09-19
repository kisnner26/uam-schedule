import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry.placeholder
    }
    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        completion(makeEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        // Generate a series of entries timed to the boundaries of "minutes left"
        // so the displayed minute countdown stays sharp without burning
        // refresh budget. We emit 1 entry per minute for the next 30 minutes,
        // then drop to every 5 minutes for the rest of the hour, then once an hour.
        let cal = Calendar.current
        let now = Date()
        var entries: [ScheduleEntry] = [makeEntry(at: now)]

        // 1-minute granularity for the next 30 minutes
        for i in 1...30 {
            if let d = cal.date(byAdding: .minute, value: i, to: now) {
                entries.append(makeEntry(at: d))
            }
        }
        // 5-minute granularity for the next hour after that
        for i in stride(from: 35, through: 90, by: 5) {
            if let d = cal.date(byAdding: .minute, value: i, to: now) {
                entries.append(makeEntry(at: d))
            }
        }

        let after = cal.date(byAdding: .minute, value: 5, to: now) ?? now
        completion(Timeline(entries: entries, policy: .after(after)))
    }
    private func makeEntry(at date: Date = Date()) -> ScheduleEntry {
        let store = ScheduleStore()
        return ScheduleEntry(
            date: date,
            currentCourse: store.currentClass()?.course,
            currentSession: store.currentClass()?.session,
            nextCourse: store.nextClass()?.course,
            nextSession: store.nextClass()?.session,
            todayClasses: store.todayClasses()
        )
    }
}

// MARK: - Entry

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let currentCourse: Course?
    let currentSession: ClassSession?
    let nextCourse: Course?
    let nextSession: ClassSession?
    let todayClasses: [(course: Course, session: ClassSession)]

    static var placeholder: ScheduleEntry {
        let c = Course(
            code: "MAT-301",
            name: "Calculo Diferencial",
            room: "B-206",
            credits: 4,
            group: "G1",
            color: "#6B1A2A",
            sessions: []
        )
        let s = ClassSession(weekday: 5, startHour: 16, startMinute: 0, endHour: 17, endMinute: 40)
        return ScheduleEntry(
            date: Date(),
            currentCourse: nil,
            currentSession: nil,
            nextCourse: c,
            nextSession: s,
            todayClasses: []
        )
    }

    init(
        date: Date,
        currentCourse: Course? = nil,
        currentSession: ClassSession? = nil,
        nextCourse: Course? = nil,
        nextSession: ClassSession? = nil,
        todayClasses: [(course: Course, session: ClassSession)] = []
    ) {
        self.date = date
        self.currentCourse = currentCourse
        self.currentSession = currentSession
        self.nextCourse = nextCourse
        self.nextSession = nextSession
        self.todayClasses = todayClasses
    }
}

// MARK: - Widget Bundle

@main
struct UAMScheduleWidgetBundle: WidgetBundle {
    var body: some Widget {
        UAMScheduleWidget()
        UAMScheduleLockScreenWidget()
        UAMClassLiveActivity()
    }
}

// MARK: - Widget Config

struct UAMScheduleWidget: Widget {
    let kind = "UAMScheduleWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
            UAMWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackgroundView()
                }
        }
        .configurationDisplayName("UAM Schedule")
        .description("Tu horario academico.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Lock Screen / StandBy widget
// Una segunda configuracion dedicada al Lock Screen (accessoryRectangular / Inline / Circular).
// iOS las separa de las del Home porque su sistema de render es distinto (vibrant tint).

struct UAMScheduleLockScreenWidget: Widget {
    let kind = "UAMScheduleLockScreenWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
            UAMLockScreenEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("UAM en Lock Screen")
        .description("Tu próxima clase, siempre visible.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

// MARK: - Lock Screen Router

struct UAMLockScreenEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ScheduleEntry

    private var active: Course? { entry.currentCourse ?? entry.nextCourse }
    private var activeS: ClassSession? { entry.currentSession ?? entry.nextSession }
    private var isActive: Bool { entry.currentCourse != nil }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenRectangular(course: active, session: activeS, isActive: isActive)
        case .accessoryInline:
            LockScreenInline(course: active, session: activeS, isActive: isActive)
        case .accessoryCircular:
            LockScreenCircular(course: active, session: activeS, isActive: isActive)
        default:
            LockScreenRectangular(course: active, session: activeS, isActive: isActive)
        }
    }
}

private struct LockScreenRectangular: View {
    let course: Course?
    let session: ClassSession?
    let isActive: Bool

    var body: some View {
        if let course, let session {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: isActive ? "record.circle" : "clock")
                        .font(.system(size: 9, weight: .bold))
                    Text(isActive ? "EN CLASE" : "PROXIMA")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.2)
                }
                .widgetAccentable()
                Text(course.name)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .lineLimit(1)
                Text("\(W.room(course, session)) · \(session.startTimeString)")
                    .font(.system(size: 11, design: .monospaced))
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("UAM")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.2)
                    .widgetAccentable()
                Text("Sin clases pendientes")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
            }
        }
    }
}

private struct LockScreenInline: View {
    let course: Course?
    let session: ClassSession?
    let isActive: Bool
    var body: some View {
        if let course, let session {
            Label(
                "\(course.code) · \(W.room(course, session)) · \(session.startTimeString)",
                systemImage: isActive ? "record.circle" : "graduationcap"
            )
        } else {
            Label("UAM · Sin clases", systemImage: "graduationcap")
        }
    }
}

private struct LockScreenCircular: View {
    let course: Course?
    let session: ClassSession?
    let isActive: Bool
    var body: some View {
        if let course, let session {
            ZStack {
                if isActive {
                    let p = W.progress(session, Date())
                    Circle()
                        .stroke(.white.opacity(0.25), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: p)
                        .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                VStack(spacing: 0) {
                    Text(course.code.prefix(4).uppercased())
                        .font(.system(size: 9, weight: .black))
                    Text(isActive ? "\(W.minutesLeft(session, Date()))m" : "\(W.minutesUntil(session, Date()))m")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .opacity(0.85)
                }
            }
            .widgetAccentable()
        } else {
            Image(systemName: "graduationcap")
                .widgetAccentable()
        }
    }
}

// MARK: - Router

struct UAMWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme
    var entry: ScheduleEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidget(entry: entry)
        case .systemMedium: MediumWidget(entry: entry)
        case .systemLarge:  LargeWidget(entry: entry)
        default:            SmallWidget(entry: entry)
        }
    }
}

// MARK: - Background

struct WidgetBackgroundView: View {
    @Environment(\.colorScheme) var scheme
    var body: some View {
        (scheme == .dark ? Color(hex: "#0D0A09") : Color(hex: "#FAF8F5"))
            .ignoresSafeArea()
    }
}

// MARK: - Shared helpers

private enum W {
    static let wine     = Color(hex: "#6B1A2A")
    static let wineMid  = Color(hex: "#6B1A2A").opacity(0.15)

    static func ink(_ s: ColorScheme) -> Color {
        s == .dark ? Color(hex: "#FAF6EE") : Color(hex: "#0F0F0F")
    }
    static func sub(_ s: ColorScheme) -> Color {
        s == .dark ? Color(hex: "#8A7F73") : Color(hex: "#6B6B6B")
    }
    static func bg(_ s: ColorScheme) -> Color {
        s == .dark ? Color(hex: "#0D0A09") : Color(hex: "#FAF8F5")
    }
    static func cardBg(_ s: ColorScheme) -> Color {
        s == .dark ? Color(hex: "#1C1612") : Color(hex: "#F0EDE7")
    }
    static func sep(_ s: ColorScheme) -> Color {
        s == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.07)
    }

    static func room(_ course: Course, _ session: ClassSession) -> String {
        let r = session.room.trimmingCharacters(in: .whitespaces)
        return r.isEmpty ? course.room : r
    }

    /// Edificio inferido del aula. Para mostrar como pista visual en el widget.
    /// Retorna nil si no se puede inferir (aula vacia o no estándar UAM).
    static func building(_ course: Course, _ session: ClassSession) -> UAMBuilding? {
        return UAMCampus.inferBuilding(for: course, session: session)
    }

    static func minutesLeft(_ session: ClassSession, _ now: Date) -> Int {
        let cal = Calendar.current
        let nowMin = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        return max(0, (session.endHour * 60 + session.endMinute) - nowMin)
    }

    static func minutesUntil(_ session: ClassSession, _ now: Date) -> Int {
        let cal = Calendar.current
        let nowMin  = cal.component(.hour, from: now)  * 60 + cal.component(.minute, from: now)
        let nowWday = cal.component(.weekday, from: now)
        let startMin = session.startHour * 60 + session.startMinute
        if session.weekday == nowWday { return max(0, startMin - nowMin) }
        let days = (session.weekday - nowWday + 7) % 7
        return days * 24 * 60 + startMin
    }

    static func countdown(_ minutes: Int, active: Bool) -> String {
        if active {
            if minutes < 60 { return "\(minutes) min" }
            let h = minutes / 60; let r = minutes % 60
            return r > 0 ? "\(h)h \(r)m" : "\(h)h"
        }
        if minutes < 60  { return "En \(minutes) min" }
        if minutes < 1440 {
            let h = minutes / 60; let r = minutes % 60
            return r > 0 ? "En \(h)h \(r)m" : "En \(h)h"
        }
        return minutes / 1440 == 1 ? "Mañana" : "En \(minutes / 1440) dias"
    }

    static func progress(_ session: ClassSession, _ now: Date) -> Double {
        let cal = Calendar.current
        let nowMin = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let start = session.startHour * 60 + session.startMinute
        let end   = session.endHour   * 60 + session.endMinute
        guard end > start else { return 0 }
        return min(1, max(0, Double(nowMin - start) / Double(end - start)))
    }
}

// MARK: - Small Widget
// Layout: status label top / course name / room + time bottom

struct SmallWidget: View {
    @Environment(\.colorScheme) var sc
    let entry: ScheduleEntry

    private var active: Course?       { entry.currentCourse ?? entry.nextCourse }
    private var activeS: ClassSession? { entry.currentSession ?? entry.nextSession }
    private var isActive: Bool        { entry.currentCourse != nil }

    var body: some View {
        ZStack(alignment: .topLeading) {
            W.bg(sc)

            if let course = active, let session = activeS {
                VStack(alignment: .leading, spacing: 0) {

                    // Status pill
                    HStack(spacing: 5) {
                        if isActive {
                            Circle()
                                .fill(W.wine)
                                .frame(width: 5, height: 5)
                        }
                        Text(isActive ? "EN CLASE" : "PROXIMA")
                            .font(.system(size: 7, weight: .black, design: .default))
                            .foregroundStyle(isActive ? W.wine : W.sub(sc))
                            .tracking(1.8)
                    }
                    .padding(.bottom, 7)

                    // Course name — primary content, gets max space
                    Text(course.name)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(W.ink(sc))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 6)

                    // Code + room line
                    HStack(spacing: 6) {
                        Text(course.code)
                            .font(.system(size: 9, weight: .bold, design: .default))
                            .foregroundStyle(W.wine.opacity(0.8))
                        Text(W.room(course, session))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(W.sub(sc))
                    }
                    .padding(.bottom, 4)

                    // Time + countdown
                    HStack(alignment: .lastTextBaseline) {
                        Text(session.startTimeString)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(W.sub(sc))
                        Spacer()
                        let mins = isActive
                            ? W.minutesLeft(session, entry.date)
                            : W.minutesUntil(session, entry.date)
                        Text(W.countdown(mins, active: isActive))
                            .font(.system(size: 11, weight: .bold, design: .serif))
                            .foregroundStyle(W.wine)
                    }

                    // Progress bar (active only)
                    if isActive {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(W.wine.opacity(0.1))
                                    .frame(height: 2)
                                Rectangle()
                                    .fill(W.wine)
                                    .frame(
                                        width: geo.size.width * W.progress(session, entry.date),
                                        height: 2
                                    )
                            }
                        }
                        .frame(height: 2)
                        .padding(.top, 7)
                    }
                }
                .padding(14)

            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("UAM")
                        .font(.system(size: 9, weight: .black, design: .default))
                        .foregroundStyle(W.wine)
                        .tracking(2.5)
                    Spacer()
                    Text("Sin clases\nhoy")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(W.sub(sc))
                }
                .padding(14)
            }
        }
    }
}

// MARK: - Medium Widget
// Left: status + name + meta. Right: time column, clean vertical layout.

struct MediumWidget: View {
    @Environment(\.colorScheme) var sc
    let entry: ScheduleEntry

    private var active: Course?       { entry.currentCourse ?? entry.nextCourse }
    private var activeS: ClassSession? { entry.currentSession ?? entry.nextSession }
    private var isActive: Bool        { entry.currentCourse != nil }

    var body: some View {
        ZStack {
            W.bg(sc)

            if let course = active, let session = activeS {
                HStack(spacing: 0) {

                    // ── Left panel ────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {

                        // Status
                        HStack(spacing: 5) {
                            if isActive {
                                Circle().fill(W.wine).frame(width: 5, height: 5)
                            }
                            Text(isActive ? "EN CLASE" : "PROXIMA CLASE")
                                .font(.system(size: 7, weight: .black))
                                .foregroundStyle(isActive ? W.wine : W.sub(sc))
                                .tracking(1.8)
                        }
                        .padding(.bottom, 8)

                        // Name
                        Text(course.name)
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(W.ink(sc))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 8)

                        // Code + room
                        HStack(spacing: 8) {
                            Text(course.code)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(W.wine.opacity(0.8))
                                .tracking(0.8)
                            Text(W.room(course, session))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(W.sub(sc))
                        }

                        // Progress
                        if isActive {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(W.wine.opacity(0.1))
                                        .frame(height: 3)
                                    Capsule()
                                        .fill(W.wine)
                                        .frame(
                                            width: geo.size.width * W.progress(session, entry.date),
                                            height: 3
                                        )
                                }
                            }
                            .frame(height: 3)
                            .padding(.top, 8)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Separator
                    Rectangle()
                        .fill(W.sep(sc))
                        .frame(width: 1)
                        .padding(.vertical, 14)

                    // ── Right panel ───────────────────────────
                    VStack(alignment: .center, spacing: 0) {
                        Text(session.startTimeString)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(W.sub(sc))

                        Rectangle()
                            .fill(W.sep(sc))
                            .frame(width: 1, height: 10)
                            .padding(.vertical, 3)

                        Text(session.endTimeString)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(W.sub(sc).opacity(0.6))

                        Spacer()

                        let mins = isActive
                            ? W.minutesLeft(session, entry.date)
                            : W.minutesUntil(session, entry.date)

                        Text(W.countdown(mins, active: isActive))
                            .font(.system(size: 13, weight: .bold, design: .serif))
                            .foregroundStyle(W.wine)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .frame(width: 96)

                }

            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("UAM · SEDE CENTRAL")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(W.wine)
                            .tracking(1.5)
                        Text("Sin clases\nprogramadas")
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                            .foregroundStyle(W.sub(sc))
                    }
                    Spacer()
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Large Widget
// Header + dense class list with NOW indicator

struct LargeWidget: View {
    @Environment(\.colorScheme) var sc
    let entry: ScheduleEntry

    private var dayLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_NI")
        f.dateFormat = "EEEE · d MMM"
        return f.string(from: entry.date).capitalized
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            W.bg(sc)

            VStack(alignment: .leading, spacing: 0) {

                // ── Header ──────────────────────────────────
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("UAM · SEDE CENTRAL")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(W.wine)
                            .tracking(2)
                        Text(dayLabel)
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                            .foregroundStyle(W.ink(sc))
                    }
                    Spacer()
                    if entry.currentCourse != nil {
                        HStack(spacing: 4) {
                            Circle().fill(W.wine).frame(width: 5, height: 5)
                            Text("En clase")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(W.wine)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                Rectangle()
                    .fill(W.sep(sc))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                // ── Class list ───────────────────────────────
                if entry.todayClasses.isEmpty {
                    Spacer()
                    Text("Sin clases hoy")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundStyle(W.sub(sc))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(entry.todayClasses.prefix(7).enumerated()), id: \.element.session.id) { idx, item in
                            let isAct = entry.currentCourse?.id == item.course.id
                                     && entry.currentSession?.id == item.session.id
                            LargeRow(
                                course: item.course,
                                session: item.session,
                                now: entry.date,
                                isActive: isAct,
                                scheme: sc
                            )
                            if idx < entry.todayClasses.prefix(7).count - 1 {
                                Rectangle()
                                    .fill(W.sep(sc))
                                    .frame(height: 0.5)
                                    .padding(.leading, 78)
                            }
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

struct LargeRow: View {
    let course: Course
    let session: ClassSession
    let now: Date
    let isActive: Bool
    let scheme: ColorScheme

    private var isPast: Bool {
        guard !isActive else { return false }
        let cal = Calendar.current
        let nowMin  = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let todayWd = cal.component(.weekday, from: now)
        guard session.weekday == todayWd else { return false }
        return nowMin > session.endHour * 60 + session.endMinute
    }

    private var rowOpacity: Double { isPast ? 0.28 : 1.0 }

    var body: some View {
        HStack(spacing: 0) {

            // Time column – fixed width for alignment
            Text(session.startTimeString)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(isActive ? W.wine : W.sub(scheme))
                .frame(width: 58, alignment: .trailing)
                .padding(.trailing, 10)

            // Color dot
            Circle()
                .fill(isActive ? W.wine : W.sub(scheme).opacity(0.35))
                .frame(width: 4, height: 4)
                .padding(.trailing, 8)

            // Name
            Text(course.name)
                .font(.system(
                    size: 12,
                    weight: isActive ? .semibold : .regular,
                    design: isActive ? .serif : .default
                ))
                .foregroundStyle(W.ink(scheme))
                .lineLimit(1)

            Spacer(minLength: 4)

            // Room
            Text(W.room(course, session))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(W.sub(scheme))
                .padding(.trailing, isActive ? 6 : 0)

            // NOW badge
            if isActive {
                Text("AHORA")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(W.wine)
                    .tracking(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(W.wine.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .opacity(rowOpacity)
        .background(isActive ? W.wine.opacity(0.04) : Color.clear)
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    UAMScheduleWidget()
} timeline: { ScheduleEntry.placeholder }

#Preview("Medium", as: .systemMedium) {
    UAMScheduleWidget()
} timeline: { ScheduleEntry.placeholder }

#Preview("Large", as: .systemLarge) {
    UAMScheduleWidget()
} timeline: { ScheduleEntry.placeholder }
