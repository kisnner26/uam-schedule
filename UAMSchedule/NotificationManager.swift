import UserNotifications
import Foundation
import WidgetKit

// MARK: - Notification category identifiers
extension Notification.Name {
    static let attendanceMarked  = Notification.Name("uam.attendanceMarked")
    static let moodleMessageTap  = Notification.Name("uam.moodleMessageTap")
    static let moodleNotiTap     = Notification.Name("uam.moodleNotiTap")
    static let classEnded = Notification.Name("uam.classEnded")
}

@preconcurrency
final class NotificationManager: @unchecked Sendable {
    @MainActor static let shared = NotificationManager()

    // Notification category IDs
    static let categoryClassStart        = "UAM_CLASS_START"
    static let categoryClassOngoing      = "UAM_CLASS_ONGOING"
    static let categoryMoodleMessage     = "UAM_MOODLE_MESSAGE"
    static let categoryMoodleNotification = "UAM_MOODLE_NOTIFICATION"

    // Moodle action IDs
    static let actionViewMessage = "UAM_MOODLE_VIEW_MSG"
    static let actionViewNoti    = "UAM_MOODLE_VIEW_NOTI"

    // Action IDs
    static let actionPresent     = "UAM_PRESENT"
    static let actionLate        = "UAM_LATE"
    static let actionAbsent      = "UAM_ABSENT"
    static let actionEndClass    = "UAM_END_CLASS"

    func requestPermission(completion: @escaping @MainActor (Bool) -> Void) {
        registerCategories()
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                Task { @MainActor in completion(granted) }
            }
    }

    // MARK: - Register interactive notification categories

    func registerCategories() {
        // Attendance actions for start-of-class notification
        let presentAction = UNNotificationAction(
            identifier: Self.actionPresent,
            title: "Presente",
            options: [.foreground]
        )
        let lateAction = UNNotificationAction(
            identifier: Self.actionLate,
            title: "Tarde",
            options: []
        )
        let absentAction = UNNotificationAction(
            identifier: Self.actionAbsent,
            title: "No asistí",
            options: [.destructive]
        )
        let endClassAction = UNNotificationAction(
            identifier: Self.actionEndClass,
            title: "Finalizar clase",
            options: [.destructive]
        )

        let startCategory = UNNotificationCategory(
            identifier: Self.categoryClassStart,
            actions: [presentAction, lateAction, absentAction],
            intentIdentifiers: [],
            options: []
        )
        let ongoingCategory = UNNotificationCategory(
            identifier: Self.categoryClassOngoing,
            actions: [presentAction, endClassAction],
            intentIdentifiers: [],
            options: []
        )

        let viewMsgAction = UNNotificationAction(
            identifier: Self.actionViewMessage,
            title: "Ver mensaje",
            options: [.foreground]
        )
        let moodleMsgCategory = UNNotificationCategory(
            identifier: Self.categoryMoodleMessage,
            actions: [viewMsgAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let viewNotiAction = UNNotificationAction(
            identifier: Self.actionViewNoti,
            title: "Ver aviso",
            options: [.foreground]
        )
        let moodleNotiCategory = UNNotificationCategory(
            identifier: Self.categoryMoodleNotification,
            actions: [viewNotiAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([
            startCategory, ongoingCategory, moodleMsgCategory, moodleNotiCategory
        ])
    }

    // MARK: - Schedule all class notifications

    func scheduleAll(courses: [Course]) {
        let center = UNUserNotificationCenter.current()
        registerCategories()
        // Bug fix: capture immutable copies to avoid Sendable warnings.
        // [Course] and UNUserNotificationCenter are not Sendable; we snapshot
        // courses into a local let and mark the closure nonisolated.
        let snapshot = courses
        center.getPendingNotificationRequests { [snapshot] requests in
            let ids = requests.filter { $0.identifier.hasPrefix("uam-") }.map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: ids)

            for course in snapshot {
                for session in course.sessions {
                    self.scheduleNotification(center: center, course: course, session: session, minutesBefore: 15)
                    self.scheduleNotification(center: center, course: course, session: session, minutesBefore: 5)
                    self.scheduleNotification(center: center, course: course, session: session, minutesBefore: 0)
                }
            }
        }
    }

    private func scheduleNotification(center: UNUserNotificationCenter, course: Course, session: ClassSession, minutesBefore: Int) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.interruptionLevel = minutesBefore == 0 ? .timeSensitive : .active

        let room = session.room.trimmingCharacters(in: .whitespaces).isEmpty ? course.room : session.room
        let sectionLabel = course.section.isEmpty ? room : "\(room) · Sec. \(course.section)"

        // Embed IDs for action handling
        content.userInfo = [
            "courseId": course.id.uuidString,
            "sessionWeekday": session.weekday,
            "courseName": course.name
        ]

        switch minutesBefore {
        case 0:
            content.title = "¡Clase comenzando!"
            content.body = "\(course.name) · \(sectionLabel)"
            content.subtitle = room
            content.categoryIdentifier = Self.categoryClassStart
        case 5:
            content.title = "Clase en 5 minutos"
            content.body = "\(course.name) · \(sectionLabel)"
            content.categoryIdentifier = Self.categoryClassOngoing
        default:
            content.title = "Clase en 15 minutos"
            content.body = "\(course.name) · \(sectionLabel)"
        }

        var hour = session.startHour
        var minute = session.startMinute - minutesBefore
        while minute < 0 { minute += 60; hour -= 1 }
        if hour < 0 { return }

        var components = DateComponents()
        components.weekday = session.weekday
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let id = "uam-\(course.id.uuidString)-\(session.id.uuidString)-\(minutesBefore)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request) { error in if let error { print("Notification error: \(error)") } }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix("uam-") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Handle notification actions
    // Called from AppDelegate / UAMScheduleApp scene phase

    @MainActor func handleAction(identifier: String, userInfo: [AnyHashable: Any], attendance: AttendanceStore) {
        // Moodle tap — no necesitan courseId
        switch identifier {
        case Self.actionViewMessage:
            NotificationCenter.default.post(name: .moodleMessageTap, object: nil)
            return
        case Self.actionViewNoti:
            NotificationCenter.default.post(name: .moodleNotiTap, object: nil)
            return
        default: break
        }

        guard let courseIdStr = userInfo["courseId"] as? String,
              let weekday = userInfo["sessionWeekday"] as? Int,
              let courseId = UUID(uuidString: courseIdStr) else { return }

        switch identifier {
        case Self.actionPresent:
            attendance.mark(courseId: courseId, sessionWeekday: weekday, status: .present)
            reloadWidgets()
        case Self.actionLate:
            attendance.mark(courseId: courseId, sessionWeekday: weekday, status: .late)
            reloadWidgets()
        case Self.actionAbsent:
            attendance.mark(courseId: courseId, sessionWeekday: weekday, status: .absent)
            reloadWidgets()
        case Self.actionEndClass:
            LiveActivityManager.shared.endActivity()
            reloadWidgets()
            // Post notification so TodayView can react
            NotificationCenter.default.post(name: .classEnded, object: courseIdStr)
        default:
            break
        }
    }

    func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Reminder notifications (unchanged)

    func scheduleReminder(_ reminder: CourseReminder, for course: Course) {
        let content = UNMutableNotificationContent()
        content.title = "Recordatorio: \(course.name)"
        content.body = reminder.title
        content.sound = .default
        content.interruptionLevel = reminder.priority == .urgent ? .timeSensitive : .active

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "uam-reminder-\(reminder.id.uuidString)", content: content, trigger: trigger)
        )

        if reminder.priority == .high || reminder.priority == .urgent,
           let earlyDate = Calendar.current.date(byAdding: .hour, value: -1, to: reminder.dueDate),
           earlyDate > Date() {
            let earlyContent = UNMutableNotificationContent()
            earlyContent.title = "Tarea en 1 hora"
            earlyContent.body = "\(course.name): \(reminder.title)"
            earlyContent.sound = .default
            earlyContent.interruptionLevel = .timeSensitive
            let earlyComps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: earlyDate)
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "uam-reminder-early-\(reminder.id.uuidString)",
                                     content: earlyContent,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: earlyComps, repeats: false))
            )
        }
    }

    func cancelReminder(_ reminderId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "uam-reminder-\(reminderId.uuidString)",
            "uam-reminder-early-\(reminderId.uuidString)"
        ])
    }
}
