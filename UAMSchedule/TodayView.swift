import WidgetKit
import SwiftUI
import UserNotifications

// MARK: - TodayView

struct TodayView: View {
    @EnvironmentObject var store: ScheduleStore
    @EnvironmentObject var profile: UserProfile
    @State private var now = Date()
    @State private var appeared = false
    @State private var showProfile = false
    @State private var showNotifications = false
    @State private var showSettings = false
    @State private var quoteVisible = true
    @State private var showCampusMap = false
    @State private var progressAnimated = false

    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    let quotes = [
        "Un dia a la vez, una clase a la vez.",
        "La constancia es la clave del exito academico.",
        "El esfuerzo de hoy es el logro de manana.",
        "Cada clase completada es un paso mas hacia tu meta.",
        "Sigue adelante, el semestre no dura para siempre.",
        "La disciplina supera al talento cuando el talento no es disciplinado.",
        "Estudia como si dependiera de ti. Descansa como si lo merecieras.",
        "No cuentes los dias, haz que los dias cuenten.",
    ]

    var todayClasses: [(course: Course, session: ClassSession)] { store.todayClasses() }
    var currentClass: (course: Course, session: ClassSession)? { store.currentClass() }
    var nextClass:    (course: Course, session: ClassSession)? { store.nextClass() }

    var completedCount: Int {
        let nowMin = Calendar.current.component(.hour, from: now) * 60
                   + Calendar.current.component(.minute, from: now)
        return todayClasses.filter { nowMin > $0.session.endHour * 60 + $0.session.endMinute }.count
    }

    var totalCredits: Int { store.courses.reduce(0) { $0 + $1.credits } }

    var quoteOfDay: String {
        quotes[Calendar.current.component(.day, from: now) % quotes.count]
    }

    // Upcoming reminders (next 3, not done)
    var upcomingReminders: [(course: Course, reminder: CourseReminder)] {
        Array(store.upcomingReminders().prefix(3))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                headerRow
                    .padding(.horizontal, DS.Space.lg)
                    .padding(.top, 18).padding(.bottom, 12)
                    .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                    .animation(DS.Anim.easeSlow.delay(0.06), value: appeared)

                // Quote strip
                if quoteVisible {
                    quoteStrip
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.bottom, 14)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                        .animation(DS.Anim.easeSlow.delay(0.10), value: appeared)
                }

                // Stat chips
                statChips
                    .padding(.horizontal, DS.Space.lg)
                    .padding(.bottom, 18)
                    .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                    .animation(DS.Anim.easeSlow.delay(0.16), value: appeared)

                // Active class card (hero)
                if let current = currentClass {
                    ActiveClassHeroCard(course: current.course, session: current.session, now: now)
                        .padding(.horizontal, DS.Space.md)
                        .padding(.bottom, 14)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                        .animation(DS.Anim.easeSlow.delay(0.20), value: appeared)
                }

                // Next class card
                if let next = nextClass, next.session.id != currentClass?.session.id {
                    nextClassCard(next)
                        .padding(.horizontal, DS.Space.md)
                        .padding(.bottom, 14)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                        .animation(DS.Anim.easeSlow.delay(0.22), value: appeared)
                }

                // Day progress card (animated)
                if !todayClasses.isEmpty {
                    dayProgressCard
                        .padding(.horizontal, DS.Space.md)
                        .padding(.bottom, 14)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                        .animation(DS.Anim.easeSlow.delay(0.28), value: appeared)
                }

                // Quick actions row
                quickActionsRow
                    .padding(.horizontal, DS.Space.md)
                    .padding(.bottom, 18)
                    .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                    .animation(DS.Anim.easeSlow.delay(0.32), value: appeared)

                // Upcoming reminders
                if !upcomingReminders.isEmpty {
                    upcomingRemindersCard
                        .padding(.horizontal, DS.Space.md)
                        .padding(.bottom, 14)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                        .animation(DS.Anim.easeSlow.delay(0.36), value: appeared)
                }

                // Today schedule
                scheduleSection
                    .padding(.bottom, 120)
                    .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                    .animation(DS.Anim.easeSlow.delay(0.40), value: appeared)
            }
        }
        .background(Color.appBackground)
        .onAppear {
            now = Date(); appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(DS.Anim.spring) { progressAnimated = true }
            }
        }
        .onReceive(timer) { t in now = t }
        .sheet(isPresented: $showProfile)       { profileSheet }
        .sheet(isPresented: $showNotifications) { NotificationsSheet() }
        .sheet(isPresented: $showSettings)      { SettingsView().environmentObject(store).environmentObject(profile) }
        .sheet(isPresented: $showCampusMap)     { UAMRouteView().environmentObject(store) }
    }

    // MARK: - Header Row

    var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { showProfile = true } label: { avatarView(size: 46) }.buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(DS.Font.display(22, weight: .semibold))
                    .foregroundStyle(Color.appInk).lineLimit(1)
                Text(dayLabel)
                    .font(DS.Font.body(11))
                    .foregroundStyle(Color.appInkTertiary)
            }

            Spacer()

            HStack(spacing: 18) {
                Button { showNotifications = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(DS.Color.wine)
                        if hasUrgentReminder {
                            Circle().fill(Color(hex: "#CC1A1A"))
                                .frame(width: 7, height: 7)
                                .offset(x: 3, y: -3)
                        }
                    }
                }.buttonStyle(.plain)

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(DS.Color.wine)
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: - Quote Strip

    var quoteStrip: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(DS.Color.wine)
                .frame(width: 2.5, height: 32)
            Text(quoteOfDay)
                .font(DS.Font.display(13))
                .foregroundStyle(Color.appInkSecondary)
                .lineLimit(2)
                .lineSpacing(2)
            Spacer()
            Button {
                withAnimation(DS.Anim.springFast) { quoteVisible = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.appInkTertiary)
            }.buttonStyle(.plain)
        }
    }

    // MARK: - Stat Chips

    var statChips: some View {
        HStack(spacing: 8) {
            TodayStatChip(icon: "graduationcap.fill",
                     value: profile.semester.isEmpty ? "-" : profile.semester,
                     label: "Semestre", hasPulse: false)
            TodayStatChip(icon: "star.square.fill", value: "\(totalCredits)",
                     label: "Creditos", hasPulse: false)
            TodayStatChip(icon: "tray.2.fill", value: "\(store.courses.count)",
                     label: "Materias", hasPulse: false)
            TodayStatChip(
                icon: todayClasses.isEmpty ? "moon.fill" : "checkmark.circle.fill",
                value: todayClasses.isEmpty ? "-" : "\(completedCount)/\(todayClasses.count)",
                label: "Hoy",
                hasPulse: !todayClasses.isEmpty && completedCount < todayClasses.count
            )
        }
    }

    // MARK: - Quick Actions Row

    var quickActionsRow: some View {
        HStack(spacing: 10) {
            QuickActionButton(icon: "map.fill", label: "Campus") {
                Soft.haptic(.light); showCampusMap = true
            }
            QuickActionButton(icon: "bell.badge.fill", label: "Recordatorios") {
                Soft.haptic(.light); showNotifications = true
            }
            QuickActionButton(icon: "calendar", label: "Semana") {
                Soft.haptic(.light)
                // Navigate to week tab — post notification
                NotificationCenter.default.post(name: Notification.Name("uam.switchToWeek"), object: nil)
            }
            QuickActionButton(icon: "gearshape.fill", label: "Ajustes") {
                Soft.haptic(.light); showSettings = true
            }
        }
    }

    // MARK: - Upcoming Reminders Card

    var upcomingRemindersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(DS.Color.wine)
                    Text("RECORDATORIOS").font(DS.Font.body(9, weight: .bold)).foregroundStyle(Color.appInkTertiary).tracking(2.5)
                }
                Spacer()
                Text("\(upcomingReminders.count) pendiente\(upcomingReminders.count == 1 ? "" : "s")")
                    .font(DS.Font.mono(10, weight: .bold)).foregroundStyle(DS.Color.wine)
            }

            VStack(spacing: 8) {
                ForEach(upcomingReminders, id: \.reminder.id) { item in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: item.reminder.priority.color))
                            .frame(width: 3, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.reminder.title)
                                .font(DS.Font.body(12, weight: .medium)).foregroundStyle(Color.appInk).lineLimit(1)
                            Text(item.course.name)
                                .font(DS.Font.body(10)).foregroundStyle(Color.appInkTertiary).lineLimit(1)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if item.reminder.isOverdue {
                                Text("VENCIDA").font(DS.Font.body(8, weight: .black)).foregroundStyle(.white)
                                    .padding(.horizontal, 5).padding(.vertical, 2).background(Color.red).clipShape(Capsule())
                            } else {
                                Text(item.reminder.dueDate, style: .date).font(DS.Font.mono(9)).foregroundStyle(Color.appInkTertiary)
                                Text(item.reminder.dueDate, style: .time).font(DS.Font.mono(9)).foregroundStyle(Color.appInkTertiary)
                            }
                        }
                    }
                    if item.reminder.id != upcomingReminders.last?.reminder.id {
                        Divider().background(Color.appCardBorder)
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
        .shadow(color: DS.Color.wine.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Next Class Card

    func nextClassCard(_ item: (course: Course, session: ClassSession)) -> some View {
        let mins = minutesUntil(session: item.session)
        let isUrgent = mins < 30

        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isUrgent ? Color(hex: "#CC1A1A") : DS.Color.wine)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    TodayPulseDot(color: isUrgent ? Color(hex: "#CC1A1A") : DS.Color.wine, size: 6)
                    Text("PROXIMA")
                        .font(DS.Font.body(9, weight: .black))
                        .foregroundStyle(Color.appInkTertiary).tracking(3)
                }

                Text(item.course.name)
                    .font(DS.Font.display(20, weight: .semibold))
                    .foregroundStyle(Color.appInk).lineLimit(1)

                HStack(spacing: 8) {
                    Text(item.course.code)
                        .font(DS.Font.mono(9, weight: .bold)).foregroundStyle(DS.Color.wine)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(DS.Color.wineMuted).clipShape(Capsule())

                    let room = item.session.room.isEmpty ? item.course.room : item.session.room
                    if !room.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill").font(.system(size: 9)).foregroundStyle(Color.appInkTertiary)
                            Text(room).font(DS.Font.mono(11)).foregroundStyle(Color.appInkTertiary)
                        }
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill").font(.system(size: 9)).foregroundStyle(Color.appInkTertiary)
                        Text(item.session.startTimeString).font(DS.Font.mono(11)).foregroundStyle(Color.appInkTertiary)
                    }
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text(formatMinutes(mins))
                    .font(DS.Font.body(13, weight: .bold))
                    .foregroundStyle(isUrgent ? .white : DS.Color.wine)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(isUrgent ? Color(hex: "#CC1A1A") : DS.Color.wineMuted)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(isUrgent ? Color(hex: "#CC1A1A").opacity(0.2) : Color.appCardBorder, lineWidth: isUrgent ? 1.5 : 1))
        .shadow(color: DS.Color.wine.opacity(0.06), radius: 10, y: 3)
    }

    // MARK: - Day Progress Card (animated)

    var dayProgressCard: some View {
        let total = todayClasses.count
        let done  = completedCount
        let pct   = total > 0 ? CGFloat(done) / CGFloat(total) : 0
        let animPct = progressAnimated ? pct : 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PROGRAMA DEL DIA")
                    .font(DS.Font.body(9, weight: .bold))
                    .foregroundStyle(Color.appInkTertiary).tracking(2.5)
                Spacer()
                Text("\(done)/\(total) clases")
                    .font(DS.Font.mono(11, weight: .bold))
                    .foregroundStyle(DS.Color.wine)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background with shimmer
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.appBackgroundTertiary)
                        .frame(height: 10)

                    // Gradient fill
                    if animPct > 0 {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(
                                colors: [DS.Color.wine, DS.Color.wineLight, DS.Color.wine],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * animPct, height: 10)
                            .animation(.spring(response: 1.2, dampingFraction: 0.75), value: animPct)
                    }

                    // Glow at tip
                    if animPct > 0.02 {
                        Circle()
                            .fill(DS.Color.wine)
                            .frame(width: 16, height: 16)
                            .shadow(color: DS.Color.wine.opacity(0.6), radius: 6)
                            .offset(x: geo.size.width * animPct - 8, y: -3)
                            .animation(.spring(response: 1.2, dampingFraction: 0.75), value: animPct)
                    }

                    // Segment dots
                    ForEach(0..<total, id: \.self) { idx in
                        let x = total > 1 ? geo.size.width * CGFloat(idx + 1) / CGFloat(total) : geo.size.width
                        Circle()
                            .fill(idx < done ? .white : Color.appBackgroundSecondary)
                            .overlay(Circle().stroke(idx < done ? DS.Color.wine : Color.appInkTertiary.opacity(0.2), lineWidth: 1.5))
                            .frame(width: 13, height: 13)
                            .offset(x: x - 6.5, y: -1.5)
                            .scaleEffect(progressAnimated && idx < done ? 1.1 : 1.0)
                            .animation(DS.Anim.spring.delay(Double(idx) * 0.12 + 0.4), value: progressAnimated)
                    }
                }
            }
            .frame(height: 16)

            // Time stamps for each class
            if todayClasses.count > 1 {
                HStack {
                    ForEach(Array(todayClasses.enumerated()), id: \.element.session.id) { idx, item in
                        if idx > 0 { Spacer() }
                        Text(item.session.startTimeString)
                            .font(DS.Font.mono(9))
                            .foregroundStyle(idx < done ? DS.Color.wine : Color.appInkTertiary.opacity(0.4))
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // MARK: - Schedule Section

    var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOY")
                .font(DS.Font.body(9, weight: .black))
                .foregroundStyle(Color.appInkTertiary).tracking(3)
                .padding(.horizontal, DS.Space.lg)

            if todayClasses.isEmpty {
                TodayEmptyCard().padding(.horizontal, DS.Space.md)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(todayClasses.enumerated()), id: \.element.session.id) { idx, item in
                        TodayClassCard(course: item.course, session: item.session, now: now, index: idx)
                    }
                }
                .padding(.horizontal, DS.Space.md)
            }
        }
    }

    // MARK: - Profile Sheet

    var profileSheet: some View {
        VStack(spacing: DS.Space.lg) {
            avatarView(size: 76).padding(.top, DS.Space.xl)
            VStack(spacing: 4) {
                Text(profile.name)
                    .font(DS.Font.display(22, weight: .semibold)).foregroundStyle(Color.appInk)
                if !profile.semester.isEmpty {
                    Text("Semestre \(profile.semester)")
                        .font(DS.Font.body(13)).foregroundStyle(Color.appInkTertiary)
                }
            }
            HStack(spacing: 12) {
                TodayProfileBadge(icon: "star.square.fill",       value: "\(totalCredits)",   label: "Creditos")
                TodayProfileBadge(icon: "tray.2.fill",            value: "\(store.courses.count)", label: "Materias")
                TodayProfileBadge(icon: "checkmark.circle.fill",  value: "\(completedCount)/\(todayClasses.count)", label: "Hoy")
            }
            .padding(.horizontal, DS.Space.lg)
            Spacer()
        }
        .presentationDetents([.medium])
        .background(Color.appBackground)
    }

    // MARK: - Helpers

    var hasUrgentReminder: Bool {
        upcomingReminders.contains { $0.reminder.isOverdue || $0.reminder.isDueSoon }
    }

    var dayLabel: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_NI")
        f.dateFormat = "EEEE, d 'de' MMMM"
        return f.string(from: now).capitalized
    }

    func minutesUntil(session: ClassSession) -> Int {
        let cal = Calendar.current
        let nowMin  = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let nowWday = cal.component(.weekday, from: now)
        let startMin = session.startHour * 60 + session.startMinute
        if session.weekday == nowWday { return max(0, startMin - nowMin) }
        return ((session.weekday - nowWday + 7) % 7) * 24 * 60 + startMin
    }

    func formatMinutes(_ m: Int) -> String {
        if m < 60   { return "En \(m) min" }
        if m < 1440 { let h = m/60; let r = m%60; return r > 0 ? "En \(h)h \(r)m" : "En \(h)h" }
        return m / 1440 == 1 ? "Manana" : "En \(m / 1440) dias"
    }

    func avatarView(size: CGFloat) -> some View {
        ZStack {
            Circle().fill(DS.Color.wineMuted).frame(width: size, height: size)
            if profile.hasPhoto, let img = profile.profileImage {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: size, height: size).clipShape(Circle())
            } else {
                Text(profile.name.isEmpty ? "?" : String(profile.name.prefix(1)).uppercased())
                    .font(DS.Font.display(size * 0.38, weight: .semibold)).foregroundStyle(DS.Color.wine)
            }
        }
        .overlay(Circle().stroke(DS.Color.wine, lineWidth: 1.5))
    }
}

// MARK: - Active Class Hero Card

struct ActiveClassHeroCard: View {
    let course: Course; let session: ClassSession; let now: Date
    @State private var pulse = false
    @State private var shimmer = false

    var progress: Double {
        let nowMin = Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now)
        let start = session.startHour * 60 + session.startMinute
        let end   = session.endHour   * 60 + session.endMinute
        return min(1, max(0, Double(nowMin - start) / Double(max(1, end - start))))
    }

    var minutesLeft: Int {
        let nowMin = Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now)
        return max(0, session.endHour * 60 + session.endMinute - nowMin)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    TodayPulseDot(color: DS.Color.wine, size: 7)
                    Text("EN CURSO AHORA")
                        .font(DS.Font.body(9, weight: .black))
                        .foregroundStyle(DS.Color.wine).tracking(2)
                }
                Spacer()
                Text("\(minutesLeft) min restantes")
                    .font(DS.Font.mono(11, weight: .bold)).foregroundStyle(DS.Color.wine)
            }

            Text(course.name)
                .font(DS.Font.display(24, weight: .semibold))
                .foregroundStyle(Color.appInk).lineLimit(2)

            HStack(spacing: 10) {
                Text(course.code)
                    .font(DS.Font.mono(10, weight: .bold)).foregroundStyle(DS.Color.wine)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(DS.Color.wineMuted).clipShape(Capsule())
                let room = session.room.isEmpty ? course.room : session.room
                if !room.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill").font(.system(size: 11)).foregroundStyle(DS.Color.wine.opacity(0.6))
                        Text(room).font(DS.Font.mono(12)).foregroundStyle(Color.appInkTertiary)
                    }
                }
                Spacer()
                Text("\(session.startTimeString)–\(session.endTimeString)")
                    .font(DS.Font.mono(10)).foregroundStyle(Color.appInkTertiary)
            }

            // Animated progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.appBackgroundTertiary).frame(height: 7)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [DS.Color.wine, DS.Color.wineLight], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: 7)
                        .animation(DS.Anim.easeSlow, value: progress)

                    // shimmer overlay
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.clear, .white.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 60, height: 7)
                        .offset(x: shimmer ? geo.size.width * progress : 0)
                        .opacity(shimmer ? 0 : 1)
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false), value: shimmer)
                }
            }
            .frame(height: 7)
        }
        .padding(18)
        .background(
            ZStack {
                Color.appBackgroundSecondary
                LinearGradient(colors: [DS.Color.wine.opacity(0.04), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(DS.Color.wine.opacity(0.2), lineWidth: 1.5))
        .shadow(color: DS.Color.wine.opacity(0.10), radius: 16, y: 5)
        .onAppear { shimmer = true }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String; let label: String; let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            withAnimation(DS.Anim.springFast) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(DS.Anim.springFast) { pressed = false }
                action()
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(pressed ? DS.Color.wine : DS.Color.wineMuted)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(pressed ? .white : DS.Color.wine)
                }
                Text(label)
                    .font(DS.Font.body(10, weight: .medium))
                    .foregroundStyle(Color.appInkTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.93 : 1.0)
    }
}

// MARK: - Today Stat Chip

struct TodayStatChip: View {
    let icon: String; let value: String; let label: String; let hasPulse: Bool
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DS.Color.wineMuted).frame(width: 30, height: 30)
                if hasPulse {
                    Circle().fill(DS.Color.wine).frame(width: 7, height: 7)
                        .scaleEffect(pulse ? 1.5 : 1.0)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                        .onAppear { pulse = true }
                } else {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.Color.wine)
                }
            }
            Text(value)
                .font(DS.Font.mono(17, weight: .bold)).foregroundStyle(Color.appInk)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label)
                .font(DS.Font.body(9)).foregroundStyle(Color.appInkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 12)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
        .contextMenu { Label(label, systemImage: icon) }
    }
}

// MARK: - Today Class Card

struct TodayClassCard: View {
    let course: Course; let session: ClassSession; let now: Date; let index: Int
    @State private var isDone = false
    @State private var cardAppeared = false

    var isActive: Bool {
        let cal = Calendar.current
        let nowMin = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let wday   = cal.component(.weekday, from: now)
        guard session.weekday == wday else { return false }
        return nowMin >= session.startHour * 60 + session.startMinute
            && nowMin <= session.endHour   * 60 + session.endMinute
    }

    var isPast: Bool {
        guard !isActive else { return false }
        let cal = Calendar.current
        let nowMin = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let wday   = cal.component(.weekday, from: now)
        guard session.weekday == wday else { return false }
        return nowMin > session.endHour * 60 + session.endMinute
    }

    var progress: Double {
        guard isActive else { return 0 }
        let cal = Calendar.current
        let nowMin = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let start = session.startHour * 60 + session.startMinute
        let end   = session.endHour   * 60 + session.endMinute
        return min(1, max(0, Double(nowMin - start) / Double(max(1, end - start))))
    }

    var minutesLeft: Int {
        let nowMin = Calendar.current.component(.hour, from: now) * 60
                   + Calendar.current.component(.minute, from: now)
        return max(0, session.endHour * 60 + session.endMinute - nowMin)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(isActive ? DS.Color.wine : Color(hex: course.color).opacity(isPast ? 0.3 : 0.8))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 7) {
                // Line 1: code + room + time badge
                HStack(spacing: 7) {
                    Text(course.code)
                        .font(DS.Font.mono(9, weight: .bold)).foregroundStyle(DS.Color.wine)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(DS.Color.wineMuted).clipShape(Capsule())

                    let room = session.room.isEmpty ? course.room : session.room
                    if !room.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill").font(.system(size: 9)).foregroundStyle(Color.appInkTertiary)
                            Text(room).font(DS.Font.mono(10)).foregroundStyle(Color.appInkTertiary)
                        }
                    }

                    Spacer()

                    let t = "\(session.startTimeString)-\(session.endTimeString)".replacingOccurrences(of: " ", with: "")
                    Text(t)
                        .font(DS.Font.mono(10))
                        .foregroundStyle(isActive ? DS.Color.wine : Color.appInkTertiary.opacity(isPast ? 0.4 : 0.9))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(isActive ? DS.Color.wineMuted : Color.appBackgroundTertiary)
                        .clipShape(Capsule())
                }

                // Line 2: name + checkbox
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        if isActive {
                            HStack(spacing: 4) {
                                TodayPulseDot(color: DS.Color.wine, size: 5)
                                Text("EN CURSO")
                                    .font(DS.Font.body(8, weight: .black))
                                    .foregroundStyle(DS.Color.wine).tracking(1.5)
                            }
                        }
                        Text(course.name)
                            .font(DS.Font.body(15, weight: isActive ? .semibold : .medium))
                            .foregroundStyle(Color.appInk.opacity(isPast ? 0.35 : 1))
                            .lineLimit(1)
                    }
                    Spacer()

                    Button {
                        withAnimation(DS.Anim.spring) { isDone.toggle() }
                        Soft.haptic(isDone ? .success : .selection)
                    } label: {
                        ZStack {
                            Circle().stroke(DS.Color.wine, lineWidth: 1.5).frame(width: 22, height: 22)
                            if isDone || isPast {
                                Circle().fill(DS.Color.wine).frame(width: 22, height: 22)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            }
                        }
                    }.buttonStyle(.plain)
                }

                // Progress bar (active only)
                if isActive {
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.appBackgroundTertiary).frame(height: 4)
                                RoundedRectangle(cornerRadius: 3).fill(
                                    LinearGradient(colors: [DS.Color.wine, DS.Color.wineLight],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geo.size.width * progress, height: 4)
                                .animation(DS.Anim.easeSlow, value: progress)
                            }
                        }
                        .frame(height: 4)
                        HStack {
                            Label(session.room.isEmpty ? course.room : session.room, systemImage: "mappin")
                                .font(DS.Font.body(10)).foregroundStyle(Color.appInkTertiary)
                                .tint(DS.Color.wine.opacity(0.5))
                            Spacer()
                            Text("\(minutesLeft) min restantes")
                                .font(DS.Font.mono(10, weight: .semibold)).foregroundStyle(DS.Color.wine)
                        }
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
        }
        .background(isActive ? DS.Color.wine.opacity(0.03) : Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(isActive ? DS.Color.wine.opacity(0.25) : Color.appCardBorder,
                    lineWidth: isActive ? 1.5 : 1))
        .shadow(color: isActive ? DS.Color.wine.opacity(0.07) : .clear, radius: 8, y: 3)
        .opacity(cardAppeared ? 1 : 0).offset(y: cardAppeared ? 0 : 10)
        .animation(DS.Anim.spring.delay(Double(index) * 0.07), value: cardAppeared)
        .onAppear { cardAppeared = true; isDone = isPast }
    }
}

// MARK: - Today Pulse Dot

struct TodayPulseDot: View {
    let color: Color; let size: CGFloat
    @State private var pulse = false
    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
            .scaleEffect(pulse ? 1.6 : 1.0)
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

// MARK: - Today Empty Card

struct TodayEmptyCard: View {
    @State private var float = false
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(DS.Color.wineMuted).frame(width: 48, height: 48)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 20)).foregroundStyle(DS.Color.wine)
            }
            .offset(y: float ? -3 : 0)
            .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: float)

            VStack(alignment: .leading, spacing: 3) {
                Text("Sin clases hoy")
                    .font(DS.Font.body(15, weight: .semibold)).foregroundStyle(Color.appInkTertiary.opacity(0.7))
                Text("Disfruta tu dia libre")
                    .font(DS.Font.body(12)).foregroundStyle(Color.appInkTertiary.opacity(0.4))
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 18)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
        .onAppear { float = true }
    }
}

// MARK: - Today Profile Badge

struct TodayProfileBadge: View {
    let icon: String; let value: String; let label: String
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(DS.Color.wine)
            Text(value).font(DS.Font.mono(16, weight: .bold)).foregroundStyle(Color.appInk)
            Text(label).font(DS.Font.body(10)).foregroundStyle(Color.appInkTertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

// MARK: - Notifications Sheet

struct NotifItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let date: Date?
    let isScheduled: Bool
}

struct NotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [NotifItem] = []
    @State private var appeared = false

    var delivered: [NotifItem] { items.filter { !$0.isScheduled } }
    var scheduled: [NotifItem] { items.filter { $0.isScheduled } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                if items.isEmpty && appeared {
                    VStack(spacing: 16) {
                        Spacer()
                        ZStack {
                            Circle().fill(DS.Color.wineMuted).frame(width: 72, height: 72)
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 28, weight: .light)).foregroundStyle(DS.Color.wine)
                        }
                        Text("Sin notificaciones")
                            .font(DS.Font.body(16, weight: .semibold)).foregroundStyle(Color.appInkTertiary)
                        Text("Las alertas de clases apareceran aqui.")
                            .font(DS.Font.body(12)).foregroundStyle(Color.appInkTertiary.opacity(0.5))
                            .multilineTextAlignment(.center).padding(.horizontal, 40)
                        Spacer()
                    }
                } else {
                    List {
                        if !delivered.isEmpty {
                            Section {
                                ForEach(delivered) { item in
                                    NotifRow(item: item)
                                        .listRowBackground(Color.appBackgroundSecondary)
                                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                withAnimation { items.removeAll { $0.id == item.id } }
                                                UNUserNotificationCenter.current()
                                                    .removeDeliveredNotifications(withIdentifiers: [item.id])
                                            } label: {
                                                Label("Borrar", systemImage: "trash.fill")
                                            }
                                            Button {
                                                withAnimation { items.removeAll { $0.id == item.id } }
                                            } label: {
                                                Label("Archivar", systemImage: "archivebox.fill")
                                            }
                                            .tint(Color(hex: "#1A3A6B"))
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                withAnimation { items.removeAll { $0.id == item.id } }
                                            } label: {
                                                Label("Leido", systemImage: "checkmark.circle.fill")
                                            }
                                            .tint(Color(hex: "#1A5C3A"))
                                        }
                                }
                            } header: {
                                Text("RECIENTES")
                                    .font(DS.Font.body(9, weight: .bold))
                                    .foregroundStyle(Color.appInkTertiary).tracking(2)
                            }
                        }

                        if !scheduled.isEmpty {
                            Section {
                                ForEach(scheduled) { item in
                                    NotifRow(item: item)
                                        .listRowBackground(Color.appBackgroundSecondary)
                                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                withAnimation { items.removeAll { $0.id == item.id } }
                                                UNUserNotificationCenter.current()
                                                    .removePendingNotificationRequests(withIdentifiers: [item.id])
                                            } label: { Label("Cancelar", systemImage: "xmark.circle.fill") }
                                        }
                                }
                            } header: {
                                Text("PROGRAMADAS")
                                    .font(DS.Font.body(9, weight: .bold))
                                    .foregroundStyle(Color.appInkTertiary).tracking(2)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.easeSlow, value: appeared)
                }
            }
            .navigationTitle("Notificaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Color.appInkTertiary)
                }
                ToolbarItem(placement: .primaryAction) {
                    if !delivered.isEmpty {
                        Button("Limpiar todo") {
                            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                            withAnimation { items.removeAll { !$0.isScheduled } }
                        }
                        .foregroundStyle(DS.Color.wine).font(DS.Font.body(13))
                    }
                }
            }
        }
        .onAppear { loadNotifications() }
    }

    func loadNotifications() {
        UNUserNotificationCenter.current().getDeliveredNotifications { @Sendable notifications in
            let extracted: [NotifItem] = notifications.map { n in
                NotifItem(id: n.request.identifier, title: n.request.content.title,
                          subtitle: n.request.content.body, date: n.date, isScheduled: false)
            }.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            Task { @MainActor in
                items.removeAll { !$0.isScheduled }
                items.insert(contentsOf: extracted, at: 0)
                appeared = true
            }
        }
        UNUserNotificationCenter.current().getPendingNotificationRequests { @Sendable requests in
            let extracted: [NotifItem] = requests.compactMap { r in
                let triggerDate: Date?
                if let cal = r.trigger as? UNCalendarNotificationTrigger { triggerDate = cal.nextTriggerDate() }
                else if let iv = r.trigger as? UNTimeIntervalNotificationTrigger { triggerDate = iv.nextTriggerDate() }
                else { triggerDate = nil }
                return NotifItem(id: r.identifier, title: r.content.title,
                                 subtitle: r.content.body, date: triggerDate, isScheduled: true)
            }.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
            Task { @MainActor in
                items.removeAll { $0.isScheduled }
                items.append(contentsOf: extracted)
            }
        }
    }
}

// MARK: - Notif Row

struct NotifRow: View {
    let item: NotifItem

    var dateLabel: String {
        guard let d = item.date else { return "" }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_NI"); f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: Date())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(DS.Color.wineMuted).frame(width: 36, height: 36)
                Image(systemName: item.isScheduled ? "clock.fill" : "bell.fill")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(DS.Color.wine)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                if !item.title.isEmpty {
                    Text(item.title)
                        .font(DS.Font.body(13, weight: .semibold)).foregroundStyle(Color.appInk).lineLimit(1)
                }
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary).lineLimit(2)
                }
                if !dateLabel.isEmpty {
                    Text(dateLabel)
                        .font(DS.Font.mono(10)).foregroundStyle(Color.appInkTertiary.opacity(0.55))
                }
            }
            Spacer()
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 12)
    }
}

// MARK: - Legacy aliases (required by other files)

struct StatChip: View {
    let icon: String; let value: String; let label: String; let hasPulse: Bool
    var body: some View { TodayStatChip(icon: icon, value: value, label: label, hasPulse: hasPulse) }
}
struct StatTile: View {
    let icon: String; let value: String; let label: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            Text(value).font(DS.Font.display(16, weight: .bold)).foregroundStyle(Color.appInk).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(DS.Font.body(9)).foregroundStyle(Color.appInkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 11)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
    }
}
struct AnimatedStatTile: View {
    let icon: String; let value: String; let label: String; let color: Color; let delay: Double
    var body: some View { StatTile(icon: icon, value: value, label: label, color: color) }
}
struct PhotoAvatar: View {
    @EnvironmentObject var profile: UserProfile; let size: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(DS.Color.wineMuted).frame(width: size, height: size)
            if profile.hasPhoto, let img = profile.profileImage {
                Image(uiImage: img).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle())
            } else {
                Text(profile.name.isEmpty ? "?" : String(profile.name.prefix(1)).uppercased())
                    .font(DS.Font.display(size * 0.38, weight: .semibold)).foregroundStyle(DS.Color.wine)
            }
        }.overlay(Circle().stroke(DS.Color.wine.opacity(0.2), lineWidth: 1.5))
    }
}
struct ProfileStatBadge: View {
    let icon: String; let value: String; let label: String
    var body: some View { TodayProfileBadge(icon: icon, value: value, label: label) }
}
struct PulseDot: View {
    let color: Color; let size: CGFloat
    var body: some View { TodayPulseDot(color: color, size: size) }
}
struct CompactEmptyDay: View { var body: some View { TodayEmptyCard() } }
struct CompactClassCard: View {
    let course: Course; let session: ClassSession; let now: Date; let index: Int
    var body: some View { TodayClassCard(course: course, session: session, now: now, index: index) }
}
struct SemesterChip: View {
    let icon: String; let text: String
    var body: some View { HStack(spacing: 4) { Image(systemName: icon).font(.system(size: 9)).foregroundStyle(DS.Color.wine.opacity(0.7)); Text(text).font(DS.Font.body(10, weight: .medium)).foregroundStyle(Color.appInkSecondary).lineLimit(1) } }
}
struct DayProgressBar: View {
    let completed: Int; let total: Int; let sessions: [(course: Course, session: ClassSession)]; let now: Date
    var body: some View { EmptyView() }
}
typealias TodayRow = TodayClassCard
struct TodayTimelineRow: View {
    let course: Course; let session: ClassSession; let now: Date; let isLast: Bool
    var body: some View { TodayClassCard(course: course, session: session, now: now, index: 0) }
}
struct ActiveClassCard: View {
    let course: Course; let session: ClassSession; let now: Date
    var body: some View { TodayClassCard(course: course, session: session, now: now, index: 0) }
}
struct NextClassBanner: View { let course: Course; let session: ClassSession; let now: Date; var body: some View { EmptyView() } }
struct EmptyDayCard: View { var body: some View { TodayEmptyCard() } }
struct WeeklyOverviewMini: View { @EnvironmentObject var store: ScheduleStore; var body: some View { EmptyView() } }
struct CreditsMiniChart: View { @EnvironmentObject var store: ScheduleStore; var body: some View { EmptyView() } }
struct ProfileAvatar: View {
    @EnvironmentObject var profile: UserProfile; let size: CGFloat
    var body: some View { PhotoAvatar(size: size).environmentObject(profile) }
}
