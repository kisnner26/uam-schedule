import Foundation
import SwiftUI

// MARK: - Moodle Config

enum MoodleConfig {
    static let baseURL = "https://uamvirtual.uam.edu.ni/grado"
    static let service = "moodle_mobile_app"
    static let tokenKey = "moodle_token"
    static let cifKey = "moodle_cif"
    /// When true, the importer will NOT re-add Moodle courses automatically.
    /// Resets to false only when the user explicitly logs in again.
    static let importSuppressedKey  = "moodle_import_suppressed"
    /// Persists moodleCourseIds that the user explicitly deleted — never re-add these.
    static let deletedMoodleIdsKey  = "moodle_deleted_course_ids"
}

// MARK: - Moodle Models

public struct MoodleAssignment: Identifiable, Codable, Hashable {
    public var id: Int
    public var courseId: Int
    public var courseName: String
    public var name: String
    public var dueDate: Date?
    public var intro: String
    public var noSubmissions: Bool
    public var submissionStatus: String?

    public var isOverdue: Bool {
        guard let d = dueDate else { return false }
        guard !noSubmissions else { return false }
        guard d < Date() else { return false }
        let status = submissionStatus?.lowercased() ?? ""
        return status != "submitted" && status != "graded" && status != "submittedforgrading"
    }

    public var isSubmitted: Bool {
        let status = submissionStatus?.lowercased() ?? ""
        return status == "submitted" || status == "graded" || status == "submittedforgrading"
    }
    public var isDueSoon: Bool {
        guard let d = dueDate else { return false }
        return d.timeIntervalSinceNow < 86400 * 3 && d > Date()
    }
    public var dueDateString: String {
        guard let d = dueDate else { return "Sin fecha" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_NI")
        f.dateFormat = "d MMM, h:mm a"
        return f.string(from: d)
    }
}

public struct MoodleCourse: Identifiable, Codable {
    public var id: Int
    public var shortname: String
    public var fullname: String
    public var summary: String
}

public struct MoodleGradeItem: Identifiable, Codable {
    public var id: Int
    public var itemname: String?
    public var itemtype: String?
    public var itemmodule: String?
    public var graderaw: Double?
    public var grademin: Double?
    public var grademax: Double?
    public var gradedatesubmitted: Int?
    public var gradedategraded: Int?
    public var percentageformatted: String?
    public var feedback: String?

    public var displayName: String { itemname ?? "Sin nombre" }

    public var gradeString: String {
        guard let raw = graderaw, let max = grademax else { return "—" }
        return String(format: "%.1f / %.0f", raw, max)
    }

    public var percentage: Double {
        guard let raw = graderaw, let max = grademax, max > 0 else { return 0 }
        return (raw / max) * 100
    }

    public var gradeColor: Color {
        guard let raw = graderaw, let max = grademax, max > 0 else { return Color.appInkTertiary }
        let pct = (raw / max) * 100
        if pct >= 70 { return Color(hex: "#1A5C3A") }
        if pct >= 50 { return Color(hex: "#8B5A1A") }
        return Color(hex: "#CC1A1A")
    }

    public var sfSymbol: String {
        switch itemmodule {
        case "assign": return "pencil.and.list.clipboard"
        case "quiz":   return "questionmark.circle"
        case "forum":  return "bubble.left.and.bubble.right"
        default:       return "chart.bar"
        }
    }
}

public struct MoodleUserGrades: Identifiable, Codable {
    public var id: Int
    public var courseName: String
    public var items: [MoodleGradeItem]

    public var courseAverage: Double? {
        let graded = items.filter { $0.graderaw != nil && $0.grademax != nil }
        guard !graded.isEmpty else { return nil }
        let total = graded.reduce(0.0) { $0 + ($1.graderaw ?? 0) }
        let max = graded.reduce(0.0) { $0 + ($1.grademax ?? 0) }
        guard max > 0 else { return nil }
        return (total / max) * 100
    }
}

// MARK: - Moodle Store

@MainActor
public class MoodleStore: ObservableObject {
    public static let shared = MoodleStore()

    @Published public var isConnected: Bool = false
    @Published public var cif: String = ""
    @Published public var assignments: [MoodleAssignment] = []
    @Published public var moodleCourses: [MoodleCourse] = []
    @Published public var isLoading: Bool = false
    @Published public var lastSyncDate: Date? = nil
    @Published public var error: String? = nil
    @Published public var lastImportResult: MoodleImportResult? = nil
    /// Shown once after login — asks if user wants to import/overwrite courses.
    @Published public var pendingImportConfirmation: Bool = false

    public weak var scheduleStore: ScheduleStore? = nil

    private var token: String? {
        get { UserDefaults.standard.string(forKey: MoodleConfig.tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: MoodleConfig.tokenKey) }
    }

    /// When true, sync will NOT re-add courses (user opted out after a login).
    public var importSuppressed: Bool {
        get { UserDefaults.standard.bool(forKey: MoodleConfig.importSuppressedKey) }
        set { UserDefaults.standard.set(newValue, forKey: MoodleConfig.importSuppressedKey) }
    }

    public init() {
        cif = UserDefaults.standard.string(forKey: MoodleConfig.cifKey) ?? ""
        let tok = UserDefaults.standard.string(forKey: MoodleConfig.tokenKey) ?? ""
        isConnected = !tok.isEmpty
        if isConnected {
            Task { await sync() }
        }
    }

    // MARK: - Auth

    public func login(cif: String, pin: String) async throws {
        let urlStr = "\(MoodleConfig.baseURL)/login/token.php?username=\(cif)&password=\(pin)&service=\(MoodleConfig.service)"
        guard let url = URL(string: urlStr) else { throw MoodleError.invalidURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let err = json?["error"] as? String { throw MoodleError.loginFailed(err) }
        guard let tok = json?["token"] as? String else { throw MoodleError.noToken }

        self.token = tok
        self.cif = cif
        UserDefaults.standard.set(cif, forKey: MoodleConfig.cifKey)
        self.isConnected = true
        // Reset suppression on fresh login so user gets the prompt again
        importSuppressed = false
        await sync(fromLogin: true)
    }

    public func logout() {
        token = nil
        cif = ""
        isConnected = false
        assignments = []
        moodleCourses = []
        lastSyncDate = nil
        lastImportResult = nil
        pendingImportConfirmation = false
        UserDefaults.standard.removeObject(forKey: MoodleConfig.tokenKey)
        UserDefaults.standard.removeObject(forKey: MoodleConfig.cifKey)
    }

    // MARK: - Sync

    /// fromLogin=true: always show import confirmation dialog regardless of suppression.
    public func sync(fromLogin: Bool = false) async {
        guard let tok = token else { return }
        isLoading = true
        error = nil
        do {
            moodleCourses = try await fetchCourses(token: tok)

            if let store = scheduleStore, !moodleCourses.isEmpty {
                if fromLogin {
                    // Fresh login — always ask user whether to import
                    pendingImportConfirmation = true
                } else if !importSuppressed {
                    // Background sync — skip ids the user explicitly deleted
                    let result = MoodleCourseImporter.sync(
                        moodleCourses: moodleCourses,
                        into: store,
                        skipIds: deletedMoodleIds
                    )
                    lastImportResult = result
                }
            }

            let courseIds = moodleCourses.map { $0.id }
            if !courseIds.isEmpty {
                assignments = try await fetchAssignments(token: tok, courseIds: courseIds)
            }
            lastSyncDate = Date()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Called when user confirms import from the dialog.
    public func confirmImport(overwrite: Bool) {
        pendingImportConfirmation = false
        importSuppressed = false
        guard let store = scheduleStore else { return }
        if overwrite {
            // Remove existing Moodle-sourced courses before re-importing
            store.courses.removeAll { $0.moodleCourseId != nil }
            store.save()
            clearDeletedIds()
        }
        let result = MoodleCourseImporter.sync(moodleCourses: moodleCourses, into: store, skipIds: deletedMoodleIds)
        lastImportResult = result
    }

    /// Called when user declines import from the dialog.
    public func declineImport() {
        pendingImportConfirmation = false
        importSuppressed = true
    }

    /// Set of moodleCourseIds the user has explicitly deleted from the store.
    /// These are NEVER re-added by background sync — only cleared on fresh login + user confirmation.
    public var deletedMoodleIds: Set<Int> {
        get {
            let arr = UserDefaults.standard.array(forKey: MoodleConfig.deletedMoodleIdsKey) as? [Int] ?? []
            return Set(arr)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: MoodleConfig.deletedMoodleIdsKey)
        }
    }

    /// Call this whenever a course with a moodleCourseId is deleted by the user.
    public func markDeleted(moodleCourseId: Int) {
        var ids = deletedMoodleIds
        ids.insert(moodleCourseId)
        deletedMoodleIds = ids
    }

    /// Resets deleted list — called only on fresh login + user confirms overwrite.
    public func clearDeletedIds() {
        UserDefaults.standard.removeObject(forKey: MoodleConfig.deletedMoodleIdsKey)
    }

    public func syncIfConnected() {
        guard isConnected else { return }
        if let last = lastSyncDate, Date().timeIntervalSince(last) < 300 { return }
        Task { await sync() }
    }

    // MARK: - API Calls

    private func fetchCourses(token: String) async throws -> [MoodleCourse] {
        let userId = try await fetchUserId(token: token)
        let params = "wstoken=\(token)&wsfunction=core_enrol_get_users_courses&moodlewsrestformat=json&userid=\(userId)"
        let data = try await callAPI(params: params)
        return try JSONDecoder().decode([MoodleCourse].self, from: data)
    }

    private func fetchUserId(token: String) async throws -> Int {
        let params = "wstoken=\(token)&wsfunction=core_webservice_get_site_info&moodlewsrestformat=json"
        let data = try await callAPI(params: params)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let uid = json?["userid"] as? Int else { throw MoodleError.parseError("userid") }
        return uid
    }

    private func fetchAssignments(token: String, courseIds: [Int]) async throws -> [MoodleAssignment] {
        let courseParam = courseIds.enumerated().map { i, id in "courseids[\(i)]=\(id)" }.joined(separator: "&")
        let params = "wstoken=\(token)&wsfunction=mod_assign_get_assignments&moodlewsrestformat=json&\(courseParam)"
        let data = try await callAPI(params: params)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let courses = json["courses"] as? [[String: Any]] else { return [] }

        var result: [MoodleAssignment] = []
        for course in courses {
            let courseId = course["id"] as? Int ?? 0
            let courseName = course["fullname"] as? String ?? ""
            guard let assigns = course["assignments"] as? [[String: Any]] else { continue }
            for a in assigns {
                let dueTs = a["duedate"] as? Int ?? 0
                let dueDate: Date? = dueTs > 0 ? Date(timeIntervalSince1970: TimeInterval(dueTs)) : nil
                result.append(MoodleAssignment(
                    id: a["id"] as? Int ?? 0,
                    courseId: courseId,
                    courseName: courseName,
                    name: a["name"] as? String ?? "",
                    dueDate: dueDate,
                    intro: (a["intro"] as? String ?? "").strippingHTML(),
                    noSubmissions: (a["nosubmissions"] as? Int ?? 0) == 1,
                    submissionStatus: nil
                ))
            }
        }

        let assignIds = result.map { $0.id }
        if !assignIds.isEmpty, let statusMap = try? await fetchSubmissionStatuses(token: token, assignIds: assignIds) {
            for i in result.indices { result[i].submissionStatus = statusMap[result[i].id] }
        }

        return result.sorted {
            switch ($0.dueDate, $1.dueDate) {
            case (nil, nil): return false
            case (nil, _): return false
            case (_, nil): return true
            case (let a, let b): return a! < b!
            }
        }
    }

    private func fetchSubmissionStatuses(token: String, assignIds: [Int]) async throws -> [Int: String] {
        let assignParam = assignIds.enumerated().map { i, id in "assignmentids[\(i)]=\(id)" }.joined(separator: "&")
        let params = "wstoken=\(token)&wsfunction=mod_assign_get_submissions&moodlewsrestformat=json&\(assignParam)"
        let data = try await callAPI(params: params)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let assignments = json["assignments"] as? [[String: Any]] else { return [:] }

        var map: [Int: String] = [:]
        for asgn in assignments {
            let assignId = asgn["assignmentid"] as? Int ?? 0
            guard let submissions = asgn["submissions"] as? [[String: Any]] else { continue }
            let sorted = submissions.sorted {
                ($0["timemodified"] as? Int ?? 0) > ($1["timemodified"] as? Int ?? 0)
            }
            if let status = sorted.first?["status"] as? String, !status.isEmpty {
                map[assignId] = status
            }
        }
        return map
    }

    // MARK: - HTTP helper

    private func callAPI(params: String) async throws -> Data {
        guard let url = URL(string: "\(MoodleConfig.baseURL)/webservice/rest/server.php") else {
            throw MoodleError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = params.data(using: .utf8)
        req.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw MoodleError.httpError(http.statusCode)
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let exc = json["exception"] as? String {
            throw MoodleError.apiException(json["message"] as? String ?? exc)
        }
        return data
    }

    // MARK: - Helpers

    /// Returns assignments matching a course by name or by code prefix.
    /// The code match strategy: extract alphanumeric prefix of courseName (e.g. "SIS0407")
    /// and check if any moodle courseName contains it.
    public func assignments(for courseName: String) -> [MoodleAssignment] {
        // Strategy 1: direct containment
        let direct = assignments.filter { $0.courseName.localizedCaseInsensitiveContains(courseName) }
        if !direct.isEmpty { return direct }
        // Strategy 2: significant words
        let words = courseName.components(separatedBy: .whitespaces).filter { $0.count > 3 }
        let byWord = assignments.filter { a in words.contains { w in a.courseName.localizedCaseInsensitiveContains(w) } }
        if !byWord.isEmpty { return byWord }
        // Strategy 3: match by course code (e.g. "SIS0407" in course name or shortname)
        let codePattern = courseName.components(separatedBy: .whitespaces)
            .first { $0.range(of: #"^[A-Z]{2,4}\d{3,}"#, options: .regularExpression) != nil } ?? ""
        if !codePattern.isEmpty {
            let byCode = assignments.filter { $0.courseName.localizedCaseInsensitiveContains(codePattern) }
            if !byCode.isEmpty { return byCode }
        }
        return []
    }

    public func pendingCount(for courseName: String) -> Int {
        assignments(for: courseName).filter { !$0.noSubmissions }.count
    }

    public var overdueAssignments: [MoodleAssignment] {
        assignments.filter { $0.isOverdue && !$0.isSubmitted }
    }

    public var dueSoonAssignments: [MoodleAssignment] {
        assignments.filter { $0.isDueSoon }
    }

    public var lastSyncString: String {
        guard let d = lastSyncDate else { return "Nunca" }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_NI")
        f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: Date())
    }
}

// MARK: - Errors

enum MoodleError: LocalizedError {
    case invalidURL, loginFailed(String), noToken, httpError(Int), apiException(String), parseError(String)
    var errorDescription: String? {
        switch self {
        case .loginFailed(let m): return "Credenciales incorrectas: \(m)"
        case .noToken: return "No se recibió un token válido."
        case .httpError(let c): return "Error HTTP \(c)."
        case .apiException(let m): return m
        case .parseError(let f): return "Error al leer campo '\(f)'."
        case .invalidURL: return "URL inválida."
        }
    }
}

// MARK: - HTML Stripping

extension String {
    func strippingHTML() -> String {
        guard let data = self.data(using: .utf8) else { return self }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                   .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Moodle Import Result

public struct MoodleImportResult {
    public var added: Int
    public var updated: Int
    public var skipped: Int

    public var summary: String {
        var parts: [String] = []
        if added   > 0 { parts.append("\(added) materia\(added   == 1 ? "" : "s") nueva\(added   == 1 ? "" : "s")") }
        if updated > 0 { parts.append("\(updated) actualizada\(updated == 1 ? "" : "s")") }
        if skipped > 0 { parts.append("\(skipped) sin cambios") }
        return parts.isEmpty ? "Sin cambios" : parts.joined(separator: " · ")
    }
    public var didChangeAnything: Bool { added > 0 || updated > 0 }
}

// MARK: - Moodle Course Importer

@MainActor
public final class MoodleCourseImporter {

    private static let palette: [String] = [
        "#6B1A2A","#1A3A6B","#1A5C3A","#6B4A1A",
        "#3A1A6B","#1A5A6B","#6B3A1A","#1A6B5A"
    ]

    @discardableResult
    public static func sync(
        moodleCourses: [MoodleCourse],
        into store: ScheduleStore,
        skipIds: Set<Int> = []
    ) -> MoodleImportResult {
        var added = 0, updated = 0, skipped = 0
        let active = filterActiveCourses(moodleCourses).filter { !skipIds.contains($0.id) }

        for (index, mc) in active.enumerated() {
            if let i = store.courses.firstIndex(where: { $0.moodleCourseId == mc.id }) {
                let newName = cleanCourseName(mc.fullname)
                let newCode = extractCode(mc.shortname)
                if store.courses[i].name != newName || store.courses[i].code != newCode {
                    store.courses[i].name = newName
                    store.courses[i].code = newCode
                    updated += 1
                } else { skipped += 1 }
            } else {
                let colorIndex = (store.courses.filter { $0.moodleCourseId != nil }.count + index) % palette.count
                store.courses.append(Course(
                    id: UUID(), code: extractCode(mc.shortname),
                    name: cleanCourseName(mc.fullname), room: "",
                    credits: 3, group: "G1", color: palette[colorIndex],
                    sessions: [], isFavorite: false, section: "",
                    reminders: [], checklist: [], flashcards: [],
                    grades: GradeRecord(), moodleCourseId: mc.id
                ))
                added += 1
            }
        }

        if added > 0 || updated > 0 { store.save() }
        return MoodleImportResult(added: added, updated: updated, skipped: skipped)
    }

    private static func filterActiveCourses(_ courses: [MoodleCourse]) -> [MoodleCourse] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return courses.filter { c in
            for year in (currentYear - 5)...(currentYear - 3) {
                if c.shortname.contains(String(year)) || c.fullname.contains(String(year)) { return false }
            }
            return true
        }
    }

    private static func extractCode(_ shortname: String) -> String {
        let t = shortname.trimmingCharacters(in: .whitespaces)
        if t.count <= 12 && !t.contains(" ") {
            return String(t.replacingOccurrences(of: #"-G\d+$"#, with: "", options: .regularExpression).prefix(10))
        }
        let initials = t.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            .prefix(3).map { String($0.prefix(2)).uppercased() }.joined()
        return initials.isEmpty ? String(t.prefix(8)) : initials
    }

    private static func cleanCourseName(_ fullname: String) -> String {
        var name = fullname.trimmingCharacters(in: .whitespaces)
        for pattern in [
            #"\s*[-|]\s*20\d{2}.*$"#, #"\s*\(\s*G\d+\s*\)\s*$"#,
            #"\s*[-|]\s*Grupo\s+\d+.*$"#, #"\s*[-|]\s*Seccion\s+\w+.*$"#,
            #"\s*-\s*[A-Z]{1,3}\d{3,}.*$"#, #"\s+20\d{2}-[I|II|III]+$"#
        ] { name = name.replacingOccurrences(of: pattern, with: "", options: .regularExpression) }
        return name.trimmingCharacters(in: .whitespaces)
    }
}
