import WidgetKit
import SwiftUI

/// Lock Screen inline widget — single-line summary above the clock.
struct GlanceInlineWidget: Widget {
    static let kind = "GlanceInlineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: GlanceProvider()) { entry in
            GlanceInlineEntryView(entry: entry)
        }
        .configurationDisplayName("SkyGlance")
        .description("Current conditions at a glance.")
        .supportedFamilies([.accessoryInline])
    }
}

struct GlanceInlineEntryView: View {
    let entry: GlanceWidgetEntry

    var body: some View {
        Group {
            if WidgetAccessPolicy.canRenderWeather {
                InlineSummaryView(condition: entry.currentCondition, text: entry.inlineSummary)
            } else {
                Label("Open SkyGlance", systemImage: "cloud.sun.fill")
            }
        }
            .widgetAccentable()
            .foregroundStyle(.white)
            .widgetURL(WidgetAccessPolicy.interactionURL(kind: GlanceInlineWidget.kind))
    }
}

#Preview(as: .accessoryInline) {
    GlanceInlineWidget()
} timeline: {
    GlanceWidgetEntry.placeholder
}
