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
                VStack(spacing: 14) {
                    headerSection
                    currentConditionsCard
                    summaryCard
                    detailsGridCard
                    dailyForecastCard
                    footerSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
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
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text("Just now")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Button(action: { onSettingsTapped?() }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1.2)
                            .background(Circle().fill(.white.opacity(0.08)))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: – Current Conditions Card

    private var currentConditionsCard: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 0) {
                // Left: temp + condition
                VStack(alignment: .leading, spacing: 2) {
                    Text(temp(primaryCurrentTemperature))
                        .font(.system(size: 64, weight: .ultraLight, design: .rounded))
                        .tracking(-2.5)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(snapshot.conditionDescription)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))

                    Text(secondaryTemperatureLabel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(width: 130, alignment: .leading)

                Spacer(minLength: 0)

                // Right: hourly strip
                HStack(spacing: 0) {
                    ForEach(snapshot.hourly.prefix(6)) { hour in
                        VStack(spacing: 8) {
                            Text(compactLabel(hour.timeLabel))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))

                            WeatherIconView(condition: hour.condition)
                                .frame(width: 22, height: 22)
                                .foregroundStyle(.white.opacity(0.9))

                            Text(temp(hour.displayTemperature(showFeelsLike: showFeelsLikeTemperatures)))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
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
            HStack(alignment: .center, spacing: 14) {
                WeatherIconView(condition: snapshot.condition)
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.white.opacity(0.75))

                Text(snapshot.spotlightSubtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }

    // MARK: – Details Grid Card

    private var detailsGridCard: some View {
        GlassCard {
            let wind    = metricValue("Wind",        fallback: "--")
            let windDir = metricDetail("Wind",       fallback: "")
            let humidity = metricValue("Humidity",   fallback: "--")
            let sunset  = metricValue("Sunset", from: snapshot.overviewMetrics, fallback: "--")
            let aqVal   = metricValue("Air Quality", from: snapshot.overviewMetrics, fallback: "--")
            let aqLabel = metricDetail("Air Quality", from: snapshot.overviewMetrics, fallback: "Good")
            let vis     = metricValue("Visibility",  fallback: "--")
            let pressure = metricValue("Pressure",   fallback: "--")

            VStack(spacing: 0) {
                // Row 1
                HStack(spacing: 0) {
                    DetailCell(
                        icon: "wind",
                        title: "Wind",
                        value: wind,
                        sub: windDir
                    )
                    cellDivider
                    DetailCell(
                        icon: "humidity",
                        title: "Humidity",
                        value: humidity,
                        sub: nil
                    )
                    cellDivider
                    DetailCell(
                        icon: "sunset",
                        title: "Sunset",
                        value: sunset,
                        sub: nil
                    )
                }

                rowDivider

                // Row 2
                HStack(spacing: 0) {
                    DetailCellAQI(value: aqVal, label: aqLabel)
                    cellDivider
                    DetailCell(
                        icon: "eye",
                        title: "Visibility",
                        value: vis,
                        sub: nil
                    )
                    cellDivider
                    let pressureDetail = metricDetail("Pressure", fallback: "Steady")
                    DetailCell(
                        icon: "gauge",
                        title: "Pressure",
                        value: pressure,
                        sub: pressureDetail.isEmpty ? "Steady" : pressureDetail
                    )
                }
            }
            .padding(.vertical, 4)
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
            .padding(.vertical, 6)
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
        HStack(spacing: 10) {
            Text(day.dayLabel)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 46, alignment: .leading)

            WeatherIconView(condition: day.condition)
                .frame(width: 22, height: 22)
                .foregroundStyle(.white.opacity(0.85))

            Text(temp(day.lowTemperature))
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 36, alignment: .trailing)

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
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
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
