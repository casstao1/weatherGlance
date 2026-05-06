import SwiftUI

struct AppDashboardView: View {
    private let appleWeatherAttributionURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    let snapshot: AppWeatherSnapshot
    let theme: GlanceTheme
    var useCelsius: Bool = false
    var showFeelsLikeTemperatures: Bool = false
    var onSettingsTapped: (() -> Void)? = nil

    var body: some View {
        ZStack {
            appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 11) {
                    headerSection
                    currentConditionsCard
                    dailyForecastCard
                    summaryCard
                    weatherLayersCard
                    detailsGridCard
                    footerSection
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: – Temperature helper

    private func temp(_ fahrenheit: Int) -> String {
        if useCelsius {
            let c = Int(round(Double(fahrenheit - 32) * 5.0 / 9.0))
            return "\(c)°"
        }
        return "\(fahrenheit)°"
    }

    private var unitSymbol: String { useCelsius ? "C" : "F" }

    private var primaryCurrentTemperature: Int {
        showFeelsLikeTemperatures ? snapshot.feelsLikeTemperature : snapshot.currentTemperature
    }

    private var secondaryTemperatureLabel: String {
        showFeelsLikeTemperatures
            ? "Actual \(temp(snapshot.currentTemperature))"
            : "Feels like \(temp(snapshot.feelsLikeTemperature))"
    }

    // MARK: – Background

    private var appBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.17, green: 0.22, blue: 0.31),
                    Color(red: 0.28, green: 0.34, blue: 0.44),
                    Color(red: 0.18, green: 0.21, blue: 0.29),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.white.opacity(0.18), Color.clear],
                center: .leading,
                startRadius: 24,
                endRadius: 380
            )
            RadialGradient(
                colors: [Color.white.opacity(0.10), Color.clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 260
            )
        }
    }

    // MARK: – Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(snapshot.cityName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Image(systemName: "location.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text("Just now")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Button(action: { onSettingsTapped?() }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1.2)
                            .background(Circle().fill(.white.opacity(0.08)))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }

    // MARK: – Current Conditions Card

    private var currentConditionsCard: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 10) {
                // Left: temp + condition
                VStack(alignment: .leading, spacing: 2) {
                    Text(temp(primaryCurrentTemperature))
                        .font(.system(size: 56, weight: .ultraLight, design: .rounded))
                        .tracking(-2)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(snapshot.conditionDescription)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))

                    Text(secondaryTemperatureLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(width: 104, alignment: .leading)

                // Right: scrollable hourly strip
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(snapshot.hourly) { hour in
                            hourlyForecastColumn(hour)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
    }

    private func hourlyForecastColumn(_ hour: AppHourlyForecast) -> some View {
        VStack(spacing: 8) {
            Text(compactLabel(hour.timeLabel))
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            WeatherIconView(condition: hour.condition)
                .frame(width: 20, height: 20)
                .foregroundStyle(.white.opacity(0.9))

            Text(temp(hour.displayTemperature(showFeelsLike: showFeelsLikeTemperatures)))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(width: 34)
    }

    private func compactLabel(_ label: String) -> String {
        if label == "Now" { return label }
        return label
            .replacingOccurrences(of: " AM", with: "A")
            .replacingOccurrences(of: " PM", with: "P")
    }

    // MARK: – Summary Card

    private var summaryCard: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 12) {
                WeatherIconView(condition: snapshot.condition)
                    .frame(width: 26, height: 26)
                    .foregroundStyle(.white.opacity(0.75))

                Text(snapshot.spotlightSubtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    // MARK: – Details Grid Card

    private var weatherLayersCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(
                    icon: "map.fill",
                    title: "Sky Layers",
                    subtitle: "Precipitation, temperature, air, and wind signals at a glance."
                )

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ],
                    spacing: 8
                ) {
                    WeatherLayerTile(
                        icon: "cloud.rain.fill",
                        title: "Precipitation",
                        value: nextPrecipitation.value,
                        detail: nextPrecipitation.detail,
                        accent: Color(red: 0.46, green: 0.78, blue: 1.0)
                    )
                    WeatherLayerTile(
                        icon: "thermometer",
                        title: "Temperature",
                        value: temp(primaryCurrentTemperature),
                        detail: "\(temp(snapshot.lowTemperature)) to \(temp(snapshot.highTemperature)) today",
                        accent: Color(red: 1.0, green: 0.72, blue: 0.42)
                    )
                    WeatherLayerTile(
                        icon: "aqi.medium",
                        title: "Air Quality",
                        value: metricValue("Air Quality", from: snapshot.overviewMetrics, fallback: "--"),
                        detail: metricDetail("Air Quality", from: snapshot.overviewMetrics, fallback: "Not available"),
                        accent: airQualityColor
                    )
                    WeatherLayerTile(
                        icon: "wind",
                        title: "Wind",
                        value: metricValue("Wind", fallback: "--"),
                        detail: metricDetail("Wind", fallback: ""),
                        accent: Color(red: 0.78, green: 0.86, blue: 1.0)
                    )
                }
            }
            .padding(12)
        }
    }

    private var detailsGridCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(
                    icon: "sparkles.rectangle.stack.fill",
                    title: "Atmosphere Matrix",
                    subtitle: nil
                )

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ],
                    spacing: 8
                ) {
                    ForEach(detailItems) { item in
                        WeatherDetailTile(item: item)
                    }
                }
            }
            .padding(12)
        }
    }

    private var cellDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 0.5)
            .padding(.vertical, 10)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    private func metricValue(_ title: String, from metrics: [AppMetric]? = nil, fallback: String) -> String {
        let source = metrics ?? snapshot.detailMetrics
        return source.first(where: { $0.title == title })?.value ?? fallback
    }

    private func metricDetail(_ title: String, from metrics: [AppMetric]? = nil, fallback: String) -> String {
        let source = metrics ?? snapshot.detailMetrics
        return source.first(where: { $0.title == title })?.detail ?? fallback
    }

    private var nextPrecipitation: (value: String, detail: String) {
        if let hour = snapshot.hourly.dropFirst().first(where: { ($0.precipitationChance ?? 0) > 0 }),
           let chance = hour.precipitationChance {
            return ("\(chance)%", "around \(compactLabel(hour.timeLabel))")
        }

        if let day = snapshot.daily.first(where: { ($0.precipitationChance ?? 0) > 0 }),
           let chance = day.precipitationChance {
            return ("\(chance)%", day.dayLabel)
        }

        return ("0%", "No near-term signal")
    }

    private var airQualityColor: Color {
        let value = Int(metricValue("Air Quality", from: snapshot.overviewMetrics, fallback: "0")) ?? 0
        if value <= 50 { return Color(red: 0.35, green: 0.92, blue: 0.45) }
        if value <= 100 { return Color(red: 0.95, green: 0.78, blue: 0.18) }
        return Color(red: 1.0, green: 0.48, blue: 0.28)
    }

    private var moonPhase: (value: String, detail: String) {
        let knownNewMoon = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2000,
            month: 1,
            day: 6,
            hour: 18,
            minute: 14
        ).date ?? Date()
        let lunarCycle = 29.53058867
        let daysSinceNewMoon = Date().timeIntervalSince(knownNewMoon) / 86_400
        let phase = (daysSinceNewMoon / lunarCycle).truncatingRemainder(dividingBy: 1)

        switch phase {
        case 0..<0.03, 0.97...1:
            return ("New", "Low moonlight")
        case 0.03..<0.22:
            return ("Waxing", "Crescent")
        case 0.22..<0.28:
            return ("First", "Quarter")
        case 0.28..<0.47:
            return ("Waxing", "Gibbous")
        case 0.47..<0.53:
            return ("Full", "Brightest phase")
        case 0.53..<0.72:
            return ("Waning", "Gibbous")
        case 0.72..<0.78:
            return ("Last", "Quarter")
        default:
            return ("Waning", "Crescent")
        }
    }

    private var detailItems: [WeatherDetailItem] {
        let pressureDetail = metricDetail("Pressure", fallback: "Steady")
        let moon = moonPhase

        return [
            WeatherDetailItem(
                icon: "cloud.rain.fill",
                title: "Precipitation",
                value: nextPrecipitation.value,
                detail: nextPrecipitation.detail,
                accent: Color(red: 0.46, green: 0.78, blue: 1.0)
            ),
            WeatherDetailItem(
                icon: "sun.max.fill",
                title: "UV Index",
                value: metricValue("UV Index", from: snapshot.overviewMetrics, fallback: "--"),
                detail: metricDetail("UV Index", from: snapshot.overviewMetrics, fallback: "Not available"),
                accent: Color(red: 1.0, green: 0.78, blue: 0.30)
            ),
            WeatherDetailItem(
                icon: "thermometer.medium",
                title: "Feels Like",
                value: metricValue("Feels Like", fallback: temp(snapshot.feelsLikeTemperature)),
                detail: showFeelsLikeTemperatures ? "Shown as primary" : "Comfort read",
                accent: Color(red: 1.0, green: 0.70, blue: 0.48)
            ),
            WeatherDetailItem(
                icon: "wind",
                title: "Wind",
                value: metricValue("Wind", fallback: "--"),
                detail: metricDetail("Wind", fallback: ""),
                accent: Color(red: 0.78, green: 0.86, blue: 1.0)
            ),
            WeatherDetailItem(
                icon: "humidity.fill",
                title: "Humidity",
                value: metricValue("Humidity", fallback: "--"),
                detail: "Moisture",
                accent: Color(red: 0.50, green: 0.82, blue: 1.0)
            ),
            WeatherDetailItem(
                icon: "drop.fill",
                title: "Dew Point",
                value: metricValue("Dew Point", fallback: "--"),
                detail: "Condensation point",
                accent: Color(red: 0.58, green: 0.90, blue: 1.0)
            ),
            WeatherDetailItem(
                icon: "gauge.medium",
                title: "Pressure",
                value: metricValue("Pressure", fallback: "--"),
                detail: pressureDetail.isEmpty ? "Steady" : pressureDetail,
                accent: Color(red: 0.74, green: 0.76, blue: 0.96)
            ),
            WeatherDetailItem(
                icon: "eye.fill",
                title: "Visibility",
                value: metricValue("Visibility", fallback: "--"),
                detail: "Line of sight",
                accent: Color(red: 0.70, green: 0.88, blue: 1.0)
            ),
            WeatherDetailItem(
                icon: "aqi.medium",
                title: "Air Quality",
                value: metricValue("Air Quality", from: snapshot.overviewMetrics, fallback: "--"),
                detail: metricDetail("Air Quality", from: snapshot.overviewMetrics, fallback: "Not available"),
                accent: airQualityColor
            ),
            WeatherDetailItem(
                icon: "sunrise.fill",
                title: "Sunrise",
                value: metricValue("Sunrise", from: snapshot.overviewMetrics, fallback: "--"),
                detail: "First light",
                accent: Color(red: 1.0, green: 0.76, blue: 0.45)
            ),
            WeatherDetailItem(
                icon: "sunset.fill",
                title: "Sunset",
                value: metricValue("Sunset", from: snapshot.overviewMetrics, fallback: "--"),
                detail: "Last light",
                accent: Color(red: 1.0, green: 0.58, blue: 0.50)
            ),
            WeatherDetailItem(
                icon: "moon.stars.fill",
                title: "Moon",
                value: moon.value,
                detail: moon.detail,
                accent: Color(red: 0.78, green: 0.72, blue: 1.0)
            ),
        ]
    }

    // MARK: – Daily Forecast Card

    private var dailyForecastCard: some View {
        GlassCard {
            let allLows  = snapshot.daily.map { $0.lowTemperature }
            let allHighs = snapshot.daily.map { $0.highTemperature }
            let weekMin  = allLows.min()  ?? 0
            let weekMax  = allHighs.max() ?? 100

            VStack(spacing: 0) {
                ForEach(Array(snapshot.daily.prefix(7).enumerated()), id: \.element.id) { idx, day in
                    DailyRow(
                        day: day,
                        weekMin: weekMin,
                        weekMax: weekMax,
                        useCelsius: useCelsius
                    )

                    if idx < min(snapshot.daily.count, 7) - 1 {
                        Rectangle()
                            .fill(.white.opacity(0.10))
                            .frame(height: 0.5)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    // MARK: – Footer

    private var footerSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text("Weather data from")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.48))
                Text(" Weather")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                Text("and Open-Meteo")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Link(destination: appleWeatherAttributionURL) {
                Text("Apple Weather legal attribution")
                    .font(.system(size: 12, weight: .medium))
                    .underline()
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .padding(.top, 4)
        .multilineTextAlignment(.center)
    }
}

// MARK: – Glass Card

private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.10))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.12), .white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.8)

            content
        }
    }
}

private struct SectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(.white.opacity(0.10))
                )
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.14), lineWidth: 0.7)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.56))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct WeatherLayerTile: View {
    let icon: String
    let title: String
    let value: String
    let detail: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Text(value.isEmpty ? "--" : value)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(detail.isEmpty ? "Current signal" : detail)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.54))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accent.opacity(0.24), lineWidth: 0.8)
        )
    }
}

private struct WeatherDetailItem: Identifiable {
    var id: String { title }
    let icon: String
    let title: String
    let value: String
    let detail: String
    let accent: Color
}

private struct WeatherDetailTile: View {
    let item: WeatherDetailItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(item.accent)
                    .frame(width: 14)

                Text(item.title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(item.value.isEmpty ? "--" : item.value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Text(item.detail.isEmpty ? "Current" : item.detail)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.12),
                            .white.opacity(0.045),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.7)
        )
    }
}

// MARK: – Detail Cell

private struct DetailCell: View {
    let icon: String
    let title: String
    let value: String
    let sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: sfSymbol(for: icon))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let sub, !sub.isEmpty {
                Text(sub)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func sfSymbol(for key: String) -> String {
        switch key {
        case "wind":     return "wind"
        case "humidity": return "humidity"
        case "sunset":   return "sunset"
        case "eye":      return "eye"
        case "gauge":    return "gauge.medium"
        default:         return "circle"
        }
    }
}

private struct DetailCellAQI: View {
    let value: String
    let label: String

    private var aqiColor: Color {
        let n = Int(value) ?? 0
        if n <= 50  { return .green }
        if n <= 100 { return Color(red: 0.9, green: 0.75, blue: 0) }
        return .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "aqi.medium")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Air Quality")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 5) {
                Circle().fill(aqiColor).frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(aqiColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: – Daily Row

private struct DailyRow: View {
    let day: AppDailyForecast
    let weekMin: Int
    let weekMax: Int
    let useCelsius: Bool

    private func temp(_ f: Int) -> String {
        if useCelsius {
            return "\(Int(round(Double(f - 32) * 5.0 / 9.0)))°"
        }
        return "\(f)°"
    }

    private var barLeading: CGFloat {
        let range = Double(max(weekMax - weekMin, 1))
        return CGFloat((Double(day.lowTemperature - weekMin)) / range)
    }

    private var barTrailing: CGFloat {
        let range = Double(max(weekMax - weekMin, 1))
        return 1.0 - CGFloat((Double(day.highTemperature - weekMin)) / range)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(day.dayLabel)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: 54, alignment: .leading)

            WeatherIconView(condition: day.condition)
                .frame(width: 20, height: 20)
                .foregroundStyle(.white.opacity(0.85))

            Text(temp(day.lowTemperature))
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: 32, alignment: .trailing)

            // Temperature range bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.18))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.45, green: 0.65, blue: 0.95),
                                    Color(red: 0.75, green: 0.85, blue: 1.0),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * (1.0 - barLeading - barTrailing),
                            height: geo.size.height
                        )
                        .offset(x: geo.size.width * barLeading)
                }
            }
            .frame(height: 5)

            Text(temp(day.highTemperature))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: 32, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

#Preview {
    AppDashboardView(
        snapshot: .placeholder,
        theme: GlanceThemeResolver.widgetGlassTheme(colorScheme: .dark),
        useCelsius: false,
        showFeelsLikeTemperatures: false
    )
}
