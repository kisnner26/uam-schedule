import SwiftUI
import AudioToolbox

// MARK: - Splash View
// Shown at app launch before onboarding or login.
// Replace the Group{} in UAMScheduleApp with:
//   SplashView { /* transition to next screen */ }

struct SplashView: View {
    var onFinish: () -> Void

    @State private var logoScale:    CGFloat = 0.6
    @State private var logoOpacity:  Double  = 0
    @State private var jagScale:     CGFloat = 0.4
    @State private var jagOpacity:   Double  = 0
    @State private var taglineSlide: CGFloat = 30
    @State private var taglineAlpha: Double  = 0
    @State private var ripple1:      CGFloat = 0.4
    @State private var ripple2:      CGFloat = 0.3
    @State private var rippleAlpha1: Double  = 0.22
    @State private var rippleAlpha2: Double  = 0.15
    @State private var bgShift:      Bool    = false

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────
            Color(hex: "#FAF8F5").ignoresSafeArea()

            // Crimson blob top
            Ellipse()
                .fill(Color(hex: "#6B1A2A").opacity(0.11))
                .frame(width: 380, height: 300)
                .rotationEffect(.degrees(-20))
                .offset(x: 150, y: bgShift ? -200 : -220)
                .blur(radius: 65)
                .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: bgShift)

            // Gold blob
            Ellipse()
                .fill(Color(hex: "#C8962A").opacity(0.07))
                .frame(width: 260, height: 200)
                .offset(x: -110, y: bgShift ? 260 : 230)
                .blur(radius: 55)
                .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: bgShift)

            // ── Ripple rings ────────────────────────
            Circle()
                .stroke(Color(hex: "#6B1A2A").opacity(rippleAlpha1), lineWidth: 1.5)
                .frame(width: 260 * ripple1, height: 260 * ripple1)
                .animation(.easeOut(duration: 1.2).delay(0.4), value: ripple1)

            Circle()
                .stroke(Color(hex: "#6B1A2A").opacity(rippleAlpha2), lineWidth: 1)
                .frame(width: 320 * ripple2, height: 320 * ripple2)
                .animation(.easeOut(duration: 1.5).delay(0.55), value: ripple2)

            // ── Content ─────────────────────────────
            VStack(spacing: 0) {
                Spacer()

                // Jaguarcín
                JaguarcinView(pose: .neutral, size: 200)
                    .scaleEffect(jagScale)
                    .opacity(jagOpacity)
                    .animation(.spring(response: 0.65, dampingFraction: 0.62).delay(0.1), value: jagScale)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: jagOpacity)

                // App name + logo area
                VStack(spacing: 6) {
                    // Thin rule
                    HStack(spacing: 10) {
                        Rectangle().fill(Color(hex: "#6B1A2A")).frame(width: 22, height: 1.5)
                        Text("UAM SCHEDULE")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(hex: "#6B1A2A"))
                            .tracking(3.5)
                        Rectangle().fill(Color(hex: "#6B1A2A").opacity(0.3)).frame(height: 1.5)
                    }
                    .padding(.horizontal, 52)
                    .padding(.top, 12)

                    Text("Tu semestre, bajo control.")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(Color(hex: "#8A7060"))
                        .italic()
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.28), value: logoScale)
                .animation(.easeOut(duration: 0.4).delay(0.28), value: logoOpacity)

                // Tagline / version
                Text("Universidad Americana · Nicaragua")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#8A7060").opacity(0.55))
                    .tracking(1.5)
                    .padding(.top, 28)
                    .offset(y: taglineSlide)
                    .opacity(taglineAlpha)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.45), value: taglineSlide)
                    .animation(.easeOut(duration: 0.4).delay(0.45), value: taglineAlpha)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            // Haptic
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            // Subtle whoosh sound
            AudioServicesPlaySystemSound(1519)

            bgShift = true

            withAnimation { jagScale = 1; jagOpacity = 1 }
            withAnimation { logoScale = 1; logoOpacity = 1 }
            taglineSlide = 0; taglineAlpha = 1

            // Ripple expand
            ripple1 = 1.0; rippleAlpha1 = 0
            ripple2 = 1.0; rippleAlpha2 = 0

            // Auto-advance after 2.2 s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeInOut(duration: 0.4)) { onFinish() }
            }
        }
    }
}
