import SwiftUI
import AudioToolbox

// MARK: - Jaguarcín Pose

enum JaguarcinPose {
    case neutral      // Splash / carga
    case thumbsUp     // Onboarding bienvenida
    case celebrate    // 100% asistencia
}

// MARK: - Jaguarcín View
// Uses a vector SVG asset ("Jaguarcin") so layout is always pixel-perfect.
// Animations (bounce, wave, sparkle) are applied as SwiftUI modifiers on top.

struct JaguarcinView: View {
    let pose: JaguarcinPose
    var size: CGFloat = 220

    @State private var bounce  = false
    @State private var wave    = false
    @State private var sparkle = false

    // The SVG viewBox is 680×520, so height = size * (520/680)
    private var imageHeight: CGFloat { size * (520 / 680) }

    var body: some View {
        ZStack {
            // Sparkles for celebrate pose
            if pose == .celebrate {
                SparkleLayer(active: sparkle, size: size)
            }

            Image("Jaguarcin")
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(width: size, height: imageHeight)
                // Thumbs-up: tilt slightly
                .rotationEffect(pose == .thumbsUp ? .degrees(wave ? -4 : 4) : .zero)
                // Celebrate: wave left-right
                .offset(x: (pose == .celebrate && wave) ? 6 : 0)
        }
        // Gentle bounce on all poses
        .scaleEffect(bounce ? 1.04 : 1.0)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.52)
            .repeatForever(autoreverses: true),
            value: bounce
        )
        .animation(
            .easeInOut(duration: 0.42)
            .repeatForever(autoreverses: true),
            value: wave
        )
        .onAppear {
            bounce  = true
            wave    = true
            sparkle = true
        }
    }
}

// MARK: - Sparkle Layer

private struct SparkleLayer: View {
    let active: Bool
    let size: CGFloat

    private let positions: [(CGFloat, CGFloat, CGFloat)] = [
        (-0.42, -0.55, 18),
        ( 0.36, -0.60, 14),
        (-0.38,  0.00, 10),
        ( 0.40, -0.10, 12),
        (-0.24, -0.72, 10),
        ( 0.26, -0.70, 16),
    ]

    var body: some View {
        ZStack {
            ForEach(positions.indices, id: \.self) { i in
                let p = positions[i]
                Text("★")
                    .font(.system(size: p.2))
                    .foregroundStyle(i % 2 == 0 ? Color(hex: "#C8962A") : Color(hex: "#6B1A2A"))
                    .offset(x: p.0 * size, y: p.1 * size)
                    .scaleEffect(active ? 1.0 : 0.2)
                    .opacity(active ? 1.0 : 0.0)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.5)
                        .delay(Double(i) * 0.09)
                        .repeatForever(autoreverses: true),
                        value: active
                    )
            }
        }
    }
}
