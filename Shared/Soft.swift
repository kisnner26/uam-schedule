import Foundation
import AudioToolbox
import UIKit

// MARK: - Soft
// Unified sound + haptic facade. All UI feedback in the app should go through
// this so the user's Sound and Haptic toggles in Settings are respected.
//
// Design notes:
// - Reads UserDefaults synchronously so it works from any context (widgets/intents).
// - Sounds use AudioServices system sound IDs (no AVAudioSession reconfig needed).
// - Haptics use UIFeedbackGenerator which is the recommended modern API.
// - We never play during system silent if the user wants that; we DO use haptics
//   because they're independent of the ringer switch.

public enum Soft {

    // MARK: - Sound catalog
    // Curated mapping of editorial intents to SystemSoundIDs that exist on every
    // iOS device. Avoiding the loud ringer set; keeping it tasteful.

    public enum SoundEvent: UInt32 {
        // Tap-level micro feedback
        case tabSwitch    = 1104   // SMS sent — short tick
        case toggle       = 1306   // Mail received — soft click
        case select       = 1519   // Tock — used in onboarding already
        case unlock       = 1100   // Lock — descending chime
        // Confirmation
        case success      = 1057   // Tweet sent — affirmative
        case successBig   = 1025   // Mail celebrate — bigger
        case error        = 1073   // Negative tock
        // Class lifecycle
        case classStart   = 1016   // Anticipate — chime
        case classEnd     = 1336   // Mail sent — gentle close
        case attendance   = 1521   // Begin record — quick "got it"
        case checklist    = 1003   // Tink — subtle
        // Route
        case routeStart   = 1255   // Tweet — distinct
        case routeArrive  = 1322   // SIRI received — confirmation
    }

    // MARK: - Haptic catalog

    public enum HapticEvent: Sendable {
        case light, medium, heavy, soft, rigid
        case success, warning, error
        case selection
    }

    // MARK: - Preferences

    private static var soundsOn: Bool {
        UserDefaults.standard.object(forKey: "soundsEnabled") as? Bool ?? true
    }
    private static var hapticsOn: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    // MARK: - API

    public static func sound(_ event: SoundEvent) {
        guard soundsOn else { return }
        AudioServicesPlaySystemSound(event.rawValue)
    }

    public static func haptic(_ event: HapticEvent) {
        guard hapticsOn else { return }
        DispatchQueue.main.async { performHaptic(event) }
    }

    /// Convenience for the most common combo: a soft tap with no sound.
    public static func tap() {
        haptic(.light)
    }

    /// Confirmation pair: success haptic + chime.
    public static func confirm() {
        haptic(.success)
        sound(.success)
    }

    /// Negative pair: error haptic + tock.
    public static func reject() {
        haptic(.error)
        sound(.error)
    }

    // MARK: - Private impl

    private static func performHaptic(_ event: HapticEvent) {
        switch event {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .rigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
