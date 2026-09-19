import SwiftUI
import AudioToolbox

// MARK: - Celebration Modal
// Present this as a .sheet or .fullScreenCover when a course reaches 100% attendance.
//
// Usage example (inside AttendanceView or CourseAttendanceCard):
//   .sheet(isPresented: $showCelebration) {
//       JaguarcinCelebrationView(courseName: course.name)
//   }

struct JaguarcinCelebrationView: View {
    let courseName: String
    @Environment(\.dismiss) private var dismiss

    @State private var appeared     = false
    @State private var confettiOn   = false
    @State private var textSlide    = false
    @State private var buttonPop    = false
    @State private var jagBounce    = false
    @State private var bgPulse      = false

    // Confetti pieces
    private let confetti: [(CGFloat, CGFloat, Color, CGFloat, Double)] = {
        var arr: [(CGFloat, CGFloat, Color, CGFloat, Double)] = []
        let colors: [Color] = [
            Color(hex: "#C8962A"), Color(hex: "#6B1A2A"),
            Color(hex: "#1BA99A"), Color(hex: "#F5C842"),
            Color(hex: "#FAF8F5"), Color(hex: "#3D0E18"),
        ]
        let w = UIScreen.main.bounds.width
        for _ in 0..<38 {
            arr.append((
                CGFloat.random(in: -w/2...w/2),
                CGFloat.random(in: -120...(-20)),
                colors.randomElement()!,
                CGFloat.random(in: 6...14),
                Double.random(in: 0.6...1.6)
            ))
        }
        return arr
    }()

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────
            Color(hex: "#FAF8F5").ignoresSafeArea()

            Ellipse()
                .fill(Color(hex: "#6B1A2A").opacity(0.1))
                .frame(width: 350, height: 280)
                .offset(x: 120, y: bgPulse ? -180 : -200)
                .blur(radius: 60)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: bgPulse)

            Ellipse()
                .fill(Color(hex: "#C8962A").opacity(0.08))
                .frame(width: 280, height: 220)
                .offset(x: -100, y: bgPulse ? 240 : 210)
                .blur(radius: 55)
                .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: bgPulse)

            // ── Confetti ─────────────────────────────
            ZStack {
                ForEach(confetti.indices, id: \.self) { i in
                    let c = confetti[i]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(c.2)
                        .frame(width: c.3, height: c.3 * 1.6)
                        .rotationEffect(.degrees(Double.random(in: 0...360)))
                        .offset(
                            x: c.0,
                            y: confettiOn ? UIScreen.main.bounds.height * 0.7 : c.1
                        )
                        .opacity(confettiOn ? 0 : 0.9)
                        .animation(
                            .easeIn(duration: c.4).delay(Double(i) * 0.04),
                            value: confettiOn
                        )
                }
            }
            .allowsHitTesting(false)

            // ── Main content ─────────────────────────
            VStack(spacing: 0) {
                Spacer()

                // 100% badge
                ZStack {
                    Circle()
                        .fill(Color(hex: "#6B1A2A").opacity(0.08))
                        .frame(width: bgPulse ? 140 : 120, height: bgPulse ? 140 : 120)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: bgPulse)

                    Circle()
                        .fill(Color(hex: "#6B1A2A").opacity(0.14))
                        .frame(width: bgPulse ? 104 : 90, height: bgPulse ? 104 : 90)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(0.2), value: bgPulse)

                    VStack(spacing: 0) {
                        Text("100%")
                            .font(.system(size: 30, weight: .black, design: .serif))
                            .foregroundStyle(Color(hex: "#6B1A2A"))
                        Text("ASISTENCIA")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(hex: "#6B1A2A"))
                            .tracking(2)
                    }
                }
                .scaleEffect(appeared ? 1 : 0.3)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.58).delay(0.05), value: appeared)
                .padding(.bottom, 16)

                // Jaguarcín celebrate
                JaguarcinView(pose: .celebrate, size: 210)
                    .scaleEffect(jagBounce ? 1.05 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.55).repeatForever(autoreverses: true), value: jagBounce)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.62).delay(0.12), value: appeared)

                // Text
                VStack(spacing: 10) {
                    Text("¡Jaguarcín está orgulloso!")
                        .font(.system(size: 26, weight: .black, design: .serif))
                        .foregroundStyle(Color(hex: "#0F0A08"))
                        .multilineTextAlignment(.center)
                        .kerning(-0.5)

                    // Course name pill
                    Text(courseName)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(hex: "#FAF8F5"))
                        .tracking(2)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#6B1A2A"))
                        .clipShape(Capsule())

                    Text("Lograste asistencia perfecta.\nSigue así todo el semestre.")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundStyle(Color(hex: "#8A7060"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.horizontal, 36)
                        .padding(.top, 4)
                }
                .offset(y: textSlide ? 0 : 24)
                .opacity(textSlide ? 1 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.25), value: textSlide)

                Spacer()

                // CTA Button
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    AudioServicesPlaySystemSound(1519)
                    dismiss()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: "#6B1A2A"))

                        // Shimmer
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.14), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        HStack(spacing: 10) {
                            Text("¡Gracias, Jaguarcín!")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#FAF8F5"))
                                .tracking(0.3)
                            Text("★")
                                .foregroundStyle(Color(hex: "#C8962A"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .shadow(color: Color(hex: "#6B1A2A").opacity(0.38), radius: 16, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .scaleEffect(buttonPop ? 1 : 0.88)
                .opacity(buttonPop ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.68).delay(0.42), value: buttonPop)
                .padding(.bottom, 52)
            }
        }
        .onAppear {
            bgPulse = true
            // Fanfare sound + haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            AudioServicesPlaySystemSound(1016)   // chime
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                AudioServicesPlaySystemSound(1025) // second chime layer
            }

            withAnimation { appeared = true }
            textSlide  = true
            buttonPop  = true
            jagBounce  = true

            // Rain confetti then fade
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation { confettiOn = true }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    JaguarcinCelebrationView(courseName: "Ingeniería de Software I")
}
