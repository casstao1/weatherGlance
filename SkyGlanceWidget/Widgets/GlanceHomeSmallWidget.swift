import WidgetKit
import SwiftUI

struct GlanceHomeSmallWidget: Widget {
    static let kind = "GlanceHomeSmallWidgetV3"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: GlanceProvider()) { entry in
            GlanceHomeSmallEntryView(entry: entry)
        }
        .configurationDisplayName("SkyGlance Compact")
        .description("Current conditions at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

struct GlanceHomeSmallEntryView: View {
    let entry: GlanceWidgetEntry

    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    @AppStorage(
        SharedLocationStore.showFeelsLikeTemperaturesKey,
        store: SharedLocationStore.defaults
    ) private var showFeelsLikeTemperatures: Bool = false

    private var cityName: String {
        entry.cityName ?? "Location"
    }

    private let primaryTextColor = Color(white: 0.16)
    private let secondaryTextColor = Color(white: 0.42)

    var body: some View {
        Group {
            if WidgetAccessPolicy.canRenderWeather {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(cityName)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 8, weight: .medium))
                            .rotationEffect(.degrees(20))
                    }
                    .foregroundStyle(primaryTextColor)

                    Spacer(minLength: 0)

                    WidgetMonochromeWeatherIcon(condition: entry.currentCondition, pointSize: 31)
                        .foregroundStyle(primaryTextColor)

                    Spacer(minLength: 4)

                    SmallWidgetTemperatureText(
                        value: "\(entry.displayCurrentTemperature(showFeelsLike: showFeelsLikeTemperatures))°",
                        primaryText: primaryTextColor
                    )

                    Text(entry.currentCondition.accessibilityLabel.capitalized)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(" Weather")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(secondaryTextColor.opacity(0.78))
                        .lineLimit(1)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(14)
            } else {
                WidgetLockedView(style: .homeSmall)
                    .padding(14)
            }
        }
        .containerBackground(for: .widget) {
            WidgetGlassBackground(cornerRadius: 24, renderingMode: widgetRenderingMode)
        }
    }
}

private struct SmallWidgetTemperatureText: View {
    let value: String
    let primaryText: Color

    private var numberPart: String {
        value.filter(\.isNumber)
    }

    private var suffixPart: String {
        let numbers = numberPart
        return String(value.dropFirst(numbers.count))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(numberPart)
                .font(.system(size: 48, weight: .ultraLight))
                .tracking(-2.4)

            Text(suffixPart)
                .font(.system(size: 25, weight: .ultraLight))
                .baselineOffset(4)
                .padding(.leading, -1)
        }
        .foregroundStyle(primaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
}

#Preview(as: .systemSmall) {
    GlanceHomeSmallWidget()
} timeline: {
    GlanceWidgetEntry.placeholder
}
