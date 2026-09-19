import SwiftUI

enum WeekFilter: String, CaseIterable {
    case all = "Todas", morning = "AM", afternoon = "PM", evening = "Noche"
    var icon: String {
        switch self { case .all: return "list.bullet"; case .morning: return "sunrise.fill"; case .afternoon: return "sun.max.fill"; case .evening: return "moon.fill" }
    }
    func matches(_ s: ClassSession) -> Bool {
        switch self { case .all: return true; case .morning: return s.startHour < 12; case .afternoon: return s.startHour >= 12 && s.startHour < 17; case .evening: return s.startHour >= 17 }
    }
}

enum ScheduleViewMode: String, CaseIterable {
    case weekly = "Semana"
    case monthly = "Mes"
}

struct WeekView: View {
    @EnvironmentObject var store: ScheduleStore
    @State private var appeared = false
    @State private var selectedFilter: WeekFilter = .all
    @State private var selectedDay: Int? = nil
    @State private var viewMode: ScheduleViewMode = .weekly

    let dayFull   = ["","Domingo","Lunes","Martes","Miércoles","Jueves","Viernes","Sábado"]
    let dayLetter = ["","D","L","M","X","J","V","S"]

    var currentWeekday: Int { Calendar.current.component(.weekday, from: Date()) }
    var activeDays: [Int] { (1...7).filter { w in store.courses.contains { $0.sessions.contains { $0.weekday == w } } } }

    func sessions(_ w: Int) -> [(Course, ClassSession)] {
        var r: [(Course, ClassSession)] = []
        for c in store.courses { for s in c.sessions where s.weekday == w && selectedFilter.matches(s) { r.append((c, s)) } }
        return r.sorted { $0.1.startHour*60+$0.1.startMinute < $1.1.startHour*60+$1.1.startMinute }
    }

    var totalH: Int { store.courses.flatMap { $0.sessions }.reduce(0) { $0 + $1.durationMinutes } / 60 }
    var days: [Int] { let base = selectedDay != nil ? [selectedDay!] : activeDays; return base.filter { !sessions($0).isEmpty } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header ─────────────────────────────────
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("HORARIO").font(DS.Font.body(9, weight: .semibold)).foregroundStyle(DS.Color.wine).tracking(3)
                        Text(viewMode == .weekly ? "Semana" : "Mes")
                            .font(DS.Font.display(34, weight: .semibold)).foregroundStyle(Color.appInk)
                        WineAccentLine(height: 1.5, width: 36).padding(.top, 2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(totalH)h").font(DS.Font.display(24, weight: .bold)).foregroundStyle(DS.Color.wine)
                        Text("semanal").font(DS.Font.body(10)).foregroundStyle(Color.appInkTertiary)
                    }
                }
                .padding(.horizontal, DS.Space.lg).padding(.top, 20).padding(.bottom, 16)
                .opacity(appeared ? 1 : 0).animation(DS.Anim.easeSlow, value: appeared)

                // ── View mode toggle ────────────────────────
                HStack(spacing: 0) {
                    ForEach(ScheduleViewMode.allCases, id: \.self) { mode in
                        let sel = viewMode == mode
                        Button {
                            withAnimation(DS.Anim.spring) { viewMode = mode; selectedDay = nil }
                        } label: {
                            Text(mode.rawValue)
                                .font(DS.Font.body(13, weight: sel ? .bold : .medium))
                                .foregroundStyle(sel ? .white : Color.appInkSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(sel ? DS.Color.wine : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.appBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
                .padding(.horizontal, DS.Space.md)
                .padding(.bottom, DS.Space.md)
                .opacity(appeared ? 1 : 0).animation(DS.Anim.easeSlow.delay(0.06), value: appeared)

                if viewMode == .weekly {
                    weeklyContent
                } else {
                    MonthlyScheduleView()
                        .padding(.horizontal, DS.Space.md)
                        .opacity(appeared ? 1 : 0)
                        .animation(DS.Anim.easeSlow.delay(0.1), value: appeared)
                }
            }
        }
        .background(Color.appBackground)
        .onAppear { appeared = true }
    }

    // MARK: - Weekly content (original layout)

    var weeklyContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                // Day pills
                HStack(spacing: 0) {
                    ForEach(activeDays, id: \.self) { w in
                        let isToday = w == currentWeekday
                        let isSel = selectedDay == w
                        let count = sessions(w).count

                        Button {
                            withAnimation(DS.Anim.springFast) { selectedDay = selectedDay == w ? nil : w }
                        } label: {
                            VStack(spacing: 4) {
                                Text(dayLetter[w])
                                    .font(.system(size: 13, weight: isToday || isSel ? .bold : .medium))
                                    .foregroundStyle(isSel ? .white : (isToday ? DS.Color.wine : Color.appInkSecondary))
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(isSel ? .white.opacity(0.7) : Color.appInkTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                    .fill(isSel ? DS.Color.wine : (isToday ? DS.Color.wine.opacity(0.08) : Color.clear))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(Color.appBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))

                // Filters
                HStack(spacing: 6) {
                    ForEach(WeekFilter.allCases, id: \.self) { f in
                        let sel = selectedFilter == f
                        Button {
                            withAnimation(DS.Anim.springFast) { selectedFilter = f }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: f.icon).font(.system(size: 10, weight: .medium))
                                Text(f.rawValue).font(.system(size: 11, weight: sel ? .bold : .regular))
                            }
                            .foregroundStyle(sel ? .white : Color.appInkTertiary)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(sel ? DS.Color.wine : Color.appBackgroundSecondary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(sel ? Color.clear : Color.appCardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, DS.Space.lg)
            .opacity(appeared ? 1 : 0)
            .animation(DS.Anim.easeSlow.delay(0.08), value: appeared)

            if days.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 28, weight: .light)).foregroundStyle(Color.appInkTertiary.opacity(0.3))
                    Text("Sin clases con este filtro")
                        .font(DS.Font.body(14)).foregroundStyle(Color.appInkTertiary.opacity(0.5))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 60)
            } else {
                VStack(spacing: 20) {
                    ForEach(Array(days.enumerated()), id: \.element) { idx, w in
                        DayCard(weekday: w, dayName: dayFull[w], items: sessions(w))
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(DS.Anim.spring.delay(0.14 + Double(idx) * 0.06), value: appeared)
                    }
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.bottom, 120)
            }
        }
    }
}

// MARK: - Monthly Schedule View

struct MonthlyScheduleView: View {
    @EnvironmentObject var store: ScheduleStore
    @State private var selectedDate: Date? = nil
    @State private var displayMonth: Date = Date()

    let calendar = Calendar.current
    let dayLetters = ["D","L","M","X","J","V","S"]

    // All days in the current displayed month
    var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: displayMonth),
              let start = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth))
        else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: start) }
    }

    // Leading blank days to align first day of month
    var leadingBlanks: Int {
        guard let first = daysInMonth.first else { return 0 }
        return (calendar.component(.weekday, from: first) - 1 + 7) % 7
    }

    var monthLabel: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "es"); f.dateFormat = "MMMM yyyy"
        return f.string(from: displayMonth).capitalized
    }

    // Sessions for a given calendar weekday (1=Sun)
    func sessions(for weekday: Int) -> [(Course, ClassSession)] {
        var r: [(Course, ClassSession)] = []
        for c in store.courses { for s in c.sessions where s.weekday == weekday { r.append((c, s)) } }
        return r.sorted { $0.1.startHour*60+$0.1.startMinute < $1.1.startHour*60+$1.1.startMinute }
    }

    func hasClasses(on date: Date) -> Bool {
        let wd = calendar.component(.weekday, from: date)
        return store.courses.contains { $0.sessions.contains { $0.weekday == wd } }
    }

    func dotColors(on date: Date) -> [String] {
        let wd = calendar.component(.weekday, from: date)
        return sessions(for: wd).prefix(3).map { $0.0.color }
    }

    var selectedSessions: [(Course, ClassSession)] {
        guard let d = selectedDate else { return [] }
        let wd = calendar.component(.weekday, from: d)
        return sessions(for: wd)
    }

    var body: some View {
        VStack(spacing: DS.Space.lg) {

            // Month nav
            HStack {
                Button {
                    withAnimation(DS.Anim.spring) {
                        displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                        selectedDate = nil
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DS.Color.wine)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthLabel)
                    .font(DS.Font.display(18, weight: .semibold))
                    .foregroundStyle(Color.appInk)

                Spacer()

                Button {
                    withAnimation(DS.Anim.spring) {
                        displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                        selectedDate = nil
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DS.Color.wine)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // Day letters header
            HStack(spacing: 0) {
                ForEach(dayLetters, id: \.self) { d in
                    Text(d)
                        .font(DS.Font.body(12, weight: .semibold))
                        .foregroundStyle(Color.appInkTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid — totalCells unused, grid handles layout automatically

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                // Leading blanks
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Rectangle().fill(Color.clear).frame(height: 52)
                }
                // Days
                ForEach(daysInMonth, id: \.self) { date in
                    let day = calendar.component(.day, from: date)
                    let isToday = calendar.isDateInToday(date)
                    let isSel = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                    let hasCls = hasClasses(on: date)
                    let dots = dotColors(on: date)

                    Button {
                        withAnimation(DS.Anim.springFast) {
                            selectedDate = isSel ? nil : date
                        }
                    } label: {
                        VStack(spacing: 3) {
                            ZStack {
                                Circle()
                                    .fill(isSel ? DS.Color.wine : (isToday ? DS.Color.wineMuted : Color.clear))
                                    .frame(width: 32, height: 32)
                                Text("\(day)")
                                    .font(DS.Font.body(14, weight: isToday || isSel ? .bold : .regular))
                                    .foregroundStyle(isSel ? .white : (isToday ? DS.Color.wine : Color.appInk))
                            }
                            // Color dots for each class
                            HStack(spacing: 2) {
                                ForEach(dots.indices, id: \.self) { i in
                                    Circle()
                                        .fill(Color(hex: dots[i]))
                                        .frame(width: 4, height: 4)
                                }
                                if dots.isEmpty && hasCls {
                                    Circle().fill(Color.appInkTertiary.opacity(0.3)).frame(width: 4, height: 4)
                                }
                            }
                            .frame(height: 6)
                        }
                        .frame(height: 52)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Selected day detail
            if let date = selectedDate, !selectedSessions.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    let f: DateFormatter = {
                        let fmt = DateFormatter(); fmt.locale = Locale(identifier: "es"); fmt.dateFormat = "EEEE d 'de' MMMM"
                        return fmt
                    }()
                    Text(f.string(from: date).capitalized)
                        .font(DS.Font.body(13, weight: .semibold))
                        .foregroundStyle(Color.appInkSecondary)
                        .padding(.horizontal, 4)

                    VStack(spacing: 8) {
                        ForEach(selectedSessions, id: \.1.id) { item in
                            MonthSessionRow(course: item.0, session: item.1)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let _ = selectedDate {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.minus")
                        .foregroundStyle(Color.appInkTertiary.opacity(0.4))
                    Text("Sin clases este día")
                        .font(DS.Font.body(13)).foregroundStyle(Color.appInkTertiary.opacity(0.5))
                }
                .frame(maxWidth: .infinity).padding(.vertical, DS.Space.md)
                .transition(.opacity)
            }

            Spacer().frame(height: 80)
        }
    }
}

// MARK: - Month Session Row

struct MonthSessionRow: View {
    let course: Course; let session: ClassSession

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color(hex: course.color)).frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            HStack(spacing: 10) {
                VStack(spacing: 1) {
                    Text(session.startTimeString)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.appInkSecondary)
                    Text(session.endTimeString)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.appInkTertiary)
                }
                .frame(width: 62)

                Rectangle().fill(Color.appSeparator).frame(width: 0.5, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(course.name)
                        .font(DS.Font.body(13, weight: .medium))
                        .foregroundStyle(Color.appInk).lineLimit(1)
                    HStack(spacing: 6) {
                        if !course.code.isEmpty {
                            Text(course.code).font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(hex: course.color).opacity(0.7)).tracking(0.8)
                        }
                        if !session.room.isEmpty {
                            Text(session.room).font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color.appInkTertiary)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 10)
        }
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

// MARK: - Day Card (existing weekly view)

struct DayCard: View {
    let weekday: Int; let dayName: String
    let items: [(course: Course, session: ClassSession)]
    var isToday: Bool { Calendar.current.component(.weekday, from: Date()) == weekday }
    var totalMin: Int { items.reduce(0) { $0 + $1.session.durationMinutes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    if isToday { RoundedRectangle(cornerRadius: 2).fill(DS.Color.wine).frame(width: 3, height: 16) }
                    Text(dayName).font(DS.Font.display(16, weight: .semibold))
                        .foregroundStyle(isToday ? DS.Color.wine : Color.appInk)
                    if isToday {
                        Text("HOY").font(.system(size: 8, weight: .black)).foregroundStyle(.white).tracking(1.5)
                            .padding(.horizontal, 6).padding(.vertical, 3).background(DS.Color.wine).clipShape(Capsule())
                    }
                }
                Spacer()
                Text("\(items.count) · \(totalMin/60)h\(totalMin%60 > 0 ? "\(totalMin%60)m" : "")")
                    .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Color.appInkTertiary)
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)

            Rectangle().fill(Color.appSeparator).frame(height: 0.5).padding(.horizontal, 14)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.session.id) { idx, item in
                    SessionRow(course: item.course, session: item.session)
                    if idx < items.count - 1 {
                        Rectangle().fill(Color.appSeparator).frame(height: 0.5).padding(.leading, 80)
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(isToday ? DS.Color.wine.opacity(0.2) : Color.appCardBorder, lineWidth: isToday ? 1.5 : 1))
        .shadow(color: isToday ? DS.Color.wine.opacity(0.06) : Color.clear, radius: 8, y: 3)
    }
}

// MARK: - Session Row (existing)

struct SessionRow: View {
    let course: Course; let session: ClassSession
    var isNow: Bool {
        let cal = Calendar.current; let now = Date()
        let m = cal.component(.hour, from: now)*60 + cal.component(.minute, from: now)
        let w = cal.component(.weekday, from: now)
        guard session.weekday == w else { return false }
        return m >= session.startHour*60+session.startMinute && m <= session.endHour*60+session.endMinute
    }
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color(hex: course.color)).frame(width: 3)
                .padding(.vertical, 8).clipShape(Capsule()).padding(.leading, 14)
            VStack(spacing: 2) {
                Text(session.startTimeString).font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(isNow ? DS.Color.wine : Color.appInkSecondary)
                Text(session.endTimeString).font(.system(size: 9, design: .monospaced)).foregroundStyle(Color.appInkTertiary)
            }
            .frame(width: 62).padding(.leading, 10)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(course.name).font(DS.Font.body(13, weight: .medium)).foregroundStyle(Color.appInk).lineLimit(1)
                    if course.isFavorite { Image(systemName: "heart.fill").font(.system(size: 8)).foregroundStyle(DS.Color.wine) }
                    if isNow {
                        Text("AHORA").font(.system(size: 7, weight: .black)).foregroundStyle(.white).tracking(1)
                            .padding(.horizontal, 5).padding(.vertical, 2).background(DS.Color.wine).clipShape(Capsule())
                    }
                }
                HStack(spacing: 8) {
                    if !course.code.isEmpty { Text(course.code).font(.system(size: 9, weight: .bold)).foregroundStyle(Color(hex: course.color).opacity(0.65)).tracking(0.8) }
                    if !session.room.isEmpty { Text(session.room).font(.system(size: 9, design: .monospaced)).foregroundStyle(Color.appInkTertiary) }
                    Text("\(course.credits) cr.").font(.system(size: 9)).foregroundStyle(Color.appInkTertiary)
                }
            }
            .padding(.leading, 10)
            Spacer()
        }
        .padding(.vertical, 10)
        .background(isNow ? DS.Color.wine.opacity(0.03) : Color.clear)
    }
}
