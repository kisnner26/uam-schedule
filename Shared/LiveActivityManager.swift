import Foundation
import ActivityKit
import Combine

// MARK: - Activity Attributes (shared between app and widget)

public struct ClassActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var courseName: String
        public var courseCode: String
        public var room: String
        public var section: String
        public var colorHex: String
        public var startTime: Date
        public var endTime: Date
        public var progressPercent: Double
        /// nil = sin marcar. "Presente", "Tardanza", "Falta"
        public var attendanceMark: String? = nil

        public var minutesLeft: Int {
            max(0, Int(endTime.timeIntervalSinceNow / 60))
        }
    }
    public var courseID: String
    public init(courseID: String) { self.courseID = courseID }
}

// MARK: - Manager
// Rewritten to fix:
// - Bug A: state recovery on cold launch (rehydrate currentActivity from Activity<>.activities)
// - Bug B: external dismissal awareness (observe activityStateUpdates)
// - Bug C: smart mode never refreshed the progress of an active activity (only start/stop)
// - Bug D: smart mode only fired on foreground; now also driven by 60s ticker while active
// - Bug E: published flag so SwiftUI views can bind reactively
// - Bug F: previously the manager was a plain class; now it's an ObservableObject

@MainActor
public final class LiveActivityManager: ObservableObject {
    public static let shared = LiveActivityManager()

    /// Whether an activity is currently live. SwiftUI views can observe this.
    @Published public private(set) var isActive: Bool = false

    /// The course currently shown in the Dynamic Island, if any.
    @Published public private(set) var activeCourseID: String? = nil

    private var currentActivity: Activity<ClassActivityAttributes>?
    private var observationTask: Task<Void, Never>?
    nonisolated(unsafe) private var refreshTimer: Timer?

    private init() {
        rehydrateFromSystem()
        startRefreshTicker()
    }

    // MARK: - Permission

    /// Whether ActivityKit is permitted on this device for this app.
    /// This is `false` if the user disabled Live Activities in Settings,
    /// or if `NSSupportsLiveActivities` is missing from the Info.plist.
    public var areActivitiesPermitted: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Rehydrate on cold launch

    /// Reconnect to any live activity already running on the system. Without this,
    /// after a process relaunch the manager would think nothing is active.
    public func rehydrateFromSystem() {
        for activity in Activity<ClassActivityAttributes>.activities {
            if activity.content.state.endTime > Date() {
                self.attach(activity)
                return
            }
        }
        self.detach()
    }

    private func attach(_ activity: Activity<ClassActivityAttributes>) {
        currentActivity = activity
        isActive = true
        activeCourseID = activity.attributes.courseID
        observationTask?.cancel()
        // Capture only Sendable primitives before entering the Task.
        let courseID = activity.attributes.courseID
        let updates = activity.activityStateUpdates
        observationTask = Task { [weak self] in
            for await state in updates {
                guard let self else { return }
                switch state {
                case .active:
                    await MainActor.run {
                        self.isActive = true
                        self.activeCourseID = courseID
                    }
                case .ended, .dismissed, .stale:
                    await MainActor.run { self.detach() }
                @unknown default:
                    break
                }
            }
        }
    }

    private func detach() {
        currentActivity = nil
        isActive = false
        activeCourseID = nil
        observationTask?.cancel()
        observationTask = nil
    }

    // MARK: - End existing

    public func endAllStale() {
        let activities = Activity<ClassActivityAttributes>.activities
        Task { [weak self] in
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            await MainActor.run { self?.detach() }
        }
    }

    public func endActivity() {
        guard let activity = currentActivity else {
            endAllStale()
            return
        }
        Task { [weak self] in
            await activity.end(nil, dismissalPolicy: .immediate)
            await MainActor.run { self?.detach() }
        }
    }

    // MARK: - Start

    public func startActivity(for course: Course, session: ClassSession) {
        guard areActivitiesPermitted else {
            print("LiveActivity: not permitted")
            return
        }

        let (startDate, endDate) = Self.computeSessionDates(for: session)
        let now = Date().timeIntervalSince1970
        let duration = max(endDate.timeIntervalSince1970 - startDate.timeIntervalSince1970, 1)
        let progress = max(0, min(1, (now - startDate.timeIntervalSince1970) / duration))

        let resolvedRoom = session.room.trimmingCharacters(in: .whitespaces).isEmpty
            ? course.room
            : session.room

        let state = ClassActivityAttributes.ContentState(
            courseName: course.name,
            courseCode: course.code,
            room: resolvedRoom,
            section: course.section,
            colorHex: course.color,
            startTime: startDate,
            endTime: endDate,
            progressPercent: progress,
            attendanceMark: nil
        )

        let attributes = ClassActivityAttributes(courseID: course.id.uuidString)

        let attrs = attributes
        let contentState = state
        let stale = endDate
        // Tear down existing in its own Task (capturing only the activity ref,
        // which is fine because it's not crossing back to self).
        if let existing = currentActivity {
            detach()
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
        }
        // Now request a new activity. Activity.request is synchronous and
        // we are already on MainActor, so no Task needed.
        do {
            let activity = try Activity.request(
                attributes: attrs,
                content: .init(state: contentState, staleDate: stale),
                pushType: nil
            )
            attach(activity)
        } catch {
            print("LiveActivity start error: \(error)")
        }
    }

    // MARK: - Update progress of the live activity

    public func tickProgress(store: ScheduleStore) {
        guard let activity = currentActivity else { return }
        guard let courseUUID = UUID(uuidString: activity.attributes.courseID),
              let course = store.courses.first(where: { $0.id == courseUUID }) else {
            endActivity()
            return
        }

        let now = Date()
        let endTime = activity.content.state.endTime
        let startTime = activity.content.state.startTime

        if now >= endTime {
            endActivity()
            return
        }

        let duration = max(endTime.timeIntervalSince(startTime), 1)
        let progress = max(0, min(1, now.timeIntervalSince(startTime) / duration))

        var newState = activity.content.state
        newState.progressPercent = progress
        newState.courseName = course.name
        newState.colorHex = course.color
        newState.section = course.section
        if newState.room.isEmpty { newState.room = course.room }

        let stateToSend = newState
        let endDate = endTime
        Task {
            await activity.update(ActivityContent(state: stateToSend, staleDate: endDate))
        }
    }

    // MARK: - Smart Mode (auto-start before class)

    public func checkAndAutoStart(store: ScheduleStore) {
        let smartMode = UserDefaults.standard.bool(forKey: "liveActivity_smartMode")
        guard smartMode, areActivitiesPermitted else { return }

        let cal = Calendar.current
        let now = Date()
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let weekday = cal.component(.weekday, from: now)

        var desired: (Course, ClassSession)? = nil
        for course in store.courses {
            for session in course.sessions where session.weekday == weekday {
                let startMinutes = session.startHour * 60 + session.startMinute
                let endMinutes   = session.endHour   * 60 + session.endMinute
                let minutesUntil = startMinutes - nowMinutes
                let inWindow = (minutesUntil >= 0 && minutesUntil <= 15) || (nowMinutes >= startMinutes && nowMinutes <= endMinutes)
                if inWindow {
                    desired = (course, session)
                    break
                }
            }
            if desired != nil { break }
        }

        if let (course, session) = desired {
            if let active = currentActivity, active.attributes.courseID == course.id.uuidString {
                tickProgress(store: store)
            } else {
                startActivity(for: course, session: session)
            }
        } else {
            if currentActivity != nil {
                endActivity()
            }
        }
    }

    // MARK: - Refresh ticker
    // 60s timer that pushes progress updates and re-runs smart mode.

    private func startRefreshTicker() {
        refreshTimer?.invalidate()
        // Timer fires on the main run loop (we are on MainActor).
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { _ in }
        // Replace with a proper recurring main-actor-bound timer.
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let store = ScheduleStore.shared
                store.load()
                if self.currentActivity != nil {
                    self.tickProgress(store: store)
                }
                self.checkAndAutoStart(store: store)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    deinit {
        refreshTimer?.invalidate()
        observationTask?.cancel()
    }

    // MARK: - Helper

    private static func computeSessionDates(for session: ClassSession) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let today = Date()
        let todayWeekday = cal.component(.weekday, from: today)
        var daysAhead = (session.weekday - todayWeekday + 7) % 7
        if daysAhead == 0 {
            let nowMinutes = cal.component(.hour, from: today) * 60 + cal.component(.minute, from: today)
            let endMinutes = session.endHour * 60 + session.endMinute
            if nowMinutes > endMinutes { daysAhead = 7 }
        }
        let sessionDate = cal.date(byAdding: .day, value: daysAhead, to: today) ?? today

        var startC = cal.dateComponents([.year, .month, .day], from: sessionDate)
        startC.hour = session.startHour; startC.minute = session.startMinute; startC.second = 0
        let startDate = cal.date(from: startC) ?? today

        var endC = cal.dateComponents([.year, .month, .day], from: sessionDate)
        endC.hour = session.endHour; endC.minute = session.endMinute; endC.second = 0
        let endDate = cal.date(from: endC) ?? today
        return (startDate, endDate)
    }
}
