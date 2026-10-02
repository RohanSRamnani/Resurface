import SwiftUI

/// Rohan's iOS design language (same tokens as Mirror): dark-only, glass cards, SF Rounded, white accent.
enum Theme {
    static let background = Color(hex: 0x0A0A0A)
    static let card = Color(hex: 0x1A1A1A)
    static let cardLight = Color(hex: 0x252525)
    static let border = Color(hex: 0x2C2C2E)
    static let textSecondary = Color(hex: 0x8E8E93)
    static let accent = Color.white
    /// Toggles only: a white "on" track would hide the white knob.
    static let on = Color(hex: 0x34C759)
    static let radius: CGFloat = 16
    static let radiusLarge: CGFloat = 24

    static let cardGradient = LinearGradient(colors: [card.opacity(0.9), cardLight.opacity(0.7)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension View {
    /// Mirror's glass card: gradient fill, hairline border, soft shadow, optional top-left glow.
    func glassCard(radius: CGFloat = Theme.radius, glow: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background {
            ZStack {
                Theme.cardGradient
                if glow {
                    RadialGradient(colors: [.white.opacity(0.12), .clear], center: .topLeading, startRadius: 0, endRadius: 260)
                }
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.border, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }
}

/// White pill with a soft glow, like Mirror's GlowButton.
struct GlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LinearGradient(colors: [.white, Color(hex: 0xE5E5E5)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Capsule())
            .shadow(color: .white.opacity(0.12), radius: 20, y: 5)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Uppercase, tracked, secondary — Mirror's caption treatment.
struct Caption: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.textSecondary)
    }
}
