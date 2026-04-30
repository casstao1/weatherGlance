import SwiftUI

enum GlanceThemeResolver {

    static func widgetGlassTheme(colorScheme: ColorScheme) -> GlanceTheme {
        if colorScheme == .dark {
            return GlanceTheme(
                primaryText: Color.white.opacity(0.96),
                secondaryText: Color.white.opacity(0.86),
                containerBackground: LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        Color.white.opacity(0.10),
                        Color.white.opacity(0.04),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                widgetBackground: LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.white.opacity(0.11),
                        Color.white.opacity(0.05),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                glassCardFill: LinearGradient(
                    colors: [
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.06),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassHighlight: LinearGradient(
                    colors: [
                        Color.white.opacity(0.34),
                        Color.white.opacity(0.04),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassStroke: Color.white.opacity(0.34),
                cardShadow: Color.black.opacity(0.10)
            )
        } else {
            return GlanceTheme(
                primaryText: Color.white.opacity(0.98),
                secondaryText: Color.white.opacity(0.84),
                containerBackground: LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.05),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                widgetBackground: LinearGradient(
                    colors: [
                        Color.white.opacity(0.26),
                        Color.white.opacity(0.14),
                        Color.white.opacity(0.06),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                glassCardFill: LinearGradient(
                    colors: [
                        Color.white.opacity(0.16),
                        Color.white.opacity(0.08),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassHighlight: LinearGradient(
                    colors: [
                        Color.white.opacity(0.36),
                        Color.white.opacity(0.05),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassStroke: Color.white.opacity(0.38),
                cardShadow: Color.black.opacity(0.08)
            )
        }
    }

    static func theme(for mood: WeatherMood, colorScheme: ColorScheme) -> GlanceTheme {
        switch mood {
        case .warm:
            return warmTheme(colorScheme: colorScheme)
        case .dark:
            return darkTheme(colorScheme: colorScheme)
        case .neutral:
            return neutralTheme(colorScheme: colorScheme)
        case .cool:
            return coolTheme(colorScheme: colorScheme)
        }
    }

    // MARK: – Warm (sunny)
    private static func warmTheme(colorScheme: ColorScheme) -> GlanceTheme {
        if colorScheme == .dark {
            return GlanceTheme(
                primaryText: Color(red: 1.0, green: 0.96, blue: 0.88),
                secondaryText: Color(red: 0.85, green: 0.76, blue: 0.60),
                containerBackground: LinearGradient(
                    colors: [
                        Color(red: 0.38, green: 0.25, blue: 0.08),
                        Color(red: 0.28, green: 0.16, blue: 0.04),
                    ],
                    startPoint: .top, endPoint: .bottom
                ),
                widgetBackground: LinearGradient(
                    colors: [
                        Color(red: 0.45, green: 0.30, blue: 0.10),
                        Color(red: 0.20, green: 0.12, blue: 0.03),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassCardFill: LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color(red: 1.0, green: 0.96, blue: 0.86).opacity(0.12),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassHighlight: LinearGradient(
                    colors: [
                        Color.white.opacity(0.36),
                        Color.white.opacity(0.04),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassStroke: Color.white.opacity(0.24),
                cardShadow: Color.black.opacity(0.18)
            )
        } else {
            return GlanceTheme(
                primaryText: Color(red: 0.30, green: 0.20, blue: 0.05),
                secondaryText: Color(red: 0.55, green: 0.42, blue: 0.18),
                containerBackground: LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.93, blue: 0.80),
                        Color(red: 0.96, green: 0.87, blue: 0.65),
                    ],
                    startPoint: .top, endPoint: .bottom
                ),
                widgetBackground: LinearGradient(
                    colors: [
                        Color(red: 0.99, green: 0.95, blue: 0.84),
                        Color(red: 0.94, green: 0.84, blue: 0.60),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassCardFill: LinearGradient(
                    colors: [
                        Color.white.opacity(0.58),
                        Color(red: 0.99, green: 0.95, blue: 0.86).opacity(0.28),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassHighlight: LinearGradient(
                    colors: [
                        Color.white.opacity(0.60),
                        Color.white.opacity(0.10),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassStroke: Color.white.opacity(0.48),
                cardShadow: Color.black.opacity(0.10)
            )
        }
    }

    // MARK: – Dark (rain)
    private static func darkTheme(colorScheme: ColorScheme) -> GlanceTheme {
        GlanceTheme(
            primaryText: Color(red: 0.94, green: 0.96, blue: 1.0),
            secondaryText: Color(red: 0.65, green: 0.72, blue: 0.82),
            containerBackground: LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.14, blue: 0.20),
                    Color(red: 0.08, green: 0.10, blue: 0.16),
                ],
                startPoint: .top, endPoint: .bottom
            ),
            widgetBackground: LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.16, blue: 0.24),
                    Color(red: 0.06, green: 0.08, blue: 0.14),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            glassCardFill: LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color(red: 0.72, green: 0.80, blue: 0.92).opacity(0.08),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            glassHighlight: LinearGradient(
                colors: [
                    Color.white.opacity(0.30),
                    Color.white.opacity(0.02),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            glassStroke: Color.white.opacity(0.22),
            cardShadow: Color.black.opacity(0.26)
        )
    }

    // MARK: – Neutral (cloudy)
    private static func neutralTheme(colorScheme: ColorScheme) -> GlanceTheme {
        if colorScheme == .dark {
            return GlanceTheme(
                primaryText: Color(red: 0.94, green: 0.94, blue: 0.96),
                secondaryText: Color(red: 0.65, green: 0.65, blue: 0.70),
                containerBackground: LinearGradient(
                    colors: [
                        Color(red: 0.20, green: 0.20, blue: 0.22),
                        Color(red: 0.14, green: 0.14, blue: 0.16),
                    ],
                    startPoint: .top, endPoint: .bottom
                ),
                widgetBackground: LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.22, blue: 0.25),
                        Color(red: 0.12, green: 0.12, blue: 0.14),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassCardFill: LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        Color.white.opacity(0.08),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassHighlight: LinearGradient(
                    colors: [
                        Color.white.opacity(0.28),
                        Color.white.opacity(0.03),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassStroke: Color.white.opacity(0.20),
                cardShadow: Color.black.opacity(0.24)
            )
        } else {
            return GlanceTheme(
                primaryText: Color(red: 0.18, green: 0.18, blue: 0.20),
                secondaryText: Color(red: 0.50, green: 0.50, blue: 0.54),
                containerBackground: LinearGradient(
                    colors: [
                        Color(red: 0.91, green: 0.91, blue: 0.93),
                        Color(red: 0.84, green: 0.84, blue: 0.88),
                    ],
                    startPoint: .top, endPoint: .bottom
                ),
                widgetBackground: LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.93, blue: 0.95),
                        Color(red: 0.82, green: 0.82, blue: 0.86),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassCardFill: LinearGradient(
                    colors: [
                        Color.white.opacity(0.62),
                        Color.white.opacity(0.30),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassHighlight: LinearGradient(
                    colors: [
                        Color.white.opacity(0.64),
                        Color.white.opacity(0.10),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassStroke: Color.white.opacity(0.48),
                cardShadow: Color.black.opacity(0.10)
            )
        }
    }

    // MARK: – Cool (snow)
    private static func coolTheme(colorScheme: ColorScheme) -> GlanceTheme {
        if colorScheme == .dark {
            return GlanceTheme(
                primaryText: Color(red: 0.90, green: 0.95, blue: 1.0),
                secondaryText: Color(red: 0.60, green: 0.72, blue: 0.88),
                containerBackground: LinearGradient(
                    colors: [
                        Color(red: 0.14, green: 0.18, blue: 0.28),
                        Color(red: 0.10, green: 0.14, blue: 0.22),
                    ],
                    startPoint: .top, endPoint: .bottom
                ),
                widgetBackground: LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.20, blue: 0.32),
                        Color(red: 0.08, green: 0.12, blue: 0.20),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassCardFill: LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        Color(red: 0.78, green: 0.88, blue: 1.0).opacity(0.08),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassHighlight: LinearGradient(
                    colors: [
                        Color.white.opacity(0.30),
                        Color.white.opacity(0.02),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassStroke: Color.white.opacity(0.22),
                cardShadow: Color.black.opacity(0.26)
            )
        } else {
            return GlanceTheme(
                primaryText: Color(red: 0.14, green: 0.20, blue: 0.34),
                secondaryText: Color(red: 0.40, green: 0.52, blue: 0.70),
                containerBackground: LinearGradient(
                    colors: [
                        Color(red: 0.88, green: 0.92, blue: 0.98),
                        Color(red: 0.80, green: 0.86, blue: 0.96),
                    ],
                    startPoint: .top, endPoint: .bottom
                ),
                widgetBackground: LinearGradient(
                    colors: [
                        Color(red: 0.90, green: 0.94, blue: 0.99),
                        Color(red: 0.78, green: 0.84, blue: 0.95),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassCardFill: LinearGradient(
                    colors: [
                        Color.white.opacity(0.60),
                        Color(red: 0.92, green: 0.96, blue: 1.0).opacity(0.26),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassHighlight: LinearGradient(
                    colors: [
                        Color.white.opacity(0.62),
                        Color.white.opacity(0.08),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                glassStroke: Color.white.opacity(0.48),
                cardShadow: Color.black.opacity(0.10)
            )
        }
    }
}
