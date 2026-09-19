import SwiftUI
import AudioToolbox

// MARK: - Onboarding Data

private struct OnboardingPage {
    let number: String
    let kicker: String
    let headline: String
    let accentWord: String
    let body: String
    let soundID: SystemSoundID
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        number: "01",
        kicker: "BIENVENIDO A UAM SCHEDULE",
        headline: "Tu semestre,\nbajo",
        accentWord: "control.",
        body: "Horario, materias, calificaciones y asistencia — todo organizado en un solo lugar diseñado para la UAM.",
        soundID: 1519
    ),
    OnboardingPage(
        number: "02",
        kicker: "NOTIFICACIONES INTELIGENTES",
        headline: "Nunca más\nllegar",
        accentWord: "tarde.",
        body: "Avisos automáticos 15 minutos antes de cada clase. La Dynamic Island te muestra el progreso en tiempo real.",
        soundID: 1520
    ),
    OnboardingPage(
        number: "03",
        kicker: "WIDGETS NATIVOS",
        headline: "Siempre\nen tu",
        accentWord: "pantalla.",
        body: "Widget en la pantalla de inicio o centro de notificaciones. Tu próxima clase, siempre a la vista.",
        soundID: 1521
    ),
    OnboardingPage(
        number: "04",
        kicker: "REGISTRO DE ASISTENCIA",
        headline: "Tu historial\nen",
        accentWord: "segundos.",
        body: "Registra tu asistencia con un toque. Escanea tu horario impreso con la cámara para configurarlo al instante.",
        soundID: 1523
    ),
]

// MARK: - Icon definitions per page

private let pageIcons: [String] = [
    "calendar.badge.clock",
    "bell.badge.fill",
    "square.grid.2x2.fill",
    "chart.bar.fill",
]

// MARK: - UAM Brand Colors

private extension Color {
    static let uamCrimson   = Color(hex: "#6B1A2A")
    static let uamDeep      = Color(hex: "#3D0E18")
    static let uamGold      = Color(hex: "#C8962A")
    static let uamCream     = Color(hex: "#F5F0E8")
    static let uamInk       = Color(hex: "#0F0A08")
    static let uamMidtone   = Color(hex: "#8A7060")
}

// MARK: - Noise Texture Layer

private struct NoiseOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            ctx.fill(Path(rect), with: .color(.clear))
            var rng = SystemRandomNumberGenerator()
            let step: CGFloat = 2.2
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let alpha = Double(bitPattern: rng.next(upperBound: 40)) / 1000.0
                    ctx.fill(
                        Path(CGRect(x: x, y: y, width: step, height: step)),
                        with: .color(Color.white.opacity(alpha))
                    )
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Large Decorative Number

private struct LargePageNumber: View {
    let number: String
    let visible: Bool

    var body: some View {
        Text(number)
            .font(.system(size: 220, weight: .black, design: .serif))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.uamCrimson.opacity(0.18), Color.uamCrimson.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .kerning(-8)
            .offset(x: 60, y: -20)
            .scaleEffect(visible ? 1.0 : 1.15)
            .opacity(visible ? 1 : 0)
            .animation(.easeOut(duration: 0.55), value: visible)
    }
}

// MARK: - Horizontal Rule with kicker

private struct KickerLine: View {
    let text: String
    let visible: Bool

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.uamCrimson)
                .frame(width: visible ? 28 : 0, height: 1.5)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: visible)

            Text(text)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(Color.uamCrimson)
                .tracking(3.5)
                .opacity(visible ? 1 : 0)
                .animation(.easeOut(duration: 0.35).delay(0.15), value: visible)

            Rectangle()
                .fill(Color.uamCrimson.opacity(0.3))
                .frame(height: 1)
                .opacity(visible ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: visible)
        }
    }
}

// MARK: - Editorial Icon Block

private struct IconBlock: View {
    let iconName: String
    let isFirst: Bool
    let visible: Bool

    var body: some View {
        ZStack {
            if isFirst {
                // ── Jaguarcín en pose thumbsUp para página de bienvenida ──
                JaguarcinView(pose: .thumbsUp, size: 130)
                    .offset(y: -8)
            } else {
                // Rotated square — editorial graphic element
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.uamCrimson.opacity(0.12))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(12))
                    .offset(x: 14, y: 10)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.uamInk)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.uamCrimson.opacity(0.45), radius: 24, y: 12)

                Image(systemName: iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.uamCream)
            }
        }
        .scaleEffect(visible ? 1 : 0.6)
        .opacity(visible ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.05), value: visible)
    }
}

// MARK: - Progress Ticker (magazine-style)

private struct ProgressTicker: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                if i == current {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.uamCrimson)
                        .frame(width: 22, height: 3)
                } else {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(i < current ? Color.uamMidtone : Color.uamMidtone.opacity(0.3))
                        .frame(width: 8, height: 3)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: current)
    }
}

// MARK: - Main Onboarding View

struct OnboardingView: View {
    @Binding var onboardingDone: Bool

    @State private var currentPage  = 0
    @State private var contentShown = false
    @State private var buttonActive = false
    @State private var shimmer      = false
    @State private var bgOffset: CGFloat = 0

    private var isLast: Bool { currentPage == pages.count - 1 }
    private var page: OnboardingPage { pages[currentPage] }

    var body: some View {
        ZStack {
            // ── Background ─────────────────────────────
            Color.uamCream.ignoresSafeArea()

            // Animated crimson blob top-right
            Ellipse()
                .fill(Color.uamCrimson.opacity(0.13))
                .frame(width: 420, height: 340)
                .rotationEffect(.degrees(-22))
                .offset(x: 160, y: bgOffset - 200)
                .blur(radius: 70)
                .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: bgOffset)

            // Deep ink blob bottom-left
            Ellipse()
                .fill(Color.uamDeep.opacity(0.09))
                .frame(width: 320, height: 260)
                .offset(x: -130, y: bgOffset + 280)
                .blur(radius: 60)
                .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: bgOffset)

            // Subtle gold accent
            Circle()
                .fill(Color.uamGold.opacity(0.06))
                .frame(width: 180)
                .offset(x: 100, y: 200 - bgOffset * 0.3)
                .blur(radius: 40)
                .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: bgOffset)

            // Film grain texture
            NoiseOverlay()
                .ignoresSafeArea()

            // ── Content ────────────────────────────────
            VStack(spacing: 0) {

                // ── Top bar ───────────────────────────
                HStack(alignment: .center) {
                    // UAM wordmark (small)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("UAM")
                            .font(.system(size: 13, weight: .black, design: .serif))
                            .foregroundStyle(Color.uamInk)
                            .tracking(2)
                        Rectangle()
                            .fill(Color.uamCrimson)
                            .frame(height: 1.5)
                    }
                    .frame(width: 44)
                    .opacity(contentShown ? 1 : 0)
                    .animation(.easeOut(duration: 0.4), value: contentShown)

                    Spacer()

                    if !isLast {
                        Button {
                            impact(.light)
                            skip()
                        } label: {
                            Text("Saltar")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.uamMidtone)
                                .tracking(1)
                        }
                        .opacity(contentShown ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: contentShown)
                    } else {
                        Color.clear.frame(height: 20)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)

                // ── Large decorative number ────────────
                ZStack(alignment: .bottomLeading) {
                    LargePageNumber(number: page.number, visible: contentShown)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 0)
                        .padding(.top, -10)
                }
                .frame(height: 130)

                // ── Icon ──────────────────────────────
                HStack {
                    IconBlock(
                        iconName: pageIcons[currentPage],
                        isFirst: currentPage == 0,
                        visible: contentShown
                    )
                    .padding(.leading, 28)
                    Spacer()
                }
                .padding(.top, 8)

                // ── Kicker ────────────────────────────
                KickerLine(text: page.kicker, visible: contentShown)
                    .padding(.horizontal, 28)
                    .padding(.top, 28)

                // ── Headline ──────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    (
                        Text(page.headline + " ")
                            .font(.system(size: 48, weight: .black, design: .serif))
                            .foregroundStyle(Color.uamInk)
                        + Text(page.accentWord)
                            .font(.system(size: 48, weight: .black, design: .serif))
                            .foregroundStyle(Color.uamCrimson)
                    )
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .kerning(-1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 14)
                .opacity(contentShown ? 1 : 0)
                .offset(y: contentShown ? 0 : 20)
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.22), value: contentShown)

                // Thin divider — magazine rule
                HStack {
                    Rectangle()
                        .fill(Color.uamInk.opacity(0.12))
                        .frame(height: 1)
                        .padding(.leading, 28)
                        .padding(.trailing, 80)
                        .scaleEffect(x: contentShown ? 1 : 0, anchor: .leading)
                        .animation(.easeOut(duration: 0.5).delay(0.3), value: contentShown)
                    Spacer()
                }
                .padding(.top, 18)

                // ── Body copy ─────────────────────────
                Text(page.body)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(Color.uamMidtone)
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 14)
                    .opacity(contentShown ? 1 : 0)
                    .offset(y: contentShown ? 0 : 12)
                    .animation(.easeOut(duration: 0.4).delay(0.35), value: contentShown)

                Spacer()

                // ── Bottom controls ───────────────────
                VStack(spacing: 20) {

                    // Progress + page fraction
                    HStack(alignment: .center) {
                        ProgressTicker(current: currentPage, total: pages.count)

                        Spacer()

                        Text("\(currentPage + 1)/\(pages.count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.uamMidtone.opacity(0.7))
                            .tracking(2)
                    }
                    .padding(.horizontal, 28)

                    // CTA Button — ink with gold shimmer on last page
                    Button {
                        impact(.medium)
                        if isLast {
                            AudioServicesPlaySystemSound(1519)
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                                onboardingDone = true
                            }
                        } else {
                            advance()
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isLast ? Color.uamCrimson : Color.uamInk)

                            // Shimmer sweep
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.12), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .offset(x: shimmer ? 340 : -340)
                            .animation(.linear(duration: 2.2).repeatForever(autoreverses: false), value: shimmer)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            HStack(spacing: 12) {
                                Text(isLast ? "Empezar ahora" : "Continuar")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.uamCream)
                                    .tracking(0.5)

                                Image(systemName: isLast ? "checkmark" : "arrow.right")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(isLast ? Color.uamGold : Color.uamCrimson)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .shadow(color: (isLast ? Color.uamCrimson : Color.uamInk).opacity(0.35), radius: 18, y: 8)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                    .scaleEffect(buttonActive ? 1 : 0.94)
                    .opacity(buttonActive ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4), value: buttonActive)
                }
                .padding(.bottom, 52)
            }
        }
        .onAppear {
            withAnimation { bgOffset = 20 }
            triggerEntrance()
        }
    }

    // MARK: - Helpers

    private func triggerEntrance() {
        contentShown = false
        buttonActive = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation { contentShown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation { buttonActive = true }
                shimmer = true
            }
        }
    }

    private func advance() {
        AudioServicesPlaySystemSound(pages[currentPage].soundID)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            currentPage += 1
        }
        triggerEntrance()
    }

    private func skip() {
        AudioServicesPlaySystemSound(pages[currentPage].soundID)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            currentPage = pages.count - 1
        }
        triggerEntrance()
    }

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
