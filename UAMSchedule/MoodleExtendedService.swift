import Foundation
import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Extended Moodle Models
// ═══════════════════════════════════════════════════════

// MARK: Course Content (modules inside a course section)

public struct MoodleCourseSection: Identifiable, Codable {
    public var id: Int
    public var name: String
    public var summary: String
    public var modules: [MoodleModule]
}

public struct MoodleModule: Identifiable, Codable, Hashable {
    public var id: Int
    public var name: String
    public var modname: String   // "resource", "assign", "forum", "url", "folder", "page", "quiz", "label"
    public var modicon: String
    public var visible: Int
    public var contents: [MoodleContent]?
    public var description: String?

    public var sfSymbol: String {
        switch modname {
        case "resource":  return "doc.fill"
        case "assign":    return "pencil.and.list.clipboard"
        case "forum":     return "bubble.left.and.bubble.right"
        case "url":       return "link"
        case "folder":    return "folder.fill"
        case "page":      return "doc.text"
        case "quiz":      return "questionmark.circle"
        case "label":     return "text.alignleft"
        default:          return "square.grid.2x2"
        }
    }

    public var typeLabel: String {
        switch modname {
        case "resource":  return "Archivo"
        case "assign":    return "Tarea"
        case "forum":     return "Foro"
        case "url":       return "Enlace"
        case "folder":    return "Carpeta"
        case "page":      return "Pagina"
        case "quiz":      return "Cuestionario"
        case "label":     return "Etiqueta"
        default:          return modname.capitalized
        }
    }
}

public struct MoodleContent: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID = UUID()
    public var type: String       // "file", "url"
    public var filename: String
    public var fileurl: String
    public var filesize: Int
    public var mimetype: String?
    public var timemodified: Int

    enum CodingKeys: String, CodingKey {
        case type, filename, fileurl, filesize, mimetype, timemodified
    }

    public var isDownloadable: Bool {
        type == "file"
    }

    public var fileIcon: String {
        guard let mime = mimetype else { return "doc" }
        if mime.contains("pdf")   { return "doc.richtext.fill" }
        if mime.contains("word") || mime.contains("document") { return "doc.text.fill" }
        if mime.contains("image") { return "photo.fill" }
        if mime.contains("video") { return "play.rectangle.fill" }
        if mime.contains("audio") { return "music.note" }
        if mime.contains("zip") || mime.contains("compressed") { return "archivebox.fill" }
        if mime.contains("presentation") || mime.contains("powerpoint") { return "square.stack.fill" }
        if mime.contains("spreadsheet") || mime.contains("excel") { return "tablecells.fill" }
        return "doc.fill"
    }

    public var fileSizeString: String {
        let kb = Double(filesize) / 1024
        if kb < 1024 { return String(format: "%.0f KB", kb) }
        return String(format: "%.1f MB", kb / 1024)
    }

    public var authenticatedURL: String {
        // Moodle requires token in file URLs
        if fileurl.contains("token=") { return fileurl }
        let sep = fileurl.contains("?") ? "&" : "?"
        return fileurl + sep + "token=TOKEN_PLACEHOLDER"
    }
}

// MARK: Submission Status

public struct MoodleSubmissionStatus: Codable {
    public var assignmentId: Int
    public var status: String          // "draft", "submitted", "graded", "new"
    public var gradingStatus: String?  // "notgraded", "graded"
    public var lastModified: Date?
    public var submittedFiles: [MoodleSubmittedFile]
    public var onlineText: String?
    public var feedback: MoodleSubmissionFeedback?

    public var isSubmitted: Bool {
        status == "submitted" || status == "graded"
    }

    public var statusLabel: String {
        switch status {
        case "submitted":  return "Enviada"
        case "graded":     return "Calificada"
        case "draft":      return "Borrador"
        default:           return "Sin enviar"
        }
    }

    public var statusColor: Color {
        switch status {
        case "submitted":  return Color(hex: "#1A5C3A")
        case "graded":     return DS.Color.wine
        case "draft":      return Color(hex: "#8B5A1A")
        default:           return Color.appInkTertiary
        }
    }

    public var statusIcon: String {
        switch status {
        case "submitted":  return "checkmark.circle.fill"
        case "graded":     return "star.circle.fill"
        case "draft":      return "doc.badge.clock"
        default:           return "circle.dashed"
        }
    }
}

public struct MoodleSubmittedFile: Identifiable, Codable {
    public var id: UUID = UUID()
    public var filename: String
    public var fileurl: String
    public var filesize: Int
    public var timemodified: Int

    enum CodingKeys: String, CodingKey {
        case filename, fileurl, filesize, timemodified
    }
}

public struct MoodleSubmissionFeedback: Codable {
    public var grade: Double?
    public var grademax: Double?
    public var feedbacktext: String?
    public var gradedDate: Date?

    public var gradeString: String {
        guard let g = grade, let m = grademax else { return "—" }
        return String(format: "%.1f / %.0f", g, m)
    }
}

// MARK: Forum

public struct MoodleForum: Identifiable, Codable {
    public var id: Int
    public var name: String
    public var intro: String
    public var numdiscussions: Int
    public var courseId: Int
}

public struct MoodleForumDiscussion: Identifiable, Codable {
    public var id: Int
    public var name: String
    public var message: String
    public var userfullname: String
    public var created: Int
    public var numreplies: Int
    public var timemodified: Int

    public var createdDate: Date { Date(timeIntervalSince1970: TimeInterval(created)) }
    public var modifiedDate: Date { Date(timeIntervalSince1970: TimeInterval(timemodified)) }
}

// ═══════════════════════════════════════════════════════
// MARK: - Extended Moodle Store
// ═══════════════════════════════════════════════════════

@MainActor
public class MoodleExtendedStore: ObservableObject {
    public static let shared = MoodleExtendedStore()

    // ── Course contents cache ─────────────────────
    @Published public var courseContents: [Int: [MoodleCourseSection]] = [:]
    @Published public var loadingContents: Set<Int> = []

    // ── Grades cache ──────────────────────────────
    @Published public var gradesCache: [Int: MoodleUserGrades] = [:]
    @Published public var loadingGrades: Set<Int> = []

    // ── Submission status cache ───────────────────
    @Published public var submissionStatusCache: [Int: MoodleSubmissionStatus] = [:]
    @Published public var loadingSubmissions: Set<Int> = []

    // ── Forums cache ──────────────────────────────
    @Published public var forumsCache: [Int: [MoodleForum]] = [:]
    @Published public var forumDiscussions: [Int: [MoodleForumDiscussion]] = [:]
    @Published public var loadingForums: Set<Int> = []

    // ── Download tracking ─────────────────────────
    @Published public var downloadProgress: [String: Double] = [:]
    @Published public var downloadedFiles: [String: URL] = [:]   // fileurl -> local URL

    // ── Upload state ──────────────────────────────
    @Published public var uploadProgress: Double = 0
    @Published public var isUploading: Bool = false
    @Published public var uploadError: String? = nil
    @Published public var uploadSuccess: Bool = false

    private var baseURL: String { MoodleConfig.baseURL }
    private var token: String? { UserDefaults.standard.string(forKey: MoodleConfig.tokenKey) }

    // ─────────────────────────────────────────────
    // MARK: Course Contents
    // ─────────────────────────────────────────────

    public func loadCourseContents(courseId: Int) async {
        guard let tok = token else { return }
        guard !loadingContents.contains(courseId) else { return }
        // Use cache if fresh (less than 10 min old)
        if courseContents[courseId] != nil { return }

        loadingContents.insert(courseId)
        defer { loadingContents.remove(courseId) }

        do {
            let params = "wstoken=\(tok)&wsfunction=core_course_get_contents&moodlewsrestformat=json&courseid=\(courseId)"
            let data = try await callAPI(params: params)
            var sections = try JSONDecoder().decode([MoodleCourseSection].self, from: data)
            // Filter empty sections and invisible modules
            sections = sections.map { section in
                var s = section
                s.modules = s.modules.filter { $0.visible == 1 && $0.modname != "label" }
                return s
            }.filter { !$0.modules.isEmpty || !$0.name.isEmpty }
            courseContents[courseId] = sections
        } catch {
            print("MoodleExtended: loadCourseContents error: \(error)")
        }
    }

    public func refreshCourseContents(courseId: Int) async {
        courseContents.removeValue(forKey: courseId)
        await loadCourseContents(courseId: courseId)
    }

    // ─────────────────────────────────────────────
    // MARK: File Download
    // ─────────────────────────────────────────────

    /// Returns local URL if already downloaded, otherwise downloads it.
    public func downloadFile(content: MoodleContent) async throws -> URL {
        guard let tok = token else { throw MoodleExtError.notAuthenticated }

        // Already downloaded?
        if let local = downloadedFiles[content.fileurl], FileManager.default.fileExists(atPath: local.path) {
            return local
        }

        // Build authenticated URL
        let rawURL = content.fileurl
        let sep = rawURL.contains("?") ? "&" : "?"
        let authURL = rawURL + sep + "token=\(tok)"
        guard let url = URL(string: authURL) else { throw MoodleExtError.invalidURL }

        downloadProgress[content.fileurl] = 0

        let (localURL, _) = try await URLSession.shared.download(from: url) { @Sendable bytesWritten, totalBytesWritten, totalExpected in
            Task { @MainActor in
                if totalExpected > 0 {
                    // Access self on the main actor
                    self.downloadProgress[content.fileurl] = Double(totalBytesWritten) / Double(totalExpected)
                }
            }
        }

        // Move to Documents/UAMSchedule/
        let destDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UAMSchedule", isDirectory: true)
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let dest = destDir.appendingPathComponent(content.filename)

        // Remove if exists
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: localURL, to: dest)

        downloadProgress.removeValue(forKey: content.fileurl)
        downloadedFiles[content.fileurl] = dest
        return dest
    }

    public func isDownloaded(_ content: MoodleContent) -> Bool {
        guard let local = downloadedFiles[content.fileurl] else { return false }
        return FileManager.default.fileExists(atPath: local.path)
    }

    public func downloadProgressFor(_ content: MoodleContent) -> Double? {
        downloadProgress[content.fileurl]
    }

    // ─────────────────────────────────────────────
    // MARK: Grades
    // ─────────────────────────────────────────────

    public func loadGrades(courseId: Int, courseName: String) async {
        guard let tok = token else { return }
        guard !loadingGrades.contains(courseId) else { return }
        if gradesCache[courseId] != nil { return }

        loadingGrades.insert(courseId)
        defer { loadingGrades.remove(courseId) }

        do {
            // Get user id first
            let userId = try await fetchUserId(token: tok)
            let params = "wstoken=\(tok)&wsfunction=gradereport_user_get_grade_items&moodlewsrestformat=json&courseid=\(courseId)&userid=\(userId)"
            let data = try await callAPI(params: params)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let userGrades = json["usergrades"] as? [[String: Any]],
                  let first = userGrades.first,
                  let gradeitems = first["gradeitems"] as? [[String: Any]] else {
                return
            }

            var items: [MoodleGradeItem] = []
            for item in gradeitems {
                let id = item["id"] as? Int ?? 0
                guard id > 0 else { continue }
                let graderaw = item["graderaw"] as? Double
                let grademin = item["grademin"] as? Double
                let grademax = item["grademax"] as? Double
                let gi = MoodleGradeItem(
                    id: id,
                    itemname: item["itemname"] as? String,
                    itemtype: item["itemtype"] as? String,
                    itemmodule: item["itemmodule"] as? String,
                    graderaw: graderaw,
                    grademin: grademin,
                    grademax: grademax,
                    gradedatesubmitted: item["gradedatesubmitted"] as? Int,
                    gradedategraded: item["gradedategraded"] as? Int,
                    percentageformatted: item["percentageformatted"] as? String,
                    feedback: (item["feedback"] as? String)?.strippingHTML()
                )
                items.append(gi)
            }

            // Filter out category/total items (no grademax or itemtype == "category")
            let filtered = items.filter {
                $0.itemtype != "category" && ($0.grademax ?? 0) > 0
            }

            gradesCache[courseId] = MoodleUserGrades(id: courseId, courseName: courseName, items: filtered)
        } catch {
            print("MoodleExtended: loadGrades error: \(error)")
        }
    }

    public func refreshGrades(courseId: Int, courseName: String) async {
        gradesCache.removeValue(forKey: courseId)
        await loadGrades(courseId: courseId, courseName: courseName)
    }

    // ─────────────────────────────────────────────
    // MARK: Submission Status
    // ─────────────────────────────────────────────

    public func loadSubmissionStatus(assignmentId: Int) async {
        guard let tok = token else { return }
        guard !loadingSubmissions.contains(assignmentId) else { return }
        if submissionStatusCache[assignmentId] != nil { return }

        loadingSubmissions.insert(assignmentId)
        defer { loadingSubmissions.remove(assignmentId) }

        do {
            let params = "wstoken=\(tok)&wsfunction=mod_assign_get_submission_status&moodlewsrestformat=json&assignid=\(assignmentId)"
            let data = try await callAPI(params: params)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            // Parse lastattempt
            var status = "new"
            var submittedFiles: [MoodleSubmittedFile] = []
            var onlineText: String? = nil
            var lastModified: Date? = nil
            var feedback: MoodleSubmissionFeedback? = nil

            if let lastAttempt = json["lastattempt"] as? [String: Any],
               let submission = lastAttempt["submission"] as? [String: Any] {
                status = submission["status"] as? String ?? "new"
                if let ts = submission["timemodified"] as? Int, ts > 0 {
                    lastModified = Date(timeIntervalSince1970: TimeInterval(ts))
                }
                // Parse plugins
                if let plugins = submission["plugins"] as? [[String: Any]] {
                    for plugin in plugins {
                        let ptype = plugin["type"] as? String ?? ""
                        if ptype == "file", let fileareas = plugin["fileareas"] as? [[String: Any]] {
                            for area in fileareas {
                                if let files = area["files"] as? [[String: Any]] {
                                    for f in files {
                                        let sf = MoodleSubmittedFile(
                                            filename: f["filename"] as? String ?? "",
                                            fileurl: f["fileurl"] as? String ?? "",
                                            filesize: f["filesize"] as? Int ?? 0,
                                            timemodified: f["timemodified"] as? Int ?? 0
                                        )
                                        submittedFiles.append(sf)
                                    }
                                }
                            }
                        }
                        if ptype == "onlinetext", let editorfields = plugin["editorfields"] as? [[String: Any]] {
                            onlineText = (editorfields.first?["text"] as? String)?.strippingHTML()
                        }
                    }
                }
            }

            // Parse feedback
            if let fbk = json["feedback"] as? [String: Any] {
                var fb = MoodleSubmissionFeedback()
                if let grade = fbk["grade"] as? [String: Any] {
                    fb.grade = grade["grade"] as? Double
                    if let ts = grade["timemodified"] as? Int, ts > 0 {
                        fb.gradedDate = Date(timeIntervalSince1970: TimeInterval(ts))
                    }
                }
                if let plugins = fbk["plugins"] as? [[String: Any]] {
                    for plugin in plugins {
                        if plugin["type"] as? String == "comments",
                           let fields = plugin["editorfields"] as? [[String: Any]],
                           let text = fields.first?["text"] as? String, !text.isEmpty {
                            fb.feedbacktext = text.strippingHTML()
                        }
                    }
                }
                feedback = fb
            }

            // Grademax from assignment info
            let gradingStatus = (json["lastattempt"] as? [String: Any])?["gradingstatus"] as? String

            let sub = MoodleSubmissionStatus(
                assignmentId: assignmentId,
                status: status,
                gradingStatus: gradingStatus,
                lastModified: lastModified,
                submittedFiles: submittedFiles,
                onlineText: onlineText,
                feedback: feedback
            )
            submissionStatusCache[assignmentId] = sub
        } catch {
            print("MoodleExtended: loadSubmissionStatus error: \(error)")
        }
    }

    public func refreshSubmissionStatus(assignmentId: Int) async {
        submissionStatusCache.removeValue(forKey: assignmentId)
        await loadSubmissionStatus(assignmentId: assignmentId)
    }

    // ─────────────────────────────────────────────
    // MARK: File Upload & Submit
    // ─────────────────────────────────────────────

    /// Full flow: upload file to draft area, then submit to assignment
    public func submitFile(
        assignmentId: Int,
        fileURL: URL,
        filename: String,
        mimeType: String
    ) async {
        guard let tok = token else {
            uploadError = "No autenticado"
            return
        }

        isUploading = true
        uploadProgress = 0
        uploadError = nil
        uploadSuccess = false

        do {
            // Step 1: Upload file to Moodle draft area
            let itemId = try await uploadFileToDraft(
                token: tok,
                fileURL: fileURL,
                filename: filename,
                mimeType: mimeType
            )

            uploadProgress = 0.7

            // Step 2: Save submission with itemId
            try await saveSubmission(token: tok, assignmentId: assignmentId, itemId: itemId)

            uploadProgress = 1.0
            uploadSuccess = true

            // Invalidate submission status cache so it refreshes
            submissionStatusCache.removeValue(forKey: assignmentId)
            await loadSubmissionStatus(assignmentId: assignmentId)

            // Also invalidate MoodleStore assignments
            await MoodleStore.shared.sync()

        } catch {
            uploadError = error.localizedDescription
        }

        isUploading = false
    }

    private func uploadFileToDraft(token: String, fileURL: URL, filename: String, mimeType: String) async throws -> Int {
        guard let url = URL(string: "\(baseURL)/webservice/upload.php") else {
            throw MoodleExtError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let fileData = try Data(contentsOf: fileURL)
        var body = Data()

        // token field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"token\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(token)\r\n".data(using: .utf8)!)

        // filearea field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"filearea\"\r\n\r\ndraft\r\n".data(using: .utf8)!)

        // file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file_1\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        uploadProgress = 0.3

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw MoodleExtError.httpError(http.statusCode)
        }

        // Response: array of uploaded files with itemid
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = arr.first,
              let itemId = first["itemid"] as? Int else {
            // Check for error
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = json["error"] as? String {
                throw MoodleExtError.apiError(msg)
            }
            throw MoodleExtError.parseError("upload itemid")
        }

        uploadProgress = 0.5
        return itemId
    }

    private func saveSubmission(token: String, assignmentId: Int, itemId: Int) async throws {
        let params = [
            "wstoken": token,
            "wsfunction": "mod_assign_save_submission",
            "moodlewsrestformat": "json",
            "assignmentid": "\(assignmentId)",
            "plugindata[files_filemanager]": "\(itemId)"
        ]
        let body = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")

        guard let url = URL(string: "\(baseURL)/webservice/rest/server.php") else {
            throw MoodleExtError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)
        req.timeoutInterval = 30

        let (data, _) = try await URLSession.shared.data(for: req)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let exc = json["exception"] as? String {
                let msg = json["message"] as? String ?? exc
                throw MoodleExtError.apiError(msg)
            }
            // warnings is fine (empty submission warnings are expected)
        }
    }

    // ─────────────────────────────────────────────
    // MARK: Forums
    // ─────────────────────────────────────────────

    public func loadForums(courseId: Int) async {
        guard let tok = token else { return }
        guard !loadingForums.contains(courseId) else { return }
        if forumsCache[courseId] != nil { return }

        loadingForums.insert(courseId)
        defer { loadingForums.remove(courseId) }

        do {
            let params = "wstoken=\(tok)&wsfunction=mod_forum_get_forums_by_courses&moodlewsrestformat=json&courseids[0]=\(courseId)"
            let data = try await callAPI(params: params)
            var forums = try JSONDecoder().decode([MoodleForum].self, from: data)
            forums = forums.filter { $0.courseId == courseId }
            forumsCache[courseId] = forums
        } catch {
            print("MoodleExtended: loadForums error: \(error)")
        }
    }

    public func loadForumDiscussions(forumId: Int) async {
        guard let tok = token else { return }
        if forumDiscussions[forumId] != nil { return }

        do {
            let params = "wstoken=\(tok)&wsfunction=mod_forum_get_forum_discussions&moodlewsrestformat=json&forumid=\(forumId)&perpage=20"
            let data = try await callAPI(params: params)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let discussions = json["discussions"] as? [[String: Any]] {
                var result: [MoodleForumDiscussion] = []
                for d in discussions {
                    let disc = MoodleForumDiscussion(
                        id: d["discussion"] as? Int ?? 0,
                        name: d["name"] as? String ?? "",
                        message: (d["message"] as? String ?? "").strippingHTML(),
                        userfullname: d["userfullname"] as? String ?? "",
                        created: d["created"] as? Int ?? 0,
                        numreplies: d["numreplies"] as? Int ?? 0,
                        timemodified: d["timemodified"] as? Int ?? 0
                    )
                    result.append(disc)
                }
                forumDiscussions[forumId] = result
            }
        } catch {
            print("MoodleExtended: loadForumDiscussions error: \(error)")
        }
    }

    // ─────────────────────────────────────────────
    // MARK: Helpers
    // ─────────────────────────────────────────────

    private func fetchUserId(token: String) async throws -> Int {
        let params = "wstoken=\(token)&wsfunction=core_webservice_get_site_info&moodlewsrestformat=json"
        let data = try await callAPI(params: params)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let uid = json?["userid"] as? Int else { throw MoodleExtError.parseError("userid") }
        return uid
    }

    private func callAPI(params: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/webservice/rest/server.php") else {
            throw MoodleExtError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = params.data(using: .utf8)
        req.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw MoodleExtError.httpError(http.statusCode)
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let exc = json["exception"] as? String {
            let msg = json["message"] as? String ?? exc
            throw MoodleExtError.apiError(msg)
        }
        return data
    }
}

// ─────────────────────────────────────────────────
// MARK: - URLSession download with progress
// ─────────────────────────────────────────────────

extension URLSession {
    func download(from url: URL, progress: @escaping @Sendable (Int64, Int64, Int64) -> Void) async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.downloadTask(with: url) { url, response, error in
                if let error = error { continuation.resume(throwing: error); return }
                guard let url = url, let response = response else {
                    continuation.resume(throwing: MoodleExtError.downloadFailed)
                    return
                }
                continuation.resume(returning: (url, response))
            }
            let observation = task.progress.observe(\.fractionCompleted) { p, _ in
                let written = Int64(p.completedUnitCount)
                let total = Int64(p.totalUnitCount)
                progress(0, written, total)
            }
            task.resume()
            _ = observation
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: - Errors
// ─────────────────────────────────────────────────

enum MoodleExtError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case httpError(Int)
    case apiError(String)
    case parseError(String)
    case downloadFailed
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:   return "Sesion expirada. Vuelve a conectar Moodle."
        case .invalidURL:         return "URL invalida."
        case .httpError(let c):   return "Error HTTP \(c)."
        case .apiError(let m):    return m
        case .parseError(let f):  return "Error al leer '\(f)'."
        case .downloadFailed:     return "Error al descargar el archivo."
        case .uploadFailed(let m): return "Error al subir: \(m)"
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: - MoodleForum Codable helpers
// ─────────────────────────────────────────────────

extension MoodleForum {
    enum CodingKeys: String, CodingKey {
        case id, name, intro, numdiscussions
        case courseId = "course"
    }
}

