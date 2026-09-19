import Foundation
import SwiftUI

// MARK: - Course

public struct Course: Identifiable, Codable, Hashable {
    public var id: UUID
    public var code: String
    public var name: String
    public var room: String
    public var credits: Int
    public var group: String
    public var color: String
    public var sessions: [ClassSession]
    public var isFavorite: Bool
    public var section: String
    public var reminders: [CourseReminder]
    public var checklist: [ChecklistItem]
    public var flashcards: [Flashcard]
    public var grades: GradeRecord
    public var moodleCourseId: Int? = nil

    public init(id: UUID = UUID(), code: String = "", name: String, room: String,
                credits: Int = 3, group: String = "G1", color: String = "#6B1A2A",
                sessions: [ClassSession] = [], isFavorite: Bool = false, section: String = "",
                reminders: [CourseReminder] = [], checklist: [ChecklistItem] = [],
                flashcards: [Flashcard] = [], grades: GradeRecord = GradeRecord(),
                moodleCourseId: Int? = nil) {
        self.id = id; self.code = code; self.name = name; self.room = room
        self.credits = credits; self.group = group; self.color = color
        self.sessions = sessions; self.isFavorite = isFavorite; self.section = section
        self.reminders = reminders; self.checklist = checklist
        self.flashcards = flashcards; self.grades = grades
        self.moodleCourseId = moodleCourseId
    }

    public var shortName: String {
        let w = name.split(separator: " ")
        return w.count >= 2 ? w.prefix(3).joined(separator: " ") : name
    }

    public var checklistProgress: Double {
        guard !checklist.isEmpty else { return 0 }
        return Double(checklist.filter { $0.isDone }.count) / Double(checklist.count)
    }

    public var totalGrade: Double { grades.corte1 + grades.corte2 + grades.corte3 }
    public var isPassing: Bool { totalGrade >= 210 }
    public var neededToPass: Double { max(0, 210 - totalGrade) }
}

// MARK: - ClassSession

public struct ClassSession: Identifiable, Codable, Hashable {
    public var id: UUID
    public var weekday: Int
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int
    public var room: String

    public init(id: UUID = UUID(), weekday: Int, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, room: String = "") {
        self.id = id; self.weekday = weekday
        self.startHour = startHour; self.startMinute = startMinute
        self.endHour = endHour; self.endMinute = endMinute
        self.room = room
    }

    public var startTimeString: String {
        let h = startHour > 12 ? startHour - 12 : (startHour == 0 ? 12 : startHour)
        return String(format: "%d:%02d %@", h, startMinute, startHour >= 12 ? "PM" : "AM")
    }
    public var endTimeString: String {
        let h = endHour > 12 ? endHour - 12 : (endHour == 0 ? 12 : endHour)
        return String(format: "%d:%02d %@", h, endMinute, endHour >= 12 ? "PM" : "AM")
    }
    public var durationMinutes: Int { (endHour * 60 + endMinute) - (startHour * 60 + startMinute) }
}

// MARK: - Reminder

public struct CourseReminder: Identifiable, Codable, Hashable {
    public var id: UUID
    public var title: String
    public var dueDate: Date
    public var priority: ReminderPriority
    public var isDone: Bool
    public var notes: String

    public init(id: UUID = UUID(), title: String, dueDate: Date = Date(), priority: ReminderPriority = .medium, isDone: Bool = false, notes: String = "") {
        self.id = id; self.title = title; self.dueDate = dueDate
        self.priority = priority; self.isDone = isDone; self.notes = notes
    }

    public var isOverdue: Bool { !isDone && dueDate < Date() }
    public var isDueSoon: Bool { !isDone && dueDate.timeIntervalSinceNow < 86400 && dueDate > Date() }
}

public enum ReminderPriority: String, Codable, CaseIterable, Hashable {
    case low = "Baja"
    case medium = "Media"
    case high = "Alta"
    case urgent = "Urgente"

    public var color: String {
        switch self {
        case .low: return "#1A5C3A"
        case .medium: return "#6B4A1A"
        case .high: return "#6B1A2A"
        case .urgent: return "#CC1A1A"
        }
    }
    public var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }
}

// MARK: - Checklist

public struct ChecklistItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var text: String
    public var isDone: Bool

    public init(id: UUID = UUID(), text: String, isDone: Bool = false) {
        self.id = id; self.text = text; self.isDone = isDone
    }
}

// MARK: - Flashcard

public struct Flashcard: Identifiable, Codable, Hashable {
    public var id: UUID
    public var question: String
    public var answer: String

    public init(id: UUID = UUID(), question: String, answer: String = "") {
        self.id = id; self.question = question; self.answer = answer
    }
}

// MARK: - Grades

public struct GradeRecord: Codable, Hashable {
    public var corte1: Double
    public var corte2: Double
    public var corte3: Double

    public init(corte1: Double = 0, corte2: Double = 0, corte3: Double = 0) {
        self.corte1 = corte1; self.corte2 = corte2; self.corte3 = corte3
    }

    public var total: Double { corte1 + corte2 + corte3 }
    public var average: Double { total / 3.0 }
    public var isPassing: Bool { total >= 210 }
}

// MARK: - Mood Tracker

public struct MoodEntry: Identifiable, Codable, Hashable {
    public var id: UUID
    public var date: Date
    public var mood: MoodLevel
    public var note: String

    public init(id: UUID = UUID(), date: Date = Date(), mood: MoodLevel, note: String = "") {
        self.id = id; self.date = date; self.mood = mood; self.note = note
    }
}

public enum MoodLevel: Int, Codable, CaseIterable, Hashable {
    case terrible = 1, bad = 2, meh = 3, good = 4, great = 5

    public var emoji: String {
        switch self { case .terrible: return "😩"; case .bad: return "😔"; case .meh: return "😐"; case .good: return "😊"; case .great: return "🔥" }
    }
    public var label: String {
        switch self { case .terrible: return "Terrible"; case .bad: return "Mal"; case .meh: return "Regular"; case .good: return "Bien"; case .great: return "Excelente" }
    }
    public var color: String {
        switch self { case .terrible: return "#CC1A1A"; case .bad: return "#6B4A1A"; case .meh: return "#6B6B6B"; case .good: return "#1A5C3A"; case .great: return "#6B1A2A" }
    }
}

// MARK: - Schedule Store

public class ScheduleStore: ObservableObject {
    public static let appGroupID = "group.com.kisnner.uamschedule"
    public static let coursesKey = "uam_courses"

    /// Wrapper seguro — cae a .standard si el App Group no está disponible
    /// (simulador sin entitlement firmado, extensiones sin configuración).
    /// Elimina el crash: CFPrefs kCFPreferencesAnyUser with a container.
    public static var groupDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
    public static let moodKey = "uam_mood"

    /// Shared instance used by background timers (LiveActivityManager refresh ticker).
    /// The main app uses its own @StateObject; this shared one is read-only-from-disk
    /// for purposes of background reasoning. Calling load() on it picks up changes
    /// written by the app via the App Group UserDefaults.
    nonisolated(unsafe) public static let shared: ScheduleStore = ScheduleStore()

    @Published public var courses: [Course] = []
    @Published public var moodEntries: [MoodEntry] = []

    public init() { load(); loadMood() }

    public func load() {
        let d = Self.groupDefaults
        if let data = d.data(forKey: Self.coursesKey),
           let decoded = try? JSONDecoder().decode([Course].self, from: data) { courses = decoded }
        else { courses = [] }
    }

    public func save() {
        let d = Self.groupDefaults
        if let encoded = try? JSONEncoder().encode(courses) { d.set(encoded, forKey: Self.coursesKey) }
    }

    public func loadMood() {
        let d = Self.groupDefaults
        if let data = d.data(forKey: Self.moodKey),
           let decoded = try? JSONDecoder().decode([MoodEntry].self, from: data) { moodEntries = decoded }
    }

    public func saveMood() {
        let d = Self.groupDefaults
        if let encoded = try? JSONEncoder().encode(moodEntries) { d.set(encoded, forKey: Self.moodKey) }
    }

    public func addMood(_ mood: MoodEntry) { moodEntries.append(mood); saveMood() }

    public func todayMood() -> MoodEntry? {
        let cal = Calendar.current
        return moodEntries.first { cal.isDateInToday($0.date) }
    }

    public func addCourse(_ c: Course) { courses.append(c); save() }
    public func deleteCourse(_ c: Course) { courses.removeAll { $0.id == c.id }; save() }
    public func toggleFavorite(_ c: Course) {
        if let i = courses.firstIndex(where: { $0.id == c.id }) {
            courses[i].isFavorite.toggle()
            save()
            Soft.haptic(courses[i].isFavorite ? .medium : .selection)
            if courses[i].isFavorite { Soft.sound(.select) }
        }
    }

    // Reminders
    public func addReminder(to courseId: UUID, reminder: CourseReminder) {
        if let i = courses.firstIndex(where: { $0.id == courseId }) { courses[i].reminders.append(reminder); save() }
    }
    public func toggleReminder(courseId: UUID, reminderId: UUID) {
        if let ci = courses.firstIndex(where: { $0.id == courseId }),
           let ri = courses[ci].reminders.firstIndex(where: { $0.id == reminderId }) {
            courses[ci].reminders[ri].isDone.toggle()
            save()
            if courses[ci].reminders[ri].isDone {
                Soft.haptic(.success); Soft.sound(.checklist)
            } else {
                Soft.haptic(.selection)
            }
        }
    }
    public func deleteReminder(courseId: UUID, reminderId: UUID) {
        if let ci = courses.firstIndex(where: { $0.id == courseId }) {
            courses[ci].reminders.removeAll { $0.id == reminderId }; save()
        }
    }

    // Checklist
    public func addChecklistItem(to courseId: UUID, item: ChecklistItem) {
        if let i = courses.firstIndex(where: { $0.id == courseId }) { courses[i].checklist.append(item); save() }
    }
    public func toggleChecklistItem(courseId: UUID, itemId: UUID) {
        if let ci = courses.firstIndex(where: { $0.id == courseId }),
           let ii = courses[ci].checklist.firstIndex(where: { $0.id == itemId }) {
            courses[ci].checklist[ii].isDone.toggle()
            save()
            if courses[ci].checklist[ii].isDone {
                Soft.haptic(.success); Soft.sound(.checklist)
            } else {
                Soft.haptic(.selection)
            }
        }
    }

    // Flashcards
    public func addFlashcard(to courseId: UUID, card: Flashcard) {
        if let i = courses.firstIndex(where: { $0.id == courseId }) { courses[i].flashcards.append(card); save() }
    }

    // Grades
    public func updateGrades(courseId: UUID, grades: GradeRecord) {
        if let i = courses.firstIndex(where: { $0.id == courseId }) { courses[i].grades = grades; save() }
    }

    // Upcoming reminders across all courses
    public func upcomingReminders() -> [(course: Course, reminder: CourseReminder)] {
        var result: [(Course, CourseReminder)] = []
        for c in courses { for r in c.reminders where !r.isDone { result.append((c, r)) } }
        return result.sorted { $0.1.dueDate < $1.1.dueDate }
    }

    public func todayClasses() -> [(course: Course, session: ClassSession)] {
        let weekday = Calendar.current.component(.weekday, from: Date())
        var r: [(Course, ClassSession)] = []
        for c in courses { for s in c.sessions where s.weekday == weekday { r.append((c, s)) } }
        return r.sorted { $0.1.startHour * 60 + $0.1.startMinute < $1.1.startHour * 60 + $1.1.startMinute }
    }

    public func nextClass() -> (course: Course, session: ClassSession)? {
        let cal = Calendar.current
        let nowMin = cal.component(.hour, from: Date()) * 60 + cal.component(.minute, from: Date())
        let weekday = cal.component(.weekday, from: Date())
        // Busca hoy: la proxima clase que aun no ha terminado, ordenada por inicio
        let todayUpcoming = todayClasses().filter { $0.session.startHour * 60 + $0.session.startMinute > nowMin }
        if let next = todayUpcoming.first { return next }
        // Busca la clase actualmente en curso
        let inProgress = todayClasses().filter { nowMin >= $0.session.startHour * 60 + $0.session.startMinute && nowMin <= $0.session.endHour * 60 + $0.session.endMinute }
        if let cur = inProgress.first { return cur }
        // Busca los proximos dias ordenado por hora de inicio
        for d in 1...7 {
            let fwd = ((weekday - 1 + d) % 7) + 1
            var s: [(Course, ClassSession)] = []
            for c in courses { for ss in c.sessions where ss.weekday == fwd { s.append((c, ss)) } }
            let sorted = s.sorted { $0.1.startHour * 60 + $0.1.startMinute < $1.1.startHour * 60 + $1.1.startMinute }
            if let first = sorted.first { return first }
        }
        return nil
    }

    public func currentClass() -> (course: Course, session: ClassSession)? {
        let cal = Calendar.current; let nowMin = cal.component(.hour, from: Date()) * 60 + cal.component(.minute, from: Date())
        let weekday = cal.component(.weekday, from: Date())
        for c in courses { for s in c.sessions where s.weekday == weekday {
            if nowMin >= s.startHour * 60 + s.startMinute && nowMin <= s.endHour * 60 + s.endMinute { return (c, s) }
        }}
        return nil
    }
}

// MARK: - Course Photo Store

public struct CoursePhotoStore {
    public static func save(_ data: Data, for courseId: UUID) {
        UserDefaults.standard.set(data, forKey: "course_photo_\(courseId.uuidString)")
    }
    public static func load(for courseId: UUID) -> UIImage? {
        guard let data = UserDefaults.standard.data(forKey: "course_photo_\(courseId.uuidString)") else { return nil }
        return UIImage(data: data)
    }
    public static func delete(for courseId: UUID) {
        UserDefaults.standard.removeObject(forKey: "course_photo_\(courseId.uuidString)")
    }
    public static func hasPhoto(for courseId: UUID) -> Bool {
        return UserDefaults.standard.data(forKey: "course_photo_\(courseId.uuidString)") != nil
    }
}

// MARK: - Preview Helpers
// Bug fix: .preview static properties were missing, causing MoodleTodaySection
// preview to fail to compile.

extension ScheduleStore {
    static var preview: ScheduleStore {
        let s = ScheduleStore()
        s.courses = [
            Course(code: "IS101", name: "Ingeniería de Software I", room: "A-201",
                   credits: 4, color: "#6B1A2A",
                   sessions: [ClassSession(weekday: 2, startHour: 8, startMinute: 0, endHour: 10, endMinute: 0)]),
            Course(code: "BD301", name: "Base de Datos III", room: "B-104",
                   credits: 3, color: "#1A3A6B",
                   sessions: [ClassSession(weekday: 3, startHour: 10, startMinute: 0, endHour: 12, endMinute: 0)]),
        ]
        return s
    }
}
