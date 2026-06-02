import SwiftUI

enum AppThemeMode: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light:
            return "浅色"
        case .dark:
            return "深色"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

struct AppTheme {
    let mode: AppThemeMode

    var background: Color {
        switch mode {
        case .light:
            return Color(red: 0.98, green: 0.955, blue: 0.91)
        case .dark:
            return Color(red: 0.07, green: 0.055, blue: 0.07)
        }
    }

    var card: Color {
        switch mode {
        case .light:
            return Color.white.opacity(0.86)
        case .dark:
            return Color.white.opacity(0.075)
        }
    }

    var elevatedCard: Color {
        switch mode {
        case .light:
            return Color.white.opacity(0.94)
        case .dark:
            return Color.white.opacity(0.1)
        }
    }

    var cardStroke: Color {
        switch mode {
        case .light:
            return Color.black.opacity(0.08)
        case .dark:
            return Color.white.opacity(0.12)
        }
    }

    var primaryText: Color {
        switch mode {
        case .light:
            return Color(red: 0.16, green: 0.12, blue: 0.1)
        case .dark:
            return Color.white
        }
    }

    var secondaryText: Color {
        switch mode {
        case .light:
            return Color(red: 0.42, green: 0.34, blue: 0.28)
        case .dark:
            return Color.white.opacity(0.68)
        }
    }

    var mutedText: Color {
        switch mode {
        case .light:
            return Color(red: 0.58, green: 0.49, blue: 0.42)
        case .dark:
            return Color.white.opacity(0.54)
        }
    }

    var accent: Color {
        Color(red: 0.95, green: 0.42, blue: 0.16)
    }

    var softAccent: Color {
        switch mode {
        case .light:
            return Color(red: 1.0, green: 0.86, blue: 0.72)
        case .dark:
            return Color(red: 0.36, green: 0.18, blue: 0.11)
        }
    }

    var controlFill: Color {
        switch mode {
        case .light:
            return accent
        case .dark:
            return Color.white
        }
    }

    var controlForeground: Color {
        switch mode {
        case .light:
            return Color.white
        case .dark:
            return Color.black
        }
    }

    var subtleFill: Color {
        switch mode {
        case .light:
            return Color.white.opacity(0.72)
        case .dark:
            return Color.white.opacity(0.14)
        }
    }

    var backgroundGradient: LinearGradient {
        switch mode {
        case .light:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.96, blue: 0.9),
                    Color(red: 0.98, green: 0.94, blue: 0.87),
                    Color(red: 0.95, green: 0.97, blue: 0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dark:
            return LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.07, blue: 0.08),
                    Color(red: 0.055, green: 0.05, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var cardShadow: Color {
        switch mode {
        case .light:
            return Color(red: 0.55, green: 0.34, blue: 0.18).opacity(0.12)
        case .dark:
            return Color.black.opacity(0.24)
        }
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme(mode: .light)
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
