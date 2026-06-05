import Foundation
import SwiftUI

struct NeonLoadingIndicator: View {
    let progress: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var theme

    var body: some View {
        if reduceMotion {
            indicator(phase: 0)
        } else {
            TimelineView(.animation) { timeline in
                indicator(phase: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func indicator(phase: TimeInterval) -> some View {
        let rotation = Angle.degrees(phase * 120)
        let pulse = reduceMotion ? 1 : 0.94 + 0.06 * sin(phase * 2.4)
        let trimAmount = progress.map { min(max($0, 0), 1) } ?? 0.72

        return ZStack {
            Circle()
                .stroke(theme.cardStroke.opacity(0.45), lineWidth: 1)

            Circle()
                .trim(from: 0, to: trimAmount)
                .stroke(
                    AngularGradient(
                        colors: [
                            theme.accent,
                            Color(red: 0.98, green: 0.72, blue: 0.20),
                            Color(red: 1.0, green: 0.48, blue: 0.18),
                            Color(red: 1.0, green: 0.84, blue: 0.54),
                            theme.accent
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(progress == nil ? rotation : .degrees(-90))
                .shadow(color: theme.accent.opacity(0.38), radius: 10)

            Circle()
                .trim(from: 0.02, to: 0.12)
                .stroke(Color.white.opacity(0.86), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(rotation + .degrees(35))
                .opacity(progress == nil && !reduceMotion ? 1 : 0)
                .shadow(color: Color.white.opacity(0.42), radius: 7)

            Image(systemName: "waveform")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.primaryText)
                .scaleEffect(pulse)
        }
        .frame(width: 76, height: 76)
        .padding(10)
        .background(
            Circle()
                .fill(theme.elevatedCard.opacity(0.78))
                .shadow(color: theme.accent.opacity(0.16), radius: 20)
        )
    }
}

enum GlowPressShape: Sendable {
    case rounded(CGFloat)
    case circle
    case capsule
}

struct GlowPressOverlay: View {
    let shape: GlowPressShape
    let isPressed: Bool
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            glowFill
            glowStroke
            PressSheenOverlay(shape: shape, isActive: isPressed)
        }
        .allowsHitTesting(false)
        .opacity(isPressed ? 0.82 : 0.08)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isPressed)
    }

    @ViewBuilder
    private var glowFill: some View {
        switch shape {
        case .rounded(let radius):
            RoundedRectangle(cornerRadius: radius)
                .fill(theme.softAccent.opacity(isPressed ? 0.12 : 0.02))
        case .circle:
            Circle()
                .fill(theme.softAccent.opacity(isPressed ? 0.14 : 0.02))
        case .capsule:
            Capsule()
                .fill(theme.softAccent.opacity(isPressed ? 0.12 : 0.02))
        }
    }

    @ViewBuilder
    private var glowStroke: some View {
        let gradient = LinearGradient(
            colors: [
                theme.accent.opacity(isPressed ? 0.72 : 0.20),
                Color(red: 0.96, green: 0.55, blue: 0.20).opacity(isPressed ? 0.56 : 0.14),
                Color(red: 1.0, green: 0.84, blue: 0.62).opacity(isPressed ? 0.42 : 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        switch shape {
        case .rounded(let radius):
            RoundedRectangle(cornerRadius: radius)
                .stroke(gradient, lineWidth: isPressed ? 1.1 : 0.6)
                .shadow(color: theme.accent.opacity(isPressed ? 0.14 : 0.04), radius: isPressed ? 8 : 3)
        case .circle:
            Circle()
                .stroke(gradient, lineWidth: isPressed ? 1.2 : 0.7)
                .shadow(color: theme.accent.opacity(isPressed ? 0.16 : 0.04), radius: isPressed ? 9 : 3)
        case .capsule:
            Capsule()
                .stroke(gradient, lineWidth: isPressed ? 1.1 : 0.6)
                .shadow(color: theme.accent.opacity(isPressed ? 0.14 : 0.04), radius: isPressed ? 8 : 3)
        }
    }
}

private struct PressSheenOverlay: View {
    let shape: GlowPressShape
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            sheen
                .frame(width: max(proxy.size.width * 0.48, 24), height: proxy.size.height * 1.8)
                .rotationEffect(.degrees(24))
                .offset(x: isActive && !reduceMotion ? proxy.size.width * 0.72 : -proxy.size.width * 0.82)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: isActive)
        }
        .clipShape(clipShape)
        .opacity(isActive && !reduceMotion ? 0.72 : 0)
    }

    private var sheen: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(0.18),
                Color.white.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var clipShape: some Shape {
        GlowClipShape(shape: shape)
    }
}

private struct GlowClipShape: Shape {
    let shape: GlowPressShape

    func path(in rect: CGRect) -> Path {
        switch shape {
        case .rounded(let radius):
            return RoundedRectangle(cornerRadius: radius).path(in: rect)
        case .circle:
            return Circle().path(in: rect)
        case .capsule:
            return Capsule().path(in: rect)
        }
    }
}
