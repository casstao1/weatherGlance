import SwiftUI

enum ForecastStripStyle {
    case heroSixHour
    case compactFiveHour
    case appPreview

    var columnSpacing: CGFloat {
        switch self {
        case .heroSixHour:
            4
        case .appPreview:
            12
        case .compactFiveHour:
            4
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .heroSixHour:
            16
        case .appPreview:
            18
        case .compactFiveHour:
            10
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .heroSixHour:
            12
        case .appPreview:
            16
        case .compactFiveHour:
            12
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .heroSixHour:
            28
        case .appPreview:
            28
        case .compactFiveHour:
            28
        }
    }

    var labelFont: Font {
        switch self {
        case .heroSixHour:
            .system(size: 10, weight: .medium)
        case .appPreview:
            .system(size: 12, weight: .regular)
        case .compactFiveHour:
            .system(size: 10, weight: .medium)
        }
    }

    var temperatureFont: Font {
        switch self {
        case .heroSixHour:
            .system(size: 16, weight: .regular)
        case .appPreview:
            .system(size: 18, weight: .regular)
        case .compactFiveHour:
            .system(size: 14, weight: .regular)
        }
    }

    var verticalSpacing: CGFloat {
        switch self {
        case .heroSixHour:
            9
        case .appPreview:
            10
        case .compactFiveHour:
            8
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .heroSixHour:
            19
        case .appPreview:
            22
        case .compactFiveHour:
            17
        }
    }

    var labelTracking: CGFloat {
        switch self {
        case .heroSixHour:
            0.0
        case .appPreview:
            0.0
        case .compactFiveHour:
            0.0
        }
    }
}

struct HourColumnView: View {
    let item: HourForecastItem
    let theme: GlanceTheme
    let style: ForecastStripStyle

    private var isCurrentHour: Bool {
        item.label == "Now"
    }

    private var dotSize: CGFloat {
        switch style {
        case .heroSixHour:
            6
        case .appPreview:
            7
        case .compactFiveHour:
            5
        }
    }

    @ViewBuilder
    private var labelView: some View {
        if isCurrentHour {
            Circle()
                .fill(theme.secondaryText)
                .frame(width: dotSize, height: dotSize)
                .frame(maxWidth: .infinity, minHeight: 12, alignment: .center)
                .offset(y: -1)
        } else {
            Text(item.label)
                .font(style.labelFont)
                .tracking(style.labelTracking)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    var body: some View {
        VStack(spacing: style.verticalSpacing) {
            labelView

            WeatherIconView(condition: item.condition)
                .frame(width: style.iconSize, height: style.iconSize)
                .foregroundStyle(theme.primaryText)

            Text("\(item.temperature)")
                .font(style.temperatureFont)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .foregroundStyle(theme.primaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityDescription)
    }
}

#Preview {
    let item = HourForecastItem(label: "Now", condition: .sunny, temperature: 72)
    let theme = GlanceThemeResolver.theme(for: .warm, colorScheme: .dark)
    return HourColumnView(item: item, theme: theme, style: .heroSixHour)
        .frame(width: 60)
        .padding()
        .background(Color.black)
}
