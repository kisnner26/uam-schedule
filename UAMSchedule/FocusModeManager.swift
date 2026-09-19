import Foundation
import UIKit
import UserNotifications

// MARK: - Focus Mode Manager
// iOS no permite activar Focus programáticamente (requiere permiso especial de Apple)
// Lo que SÍ podemos hacer: interruption level timeSensitive para que pasen el Focus
// y mostrar al usuario cómo activar Focus desde la app con un deep link

@MainActor
final class FocusModeManager: ObservableObject {
    static let shared = FocusModeManager()
    @Published var isFocusActive = false

    // Prompt user to enable Focus — we can only open Settings
    func promptFocusMode() {
        // Deep link to Focus settings
        if let url = URL(string: "App-prefs:Focus") {
            UIApplication.shared.open(url)
        }
    }

    // Mark all UAMSchedule notifications as timeSensitive
    // so they break through Focus automatically
    func enableBreakthrough() {
        isFocusActive = true
        UserDefaults.standard.set(true, forKey: "focus_breakthrough")
    }

    func disableBreakthrough() {
        isFocusActive = false
        UserDefaults.standard.set(false, forKey: "focus_breakthrough")
    }
}
