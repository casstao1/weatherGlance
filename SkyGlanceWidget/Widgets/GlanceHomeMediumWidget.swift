import SwiftUI
import WidgetKit

struct GlanceHomeMediumWidget: Widget {
    static let kind = "GlanceHomeMediumWidgetV3"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: GlanceProvider()) { entry in
            GlanceHomeMediumEntryView(entry: entry)
        }
        .configurationDisplayName("SkyGlance")
        .description("Current weather with a compact hourly forecast.")
        .supportedFamilies([.systemMedium])
    }
}

struct GlanceHomeMediumEntryView: View {
    let entry: GlanceWidgetEntry

    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    @AppStorage(
        SharedLocationStore.showFeelsLikeTemperaturesKey,
        store: SharedLocationStore.defaults
    ) private var showFeelsLikeTemperatures: Bool = false
    @AppStorage(
        SharedLocationStore.homeWidgetDarkModeKey,
        store: SharedLocationStore.defaults
    ) private var legacyHomeWidgetDarkMode: Bool = false
    @AppStorage(
        SharedLocationStore.homeWidgetAppearanceModeKey,
        store: SharedLocationStore.defaults
    ) private var homeWidgetAppearanceModeRawValue: String = ""

    private var palette: HomeWidgetPalette {
        HomeWidgetPalette(isDarkMode: isHomeWidgetDarkMode)
    }

    private var isHomeWidgetDarkMode: Bool {
        HomeWidgetAppearanceMode
            .resolved(
                rawValue: homeWidgetAppearanceModeRawValue,
                legacyDarkMode: legacyHomeWidgetDarkMode
            )
            .isDark(for: entry)
    }

    var body: some View {
        Group {
            if WidgetAccessPolicy.canRenderWeather {
                GeometryReader { proxy in
                    let leftColumnWidth = min(max(proxy.size.width * 0.29, 112), 124)
                    let columnGap: CGFloat = 9
                    let rightColumnWidth = max(proxy.size.width - leftColumnWidth - columnGap, 0)
                    let hourlySpacing = min(max(rightColumnWidth * 0.055, 5), 18)
                    let hourlyItemWidth = max((rightColumnWidth - hourlySpacing * 5) / 6, 24)

                    ZStack(alignment: .bottomTrailing) {
                        HStack(alignment: .top, spacing: columnGap) {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 4) {
                                    Text(entry.cityName ?? "Current Location")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(palette.primaryText)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)

                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundStyle(palette.primaryText)
                                        .rotationEffect(.degrees(20))
                                }

                                WidgetTemperatureText(
                                    value: "\(entry.displayCurrentTemperature(showFeelsLike: showFeelsLikeTemperatures))°",
                                    primaryText: palette.primaryText
                                )
                                .padding(.top, 11)

                                Text(entry.currentCondition.accessibilityLabel.capitalized)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(palette.primaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                    .padding(.top, 4)

                                Text(entry.secondaryTemperatureLabel(showFeelsLike: showFeelsLikeTemperatures))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(palette.secondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                    .padding(.top, 1)

                                HStack(spacing: 4) {
                                    Image(systemName: entry.homeSunEventSymbol)
                                    Text(entry.homeSunEventTime)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                }
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(palette.secondaryText)
                                .padding(.top, 12)
                            }
                            .frame(width: leftColumnWidth, alignment: .leading)
                            .layoutPriority(1)

                            HStack(alignment: .top, spacing: hourlySpacing) {
                                ForEach(entry.hours.prefix(6)) { item in
                                    HourlyForecastItemView(
                                        item: item,
                                        textColor: palette.primaryText,
                                        showFeelsLikeTemperatures: showFeelsLikeTemperatures
                                    )
                                    .frame(width: hourlyItemWidth)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)

                        Text(" Weather")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(palette.secondaryText.opacity(0.78))
                            .lineLimit(1)
                            .accessibilityHidden(true)
                    }
                }
            } else {
                WidgetLockedView(style: .homeMedium, isHomeWidgetDarkMode: isHomeWidgetDarkMode)
            }
        }
        .containerBackground(for: .widget) {
            WidgetGlassBackground(
                cornerRadius: 28,
                renderingMode: widgetRenderingMode,
                isDarkMode: isHomeWidgetDarkMode
            )
        }
    }
}

struct HomeWidgetPalette {
    let isDarkMode: Bool

    var primaryText: Color {
        isDarkMode ? Color.white.opacity(0.94) : Color.black.opacity(0.84)
    }

    var secondaryText: Color {
        isDarkMode ? Color.white.opacity(0.58) : Color.black.opacity(0.58)
    }
}

struct WidgetLockedView: View {
    enum Style {
        case homeSmall
        case homeMedium
        case accessoryCircular
        case accessoryRectangular
    }

    let style: Style
    var isHomeWidgetDarkMode: Bool = false

    private var palette: HomeWidgetPalette {
        HomeWidgetPalette(isDarkMode: isHomeWidgetDarkMode)
    }

    var body: some View {
        switch style {
        case .homeSmall:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(palette.primaryText)

                Spacer(minLength: 0)

                Text("Trial ended")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.primaryText)

                Text("Open app to unlock")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

        case .homeMedium:
            HStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(palette.primaryText)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Trial ended")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.primaryText)

                    Text("Open SkyGlance to unlock lifetime access.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

        case .accessoryCircular:
            VStack(spacing: 3) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))

                Text("Pro")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }

        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Trial ended")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("Open app to unlock")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HourlyForecastItemView: View {
    let item: HourForecastItem
    let textColor: Color
    let showFeelsLikeTemperatures: Bool

    var body: some View {
        VStack(spacing: 9) {
            Text(item.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)

            Image(systemName: item.condition.widgetSymbol)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 18.5, weight: .light))
                .foregroundStyle(textColor)
                .frame(width: 22, height: 22)

            Text("\(item.displayTemperature(showFeelsLike: showFeelsLikeTemperatures))°")
                .font(.system(size: 14.5, weight: .regular))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}

private struct WidgetTemperatureText: View {
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
                .font(.system(size: 52, weight: .ultraLight))
                .tracking(-3.5)

            Text(suffixPart)
                .font(.system(size: 28, weight: .ultraLight))
                .baselineOffset(4)
                .padding(.leading, -1)
        }
        .foregroundStyle(primaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
}

struct WidgetMonochromeWeatherIcon: View {
    let condition: WeatherCondition
    let pointSize: CGFloat

    var body: some View {
        Image(systemName: condition.widgetSymbol)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: pointSize, weight: .regular))
            .frame(width: pointSize + 6, height: pointSize + 6)
            .accessibilityHidden(true)
    }
}

struct WidgetGlassBackground: View {
    let cornerRadius: CGFloat
    let renderingMode: WidgetRenderingMode
    let isDarkMode: Bool

    private var isFullColor: Bool {
        renderingMode == .fullColor
    }

    private var baseColor: Color {
        isDarkMode
        ? Color.black
        : Color(red: 247.0 / 255.0, green: 247.0 / 255.0, blue: 245.0 / 255.0)
    }

    private var glassColors: [Color] {
        isDarkMode
        ? [
            Color.black.opacity(0.82),
            Color.black.opacity(0.42),
            Color.black.opacity(0.18),
        ]
        : [
            Color.white.opacity(0.82),
            Color.white.opacity(0.42),
            Color.white.opacity(0.18),
        ]
    }

    private var radialHighlight: [Color] {
        isDarkMode
        ? [
            Color.black.opacity(0.30),
            Color.clear,
        ]
        : [
            Color.white.opacity(0.30),
            Color.clear,
        ]
    }

    private var borderColor: Color {
        isDarkMode ? Color.black.opacity(0.55) : Color.white.opacity(0.55)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    isFullColor
                    ? baseColor
                    : Color.clear
                )

            if isFullColor {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: glassColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: radialHighlight,
                            center: .topLeading,
                            startRadius: 12,
                            endRadius: 180
                        )
                    )

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
        }
    }
}

#Preview(as: .systemMedium) {
    GlanceHomeMediumWidget()
} timeline: {
    GlanceWidgetEntry.placeholder
}
