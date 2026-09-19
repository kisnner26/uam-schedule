import SwiftUI

// MARK: - Design Tokens

struct DS {
    struct Color {
        static let wine        = SwiftUI.Color(hex: "#6B1A2A")
        static let wineLight   = SwiftUI.Color(hex: "#8B2438")
        static let wineMuted   = SwiftUI.Color(hex: "#6B1A2A").opacity(0.10)
        static let ink         = SwiftUI.Color(hex: "#0F0F0F")
        static let inkSecondary  = SwiftUI.Color(hex: "#2C2C2C")
        static let inkTertiary   = SwiftUI.Color(hex: "#6B6B6B")
        static let inkQuaternary = SwiftUI.Color(hex: "#ABABAB")
        static let paper          = SwiftUI.Color(hex: "#FAF8F5")
        static let paperSecondary = SwiftUI.Color(hex: "#F2EFE9")
        static let paperTertiary  = SwiftUI.Color(hex: "#E8E4DC")
        static let separator  = SwiftUI.Color(hex: "#0F0F0F").opacity(0.07)
        static let cardBorder = SwiftUI.Color(hex: "#0F0F0F").opacity(0.05)
        static let courseColors: [String] = [
            "#6B1A2A","#1A3A6B","#1A5C3A","#6B4A1A",
            "#3A1A6B","#1A5A6B","#6B3A1A","#1A6B5A",
        ]
    }

    struct Font {
        static func display(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .serif)
        }
        static func body(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }
        static func mono(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }

    struct Space {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // Border radii
    struct Radius {
        static let sm:  CGFloat = 12
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 20
        static let xl:  CGFloat = 26
        static let pill: CGFloat = 999
    }

    struct Anim {
        static let spring     = Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let springFast = Animation.spring(response: 0.3, dampingFraction: 0.75)
        static let ease       = Animation.easeInOut(duration: 0.25)
        static let easeSlow   = Animation.easeInOut(duration: 0.4)
    }
}

// MARK: - Adaptive colors

extension SwiftUI.Color {
    static func adaptive(light: SwiftUI.Color, dark: SwiftUI.Color) -> SwiftUI.Color {
        SwiftUI.Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }
    static var appBackground: SwiftUI.Color {
        adaptive(light: DS.Color.paper, dark: SwiftUI.Color(hex: "#0D0A09"))
    }
    static var appBackgroundSecondary: SwiftUI.Color {
        adaptive(light: DS.Color.paperSecondary, dark: SwiftUI.Color(hex: "#161210"))
    }
    static var appBackgroundTertiary: SwiftUI.Color {
        adaptive(light: DS.Color.paperTertiary, dark: SwiftUI.Color(hex: "#1E1916"))
    }
    static var appInk: SwiftUI.Color {
        adaptive(light: DS.Color.ink, dark: SwiftUI.Color(hex: "#F5F0E8"))
    }
    static var appInkSecondary: SwiftUI.Color {
        adaptive(light: DS.Color.inkSecondary, dark: SwiftUI.Color(hex: "#C8BFB0"))
    }
    static var appInkTertiary: SwiftUI.Color {
        adaptive(light: DS.Color.inkTertiary, dark: SwiftUI.Color(hex: "#8A7E72"))
    }
    static var appSeparator: SwiftUI.Color {
        adaptive(light: DS.Color.separator, dark: SwiftUI.Color.white.opacity(0.07))
    }
    static var appCardBorder: SwiftUI.Color {
        adaptive(light: DS.Color.cardBorder, dark: SwiftUI.Color.white.opacity(0.05))
    }
}

// MARK: - Card modifier (rounder)

struct CardStyle: ViewModifier {
    var padding: CGFloat = DS.Space.md
    var radius: CGFloat  = DS.Radius.lg
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.appBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.appCardBorder, lineWidth: 1)
            )
    }
}

struct WineAccentLine: View {
    var height: CGFloat = 1.5
    var width: CGFloat? = 32
    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(DS.Color.wine)
            .frame(width: width, height: height)
    }
}

extension View {
    func cardStyle(padding: CGFloat = DS.Space.md, radius: CGFloat = DS.Radius.lg) -> some View {
        modifier(CardStyle(padding: padding, radius: radius))
    }
}
