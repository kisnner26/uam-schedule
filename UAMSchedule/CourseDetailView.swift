import SwiftUI

struct CourseDetailView: View {
    @EnvironmentObject var store: ScheduleStore
    let courseId: UUID
    @State private var selectedTab = 0
    @State private var showRoute = false
    @Environment(\.dismiss) private var dismiss

    var course: Course? { store.courses.first { $0.id == courseId } }

    let tabs = ["Recordatorios", "Pendientes", "Flashcards", "Notas", "Moodle"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                if let course = course {
                    VStack(spacing: 0) {

                        // ── Route to classroom ───────────────────
                        RouteToClassroomCard(course: course) {
                            Soft.haptic(.light)
                            showRoute = true
                        }
                        .padding(.horizontal, DS.Space.md)
                        .padding(.top, DS.Space.md)

                        // Tab selector
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tabs.indices, id: \.self) { i in
                                    Button {
                                        Soft.haptic(.selection)
                                        withAnimation(DS.Anim.springFast) { selectedTab = i }
                                    } label: {
                                        Text(tabs[i])
                                            .font(DS.Font.body(12, weight: selectedTab == i ? .bold : .regular))
                                            .foregroundStyle(selectedTab == i ? .white : Color.appInkSecondary)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(selectedTab == i ? Color(hex: course.color) : Color.appBackgroundSecondary)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(selectedTab == i ? Color.clear : Color.appCardBorder, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, DS.Space.lg)
                            .padding(.vertical, DS.Space.md)
                        }

                        // Content
                        Group {
                            switch selectedTab {
                            case 0: RemindersTab(courseId: courseId)
                            case 1: ChecklistTab(courseId: courseId)
                            case 2: FlashcardsTab(courseId: courseId)
                            case 3: GradesTab(courseId: courseId)
                            case 4: MoodleAssignmentsTab(courseName: course.name)
                            default: EmptyView()
                            }
                        }
                    }
                    .navigationTitle(course.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") { dismiss() }.foregroundStyle(Color.appInkTertiary)
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                Soft.haptic(.light)
                                showRoute = true
                            } label: {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(hex: course.color))
                            }
                        }
                    }
                    .sheet(isPresented: $showRoute) {
                        UAMRouteView()
                    }
                }
            }
        }
    }
}

// MARK: - Route to classroom card

private struct RouteToClassroomCard: View {
    let course: Course
    let onTap: () -> Void

    private var inferredBuilding: UAMBuilding? {
        UAMCampus.inferBuilding(for: course, session: course.sessions.first)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(hex: course.color).opacity(0.08))
                        .frame(width: 38, height: 38)
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: course.color))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("CÓMO LLEGAR AL AULA")
                        .font(DS.Font.body(9, weight: .semibold))
                        .foregroundStyle(Color(hex: course.color))
                        .tracking(2)
                    HStack(spacing: 5) {
                        Text(course.room.isEmpty ? "Sin aula asignada" : "Aula \(course.room)")
                            .font(DS.Font.body(13, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                        if let b = inferredBuilding {
                            Text("·")
                                .foregroundStyle(Color.appInkTertiary)
                            Text(b.code)
                                .font(DS.Font.body(12, weight: .medium))
                                .foregroundStyle(Color.appInkSecondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appInkTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.appBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(Color(hex: course.color).opacity(0.25), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reminders Tab

struct RemindersTab: View {
    @EnvironmentObject var store: ScheduleStore
    let courseId: UUID
    @State private var showAdd = false
    @State private var newTitle = ""
    @State private var newDate = Date()
    @State private var newPriority: ReminderPriority = .medium
    @State private var newNotes = ""
    @State private var editingReminder: CourseReminder? = nil

    var course: Course? { store.courses.first { $0.id == courseId } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Space.md) {
                // Add button
                Button { withAnimation(DS.Anim.spring) { showAdd.toggle() } } label: {
                    Label("Agregar recordatorio", systemImage: "plus.circle.fill")
                        .font(DS.Font.body(14, weight: .semibold))
                        .foregroundStyle(DS.Color.wine)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Space.md)
                        .background(DS.Color.wineMuted)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                }
                .buttonStyle(.plain)

                // Add form
                if showAdd {
                    ReminderForm(
                        title: $newTitle, date: $newDate, priority: $newPriority, notes: $newNotes,
                        buttonLabel: "Guardar recordatorio"
                    ) {
                        guard !newTitle.isEmpty else { return }
                        let r = CourseReminder(title: newTitle, dueDate: newDate, priority: newPriority, notes: newNotes)
                        withAnimation(DS.Anim.spring) {
                            store.addReminder(to: courseId, reminder: r)
                            // Schedule system notification
                            if let c = course { NotificationManager.shared.scheduleReminder(r, for: c) }
                            newTitle = ""; newNotes = ""; newDate = Date(); showAdd = false
                        }
                        Soft.haptic(.success)
                    } onCancel: {
                        withAnimation(DS.Anim.springFast) { showAdd = false }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // List
                if let reminders = course?.reminders.sorted(by: { $0.dueDate < $1.dueDate }), !reminders.isEmpty {
                    ForEach(reminders) { rem in
                        ReminderRow(reminder: rem, courseColor: course?.color ?? "#6B1A2A") {
                            withAnimation(DS.Anim.springFast) { store.toggleReminder(courseId: courseId, reminderId: rem.id) }
                        } onEdit: {
                            editingReminder = rem
                        } onDelete: {
                            NotificationManager.shared.cancelReminder(rem.id)
                            withAnimation(DS.Anim.spring) { store.deleteReminder(courseId: courseId, reminderId: rem.id) }
                        }
                    }
                } else if !showAdd {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash").font(.system(size: 28)).foregroundStyle(Color.appInkTertiary.opacity(0.3))
                        Text("Sin recordatorios").font(DS.Font.body(14)).foregroundStyle(Color.appInkTertiary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, 40)
        }
        .sheet(item: $editingReminder) { rem in
            EditReminderSheet(reminder: rem, courseId: courseId, course: course)
                .environmentObject(store)
        }
    }
}

// MARK: - Shared Reminder Form

struct ReminderForm: View {
    @Binding var title: String
    @Binding var date: Date
    @Binding var priority: ReminderPriority
    @Binding var notes: String
    var buttonLabel: String
    var onSave: () -> Void
    var onCancel: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            TextField("Ej: Entregar proyecto final", text: $title)
                .font(DS.Font.body(14)).padding(12)
                .background(Color.appBackgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            DatePicker("Fecha límite", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .font(DS.Font.body(13)).tint(DS.Color.wine)

            Picker("Prioridad", selection: $priority) {
                ForEach(ReminderPriority.allCases, id: \.self) { p in Text(p.rawValue).tag(p) }
            }
            .pickerStyle(.segmented)

            TextField("Notas adicionales (opcional)", text: $notes, axis: .vertical)
                .font(DS.Font.body(13)).lineLimit(3)
                .padding(10).background(Color.appBackgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 10) {
                if let cancel = onCancel {
                    Button { cancel() } label: {
                        Text("Cancelar").font(DS.Font.body(14, weight: .medium)).foregroundStyle(Color.appInkTertiary)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.appBackgroundTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    }.buttonStyle(.plain)
                }
                Button { onSave() } label: {
                    Text(buttonLabel).font(DS.Font.body(14, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(DS.Color.wine).clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                }.buttonStyle(.plain)
            }
        }
        .cardStyle()
    }
}

// MARK: - Edit Reminder Sheet

struct EditReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: ScheduleStore
    let reminder: CourseReminder
    let courseId: UUID
    let course: Course?

    @State private var title: String
    @State private var date: Date
    @State private var priority: ReminderPriority
    @State private var notes: String

    init(reminder: CourseReminder, courseId: UUID, course: Course?) {
        self.reminder = reminder; self.courseId = courseId; self.course = course
        _title = State(initialValue: reminder.title)
        _date = State(initialValue: reminder.dueDate)
        _priority = State(initialValue: reminder.priority)
        _notes = State(initialValue: reminder.notes)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ReminderForm(title: $title, date: $date, priority: $priority, notes: $notes, buttonLabel: "Guardar cambios") {
                        guard !title.isEmpty else { return }
                        // Cancel old notification, schedule new one
                        NotificationManager.shared.cancelReminder(reminder.id)
                        var updated = reminder
                        updated.title = title; updated.dueDate = date; updated.priority = priority; updated.notes = notes
                        // Update in store
                        store.deleteReminder(courseId: courseId, reminderId: reminder.id)
                        store.addReminder(to: courseId, reminder: updated)
                        if let c = course { NotificationManager.shared.scheduleReminder(updated, for: c) }
                        Soft.haptic(.success)
                        dismiss()
                    }
                    .padding(.horizontal, DS.Space.md)
                    .padding(.top, DS.Space.md)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Editar recordatorio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.appInkTertiary)
                }
            }
        }
    }
}

struct ReminderRow: View {
    let reminder: CourseReminder
    let courseColor: String
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: reminder.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22)).foregroundStyle(reminder.isDone ? Color(hex: courseColor) : Color.appInkTertiary.opacity(0.4))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(reminder.title)
                        .font(DS.Font.body(14, weight: .medium))
                        .foregroundStyle(reminder.isDone ? Color.appInkTertiary : Color.appInk)
                        .strikethrough(reminder.isDone)
                    if reminder.isOverdue {
                        Text("VENCIDA").font(DS.Font.body(8, weight: .black)).foregroundStyle(.white).tracking(1)
                            .padding(.horizontal, 5).padding(.vertical, 2).background(Color.red).clipShape(Capsule())
                    } else if reminder.isDueSoon {
                        Text("PRONTO").font(DS.Font.body(8, weight: .black)).foregroundStyle(.white).tracking(1)
                            .padding(.horizontal, 5).padding(.vertical, 2).background(Color.orange).clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: reminder.priority.icon).font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(hex: reminder.priority.color))
                    Text(reminder.dueDate, style: .date).font(DS.Font.mono(10)).foregroundStyle(Color.appInkTertiary)
                    Text(reminder.dueDate, style: .time).font(DS.Font.mono(10)).foregroundStyle(Color.appInkTertiary)
                }

                if !reminder.notes.isEmpty {
                    Text(reminder.notes).font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary).lineLimit(2)
                }
            }

            Spacer()

            HStack(spacing: 14) {
                Button(action: onEdit) {
                    Image(systemName: "pencil").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.Color.wine.opacity(0.6))
                }.buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(Color.appInkTertiary.opacity(0.4))
                }.buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

// MARK: - Checklist Tab

struct ChecklistTab: View {
    @EnvironmentObject var store: ScheduleStore
    let courseId: UUID
    @State private var newItem = ""

    var course: Course? { store.courses.first { $0.id == courseId } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Space.md) {
                // Progress
                if let c = course, !c.checklist.isEmpty {
                    VStack(spacing: 6) {
                        HStack {
                            Text("Progreso").font(DS.Font.body(12, weight: .medium)).foregroundStyle(Color.appInkTertiary)
                            Spacer()
                            Text("\(Int(c.checklistProgress * 100))%").font(DS.Font.mono(12, weight: .bold)).foregroundStyle(DS.Color.wine)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Color.appBackgroundTertiary).frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [DS.Color.wine, DS.Color.wineLight], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * c.checklistProgress, height: 8)
                                    .animation(DS.Anim.easeSlow, value: c.checklistProgress)
                            }
                        }.frame(height: 8)
                    }
                    .cardStyle()
                }

                // Add
                HStack(spacing: 8) {
                    TextField("Nuevo pendiente...", text: $newItem)
                        .font(DS.Font.body(14)).padding(10)
                        .background(Color.appBackgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Button {
                        guard !newItem.isEmpty else { return }
                        withAnimation(DS.Anim.spring) {
                            store.addChecklistItem(to: courseId, item: ChecklistItem(text: newItem))
                            newItem = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 28)).foregroundStyle(DS.Color.wine)
                    }
                    .buttonStyle(.plain)
                }

                // Items
                if let items = course?.checklist {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            Button {
                                withAnimation(DS.Anim.springFast) { store.toggleChecklistItem(courseId: courseId, itemId: item.id) }
                            } label: {
                                Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 20))
                                    .foregroundStyle(item.isDone ? DS.Color.wine : Color.appInkTertiary.opacity(0.4))
                            }
                            .buttonStyle(.plain)

                            Text(item.text)
                                .font(DS.Font.body(14))
                                .foregroundStyle(item.isDone ? Color.appInkTertiary : Color.appInk)
                                .strikethrough(item.isDone)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.appBackgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Flashcards Tab

struct FlashcardsTab: View {
    @EnvironmentObject var store: ScheduleStore
    let courseId: UUID
    @State private var showAdd = false
    @State private var newQ = ""
    @State private var newA = ""
    @State private var flippedCards: Set<UUID> = []
    @State private var currentIndex = 0
    @State private var studyMode = false

    var course: Course? { store.courses.first { $0.id == courseId } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Space.md) {
                Button { withAnimation(DS.Anim.spring) { showAdd.toggle() } } label: {
                    Label("Agregar flashcard", systemImage: "plus.circle.fill")
                        .font(DS.Font.body(14, weight: .semibold)).foregroundStyle(DS.Color.wine)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Space.md).background(DS.Color.wineMuted)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                }
                .buttonStyle(.plain)

                if showAdd {
                    VStack(spacing: 10) {
                        TextField("Pregunta / Concepto", text: $newQ)
                            .font(DS.Font.body(14)).padding(10).background(Color.appBackgroundTertiary).clipShape(RoundedRectangle(cornerRadius: 10))
                        TextField("Respuesta / Definición", text: $newA, axis: .vertical)
                            .font(DS.Font.body(13)).lineLimit(4).padding(10).background(Color.appBackgroundTertiary).clipShape(RoundedRectangle(cornerRadius: 10))
                        Button {
                            guard !newQ.isEmpty else { return }
                            withAnimation(DS.Anim.spring) {
                                store.addFlashcard(to: courseId, card: Flashcard(question: newQ, answer: newA))
                                newQ = ""; newA = ""; showAdd = false
                            }
                        } label: {
                            Text("Guardar").font(DS.Font.body(14, weight: .bold)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(DS.Color.wine).clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .cardStyle()
                }

                // Cards
                if let cards = course?.flashcards, !cards.isEmpty {
                    Text("\(cards.count) flashcards").font(DS.Font.mono(11)).foregroundStyle(Color.appInkTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(cards) { card in
                        let isFlipped = flippedCards.contains(card.id)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(isFlipped ? "RESPUESTA" : "PREGUNTA")
                                .font(DS.Font.body(8, weight: .black)).foregroundStyle(DS.Color.wine).tracking(2)
                            Text(isFlipped ? card.answer : card.question)
                                .font(DS.Font.body(isFlipped ? 13 : 15, weight: isFlipped ? .regular : .semibold))
                                .foregroundStyle(Color.appInk)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Toca para voltear").font(DS.Font.body(10)).foregroundStyle(Color.appInkTertiary)
                        }
                        .padding(DS.Space.md)
                        .background(isFlipped ? Color(hex: course?.color ?? "#6B1A2A").opacity(0.06) : Color.appBackgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .stroke(isFlipped ? Color(hex: course?.color ?? "#6B1A2A").opacity(0.3) : Color.appCardBorder, lineWidth: 1))
                        .onTapGesture {
                            withAnimation(DS.Anim.springFast) {
                                if isFlipped { flippedCards.remove(card.id) } else { flippedCards.insert(card.id) }
                            }
                        }
                    }
                } else if !showAdd {
                    Text("Sin flashcards").font(DS.Font.body(14)).foregroundStyle(Color.appInkTertiary)
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Grades Tab (Calculator)

struct GradesTab: View {
    @EnvironmentObject var store: ScheduleStore
    let courseId: UUID
    @State private var c1: String = ""
    @State private var c2: String = ""
    @State private var c3: String = ""
    @State private var loaded = false

    var course: Course? { store.courses.first { $0.id == courseId } }

    var total: Double { (Double(c1) ?? 0) + (Double(c2) ?? 0) + (Double(c3) ?? 0) }
    var average: Double { total / 3.0 }
    var isPassing: Bool { total >= 210 }
    var needed: Double { max(0, 210 - total) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Space.lg) {

                // Summary circle
                ZStack {
                    Circle().stroke(Color.appBackgroundTertiary, lineWidth: 8).frame(width: 120, height: 120)
                    Circle().trim(from: 0, to: min(1, total / 300))
                        .stroke(isPassing ? DS.Color.wine : Color.orange, lineWidth: 8)
                        .rotationEffect(.degrees(-90)).frame(width: 120, height: 120)
                        .animation(DS.Anim.easeSlow, value: total)
                    VStack(spacing: 2) {
                        Text("\(Int(total))").font(DS.Font.display(28, weight: .bold)).foregroundStyle(Color.appInk)
                        Text("/ 300").font(DS.Font.mono(11)).foregroundStyle(Color.appInkTertiary)
                    }
                }
                .padding(.top, DS.Space.md)

                // Status
                HStack(spacing: DS.Space.md) {
                    StatusPill(label: "Promedio", value: String(format: "%.1f", average), color: DS.Color.wine)
                    StatusPill(label: "Estado", value: isPassing ? "Aprobando" : "Reprobando", color: isPassing ? Color(hex: "#1A5C3A") : Color.orange)
                    if !isPassing {
                        StatusPill(label: "Necesitas", value: "\(Int(needed)) pts", color: Color(hex: "#CC1A1A"))
                    }
                }

                // Input
                VStack(spacing: 12) {
                    GradeInput(label: "Corte 1", sublabel: "/ 100 puntos", value: $c1)
                    GradeInput(label: "Corte 2", sublabel: "/ 100 puntos", value: $c2)
                    GradeInput(label: "Corte 3", sublabel: "/ 100 puntos", value: $c3)

                    Button {
                        let grades = GradeRecord(corte1: Double(c1) ?? 0, corte2: Double(c2) ?? 0, corte3: Double(c3) ?? 0)
                        store.updateGrades(courseId: courseId, grades: grades)
                    } label: {
                        Text("Guardar notas").font(DS.Font.body(14, weight: .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(DS.Color.wine).clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .cardStyle()

                // Explanation
                VStack(alignment: .leading, spacing: 6) {
                    Text("SISTEMA DE EVALUACIÓN")
                        .font(DS.Font.body(9, weight: .bold)).foregroundStyle(Color.appInkTertiary).tracking(2)
                    Text("3 cortes de 100 puntos cada uno. Mínimo para aprobar: 210 de 300 (promedio 70).")
                        .font(DS.Font.body(12)).foregroundStyle(Color.appInkTertiary).lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Space.md)
                .background(Color.appBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, 40)
        }
        .onAppear {
            if !loaded, let g = course?.grades {
                c1 = g.corte1 > 0 ? "\(Int(g.corte1))" : ""
                c2 = g.corte2 > 0 ? "\(Int(g.corte2))" : ""
                c3 = g.corte3 > 0 ? "\(Int(g.corte3))" : ""
                loaded = true
            }
        }
    }
}

struct StatusPill: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(DS.Font.body(13, weight: .bold)).foregroundStyle(color)
            Text(label).font(DS.Font.body(9)).foregroundStyle(Color.appInkTertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

struct GradeInput: View {
    let label: String; let sublabel: String; @Binding var value: String
    var body: some View {
        HStack {
            Text(label).font(DS.Font.body(14, weight: .medium)).foregroundStyle(Color.appInk)
            Text(sublabel).font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary)
            Spacer()
            TextField("0", text: $value)
                .font(DS.Font.mono(16, weight: .bold)).foregroundStyle(DS.Color.wine)
                .multilineTextAlignment(.trailing).keyboardType(.numberPad)
                .frame(width: 60)
        }
    }
}
