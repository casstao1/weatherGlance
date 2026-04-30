import WidgetKit
import SwiftUI

/// Lock Screen circular widget for the standard compact slot.
struct GlanceCircularWidget: Widget {
    static let kind = "GlanceCircularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: GlanceProvider()) { entry in
            GlanceCircularEntryView(entry: entry)
        }
        .configurationDisplayName("SkyGlance")
        .description("Current temperature for your lock screen.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct GlanceCircularEntryView: View {
    let entry: GlanceWidgetEntry

    @AppStorage(
        SharedLocationStore.showFeelsLikeTemperaturesKey,
        store: SharedLocationStore.defaults
    ) private var showFeelsLikeTemperatures: Bool = false

    var body: some View {
        let displayTemperature = entry.displayCurrentTemperature(showFeelsLike: showFeelsLikeTemperatures)

        Group {
            if WidgetAccessPolicy.canRenderWeather {
                VStack(spacing: 3) {
                    WeatherIconView(condition: entry.currentCondition)
                        .frame(width: 20, height: 20)

                    Text("\(displayTemperature)")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(entry.currentCondition.accessibilityLabel), \(displayTemperature) degrees")
            } else {
                WidgetLockedView(style: .accessoryCircular)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Trial ended. Open app to unlock.")
            }
        }
        .widgetAccentable()
        .foregroundStyle(.white)
        .background(Color.clear)
        .containerBackground(Color.clear, for: .widget)
    }
}

#Preview(as: .accessoryCircular) {
    GlanceCircularWidget()
} timeline: {
    GlanceWidgetEntry.placeholder
}
