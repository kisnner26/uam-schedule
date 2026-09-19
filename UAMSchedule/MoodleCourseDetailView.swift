import SwiftUI
import QuickLook
import UniformTypeIdentifiers

// ═══════════════════════════════════════════════════════
// MARK: - Course Detail Hub
// ═══════════════════════════════════════════════════════

struct MoodleCourseDetailView: View {
    let course: MoodleCourse
    @StateObject private var ext = MoodleExtendedStore.shared
    @StateObject private var moodle = MoodleStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: CourseTab = .contenido
    @State private var appeared = false

    enum CourseTab: String, CaseIterable {
        case contenido  = "Contenido"
        case tareas     = "Tareas"
        case notas      = "Notas"
        case foros      = "Foros"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {

                    // ── Course header ─────────────────────────
                    VStack(alignment: .leading, spacing: 3) {
                        Text(course.shortname)
                            .font(DS.Font.body(9, weight: .bold))
                            .foregroundStyle(DS.Color.wine)
                            .tracking(2)
                        Text(course.fullname)
                            .font(DS.Font.display(22, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .lineLimit(2)
                        WineAccentLine(height: 1.5, width: 28).padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.Space.lg)
                    .padding(.top, DS.Space.md)
                    .padding(.bottom, DS.Space.sm)
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.easeSlow.delay(0.05), value: appeared)

                    // ── Tab selector ──────────────────────────
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Space.sm) {
                            ForEach(CourseTab.allCases, id: \.self) { tab in
                                CourseTabChip(
                                    label: tab.rawValue,
                                    isActive: selectedTab == tab
                                ) {
                                    withAnimation(DS.Anim.springFast) { selectedTab = tab }
                                }
                            }
                        }
                        .padding(.horizontal, DS.Space.md)
                        .padding(.vertical, DS.Space.sm)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.easeSlow.delay(0.08), value: appeared)

                    Rectangle()
                        .fill(Color.appSeparator)
                        .frame(height: 0.5)

                    // ── Tab content ───────────────────────────
                    Group {
                        switch selectedTab {
                        case .contenido:
                            CourseContentsTab(course: course)
                        case .tareas:
                            CourseAssignmentsTab(course: course)
                        case .notas:
                            CourseGradesTab(course: course)
                        case .foros:
                            CourseForumsTab(course: course)
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.easeSlow.delay(0.12), value: appeared)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.appInkTertiary)
                }
            }
        }
        .onAppear {
            appeared = true
            // Preload content and grades on open
            Task {
                await ext.loadCourseContents(courseId: course.id)
                await ext.loadGrades(courseId: course.id, courseName: course.fullname)
                await ext.loadForums(courseId: course.id)
            }
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: - Tab Chip
// ─────────────────────────────────────────────────

private struct CourseTabChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DS.Font.body(12, weight: isActive ? .bold : .regular))
                .foregroundStyle(isActive ? .white : Color.appInkSecondary)
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, 8)
                .background(isActive ? DS.Color.wine : Color.appBackgroundSecondary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isActive ? Color.clear : Color.appCardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Tab: Contenido
// ═══════════════════════════════════════════════════════

struct CourseContentsTab: View {
    let course: MoodleCourse
    @StateObject private var ext = MoodleExtendedStore.shared

    private var sections: [MoodleCourseSection] {
        ext.courseContents[course.id] ?? []
    }
    private var isLoading: Bool {
        ext.loadingContents.contains(course.id)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Space.md) {

                if isLoading && sections.isEmpty {
                    LoadingPlaceholder(text: "Cargando contenido del curso...")
                } else if sections.isEmpty {
                    EmptyStateMoodle(
                        icon: "folder",
                        title: "Sin contenido disponible",
                        sub: "Este curso no tiene archivos o modulos visibles."
                    )
                } else {
                    ForEach(sections) { section in
                        SectionBlock(section: section, course: course)
                    }
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.top, DS.Space.md)
        }
        .refreshable {
            await ext.refreshCourseContents(courseId: course.id)
        }
    }
}

private struct SectionBlock: View {
    let section: MoodleCourseSection
    let course: MoodleCourse
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {

            // Section header
            Button {
                withAnimation(DS.Anim.springFast) { isExpanded.toggle() }
            } label: {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.appInkTertiary)
                    Text(section.name.isEmpty ? "Seccion" : section.name)
                        .font(DS.Font.body(11, weight: .bold))
                        .foregroundStyle(Color.appInkSecondary)
                        .tracking(0.5)
                    Text("(\(section.modules.count))")
                        .font(DS.Font.mono(10))
                        .foregroundStyle(Color.appInkTertiary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: DS.Space.sm) {
                    ForEach(section.modules) { module in
                        ModuleRow(module: module, courseId: course.id)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DS.Space.md)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

private struct ModuleRow: View {
    let module: MoodleModule
    let courseId: Int
    @StateObject private var ext = MoodleExtendedStore.shared
    @State private var showDetail = false
    @State private var quickLookURL: URL? = nil
    @State private var isDownloading = false
    @State private var downloadError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Space.sm) {
                // Module icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(moduleColor.opacity(0.10))
                        .frame(width: 34, height: 34)
                    Image(systemName: module.sfSymbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(moduleColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(module.name)
                        .font(DS.Font.body(13, weight: .medium))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(2)
                    Text(module.typeLabel)
                        .font(DS.Font.body(10))
                        .foregroundStyle(Color.appInkTertiary)
                }

                Spacer()

                // Actions
                if module.modname == "resource" || module.modname == "folder" {
                    Button {
                        handleFileModuleTap()
                    } label: {
                        if isDownloading {
                            ProgressView().scaleEffect(0.7)
                                .frame(width: 28, height: 28)
                        } else if let firstContent = module.contents?.first,
                                  ext.isDownloaded(firstContent) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(hex: "#1A5C3A"))
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(DS.Color.wine)
                                .frame(width: 28, height: 28)
                        }
                    }
                    .buttonStyle(.plain)
                } else if module.modname == "url" {
                    Image(systemName: "arrow.up.right.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(DS.Color.wine)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appInkTertiary)
                }
            }
            .padding(.vertical, DS.Space.sm)
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap()
            }

            // File list for folders
            if module.modname == "folder", let contents = module.contents, showDetail {
                VStack(spacing: DS.Space.xs) {
                    ForEach(contents) { content in
                        FileContentRow(content: content)
                    }
                }
                .padding(.leading, 42)
                .padding(.top, DS.Space.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Error
            if let err = downloadError {
                Text(err)
                    .font(DS.Font.body(11))
                    .foregroundStyle(Color(hex: "#CC1A1A"))
                    .padding(.leading, 42)
                    .padding(.top, 4)
            }
        }
        .quickLookPreview($quickLookURL)
    }

    private var moduleColor: Color {
        switch module.modname {
        case "resource": return DS.Color.wine
        case "assign":   return Color(hex: "#8B5A1A")
        case "forum":    return Color(hex: "#1A3A6B")
        case "url":      return Color(hex: "#1A5C3A")
        case "folder":   return Color(hex: "#6B4A1A")
        case "quiz":     return Color(hex: "#3A1A6B")
        default:         return Color.appInkTertiary
        }
    }

    private func handleTap() {
        if module.modname == "url" {
            if let urlStr = module.contents?.first?.fileurl,
               let url = URL(string: urlStr) {
                UIApplication.shared.open(url)
            }
        } else if module.modname == "folder" {
            withAnimation(DS.Anim.springFast) { showDetail.toggle() }
        } else if module.modname == "resource" {
            handleFileModuleTap()
        }
    }

    private func handleFileModuleTap() {
        guard let content = module.contents?.first else { return }
        if ext.isDownloaded(content) {
            quickLookURL = ext.downloadedFiles[content.fileurl]
            return
        }
        isDownloading = true
        downloadError = nil
        Task {
            do {
                let url = try await ext.downloadFile(content: content)
                await MainActor.run {
                    isDownloading = false
                    quickLookURL = url
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    downloadError = error.localizedDescription
                }
            }
        }
    }
}

struct FileContentRow: View {
    let content: MoodleContent
    @StateObject private var ext = MoodleExtendedStore.shared
    @State private var quickLookURL: URL? = nil
    @State private var isDownloading = false
    @State private var downloadError: String? = nil

    var progress: Double? { ext.downloadProgressFor(content) }
    var isDownloaded: Bool { ext.isDownloaded(content) }

    var body: some View {
        HStack(spacing: DS.Space.sm) {
            Image(systemName: content.fileIcon)
                .font(.system(size: 13))
                .foregroundStyle(DS.Color.wine)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(content.filename)
                    .font(DS.Font.body(12))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                Text(content.fileSizeString)
                    .font(DS.Font.mono(10))
                    .foregroundStyle(Color.appInkTertiary)
            }

            Spacer()

            if let p = progress {
                // Download progress ring
                ZStack {
                    Circle().stroke(DS.Color.wine.opacity(0.15), lineWidth: 2)
                    Circle().trim(from: 0, to: p)
                        .stroke(DS.Color.wine, lineWidth: 2)
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 20, height: 20)
            } else if isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "#1A5C3A"))
                    .font(.system(size: 16))
            } else {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(DS.Color.wine)
                    .font(.system(size: 16))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if isDownloaded {
                quickLookURL = ext.downloadedFiles[content.fileurl]
                return
            }
            guard !isDownloading else { return }
            isDownloading = true
            Task {
                do {
                    let url = try await ext.downloadFile(content: content)
                    await MainActor.run {
                        isDownloading = false
                        quickLookURL = url
                    }
                } catch {
                    await MainActor.run {
                        isDownloading = false
                        downloadError = error.localizedDescription
                    }
                }
            }
        }
        .quickLookPreview($quickLookURL)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Tab: Tareas (with submission status)
// ═══════════════════════════════════════════════════════

struct CourseAssignmentsTab: View {
    let course: MoodleCourse
    @StateObject private var moodle = MoodleStore.shared
    @State private var selectedAssignment: MoodleAssignment? = nil

    private var assignments: [MoodleAssignment] {
        moodle.assignments.filter { $0.courseId == course.id }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Space.sm) {
                if assignments.isEmpty {
                    EmptyStateMoodle(
                        icon: "doc.text",
                        title: "Sin tareas",
                        sub: "No hay entregas registradas para este curso."
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(assignments) { a in
                        AssignmentDetailRow(assignment: a)
                            .onTapGesture {
                                selectedAssignment = a
                            }
                    }
                }
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.top, DS.Space.md)
        }
        .sheet(item: $selectedAssignment) { a in
            MoodleSubmissionView(assignment: a)
        }
    }
}

private struct AssignmentDetailRow: View {
    let assignment: MoodleAssignment
    @StateObject private var ext = MoodleExtendedStore.shared

    private var subStatus: MoodleSubmissionStatus? {
        ext.submissionStatusCache[assignment.id]
    }

    var body: some View {
        HStack(spacing: DS.Space.sm) {
            // Status indicator
            VStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.name)
                    .font(DS.Font.body(14, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(2)

                HStack(spacing: DS.Space.xs) {
                    // Submission status badge
                    if let sub = subStatus {
                        Text(sub.statusLabel)
                            .font(DS.Font.body(10, weight: .semibold))
                            .foregroundStyle(sub.statusColor)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(sub.statusColor.opacity(0.10))
                            .clipShape(Capsule())
                    } else if ext.loadingSubmissions.contains(assignment.id) {
                        ProgressView().scaleEffect(0.5).frame(width: 20, height: 14)
                    } else {
                        Text(assignment.isOverdue ? "Vencida" : "Pendiente")
                            .font(DS.Font.body(10, weight: .semibold))
                            .foregroundStyle(assignment.isOverdue ? Color(hex: "#CC1A1A") : Color.appInkTertiary)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background((assignment.isOverdue ? Color(hex: "#CC1A1A") : Color.appInkTertiary).opacity(0.10))
                            .clipShape(Capsule())
                    }

                    // Due date
                    if assignment.dueDate != nil {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.appInkTertiary)
                        Text(assignment.dueDateString)
                            .font(DS.Font.mono(10))
                            .foregroundStyle(Color.appInkTertiary)
                    }
                }

                // Grade if available
                if let fb = subStatus?.feedback, let grade = fb.grade {
                    Text(fb.gradeString)
                        .font(DS.Font.mono(11, weight: .bold))
                        .foregroundStyle(DS.Color.wine)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.appInkTertiary)
        }
        .padding(DS.Space.md)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).stroke(borderColor, lineWidth: 1))
        .onAppear {
            Task { await ext.loadSubmissionStatus(assignmentId: assignment.id) }
        }
    }

    private var statusColor: Color {
        if let sub = subStatus { return sub.statusColor }
        if assignment.isOverdue { return Color(hex: "#CC1A1A") }
        if assignment.isDueSoon { return Color(hex: "#8B5A1A") }
        return Color.appInkTertiary
    }

    private var borderColor: Color {
        if assignment.isOverdue, subStatus?.isSubmitted != true {
            return Color(hex: "#CC1A1A").opacity(0.20)
        }
        return Color.appCardBorder
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Tab: Notas
// ═══════════════════════════════════════════════════════

struct CourseGradesTab: View {
    let course: MoodleCourse
    @StateObject private var ext = MoodleExtendedStore.shared

    private var grades: MoodleUserGrades? { ext.gradesCache[course.id] }
    private var isLoading: Bool { ext.loadingGrades.contains(course.id) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Space.md) {

                if isLoading && grades == nil {
                    LoadingPlaceholder(text: "Cargando calificaciones...")
                } else if let g = grades {

                    // ── Average card ──────────────────────────
                    if let avg = g.courseAverage {
                        AverageSummaryCard(average: avg, courseName: course.fullname)
                    }

                    // ── Items ─────────────────────────────────
                    if g.items.isEmpty {
                        EmptyStateMoodle(
                            icon: "chart.bar",
                            title: "Sin calificaciones",
                            sub: "No hay items calificados aun en este curso."
                        )
                    } else {
                        VStack(spacing: DS.Space.sm) {
                            ForEach(g.items) { item in
                                GradeItemRow(item: item)
                            }
                        }
                    }
                } else {
                    EmptyStateMoodle(
                        icon: "chart.bar",
                        title: "Sin calificaciones",
                        sub: "No se encontraron notas para este curso."
                    )
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.top, DS.Space.md)
        }
        .refreshable {
            await ext.refreshGrades(courseId: course.id, courseName: course.fullname)
        }
    }
}

private struct AverageSummaryCard: View {
    let average: Double
    let courseName: String

    var gradeColor: Color {
        if average >= 70 { return Color(hex: "#1A5C3A") }
        if average >= 50 { return Color(hex: "#8B5A1A") }
        return Color(hex: "#CC1A1A")
    }

    var body: some View {
        HStack(spacing: DS.Space.lg) {
            // Circular gauge
            ZStack {
                Circle().stroke(Color.appBackgroundTertiary, lineWidth: 6).frame(width: 72, height: 72)
                Circle().trim(from: 0, to: min(1, average / 100))
                    .stroke(gradeColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 72, height: 72)
                    .animation(DS.Anim.easeSlow, value: average)
                VStack(spacing: 0) {
                    Text(String(format: "%.0f", average))
                        .font(DS.Font.mono(20, weight: .bold))
                        .foregroundStyle(gradeColor)
                    Text("%")
                        .font(DS.Font.body(9))
                        .foregroundStyle(Color.appInkTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("PROMEDIO GENERAL")
                    .font(DS.Font.body(8, weight: .bold))
                    .foregroundStyle(Color.appInkTertiary)
                    .tracking(2)
                Text(average >= 70 ? "Aprobando" : average >= 50 ? "En riesgo" : "Reprobando")
                    .font(DS.Font.body(16, weight: .semibold))
                    .foregroundStyle(gradeColor)
                Text("Basado en items calificados")
                    .font(DS.Font.body(11))
                    .foregroundStyle(Color.appInkTertiary)
            }
            Spacer()
        }
        .padding(DS.Space.md)
        .background(gradeColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).stroke(gradeColor.opacity(0.15), lineWidth: 1))
    }
}

private struct GradeItemRow: View {
    let item: MoodleGradeItem

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: item.sfSymbol)
                    .font(.system(size: 12))
                    .foregroundStyle(item.gradeColor)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(DS.Font.body(13, weight: .medium))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(2)
                    if let pct = item.percentageformatted {
                        Text(pct)
                            .font(DS.Font.mono(10))
                            .foregroundStyle(Color.appInkTertiary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.gradeString)
                        .font(DS.Font.mono(15, weight: .bold))
                        .foregroundStyle(item.graderaw != nil ? item.gradeColor : Color.appInkTertiary)

                    if item.graderaw != nil {
                        // Mini progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.appBackgroundTertiary).frame(height: 3)
                                Capsule()
                                    .fill(item.gradeColor)
                                    .frame(width: geo.size.width * min(1, item.percentage / 100), height: 3)
                            }
                        }
                        .frame(width: 60, height: 3)
                    }
                }
            }

            // Feedback
            if let fb = item.feedback, !fb.isEmpty {
                Text(fb)
                    .font(DS.Font.body(11))
                    .foregroundStyle(Color.appInkTertiary)
                    .lineLimit(3)
                    .padding(.leading, 26)
            }
        }
        .padding(DS.Space.md)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Tab: Foros
// ═══════════════════════════════════════════════════════

struct CourseForumsTab: View {
    let course: MoodleCourse
    @StateObject private var ext = MoodleExtendedStore.shared
    @State private var selectedForum: MoodleForum? = nil

    private var forums: [MoodleForum] { ext.forumsCache[course.id] ?? [] }
    private var isLoading: Bool { ext.loadingForums.contains(course.id) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Space.sm) {
                if isLoading && forums.isEmpty {
                    LoadingPlaceholder(text: "Cargando foros...")
                } else if forums.isEmpty {
                    EmptyStateMoodle(
                        icon: "bubble.left.and.bubble.right",
                        title: "Sin foros",
                        sub: "No hay foros activos en este curso."
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(forums) { forum in
                        ForumRow(forum: forum)
                            .onTapGesture { selectedForum = forum }
                    }
                }
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.top, DS.Space.md)
        }
        .sheet(item: $selectedForum) { forum in
            ForumDiscussionsView(forum: forum)
        }
    }
}

private struct ForumRow: View {
    let forum: MoodleForum

    var body: some View {
        HStack(spacing: DS.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(Color(hex: "#1A3A6B").opacity(0.08))
                    .frame(width: 38, height: 38)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "#1A3A6B"))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(forum.name)
                    .font(DS.Font.body(13, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                Text("\(forum.numdiscussions) discusion\(forum.numdiscussions == 1 ? "" : "es")")
                    .font(DS.Font.body(11))
                    .foregroundStyle(Color.appInkTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.appInkTertiary)
        }
        .padding(DS.Space.md)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

private struct ForumDiscussionsView: View {
    let forum: MoodleForum
    @StateObject private var ext = MoodleExtendedStore.shared
    @Environment(\.dismiss) private var dismiss

    private var discussions: [MoodleForumDiscussion] { ext.forumDiscussions[forum.id] ?? [] }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Space.sm) {
                        if discussions.isEmpty {
                            if ext.loadingForums.contains(forum.id) {
                                LoadingPlaceholder(text: "Cargando discusiones...")
                            } else {
                                EmptyStateMoodle(icon: "bubble.left", title: "Sin discusiones", sub: "No hay posts en este foro aun.")
                                    .padding(.top, 40)
                            }
                        } else {
                            ForEach(discussions) { disc in
                                DiscussionRow(discussion: disc)
                            }
                        }
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, DS.Space.md)
                    .padding(.top, DS.Space.md)
                }
            }
            .navigationTitle(forum.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Color.appInkTertiary)
                }
            }
        }
        .onAppear {
            Task { await ext.loadForumDiscussions(forumId: forum.id) }
        }
    }
}

private struct DiscussionRow: View {
    let discussion: MoodleForumDiscussion

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.sm) {
                Circle()
                    .fill(DS.Color.wine.opacity(0.07))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(discussion.userfullname.prefix(1)))
                            .font(DS.Font.body(13, weight: .bold))
                            .foregroundStyle(DS.Color.wine)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(discussion.userfullname)
                        .font(DS.Font.body(12, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    Text(discussion.createdDate, style: .relative)
                        .font(DS.Font.body(10))
                        .foregroundStyle(Color.appInkTertiary)
                }
                Spacer()
                if discussion.numreplies > 0 {
                    Label("\(discussion.numreplies)", systemImage: "bubble.right")
                        .font(DS.Font.body(10))
                        .foregroundStyle(Color.appInkTertiary)
                }
            }
            Text(discussion.name)
                .font(DS.Font.body(13, weight: .semibold))
                .foregroundStyle(Color.appInk)
            if !discussion.message.isEmpty {
                Text(discussion.message)
                    .font(DS.Font.body(12))
                    .foregroundStyle(Color.appInkTertiary)
                    .lineLimit(3)
                    .lineSpacing(2)
            }
        }
        .padding(DS.Space.md)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Shared small components
// ═══════════════════════════════════════════════════════

struct LoadingPlaceholder: View {
    let text: String
    var body: some View {
        VStack(spacing: DS.Space.md) {
            ProgressView()
            Text(text)
                .font(DS.Font.body(13))
                .foregroundStyle(Color.appInkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

struct EmptyStateMoodle: View {
    let icon: String
    let title: String
    let sub: String
    var iconColor: Color = Color.appInkTertiary.opacity(0.5)

    var body: some View {
        VStack(spacing: DS.Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(iconColor)
            Text(title)
                .font(DS.Font.body(14, weight: .semibold))
                .foregroundStyle(Color.appInkSecondary)
            Text(sub)
                .font(DS.Font.body(12))
                .foregroundStyle(Color.appInkTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Space.lg)
    }
}
