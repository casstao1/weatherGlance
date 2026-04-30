import SwiftUI

struct ForecastStripView: View {
    let items: [HourForecastItem]
    let theme: GlanceTheme
    let style: ForecastStripStyle
    var fillsAvailableSpace: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(theme.glassCardFill)

            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .strokeBorder(theme.glassStroke, lineWidth: 1)

            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(theme.glassHighlight)
                .mask(alignment: .top) {
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white, .white.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.clear,
                            Color.white.opacity(0.02),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.32),
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.24),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )

            HStack(spacing: style.columnSpacing) {
                ForEach(items) { item in
                    HourColumnView(item: item, theme: theme, style: style)
                }
            }
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
        }
        .frame(maxWidth: fillsAvailableSpace ? .infinity : nil,
               maxHeight: fillsAvailableSpace ? .infinity : nil)
        .shadow(color: theme.cardShadow, radius: 4, y: 1)
    }
}

#Preview("5-hour warm") {
    let entry = GlanceWidgetEntry.placeholder
    let theme = GlanceThemeResolver.theme(for: entry.mood, colorScheme: .dark)

    ForecastStripView(items: entry.hourItems, theme: theme, style: .heroSixHour)
        .padding()
        .background(Color.black)
}

#Preview("5-hour cool") {
    let entry = GlanceWidgetEntry(
        date: Date(),
        cityName: "Denver",
        currentTemperature: 28,
        currentCondition: .snow,
        inlineSummary: "❄ 28°",
        hours: [
            HourForecastItem(label: "Now", condition: .snow,         temperature: 28),
            HourForecastItem(label: "10A", condition: .snow,         temperature: 30),
            HourForecastItem(label: "11A", condition: .partlyCloudy, temperature: 32),
            HourForecastItem(label: "12P", condition: .cloudy,       temperature: 34),
            HourForecastItem(label: "1P",  condition: .cloudy,       temperature: 35),
        ],
        mood: .cool
    )
    let theme = GlanceThemeResolver.theme(for: .cool, colorScheme: .dark)
    ForecastStripView(items: entry.hourItems, theme: theme, style: .compactFiveHour)
        .padding()
        .background(Color.black)
}
