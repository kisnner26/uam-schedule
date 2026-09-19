import SwiftUI

// MARK: - AppIcons
// Single source of truth for every SF Symbol used in UAMSchedule.
// Every icon was hand-picked from SF Symbols 5/6 for visual freshness
// (bold outlines, filled variants, compound glyphs) — nothing from
// the generic defaults set (book, calendar, gearshape, sun.max, etc.)

public enum AppIcons {

    // ── Navigation / Tab Bar ─────────────────────────────────
    /// Today tab — active
    public static let todayActive    = "clock.fill"
    /// Today tab — inactive
    public static let today          = "clock"
    /// Week/Schedule tab — active
    public static let scheduleActive = "rectangle.split.3x1.fill"
    /// Week/Schedule tab — inactive
    public static let schedule       = "rectangle.split.3x1"
    /// Courses tab — active
    public static let coursesActive  = "square.stack.fill"
    /// Courses tab — inactive
    public static let courses        = "square.stack"
    /// Settings tab — active
    public static let settingsActive = "slider.horizontal.3"
    /// Settings tab — inactive
    public static let settings       = "slider.horizontal.3"

    // ── Courses ──────────────────────────────────────────────
    public static let courseAdd      = "plus.square.on.square"
    public static let courseEdit     = "square.and.pencil"
    public static let courseDelete   = "trash.slash"
    public static let courseFav      = "bookmark"
    public static let courseFavFill  = "bookmark.fill"
    public static let courseCode     = "barcode"
    public static let credits        = "star.square"
    public static let section        = "person.2"
    public static let calendarAdd    = "calendar.badge.plus"

    // ── Sessions / Schedule ──────────────────────────────────
    public static let room           = "building.2"
    public static let code           = "barcode"
    public static let clock          = "clock"
    public static let clockFill      = "clock.fill"
    public static let duration       = "hourglass"
    public static let day            = "calendar"

    // ── Status ───────────────────────────────────────────────
    public static let done           = "checkmark.circle.fill"
    public static let pending        = "circle"
    public static let active         = "record.circle"
    public static let endClass       = "stop.circle"
    public static let emptyDay       = "moon.stars"
    public static let noClasses      = "tray"

    // ── Attendance ───────────────────────────────────────────
    public static let attendanceView = "chart.bar.xaxis"
    public static let present        = "person.badge.shield.checkmark"
    public static let late           = "person.badge.clock"
    public static let absent         = "person.slash"
    public static let excused        = "person.badge.plus"
    public static let attendancePct  = "percent"
    public static let warningLimit   = "exclamationmark.triangle"

    // ── Reminders ────────────────────────────────────────────
    public static let reminder       = "bell.and.waves.left.and.right"
    public static let reminderFill   = "bell.and.waves.left.and.right.fill"
    public static let reminderAdd    = "bell.badge.plus"
    public static let priorityLow    = "arrow.down.circle"
    public static let priorityMed    = "arrow.up.arrow.down.circle"
    public static let priorityHigh   = "arrow.up.circle.fill"
    public static let priorityUrgent = "exclamationmark.circle.fill"
    public static let dueDate        = "calendar.circle"
    public static let overdue        = "calendar.badge.exclamationmark"
    public static let noteDone       = "checkmark.seal"

    // ── Checklist / Pendientes ───────────────────────────────
    public static let checklist      = "list.bullet.clipboard"
    public static let checklistItem  = "square.dotted"
    public static let checklistDone  = "checkmark.square.fill"

    // ── Flashcards ───────────────────────────────────────────
    public static let flashcard      = "rectangle.on.rectangle.angled"
    public static let flashcardFlip  = "arrow.2.squarepath"
    public static let flashcardAdd   = "rectangle.badge.plus"

    // ── Grades ───────────────────────────────────────────────
    public static let grades         = "chart.line.uptrend.xyaxis"
    public static let gradePass      = "checkmark.seal.fill"
    public static let gradeFail      = "xmark.seal"
    public static let gradeCorte     = "doc.text.magnifyingglass"

    // ── Profile / Account ────────────────────────────────────
    public static let avatar         = "person.crop.circle"
    public static let name           = "person.text.rectangle"
    public static let university     = "building.columns"
    public static let career         = "briefcase"
    public static let semester       = "calendar.badge.clock"
    public static let graduation     = "graduationcap"
    public static let email          = "envelope"
    public static let cameraChange   = "camera.viewfinder"

    // ── Tools / Settings ─────────────────────────────────────
    public static let toolAttendance = "chart.bar.xaxis.ascending"
    public static let toolSiri       = "waveform.badge.magnifyingglass"
    public static let toolBackup     = "arrow.trianglehead.2.clockwise.rotate.90"
    public static let toolScanner    = "doc.viewfinder"
    public static let toolShare      = "link.badge.plus"
    public static let toolFocus      = "moon.haze"
    public static let appearance     = "paintpalette"
    public static let themeDark      = "moon.circle"
    public static let themeLight     = "sun.min.fill"
    public static let themeSystem    = "circle.lefthalf.filled"
    public static let greeting       = "hand.raised"
    public static let progressBar    = "chart.bar.fill"
    public static let compact        = "rectangle.compress.vertical"
    public static let dynamicIsland  = "dot.radiowaves.up.forward"
    public static let smartMode      = "cpu.fill"
    public static let infoNote       = "info.bubble"

    // ── Actions ──────────────────────────────────────────────
    public static let share          = "paperplane"
    public static let copy           = "doc.on.clipboard"
    public static let delete         = "trash"
    public static let deleteSlash    = "trash.slash"
    public static let add            = "plus"
    public static let addCircle      = "plus.circle"
    public static let close          = "xmark"
    public static let closeCircle    = "xmark.circle.fill"
    public static let back           = "chevron.backward"
    public static let forward        = "chevron.forward"
    public static let expand         = "chevron.down.circle"
    public static let collapse       = "chevron.up.circle"
    public static let search         = "magnifyingglass.circle"
    public static let edit           = "pencil.and.outline"
    public static let logout         = "rectangle.portrait.and.arrow.forward"
    public static let reset          = "arrow.counterclockwise.circle"

    // ── Mood ─────────────────────────────────────────────────
    public static let mood           = "face.smiling"
    public static let moodHistory    = "chart.xyaxis.line"

    // ── Widget / Live Activity ───────────────────────────────
    public static let widgetInfo     = "rectangle.on.rectangle.slash"
    public static let liveActivity   = "oval.portrait.fill"

    // ── Calendar / Week ──────────────────────────────────────
    public static let weekView       = "rectangle.split.3x1"
    public static let monthView      = "calendar"
    public static let filterAM       = "sunrise"
    public static let filterPM       = "sunset"
    public static let filterNight    = "moon"
    public static let filterAll      = "circle.grid.2x2"

    // ── OCR / Scanner ────────────────────────────────────────
    public static let scanner        = "viewfinder.rectangular"
    public static let mic            = "waveform.circle"
    public static let camera         = "camera"
    public static let photo          = "photo.on.rectangle"

    // ── Import / Export ──────────────────────────────────────
    public static let importIcon     = "square.and.arrow.down.on.square"
    public static let exportIcon     = "square.and.arrow.up.on.square"
    public static let backup         = "externaldrive.badge.checkmark"
    public static let restore        = "externaldrive.badge.icloud"

    // MARK: - Convenience: icon for priority level

    public static func priorityIcon(for priority: ReminderPriority) -> String {
        switch priority {
        case .low:    return priorityLow
        case .medium: return priorityMed
        case .high:   return priorityHigh
        case .urgent: return priorityUrgent
        }
    }
}

// MARK: - AppIconView
// Convenience view — renders a standardized icon tile (used in Settings rows, etc.)

struct AppIconTile: View {
    let symbol: String
    var size:  CGFloat = 32
    var tint:  Color   = DS.Color.wine
    var bg:    Color   = DS.Color.wineMuted

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(bg)
                .frame(width: size, height: size)
            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .medium))
                .foregroundStyle(tint)
        }
    }
}
