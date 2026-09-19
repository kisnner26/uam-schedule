import SwiftUI
import PhotosUI

struct CoursesView: View {
    @EnvironmentObject var store: ScheduleStore
    @State private var editingCourse: Course? = nil
    @State private var detailCourseId: UUID? = nil
    @State private var showingAddSheet = false
    @State private var appeared = false
    @State private var showFavoritesOnly = false
    @State private var showCalendarImport = false
    @State private var courseToDelete: Course? = nil
    @State private var viewMode: CourseViewMode = .list

    enum CourseViewMode { case list, grid }

    var totalCredits: Int { store.courses.reduce(0) { $0 + $1.credits } }
    var displayedCourses: [Course] {
        showFavoritesOnly ? store.courses.filter { $0.isFavorite } : store.courses
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("REGISTRO").font(DS.Font.body(9, weight: .semibold)).foregroundStyle(DS.Color.wine).tracking(3)
                        Text("Materias").font(DS.Font.display(34, weight: .semibold)).foregroundStyle(Color.appInk)
                        WineAccentLine(height: 1.5, width: 36).padding(.top, 3)
                        HStack(spacing: 4) {
                            Text("\(store.courses.count) materias"); Text("·"); Text("\(totalCredits) creditos")
                        }.font(DS.Font.body(12)).foregroundStyle(Color.appInkTertiary).padding(.top, 3)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button {
                            withAnimation(DS.Anim.springFast) { viewMode = viewMode == .list ? .grid : .list }
                        } label: {
                            Image(systemName: viewMode == .list ? "square.grid.2x2" : "list.bullet")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.appInkTertiary)
                                .frame(width: 36, height: 36)
                                .background(Color.appBackgroundSecondary)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.appCardBorder, lineWidth: 1))
                        }.buttonStyle(.plain)
                        Button { withAnimation(DS.Anim.spring) { showCalendarImport = true } } label: {
                            Image(systemName: "calendar.badge.plus").font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DS.Color.wine).frame(width: 36, height: 36)
                                .background(DS.Color.wineMuted).clipShape(Circle())
                                .overlay(Circle().stroke(DS.Color.wine.opacity(0.2), lineWidth: 1))
                        }.buttonStyle(.plain)
                        Button { withAnimation(DS.Anim.spring) { showingAddSheet = true } } label: {
                            Image(systemName: "plus").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                                .frame(width: 36, height: 36).background(DS.Color.wine).clipShape(Circle())
                                .shadow(color: DS.Color.wine.opacity(0.3), radius: 8, y: 3)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Space.lg).padding(.top, 20).padding(.bottom, DS.Space.md)
                .opacity(appeared ? 1 : 0).animation(DS.Anim.easeSlow, value: appeared)

                // Stats strip
                if !store.courses.isEmpty {
                    CourseStatsStrip(courses: store.courses)
                        .padding(.horizontal, DS.Space.md).padding(.bottom, DS.Space.md)
                        .opacity(appeared ? 1 : 0).animation(DS.Anim.easeSlow.delay(0.04), value: appeared)
                }

                // Filters
                HStack(spacing: 8) {
                    FilterChip(label: "Todas", icon: "tray.2.fill", isSelected: !showFavoritesOnly) {
                        withAnimation(DS.Anim.springFast) { showFavoritesOnly = false }
                    }
                    FilterChip(label: "Favoritas", icon: "bookmark.fill", isSelected: showFavoritesOnly) {
                        withAnimation(DS.Anim.springFast) { showFavoritesOnly = true }
                    }
                    Spacer()
                }
                .padding(.horizontal, DS.Space.lg).padding(.bottom, DS.Space.md)
                .opacity(appeared ? 1 : 0).animation(DS.Anim.easeSlow.delay(0.05), value: appeared)

                // Empty state
                if displayedCourses.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: showFavoritesOnly ? "bookmark.slash" : "tray")
                            .font(.system(size: 36, weight: .light)).foregroundStyle(Color.appInkTertiary.opacity(0.3))
                        Text(showFavoritesOnly ? "No tienes materias favoritas" : "No tienes materias agregadas")
                            .font(DS.Font.body(15)).foregroundStyle(Color.appInkTertiary.opacity(0.5))
                        if !showFavoritesOnly {
                            Text("Toca + para agregar tu primera materia")
                                .font(DS.Font.body(13)).foregroundStyle(Color.appInkTertiary.opacity(0.35))
                        }
                    }.frame(maxWidth: .infinity).padding(.vertical, 60)
                    .opacity(appeared ? 1 : 0).animation(DS.Anim.easeSlow.delay(0.1), value: appeared)
                }

                // Course list / grid
                if viewMode == .list {
                    VStack(spacing: 0) {
                        ForEach(Array(displayedCourses.enumerated()), id: \.element.id) { idx, course in
                            CourseListRow(
                                course: course,
                                onTap: { detailCourseId = course.id },
                                onFavorite: { withAnimation(DS.Anim.springFast) { store.toggleFavorite(course) } },
                                onDelete: { courseToDelete = course },
                                onEdit: { editingCourse = course }
                            )
                            .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                            .animation(DS.Anim.spring.delay(0.1 + Double(idx) * 0.04), value: appeared)
                            if idx < displayedCourses.count - 1 {
                                Divider().padding(.leading, DS.Space.md + 46 + 12)
                            }
                        }
                    }
                    .background(Color.appBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
                    .padding(.horizontal, DS.Space.md).padding(.bottom, 120)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Array(displayedCourses.enumerated()), id: \.element.id) { idx, course in
                            CourseGridCard(
                                course: course,
                                onTap: { detailCourseId = course.id },
                                onFavorite: { withAnimation(DS.Anim.springFast) { store.toggleFavorite(course) } },
                                onDelete: { courseToDelete = course },
                                onEdit: { editingCourse = course }
                            )
                            .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                            .animation(DS.Anim.spring.delay(0.1 + Double(idx) * 0.05), value: appeared)
                        }
                    }
                    .padding(.horizontal, DS.Space.md).padding(.bottom, 120)
                }
            }
        }
        .background(Color.appBackground)
        .onAppear { appeared = true }
        .sheet(item: $editingCourse) { course in
            CourseEditorView(course: course, isNew: false) { updated in
                if let idx = store.courses.firstIndex(where: { $0.id == updated.id }) {
                    withAnimation(DS.Anim.spring) { store.courses[idx] = updated; store.save() }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            CourseEditorView(course: Course(name: "", room: ""), isNew: true) { newCourse in
                withAnimation(DS.Anim.spring) { store.addCourse(newCourse) }
            }
        }
        .sheet(isPresented: $showCalendarImport) { CalendarImportView().environmentObject(store) }
        .sheet(item: $detailCourseId) { id in CourseDetailView(courseId: id) }
        .alert("Eliminar materia", isPresented: Binding(
            get: { courseToDelete != nil },
            set: { if !$0 { courseToDelete = nil } }
        )) {
            Button("Cancelar", role: .cancel) { courseToDelete = nil }
            Button("Eliminar", role: .destructive) {
                if let c = courseToDelete {
                    withAnimation(DS.Anim.spring) { CoursePhotoStore.delete(for: c.id); if let mid = c.moodleCourseId { NotificationCenter.default.post(name: Notification.Name("uam.moodleCourseDeleted"), object: mid) }; store.deleteCourse(c) }
                }
                courseToDelete = nil
            }
        } message: {
            if let c = courseToDelete {
                Text("Eliminar \"\(c.name)\"? Se borraran tambien sus recordatorios, pendientes y flashcards.")
            }
        }
    }
}

extension UUID: @retroactive Identifiable { public var id: UUID { self } }

// MARK: - Stats Strip

struct CourseStatsStrip: View {
    let courses: [Course]
    var totalCredits: Int { courses.reduce(0) { $0 + $1.credits } }
    var totalPending: Int { courses.reduce(0) { $0 + $1.reminders.filter { !$0.isDone }.count } }
    var activeDays: Int { Set(courses.flatMap { $0.sessions.map { $0.weekday } }).count }

    var body: some View {
        HStack(spacing: 0) {
            StripStat(icon: "star.square.fill", value: "\(totalCredits)", label: "creditos", color: DS.Color.wine)
            Divider().frame(height: 30)
            StripStat(icon: "calendar.badge.clock", value: "\(activeDays)", label: "dias activos", color: Color(hex: "#1A3A6B"))
            Divider().frame(height: 30)
            StripStat(icon: "bell.badge.fill", value: "\(totalPending)", label: "pendientes", color: totalPending > 0 ? Color.orange : Color.appInkTertiary)
        }
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

struct StripStat: View {
    let icon: String; let value: String; let label: String; let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(DS.Font.display(15, weight: .semibold)).foregroundStyle(Color.appInk)
                Text(label).font(DS.Font.body(9)).foregroundStyle(Color.appInkTertiary)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String; let icon: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .medium))
                Text(label).font(DS.Font.body(12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? DS.Color.wine : Color.appInkTertiary)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isSelected ? DS.Color.wineMuted : Color.appBackgroundSecondary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? DS.Color.wine.opacity(0.3) : Color.appCardBorder, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

// MARK: - Course List Row

struct CourseListRow: View {
    let course: Course
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    @State private var photo: UIImage? = nil
    let dayShort = ["","Dom","Lun","Mar","Mie","Jue","Vie","Sab"]
    var daysLabel: String { course.sessions.map { dayShort[$0.weekday] }.joined(separator: " · ") }
    var pendingReminders: Int { course.reminders.filter { !$0.isDone }.count }

    var body: some View {
        HStack(spacing: 12) {
            // Photo or color tile
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: course.color).opacity(0.10))
                    .frame(width: 46, height: 46)
                if let img = photo {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 46, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    VStack(spacing: 0) {
                        Text("\(course.credits)").font(DS.Font.display(16, weight: .bold)).foregroundStyle(Color(hex: course.color))
                        Text("cr").font(DS.Font.body(8, weight: .medium)).foregroundStyle(Color(hex: course.color).opacity(0.5))
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color(hex: course.color).opacity(0.15), lineWidth: 1))

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if !course.code.isEmpty {
                        Text(course.code).font(DS.Font.mono(9, weight: .bold))
                            .foregroundStyle(Color(hex: course.color))
                            .tracking(0.8)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color(hex: course.color).opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    if course.isFavorite {
                        Image(systemName: "bookmark.fill").font(.system(size: 9)).foregroundStyle(DS.Color.wine)
                    }
                }
                Text(course.name).font(DS.Font.body(14, weight: .semibold)).foregroundStyle(Color.appInk).lineLimit(1)
                HStack(spacing: 8) {
                    if !course.room.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin").font(.system(size: 9)).foregroundStyle(Color.appInkTertiary)
                            Text(course.room).font(DS.Font.mono(10)).foregroundStyle(Color.appInkTertiary)
                        }
                    }
                    if !daysLabel.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar").font(.system(size: 9)).foregroundStyle(Color.appInkTertiary)
                            Text(daysLabel).font(DS.Font.body(10)).foregroundStyle(Color.appInkTertiary)
                        }
                    }
                }
                HStack(spacing: 6) {
                    if pendingReminders > 0 { CourseBadge(icon: "bell.badge.fill", label: "\(pendingReminders)", color: .orange) }
                    if !course.checklist.isEmpty {
                        let done = course.checklist.filter { $0.isDone }.count
                        CourseBadge(icon: "checklist", label: "\(done)/\(course.checklist.count)", color: Color.appInkTertiary)
                    }
                    if !course.flashcards.isEmpty { CourseBadge(icon: "rectangle.on.rectangle", label: "\(course.flashcards.count)", color: Color.appInkTertiary) }
                    MoodleCourseBadge(courseName: course.name)
                }
            }
            Spacer()
            VStack(spacing: 12) {
                Button(action: onFavorite) {
                    Image(systemName: course.isFavorite ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 14))
                        .foregroundStyle(course.isFavorite ? DS.Color.wine : Color.appInkTertiary.opacity(0.4))
                }.buttonStyle(.plain)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.appInkTertiary.opacity(0.25))
            }
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            Button { onTap() } label: { Label("Ver detalle", systemImage: "book.closed") }
            Button { onFavorite() } label: {
                Label(course.isFavorite ? "Quitar favorito" : "Marcar favorita",
                      systemImage: course.isFavorite ? "bookmark.slash" : "bookmark")
            }
            Button { onEdit() } label: { Label("Editar", systemImage: "pencil") }
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("Eliminar", systemImage: "trash") }
        } preview: {
            CourseContextPreview(course: course)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Eliminar", systemImage: "trash")
            }
            Button { onEdit() } label: {
                Label("Editar", systemImage: "pencil")
            }.tint(Color(hex: "#1A3A6B"))
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { onFavorite() } label: {
                Label(course.isFavorite ? "Quitar" : "Favorita",
                      systemImage: course.isFavorite ? "bookmark.slash" : "bookmark.fill")
            }.tint(DS.Color.wine)
        }
        .onAppear { photo = CoursePhotoStore.load(for: course.id) }
        .onChange(of: course.id) { _, _ in photo = CoursePhotoStore.load(for: course.id) }
    }
}

// MARK: - Context Menu Preview

struct CourseContextPreview: View {
    let course: Course
    @State private var photo: UIImage? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Cover
            ZStack {
                Rectangle().fill(Color(hex: course.color).opacity(0.15))
                if let img = photo {
                    Image(uiImage: img).resizable().scaledToFill()
                }
                Rectangle().fill(
                    LinearGradient(colors: [.clear, Color.black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                )
            }
            .frame(width: 280, height: 160)

            VStack(alignment: .leading, spacing: 4) {
                if !course.code.isEmpty {
                    Text(course.code).font(DS.Font.mono(10, weight: .bold))
                        .foregroundStyle(Color(hex: course.color)).tracking(1)
                }
                Text(course.name).font(DS.Font.display(18, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                HStack(spacing: 8) {
                    if !course.room.isEmpty {
                        Label(course.room, systemImage: "mappin").font(DS.Font.body(11)).foregroundStyle(.white.opacity(0.7))
                    }
                    Text("\(course.credits) cr.").font(DS.Font.mono(11)).foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(DS.Space.md)
        }
        .frame(width: 280, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear { photo = CoursePhotoStore.load(for: course.id) }
    }
}

// MARK: - Course Badge

struct CourseBadge: View {
    let icon: String; let label: String; let color: Color
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8, weight: .semibold))
            Text(label).font(DS.Font.body(9, weight: .semibold))
        }
        .foregroundStyle(color).padding(.horizontal, 5).padding(.vertical, 2)
        .background(color.opacity(0.10)).clipShape(Capsule())
    }
}

// MARK: - Course Grid Card

struct CourseGridCard: View {
    let course: Course
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    @State private var photo: UIImage? = nil
    let dayShort = ["","D","L","M","X","J","V","S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Rectangle().fill(Color(hex: course.color).opacity(0.08)).frame(height: 72)
                    if let img = photo {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 72).clipped()
                    } else {
                        Text("\(course.credits)").font(DS.Font.display(32, weight: .bold))
                            .foregroundStyle(Color(hex: course.color).opacity(0.2))
                            .frame(maxWidth: .infinity).frame(height: 72)
                    }
                }
                Button(action: onFavorite) {
                    Image(systemName: course.isFavorite ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(course.isFavorite ? .white : .white.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .background(course.isFavorite ? DS.Color.wine : Color.black.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain).padding(8)
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: DS.Radius.md, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: DS.Radius.md))

            VStack(alignment: .leading, spacing: 4) {
                if !course.code.isEmpty {
                    Text(course.code).font(DS.Font.mono(8, weight: .bold)).foregroundStyle(Color(hex: course.color)).tracking(0.8)
                }
                Text(course.name).font(DS.Font.body(12, weight: .semibold)).foregroundStyle(Color.appInk).lineLimit(2)
                HStack(spacing: 4) {
                    if !course.room.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "mappin").font(.system(size: 8))
                            Text(course.room).font(DS.Font.mono(9))
                        }.foregroundStyle(Color.appInkTertiary)
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(course.sessions.prefix(3), id: \.weekday) { s in
                            Text(dayShort[s.weekday]).font(DS.Font.body(8, weight: .bold))
                                .foregroundStyle(Color(hex: course.color).opacity(0.7))
                                .frame(width: 14, height: 14)
                                .background(Color(hex: course.color).opacity(0.08))
                                .clipShape(Circle())
                        }
                    }
                }
            }.padding(10)
        }
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).stroke(Color(hex: course.color).opacity(0.12), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            Button { onTap() } label: { Label("Ver detalle", systemImage: "book.closed") }
            Button { onFavorite() } label: {
                Label(course.isFavorite ? "Quitar favorito" : "Marcar favorita",
                      systemImage: course.isFavorite ? "bookmark.slash" : "bookmark")
            }
            Button { onEdit() } label: { Label("Editar", systemImage: "pencil") }
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("Eliminar", systemImage: "trash") }
        } preview: {
            CourseContextPreview(course: course)
        }
        .onAppear { photo = CoursePhotoStore.load(for: course.id) }
        .onChange(of: course.id) { _, _ in photo = CoursePhotoStore.load(for: course.id) }
    }
}

// MARK: - Course Editor (rediseno)

struct CourseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var course: Course
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoPreview: UIImage? = nil
    @State private var activeSection: EditorSection = .info
    let isNew: Bool
    let onSave: (Course) -> Void
    let colorOptions = DS.Color.courseColors

    enum EditorSection: String, CaseIterable {
        case info = "Info"
        case horarios = "Horarios"
        case color = "Color"
    }

    init(course: Course, isNew: Bool, onSave: @escaping (Course) -> Void) {
        _course = State(initialValue: course)
        self.isNew = isNew; self.onSave = onSave
    }

    var isValid: Bool { !course.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        coverHero
                        sectionTabs.padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.md)
                        Group {
                            switch activeSection {
                            case .info: infoSection
                            case .horarios: horariosSection
                            case .color: colorSection
                            }
                        }
                        .padding(.horizontal, DS.Space.md).padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(isNew ? "Nueva Materia" : "Editar").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.appInkTertiary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Agregar" : "Guardar") { onSave(course); dismiss() }
                        .foregroundStyle(isValid ? DS.Color.wine : Color.appInkTertiary)
                        .fontWeight(.semibold).disabled(!isValid)
                }
            }
        }
        .onAppear { photoPreview = CoursePhotoStore.load(for: course.id) }
    }

    // MARK: Cover hero - foto tiempo real

    var coverHero: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(hex: course.color).opacity(0.3), Color(hex: course.color).opacity(0.05)],
                startPoint: .top, endPoint: .bottom
            ).frame(height: 180)

            if let img = photoPreview {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(maxWidth: .infinity).frame(height: 180).clipped()
                    .overlay(LinearGradient(colors: [.clear, Color.black.opacity(0.4)], startPoint: .top, endPoint: .bottom))
            } else {
                VStack(spacing: 4) {
                    Text(String(course.name.prefix(1)).uppercased())
                        .font(DS.Font.display(56, weight: .bold))
                        .foregroundStyle(Color(hex: course.color).opacity(0.35))
                    if !course.code.isEmpty {
                        Text(course.code).font(DS.Font.mono(12, weight: .bold))
                            .foregroundStyle(Color(hex: course.color).opacity(0.5)).tracking(2)
                    }
                }.frame(maxWidth: .infinity).frame(height: 180)
            }

            HStack {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill").font(.system(size: 12, weight: .bold))
                        Text(photoPreview != nil ? "Cambiar foto" : "Agregar foto").font(DS.Font.body(12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                }
                .onChange(of: selectedPhoto) { _, item in
                    Task {
                        if let data = try? await item?.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            withAnimation(DS.Anim.spring) { photoPreview = img }
                            CoursePhotoStore.save(data, for: course.id)
                        }
                    }
                }
                Spacer()
                if photoPreview != nil {
                    Button {
                        withAnimation(DS.Anim.springFast) { photoPreview = nil; CoursePhotoStore.delete(for: course.id) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 12, weight: .bold))
                            Text("Quitar").font(DS.Font.body(12, weight: .semibold))
                        }
                        .foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.red.opacity(0.6), in: Capsule())
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Space.md).padding(.bottom, DS.Space.md)
        }
        .animation(DS.Anim.spring, value: photoPreview != nil)
    }

    // MARK: Section Tabs

    var sectionTabs: some View {
        HStack(spacing: 0) {
            ForEach(EditorSection.allCases, id: \.self) { section in
                let isSelected = activeSection == section
                Button { withAnimation(DS.Anim.springFast) { activeSection = section } } label: {
                    Text(section.rawValue).font(DS.Font.body(13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? DS.Color.wine : Color.appInkTertiary)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(isSelected ? DS.Color.wineMuted : Color.appBackgroundSecondary)
                }.buttonStyle(.plain)
                if section != EditorSection.allCases.last { Divider().frame(height: 36) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // MARK: Info section

    var infoSection: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Nombre *", systemImage: "text.cursor").font(DS.Font.body(10, weight: .semibold))
                    .foregroundStyle(DS.Color.wine).tracking(1)
                TextField("Ej: Ingenieria de Software", text: $course.name)
                    .font(DS.Font.body(16, weight: .medium)).foregroundStyle(Color.appInk)
            }
            .padding(DS.Space.md).background(Color.appBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm)
                .stroke(course.name.isEmpty ? DS.Color.wine.opacity(0.4) : Color.appCardBorder, lineWidth: 1))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                EditorFieldCard(icon: "barcode", label: "Codigo", placeholder: "SIS0401") {
                    TextField("SIS0401", text: $course.code).font(DS.Font.mono(14)).foregroundStyle(Color.appInk)
                }
                EditorFieldCard(icon: "mappin.square.fill", label: "Aula", placeholder: "C-204") {
                    TextField("C-204", text: $course.room).font(DS.Font.mono(14)).foregroundStyle(Color.appInk)
                }
                EditorFieldCard(icon: "person.2.fill", label: "Seccion", placeholder: "A, B, 01") {
                    TextField("A, B, 01", text: $course.section).font(DS.Font.body(14)).foregroundStyle(Color.appInk)
                }
                EditorFieldCard(icon: "number.square.fill", label: "Grupo", placeholder: "G1") {
                    TextField("G1", text: $course.group).font(DS.Font.body(14)).foregroundStyle(Color.appInk)
                }
            }

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "star.square.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.Color.wine)
                    Text("Creditos").font(DS.Font.body(14)).foregroundStyle(Color.appInk)
                }
                Spacer()
                HStack(spacing: 0) {
                    Button {
                        withAnimation(DS.Anim.springFast) { if course.credits > 1 { course.credits -= 1 } }
                    } label: {
                        Image(systemName: "minus").font(.system(size: 13, weight: .bold))
                            .foregroundStyle(course.credits > 1 ? DS.Color.wine : Color.appInkTertiary)
                            .frame(width: 36, height: 36)
                    }.buttonStyle(.plain)
                    Text("\(course.credits)").font(DS.Font.display(20, weight: .bold)).foregroundStyle(DS.Color.wine).frame(minWidth: 32)
                    Button {
                        withAnimation(DS.Anim.springFast) { if course.credits < 10 { course.credits += 1 } }
                    } label: {
                        Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DS.Color.wine).frame(width: 36, height: 36)
                    }.buttonStyle(.plain)
                }
                .background(Color.appBackgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(DS.Space.md).background(Color.appBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(Color.appCardBorder, lineWidth: 1))
        }
    }

    // MARK: Horarios section

    var horariosSection: some View {
        VStack(spacing: 10) {
            ForEach(0 ..< course.sessions.count, id: \.self) { idx in
                SessionEditorCard(session: $course.sessions[idx]) {
                    withAnimation(DS.Anim.spring) {
                        var s = course.sessions
                        s.remove(at: idx)
                        course.sessions = s
                    }
                }
            }
            Button {
                withAnimation(DS.Anim.springFast) {
                    course.sessions.append(ClassSession(weekday: 2, startHour: 8, startMinute: 0, endHour: 10, endMinute: 0))
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 16, weight: .semibold))
                    Text("Agregar horario").font(DS.Font.body(14, weight: .semibold))
                }
                .foregroundStyle(DS.Color.wine).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(DS.Color.wineMuted)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Color.wine.opacity(0.2), lineWidth: 1))
            }.buttonStyle(.plain)
        }
    }

    // MARK: Color section

    var colorSection: some View {
        VStack(spacing: DS.Space.md) {
            RoundedRectangle(cornerRadius: DS.Radius.sm).fill(Color(hex: course.color)).frame(height: 56)
                .overlay(Text(course.code.isEmpty ? "COLOR" : course.code).font(DS.Font.mono(11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8)).tracking(2))
                .animation(DS.Anim.springFast, value: course.color)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(colorOptions, id: \.self) { hex in
                    let isSelected = course.color == hex
                    Circle().fill(Color(hex: hex)).frame(height: 48)
                        .overlay(Circle().stroke(Color.appInk, lineWidth: isSelected ? 2.5 : 0).padding(3))
                        .overlay(Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white).opacity(isSelected ? 1 : 0))
                        .scaleEffect(isSelected ? 1.08 : 1.0)
                        .animation(DS.Anim.springFast, value: course.color)
                        .onTapGesture { withAnimation(DS.Anim.springFast) { course.color = hex } }
                }
            }
        }
        .padding(DS.Space.md).background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

// MARK: - Editor Field Card

struct EditorFieldCard<Content: View>: View {
    let icon: String; let label: String; let placeholder: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundStyle(DS.Color.wine.opacity(0.7))
                Text(label.uppercased()).font(DS.Font.body(8, weight: .semibold)).foregroundStyle(Color.appInkTertiary).tracking(0.8)
            }
            content()
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

// MARK: - Session Editor Card

struct SessionEditorCard: View {
    @Binding var session: ClassSession
    let onDelete: () -> Void
    let dayNames = ["","Domingo","Lunes","Martes","Miercoles","Jueves","Viernes","Sabado"]

    var startDate: Binding<Date> { Binding(
        get: { var c = Calendar.current.dateComponents([.year,.month,.day], from: Date()); c.hour = session.startHour; c.minute = session.startMinute; return Calendar.current.date(from: c) ?? Date() },
        set: { d in session.startHour = Calendar.current.component(.hour, from: d); session.startMinute = Calendar.current.component(.minute, from: d) }
    )}
    var endDate: Binding<Date> { Binding(
        get: { var c = Calendar.current.dateComponents([.year,.month,.day], from: Date()); c.hour = session.endHour; c.minute = session.endMinute; return Calendar.current.date(from: c) ?? Date() },
        set: { d in session.endHour = Calendar.current.component(.hour, from: d); session.endMinute = Calendar.current.component(.minute, from: d) }
    )}

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar").font(.system(size: 12, weight: .semibold)).foregroundStyle(DS.Color.wine)
                    Text("Dia").font(DS.Font.body(13)).foregroundStyle(Color.appInk)
                }
                Spacer()
                Picker("", selection: $session.weekday) {
                    ForEach(1...7, id: \.self) { i in Text(dayNames[i]).tag(i) }
                }.foregroundStyle(Color.appInk).tint(DS.Color.wine)
            }.padding(.horizontal, DS.Space.md).padding(.vertical, 11)

            Divider().padding(.horizontal, DS.Space.md)

            HStack(spacing: 0) {
                HStack {
                    Image(systemName: "clock.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(DS.Color.wine)
                    Text("Inicio").font(DS.Font.body(13)).foregroundStyle(Color.appInk)
                    Spacer()
                    DatePicker("", selection: startDate, displayedComponents: .hourAndMinute).labelsHidden().tint(DS.Color.wine)
                }.padding(.horizontal, DS.Space.md).padding(.vertical, 8)
                Divider().frame(height: 36)
                HStack {
                    Text("Fin").font(DS.Font.body(13)).foregroundStyle(Color.appInk)
                    Spacer()
                    DatePicker("", selection: endDate, displayedComponents: .hourAndMinute).labelsHidden().tint(DS.Color.wine)
                }.padding(.horizontal, DS.Space.md).padding(.vertical, 8)
            }

            Divider().padding(.horizontal, DS.Space.md)

            Button(action: onDelete) {
                HStack {
                    Spacer()
                    Image(systemName: "trash").font(.system(size: 12))
                    Text("Eliminar horario").font(DS.Font.body(12))
                    Spacer()
                }.foregroundStyle(.red.opacity(0.7)).padding(.vertical, 10)
            }.buttonStyle(.plain)
        }
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

struct EditorRow<Content: View>: View {
    let label: String; @ViewBuilder let content: () -> Content
    var body: some View {
        HStack { Text(label).font(DS.Font.body(14)).foregroundStyle(Color.appInkSecondary); Spacer(); content() }
    }
}

struct SessionEditorRow: View {
    @Binding var session: ClassSession
    let dayNames = ["","Domingo","Lunes","Martes","Miercoles","Jueves","Viernes","Sabado"]
    var startDate: Binding<Date> { Binding(
        get: { var c = Calendar.current.dateComponents([.year,.month,.day], from: Date()); c.hour = session.startHour; c.minute = session.startMinute; return Calendar.current.date(from: c) ?? Date() },
        set: { d in session.startHour = Calendar.current.component(.hour, from: d); session.startMinute = Calendar.current.component(.minute, from: d) }
    )}
    var endDate: Binding<Date> { Binding(
        get: { var c = Calendar.current.dateComponents([.year,.month,.day], from: Date()); c.hour = session.endHour; c.minute = session.endMinute; return Calendar.current.date(from: c) ?? Date() },
        set: { d in session.endHour = Calendar.current.component(.hour, from: d); session.endMinute = Calendar.current.component(.minute, from: d) }
    )}
    var body: some View {
        VStack(spacing: 10) {
            Picker("Dia", selection: $session.weekday) { ForEach(1...7, id: \.self) { Text(dayNames[$0]).tag($0) } }.foregroundStyle(Color.appInk)
            DatePicker("Inicio", selection: startDate, displayedComponents: .hourAndMinute).foregroundStyle(Color.appInkSecondary).tint(DS.Color.wine)
            DatePicker("Fin", selection: endDate, displayedComponents: .hourAndMinute).foregroundStyle(Color.appInkSecondary).tint(DS.Color.wine)
        }
    }
}
