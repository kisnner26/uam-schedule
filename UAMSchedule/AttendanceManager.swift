import Foundation
import SwiftUI

// MARK: - Attendance Models

public struct AttendanceRecord: Identifiable, Codable, Hashable {
    public var id: UUID
    public var courseId: UUID
    public var sessionWeekday: Int
    public var date: Date
    public var status: AttendanceStatus

    public init(id: UUID = UUID(), courseId: UUID, sessionWeekday: Int, date: Date = Date(), status: AttendanceStatus) {
        self.id = id; self.courseId = courseId; self.sessionWeekday = sessionWeekday
        self.date = date; self.status = status
    }
}

public enum AttendanceStatus: String, Codable, CaseIterable {
    case present = "Presente"
    case absent = "Falta"
    case late = "Tardanza"
    case justified = "Justificada"

    public var icon: String {
        switch self {
        case .present: return "checkmark.circle.fill"
        case .absent: return "xmark.circle.fill"
        case .late: return "clock.badge.exclamationmark.fill"
        case .justified: return "doc.badge.checkmark.fill"
        }
    }

    public var color: String {
        switch self {
        case .present: return "#1A5C3A"
        case .absent: return "#CC1A1A"
        case .late: return "#6B4A1A"
        case .justified: return "#1A3A6B"
        }
    }
}

// MARK: - Attendance Store

class AttendanceStore: ObservableObject {
    static let key = "uam_attendance"
    @Published var records: [AttendanceRecord] = []

    init() { load() }

    /// Recarga desde App Group UserDefaults — llamar al entrar al foreground
    /// para que los cambios hechos desde el widget sean visibles en la app.
    func reload() { load() }

    func load() {
        let d = ScheduleStore.groupDefaults
        if let data = d.data(forKey: Self.key),
           let decoded = try? Self.makeDecoder().decode([AttendanceRecord].self, from: data) {
            records = decoded
        }
    }

    func save() {
        let d = ScheduleStore.groupDefaults
        if let encoded = try? Self.makeEncoder().encode(records) {
            d.set(encoded, forKey: Self.key)
            d.synchronize()
        }
    }

    // Bug 4 fix: alinear dateEncodingStrategy con el widget (EndClassIntent usa Unix epoch).
    // JSONEncoder/Decoder default usa epoch 2001 (Apple Reference Date), el widget
    // escribe con timeIntervalSince1970. Ambos lados deben usar .secondsSince1970.
    private static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }
    private static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }

    func mark(courseId: UUID, sessionWeekday: Int, status: AttendanceStatus) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Remove existing record for today + this course
        records.removeAll { r in
            r.courseId == courseId && r.sessionWeekday == sessionWeekday && cal.isDate(r.date, inSameDayAs: today)
        }
        let record = AttendanceRecord(courseId: courseId, sessionWeekday: sessionWeekday, status: status)
        records.append(record)
        save()
        // Feedback aligned with the kind of mark.
        switch status {
        case .present, .justified: Soft.haptic(.success); Soft.sound(.attendance)
        case .late:                Soft.haptic(.warning); Soft.sound(.toggle)
        case .absent:              Soft.haptic(.error);   Soft.sound(.error)
        }
    }

    func statusToday(courseId: UUID, sessionWeekday: Int) -> AttendanceStatus? {
        let cal = Calendar.current
        return records.first { r in
            r.courseId == courseId && r.sessionWeekday == sessionWeekday && cal.isDateInToday(r.date)
        }?.status
    }

    func stats(courseId: UUID, totalSessions: Int) -> AttendanceStats {
        let courseRecords = records.filter { $0.courseId == courseId }
        let present = courseRecords.filter { $0.status == .present || $0.status == .late || $0.status == .justified }.count
        let absent = courseRecords.filter { $0.status == .absent }.count
        let totalMarked = courseRecords.count
        return AttendanceStats(
            present: present, absent: absent, totalMarked: totalMarked,
            totalSessions: totalSessions
        )
    }
}

struct AttendanceStats {
    let present: Int
    let absent: Int
    let totalMarked: Int
    let totalSessions: Int // estimated: 18 weeks * sessions per week

    // 18 weeks total, max 20% absences
    var maxAbsences: Int { max(1, Int(Double(totalSessions) * 0.20)) }
    var absencesLeft: Int { max(0, maxAbsences - absent) }
    var attendanceRate: Double { totalMarked > 0 ? Double(present) / Double(totalMarked) : 1.0 }
    var isAtRisk: Bool { absent >= maxAbsences - 1 }
    var isFailed: Bool { absent >= maxAbsences }

    var progressLabel: String { "\(present)/\(totalMarked) clases" }
    var riskLabel: String {
        if isFailed { return "REPROBADO POR FALTAS" }
        if isAtRisk { return "EN RIESGO (\(absencesLeft) falta\(absencesLeft == 1 ? "" : "s") restante)" }
        return "\(absencesLeft) faltas disponibles"
    }
}
