import UIKit

/// Returns the top safe area inset (status bar height) for the current device window.
/// Only used by the main app target — not available in widget extensions.
@MainActor
func topSafeArea() -> CGFloat {
    let scenes = UIApplication.shared.connectedScenes
    let windowScene = scenes.first as? UIWindowScene
    return windowScene?.windows.first?.safeAreaInsets.top ?? 44
}

/// Returns the bottom safe area inset (home indicator area) for the current device window.
@MainActor
func bottomSafeArea() -> CGFloat {
    let scenes = UIApplication.shared.connectedScenes
    let windowScene = scenes.first as? UIWindowScene
    return windowScene?.windows.first?.safeAreaInsets.bottom ?? 0
}
