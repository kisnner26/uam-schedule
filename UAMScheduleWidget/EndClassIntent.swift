import AppIntents
import ActivityKit
import WidgetKit
import Foundation

// MARK: - End Class Intent

struct EndClassIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Finalizar clase"
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        for activity in Activity<ClassActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Mark Present Intent

struct MarkPresentIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Marcar presente"
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Course ID") var courseID: String
    @Parameter(title: "Weekday")   var weekday: Int

    func perform() async throws -> some IntentResult {
        markAttendance(courseID: courseID, weekday: weekday, status: "Presente")
        await tryMoodleAttendance(courseID: courseID, status: "Presente")
        await updateActivityMark(courseID: courseID, mark: "Presente")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Mark Late Intent

struct MarkLateIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Marcar tarde"
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Course ID") var courseID: String
    @Parameter(title: "Weekday")   var weekday: Int

    func perform() async throws -> some IntentResult {
        markAttendance(courseID: courseID, weekday: weekday, status: "Tardanza")
        await tryMoodleAttendance(courseID: courseID, status: "Tardanza")
        await updateActivityMark(courseID: courseID, mark: "Tardanza")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Mark Absent Intent

struct MarkAbsentIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Marcar ausente"
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Course ID") var courseID: String
    @Parameter(title: "Weekday")   var weekday: Int

    func perform() async throws -> some IntentResult {
        markAttendance(courseID: courseID, weekday: weekday, status: "Falta")
        await tryMoodleAttendance(courseID: courseID, status: "Falta")
        await updateActivityMark(courseID: courseID, mark: "Falta")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Update Live Activity state (feedback visual)

@MainActor
private func updateActivityMark(courseID: String, mark: String) async {
    for activity in Activity<ClassActivityAttributes>.activities
        where activity.attributes.courseID == courseID {
        var state = activity.content.state
        state.attendanceMark = mark
        let content = ActivityContent(state: state, staleDate: nil)
        await activity.update(content)
    }
}

// MARK: - Moodle Attendance (best-effort)

private func tryMoodleAttendance(courseID: String, status: String) async {
    let defaults = UserDefaults(suiteName: "group.com.kisnner.uamschedule") ?? .standard
    guard let token = defaults.string(forKey: "moodle_token"), !token.isEmpty else { return }
    let statusCode: Int
    switch status {
    case "Presente": statusCode = 1
    case "Tardanza": statusCode = 3
    case "Falta":    statusCode = 2
    default:         statusCode = 1
    }
    let sessionKey = "moodle_attendance_session_\(courseID)"
    guard let sessionID = defaults.value(forKey: sessionKey) as? Int, sessionID > 0 else {
        var pending = defaults.array(forKey: "moodle_attendance_pending") as? [[String: Any]] ?? []
        pending.append(["courseID": courseID, "status": status,
                        "statusCode": statusCode, "date": Date().timeIntervalSince1970])
        defaults.set(pending, forKey: "moodle_attendance_pending")
        defaults.synchronize()
        return
    }
    let params = "wstoken=\(token)&wsfunction=mod_attendance_add_session_attendance&moodlewsrestformat=json&sessionid=\(sessionID)&statusid=\(statusCode)"
    guard let url = URL(string: "https://uamvirtual.uam.edu.ni/grado/webservice/rest/server.php") else { return }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    req.httpBody = params.data(using: .utf8)
    req.timeoutInterval = 10
    _ = try? await URLSession.shared.data(for: req)
}

// MARK: - Local attendance writer

private struct AttendanceRecordDTO: Codable {
    var id: String; var courseId: String; var sessionWeekday: Int
    var date: Double; var status: String
}

private func markAttendance(courseID: String, weekday: Int, status: String) {
    guard UUID(uuidString: courseID) != nil else { return }
    let defaults = UserDefaults(suiteName: "group.com.kisnner.uamschedule") ?? .standard
    let key = "uam_attendance"
    var records: [AttendanceRecordDTO] = []
    if let data = defaults.data(forKey: key) {
        if let decoded = try? makeDecoder().decode([AttendanceRecordDTO].self, from: data) {
            records = decoded
        } else if let legacy = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            records = legacy.compactMap { r in
                guard let cid = r["courseId"] as? String, let wd = r["sessionWeekday"] as? Int,
                      let ts = r["date"] as? Double, let st = r["status"] as? String,
                      let rid = r["id"] as? String else { return nil }
                return AttendanceRecordDTO(id: rid, courseId: cid, sessionWeekday: wd, date: ts, status: st)
            }
        }
    }
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date()).timeIntervalSince1970
    records.removeAll { r in
        let rd = cal.startOfDay(for: Date(timeIntervalSince1970: r.date)).timeIntervalSince1970
        return r.courseId == courseID && r.sessionWeekday == weekday && abs(rd - today) < 1
    }
    records.append(AttendanceRecordDTO(id: UUID().uuidString, courseId: courseID,
                                       sessionWeekday: weekday, date: Date().timeIntervalSince1970,
                                       status: status))
    if let data = try? makeEncoder().encode(records) {
        defaults.set(data, forKey: key); defaults.synchronize()
    }
}

private func makeDecoder() -> JSONDecoder {
    let d = JSONDecoder(); d.dateDecodingStrategy = .secondsSince1970; return d
}
private func makeEncoder() -> JSONEncoder {
    let e = JSONEncoder(); e.dateEncodingStrategy = .secondsSince1970; return e
}

