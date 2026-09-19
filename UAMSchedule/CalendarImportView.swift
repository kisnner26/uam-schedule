import SwiftUI
import EventKit

struct CalendarImportView: View {
    @EnvironmentObject var store: ScheduleStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .intro
    @State private var allCalendars: [EKCalendar] = []
    @State private var selectedCalendarId: String? = nil
    @State private var detectedCourses: [DetectedCourse] = []
    @State private var selectedIds: Set<UUID> = []
    @State private var permissionDenied = false
    @State private var appeared = false
    @State private var isAnalyzing = false
    // Keep EKEventStore alive for the entire lifetime of this view
    private let ek = EKEventStore()

    enum Step { case intro, picking, reviewing, done }

    var selectedCalendar: EKCalendar? {
        allCalendars.first { $0.calendarIdentifier == selectedCalendarId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                switch step {
                case .intro:     introStep
                case .picking:   pickingStep
                case .reviewing: reviewStep
                case .done:      doneStep
                }
            }
            .navigationTitle("Importar Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.appInkTertiary)
                }
            }
        }
        .onAppear { appeared = true }
    }

    // MARK: - Intro

    var introStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: DS.Space.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(DS.Color.wineMuted).frame(width: 96, height: 96)
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(DS.Color.wine)
                }
                .scaleEffect(appeared ? 1 : 0.85)
                .animation(DS.Anim.spring.delay(0.1), value: appeared)

                VStack(spacing: 10) {
                    Text("Importar desde Calendario")
                        .font(DS.Font.display(22, weight: .semibold))
                        .foregroundStyle(Color.appInk).multilineTextAlignment(.center)
                    Text("Detecta automaticamente tus clases en el Calendario de Apple. Eventos que se repiten semanalmente se convierten en materias con horario.")
                        .font(DS.Font.body(14)).foregroundStyle(Color.appInkTertiary)
                        .multilineTextAlignment(.center).lineSpacing(3)
                        .padding(.horizontal, DS.Space.lg)
                }
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                .animation(DS.Anim.easeSlow.delay(0.15), value: appeared)

                VStack(spacing: 8) {
                    DetectRow(icon: "repeat",   text: "Eventos que se repiten cada semana")
                    DetectRow(icon: "clock",    text: "Hora de inicio y fin de cada clase")
                    DetectRow(icon: "mappin",   text: "Aula o ubicacion del evento")
                }
                .opacity(appeared ? 1 : 0)
                .animation(DS.Anim.easeSlow.delay(0.2), value: appeared)
            }
            Spacer()

            if permissionDenied {
                VStack(spacing: 10) {
                    Text("Acceso al calendario denegado")
                        .font(DS.Font.body(13)).foregroundStyle(Color.appInkTertiary)
                    Text("Ve a Ajustes > Privacidad > Calendarios y activa el permiso para UAMSchedule.")
                        .font(DS.Font.body(12)).foregroundStyle(Color.appInkTertiary)
                        .multilineTextAlignment(.center).padding(.horizontal, DS.Space.lg)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Abrir Ajustes del Sistema")
                            .font(DS.Font.body(13, weight: .semibold)).foregroundStyle(DS.Color.wine)
                    }.buttonStyle(.plain)
                }
                .padding(.bottom, DS.Space.lg)
            }

            Button { requestAccess() } label: {
                Label(permissionDenied ? "Reintentar acceso" : "Conectar Calendario Apple",
                      systemImage: "calendar")
                    .font(DS.Font.body(16, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(DS.Color.wine)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                    .shadow(color: DS.Color.wine.opacity(0.3), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Space.md).padding(.bottom, 48)
            .opacity(appeared ? 1 : 0)
            .animation(DS.Anim.spring.delay(0.25), value: appeared)
        }
    }

    // MARK: - Picking

    var pickingStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PASO 1 DE 2").font(DS.Font.body(9, weight: .semibold))
                        .foregroundStyle(DS.Color.wine).tracking(3)
                    Text("Elige un calendario")
                        .font(DS.Font.display(26, weight: .semibold)).foregroundStyle(Color.appInk)
                    WineAccentLine(height: 1.5, width: 36).padding(.top, 3)
                    Text("Selecciona el calendario donde guardas tus clases")
                        .font(DS.Font.body(13)).foregroundStyle(Color.appInkTertiary).padding(.top, 3)
                }
                .padding(.horizontal, DS.Space.lg)
                .padding(.top, DS.Space.lg).padding(.bottom, DS.Space.xl)

                VStack(spacing: 8) {
                    ForEach(allCalendars, id: \.calendarIdentifier) { cal in
                        let isSel = selectedCalendarId == cal.calendarIdentifier
                        Button {
                            withAnimation(DS.Anim.springFast) { selectedCalendarId = cal.calendarIdentifier }
                        } label: {
                            HStack(spacing: 14) {
                                Circle().fill(Color(cgColor: cal.cgColor)).frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(Color.appCardBorder, lineWidth: 1))
                                Text(cal.title)
                                    .font(DS.Font.body(15, weight: isSel ? .semibold : .regular))
                                    .foregroundStyle(Color.appInk)
                                Spacer()
                                if isSel {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20)).foregroundStyle(DS.Color.wine)
                                } else {
                                    Circle().stroke(Color.appInkTertiary.opacity(0.2), lineWidth: 1.5)
                                        .frame(width: 20, height: 20)
                                }
                            }
                            .padding(14)
                            .background(isSel ? DS.Color.wine.opacity(0.04) : Color.appBackgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(isSel ? DS.Color.wine.opacity(0.25) : Color.appCardBorder,
                                        lineWidth: isSel ? 1.5 : 1))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Space.md)

                if selectedCalendarId != nil {
                    Button { if !isAnalyzing { detectClasses() } } label: {
                        HStack(spacing: 8) {
                            if isAnalyzing { ProgressView().progressViewStyle(.circular).tint(.white) }
                            Text(isAnalyzing ? "Analizando..." : "Analizar calendario")
                                .font(DS.Font.body(15, weight: .bold)).foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(DS.Color.wine)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                        .shadow(color: DS.Color.wine.opacity(0.3), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain).disabled(isAnalyzing)
                    .padding(.horizontal, DS.Space.md)
                    .padding(.top, DS.Space.xl).padding(.bottom, 40)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
    }

    // MARK: - Review

    var reviewStep: some View {
        VStack(spacing: 0) {
            if detectedCourses.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 40, weight: .light)).foregroundStyle(Color.appInkTertiary.opacity(0.3))
                    Text("Sin clases detectadas")
                        .font(DS.Font.body(15, weight: .semibold)).foregroundStyle(Color.appInkTertiary.opacity(0.6))
                    Text("No se encontraron eventos que se repitan semanalmente en las proximas 18 semanas.")
                        .font(DS.Font.body(13)).foregroundStyle(Color.appInkTertiary.opacity(0.45))
                        .multilineTextAlignment(.center).padding(.horizontal, DS.Space.xl)
                    Button { withAnimation(DS.Anim.springFast) { step = .picking } } label: {
                        Text("Elegir otro calendario")
                            .font(DS.Font.body(13, weight: .semibold)).foregroundStyle(DS.Color.wine)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(DS.Color.wineMuted).clipShape(Capsule())
                    }.buttonStyle(.plain)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PASO 2 DE 2").font(DS.Font.body(9, weight: .semibold))
                                .foregroundStyle(DS.Color.wine).tracking(3)
                            Text("Confirmar materias")
                                .font(DS.Font.display(26, weight: .semibold)).foregroundStyle(Color.appInk)
                            WineAccentLine(height: 1.5, width: 36).padding(.top, 3)
                            HStack(spacing: 4) {
                                Text("\(detectedCourses.count) clases detectadas")
                                Text("·")
                                Button {
                                    withAnimation(DS.Anim.springFast) {
                                        selectedIds = Set(detectedCourses.map { $0.id })
                                    }
                                } label: { Text("Seleccionar todo").foregroundStyle(DS.Color.wine) }
                                .buttonStyle(.plain)
                            }
                            .font(DS.Font.body(12)).foregroundStyle(Color.appInkTertiary).padding(.top, 3)
                        }
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.top, DS.Space.lg).padding(.bottom, DS.Space.lg)

                        VStack(spacing: 8) {
                            ForEach(detectedCourses) { dc in
                                DetectedCourseCard(dc: dc, isSelected: selectedIds.contains(dc.id)) {
                                    withAnimation(DS.Anim.springFast) {
                                        if selectedIds.contains(dc.id) { selectedIds.remove(dc.id) }
                                        else { selectedIds.insert(dc.id) }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DS.Space.md).padding(.bottom, 120)
                    }
                }
                if !selectedIds.isEmpty {
                    VStack {
                        Spacer()
                        Button {
                            detectedCourses.filter { selectedIds.contains($0.id) }
                                .map { $0.toCourse() }.forEach { store.addCourse($0) }
                            withAnimation(DS.Anim.spring) { step = .done }
                        } label: {
                            Text("Importar \(selectedIds.count) materia\(selectedIds.count > 1 ? "s" : "")")
                                .font(DS.Font.body(15, weight: .bold)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 15)
                                .background(DS.Color.wine)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                                .shadow(color: DS.Color.wine.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DS.Space.md).padding(.bottom, 32)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
    }

    // MARK: - Done

    var doneStep: some View {
        VStack(spacing: DS.Space.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64)).foregroundStyle(Color(hex: "#1A5C3A"))
            VStack(spacing: 6) {
                Text("Importado!")
                    .font(DS.Font.display(26, weight: .semibold)).foregroundStyle(Color.appInk)
                Text("\(selectedIds.count) materia\(selectedIds.count > 1 ? "s" : "") agregada\(selectedIds.count > 1 ? "s" : "") a tu horario.")
                    .font(DS.Font.body(14)).foregroundStyle(Color.appInkTertiary)
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Listo").font(DS.Font.body(16, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(DS.Color.wine).clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            }.buttonStyle(.plain).padding(.horizontal, DS.Space.md).padding(.bottom, 48)
        }
    }

    // MARK: - Permission Request (iOS 17 + fallback)

    func requestAccess() {
        permissionDenied = false
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized, .fullAccess:
            loadCalendars()
        case .denied, .restricted:
            permissionDenied = true
        case .notDetermined, .writeOnly:
            if #available(iOS 17.0, *) {
                ek.requestFullAccessToEvents { granted, _ in
                    DispatchQueue.main.async {
                        if granted { self.loadCalendars() } else { self.permissionDenied = true }
                    }
                }
            } else {
                ek.requestAccess(to: .event) { granted, _ in
                    DispatchQueue.main.async {
                        if granted { self.loadCalendars() } else { self.permissionDenied = true }
                    }
                }
            }
        @unknown default:
            ek.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async {
                    if granted { self.loadCalendars() } else { self.permissionDenied = true }
                }
            }
        }
    }

    func loadCalendars() {
        allCalendars = ek.calendars(for: .event).sorted { $0.title < $1.title }
        withAnimation(DS.Anim.spring) { step = .picking }
    }

    func detectClasses() {
        guard let cal = selectedCalendar else { return }
        isAnalyzing = true
        let ekRef = self.ek

        DispatchQueue.global(qos: .userInitiated).async {
            let now = Date()
            let end = Calendar.current.date(byAdding: .weekOfYear, value: 18, to: now) ?? now
            let pred = ekRef.predicateForEvents(withStart: now, end: end, calendars: [cal])
            let events = ekRef.events(matching: pred).filter { !$0.isAllDay }

            var groups: [String: [EKEvent]] = [:]
            for event in events {
                let key = (event.title ?? "Sin titulo").trimmingCharacters(in: .whitespaces)
                guard !key.isEmpty else { continue }
                groups[key, default: []].append(event)
            }

            let recurring = groups.filter { $0.value.count >= 3 }
            let detected: [DetectedCourse] = recurring.map { title, evts in
                let sorted = evts.sorted { $0.startDate < $1.startDate }
                let first = sorted[0]
                let weekdays = Set(sorted.map { Calendar.current.component(.weekday, from: $0.startDate) })
                let sessions: [ClassSession] = weekdays.compactMap { wd in
                    guard let sample = sorted.first(where: {
                        Calendar.current.component(.weekday, from: $0.startDate) == wd
                    }) else { return nil }
                    let c = Calendar.current
                    return ClassSession(
                        weekday: wd,
                        startHour: c.component(.hour, from: sample.startDate),
                        startMinute: c.component(.minute, from: sample.startDate),
                        endHour: c.component(.hour, from: sample.endDate),
                        endMinute: c.component(.minute, from: sample.endDate),
                        room: sample.location ?? ""
                    )
                }.sorted { $0.weekday < $1.weekday }

                let colors = DS.Color.courseColors
                return DetectedCourse(
                    title: title, room: first.location ?? "", sessions: sessions,
                    occurrences: evts.count,
                    color: colors[abs(title.hashValue) % colors.count],
                    calColor: Color(cgColor: cal.cgColor)
                )
            }.sorted { $0.title < $1.title }

            DispatchQueue.main.async {
                detectedCourses = detected
                selectedIds = Set(detected.map { $0.id })
                isAnalyzing = false
                withAnimation(DS.Anim.spring) { step = .reviewing }
            }
        }
    }
}

// MARK: - Models & Subviews

struct DetectedCourse: Identifiable, @unchecked Sendable {
    let id = UUID()
    let title: String; let room: String; let sessions: [ClassSession]
    let occurrences: Int; let color: String; let calColor: Color
    func toCourse() -> Course { Course(name: title, room: room, color: color, sessions: sessions) }
    var daysLabel: String {
        let names = ["","Dom","Lun","Mar","Mie","Jue","Vie","Sab"]
        return sessions.map { names[$0.weekday] }.joined(separator: " · ")
    }
    var timeLabel: String { guard let f = sessions.first else { return "" }; return "\(f.startTimeString) - \(f.endTimeString)" }
}

struct DetectedCourseCard: View {
    let dc: DetectedCourse; let isSelected: Bool; let onToggle: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? DS.Color.wine : Color.appInkTertiary.opacity(0.3))
                .animation(DS.Anim.springFast, value: isSelected)
            Rectangle().fill(Color(hex: dc.color)).frame(width: 3, height: 48).clipShape(Capsule())
            VStack(alignment: .leading, spacing: 4) {
                Text(dc.title).font(DS.Font.body(14, weight: .semibold)).foregroundStyle(Color.appInk).lineLimit(1)
                HStack(spacing: 10) {
                    if !dc.room.isEmpty {
                        Label(dc.room, systemImage: "mappin").font(DS.Font.body(10))
                            .foregroundStyle(Color.appInkTertiary).tint(DS.Color.wine.opacity(0.4))
                    }
                    Text(dc.daysLabel).font(DS.Font.body(10)).foregroundStyle(Color.appInkTertiary)
                }
                HStack(spacing: 8) {
                    Text(dc.timeLabel).font(DS.Font.mono(10)).foregroundStyle(Color.appInkTertiary)
                    Text("·").foregroundStyle(Color.appInkTertiary.opacity(0.4))
                    Text("\(dc.occurrences) ocurrencias").font(DS.Font.mono(10)).foregroundStyle(DS.Color.wine.opacity(0.6))
                }
            }
            Spacer()
        }
        .padding(12)
        .background(isSelected ? DS.Color.wine.opacity(0.03) : Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md)
            .stroke(isSelected ? DS.Color.wine.opacity(0.2) : Color.appCardBorder, lineWidth: isSelected ? 1.5 : 1))
        .onTapGesture { onToggle() }
    }
}

struct DetectRow: View {
    let icon: String; let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.Color.wine.opacity(0.65)).frame(width: 20)
            Text(text).font(DS.Font.body(13)).foregroundStyle(Color.appInkSecondary)
            Spacer()
        }.padding(.horizontal, DS.Space.lg)
    }
}
