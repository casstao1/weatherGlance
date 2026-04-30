import WidgetKit
import SwiftUI

/// Lock Screen rectangular bottom widget.
struct GlanceLockScreenWidget: Widget {
    static let kind = "GlanceLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: GlanceProvider()) { entry in
            GlanceLockScreenEntryView(entry: entry)
        }
        .configurationDisplayName("SkyGlance")
        .description("Compact 5-hour forecast on your lock screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: – Shared Entry View

struct GlanceLockScreenEntryView: View {
    let entry: GlanceWidgetEntry

    @AppStorage(
        SharedLocationStore.showFeelsLikeTemperaturesKey,
        store: SharedLocationStore.defaults
    ) private var showFeelsLikeTemperatures: Bool = false

    private var items: [HourForecastItem] {
        entry.hourItems
    }

    var body: some View {
        Group {
            if WidgetAccessPolicy.canRenderWeather {
                HStack(spacing: 5) {
                    ForEach(items) { item in
                        LockHourColumnView(
                            item: item,
                            referenceDate: entry.date,
                            showFeelsLikeTemperatures: showFeelsLikeTemperatures
                        )
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 1)
                .padding(.vertical, 1)
            } else {
                WidgetLockedView(style: .accessoryRectangular)
            }
        }
        .widgetAccentable()
        .foregroundStyle(.white)
        .background(Color.clear)
        .containerBackground(Color.clear, for: .widget)
    }
}

private struct LockHourColumnView: View {
    let item: HourForecastItem
    let referenceDate: Date
    let showFeelsLikeTemperatures: Bool

    private var isCurrentHour: Bool {
        item.label == "Now"
    }

    private var labelFont: Font {
        .system(size: 15, weight: .semibold, design: .rounded)
    }

    private var temperatureFont: Font {
        labelFont
    }

    private var iconSize: CGFloat {
        22
    }

    private var currentHourLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: referenceDate)
            .replacingOccurrences(of: "AM", with: "A")
            .replacingOccurrences(of: "PM", with: "P")
    }

    private var displayLabel: String {
        if isCurrentHour {
            return currentHourLabel
        }
        return item.label
    }

    @ViewBuilder
    private var labelView: some View {
        Text(displayLabel)
            .font(labelFont)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(Color.white.opacity(0.92))
    }

    var body: some View {
        VStack(spacing: 6) {
            labelView

            WeatherIconView(condition: item.condition)
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(Color.white.opacity(0.95))

            Text("\(item.displayTemperature(showFeelsLike: showFeelsLikeTemperatures))")
                .font(temperatureFont)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Color.white.opacity(0.96))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityDescription(showFeelsLike: showFeelsLikeTemperatures))
    }
}

// MARK: – Previews

#Preview("5-hour", as: .accessoryRectangular) {
    GlanceLockScreenWidget()
} timeline: {
    GlanceWidgetEntry.placeholder
}
