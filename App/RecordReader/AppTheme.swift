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
            return Color(red: 0.965, green: 0.968, blue: 0.955)
        case .dark:
            return Color(red: 0.07, green: 0.055, blue: 0.07)
        }
    }

    var card: Color {
        switch mode {
        case .light:
            return Color.white
        case .dark:
            return Color.white.opacity(0.075)
        }
    }

    var elevatedCard: Color {
        switch mode {
        case .light:
            return Color(red: 1.0, green: 0.98, blue: 0.965)
        case .dark:
            return Color.white.opacity(0.1)
        }
    }

    var cardStroke: Color {
        switch mode {
        case .light:
            return Color(red: 0.93, green: 0.84, blue: 0.79)
        case .dark:
            return Color.white.opacity(0.12)
        }
    }

    var primaryText: Color {
        switch mode {
        case .light:
            return Color(red: 0.16, green: 0.13, blue: 0.12)
        case .dark:
            return Color.white
        }
    }

    var secondaryText: Color {
        switch mode {
        case .light:
            return Color(red: 0.42, green: 0.36, blue: 0.33)
        case .dark:
            return Color.white.opacity(0.68)
        }
    }

    var mutedText: Color {
        switch mode {
        case .light:
            return Color(red: 0.52, green: 0.48, blue: 0.45)
        case .dark:
            return Color.white.opacity(0.54)
        }
    }

    var accent: Color {
        Color(red: 0.82, green: 0.28, blue: 0.06)
    }

    var softAccent: Color {
        switch mode {
        case .light:
            return Color(red: 1.0, green: 0.93, blue: 0.89)
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
            return Color(red: 0.94, green: 0.91, blue: 0.89)
        case .dark:
            return Color.white.opacity(0.14)
        }
    }

    var headerBackground: Color {
        switch mode {
        case .light:
            return Color(red: 1.0, green: 0.975, blue: 0.96)
        case .dark:
            return Color.white.opacity(0.06)
        }
    }

    var screenSurface: Color {
        switch mode {
        case .light:
            return Color.white
        case .dark:
            return Color(red: 0.07, green: 0.055, blue: 0.07)
        }
    }

    var backgroundGradient: LinearGradient {
        switch mode {
        case .light:
            return LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.965, blue: 0.95),
                    Color(red: 0.985, green: 0.985, blue: 0.975)
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
            return Color(red: 0.48, green: 0.28, blue: 0.18).opacity(0.10)
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
