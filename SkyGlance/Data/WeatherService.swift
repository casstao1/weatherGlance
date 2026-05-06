import Foundation
import WeatherKit
import CoreLocation
import WidgetKit

/// Fetches weather data and builds app/widget models.
@MainActor
final class WeatherService: ObservableObject {

    private struct RefreshFingerprint {
        let latitude: Double
        let longitude: Double
        let cityName: String?
        let timestamp: Date
    }

    private typealias ForecastBundle = (entries: [GlanceWidgetEntry], snapshot: AppWeatherSnapshot)

    static let shared = WeatherService()

    private let service = WeatherKit.WeatherService.shared
    private let openMeteoService = OpenMeteoService()
    private let mapper = TimelineMapper()
    private let calendar = Calendar.autoupdatingCurrent
    private let dashboardSnapshotStaleInterval: TimeInterval = 15 * 60
    private var refreshGeneration = 0
    private var lastRefreshFingerprint: RefreshFingerprint?
    private var dashboardSnapshotPublishedAt: Date?

    @Published var latestEntry: GlanceWidgetEntry = .placeholder
    @Published var dashboardSnapshot: AppWeatherSnapshot = .placeholder
    @Published private(set) var hasLoadedDashboardSnapshot = false

    private var shouldAttemptWeatherKit: Bool {
        let processInfo = ProcessInfo.processInfo
        return processInfo.arguments.contains("-skyglanceEnableWeatherKit")
            || processInfo.environment["SKYGLANCE_ENABLE_WEATHERKIT"] == "1"
            || processInfo.environment["SKYGLANCE_WEATHER_PROVIDER"]?.lowercased() == "weatherkit"
    }

    // MARK: – Public

    /// Fetch weather for a given location and return a timeline of entries.
    func fetchTimeline(
        for location: CLLocation,
        cityName: String? = nil
    ) async throws -> [GlanceWidgetEntry] {
        guard EntitlementStore.hasProAccess else {
            throw WeatherServiceError.proAccessRequired
        }

        if shouldAttemptWeatherKit {
            do {
                let weather = try await fetchWeatherKitForecast(for: location)
                return timelineEntries(from: weather, cityName: cityName)
            } catch {
                print("[WeatherService] WeatherKit failed; using Open-Meteo fallback: \(error)")
            }
        }

        return try await fetchOpenMeteoBundle(for: location, cityName: cityName).entries
    }

    func fetchDashboard(
        for location: CLLocation,
        cityName: String? = nil
    ) async throws -> AppWeatherSnapshot {
        guard EntitlementStore.hasProAccess else {
            throw WeatherServiceError.proAccessRequired
        }

        if shouldAttemptWeatherKit {
            do {
                let weather = try await fetchWeatherKitForecast(for: location)
                return makeDashboardSnapshot(from: weather, cityName: cityName)
            } catch {
                print("[WeatherService] WeatherKit failed; using Open-Meteo fallback: \(error)")
            }
        }

        return try await fetchOpenMeteoBundle(for: location, cityName: cityName).snapshot
    }

    private func timelineEntries(
        from weather: Weather,
        cityName: String?
    ) -> [GlanceWidgetEntry] {
        let now = Date()
        let startOfCurrentHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let feelsLike = fahrenheitValue(weather.currentWeather.apparentTemperature)
        let windSpeed = milesPerHourString(from: weather.currentWeather.wind.speed)

        // Build entries at each upcoming hour for the next 12 hours
        return (0..<12).compactMap { offset -> GlanceWidgetEntry? in
            guard let entryDate = calendar.date(byAdding: .hour, value: offset, to: startOfCurrentHour) else {
                return nil
            }

            let dailyWeather = weather.dailyForecast.first { calendar.isDate($0.date, inSameDayAs: entryDate) }
                ?? weather.dailyForecast.first
            let sunrise = dailyWeather?.sun.sunrise
            let sunset = dailyWeather?.sun.sunset

            return mapper.makeEntry(
                from: weather.hourlyForecast,
                currentWeather: offset == 0 ? weather.currentWeather : nil,
                cityName: cityName,
                at: entryDate,
                referenceDate: startOfCurrentHour,
                feelsLikeTemperature: feelsLike,
                windSpeed: windSpeed,
                sunriseTime: compactSunEventTime(sunrise),
                sunsetTime: compactSunEventTime(sunset),
                isDaylight: isDaylight(at: entryDate, sunrise: sunrise, sunset: sunset)
            )
        }
    }

    /// Convenience — fetch and publish the most current entry.
    func refresh(for location: CLLocation, cityName: String? = nil, force: Bool = false) async {
        guard EntitlementStore.hasProAccess else { return }

        let resolvedCityName = cityName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if !force, hasLoadedDashboardSnapshot, shouldSkipRefresh(for: location, cityName: resolvedCityName) {
            return
        }

        refreshGeneration += 1
        let generation = refreshGeneration
        updateRefreshFingerprint(for: location, cityName: resolvedCityName)

        if shouldAttemptWeatherKit {
            do {
                let weather = try await fetchWeatherKitForecast(for: location)
                guard generation == refreshGeneration else { return }

                let displayCityName: String
                if let resolvedCityName, !resolvedCityName.isEmpty {
                    displayCityName = resolvedCityName
                } else {
                    displayCityName = "Current Location"
                }

                let timeline = timelineEntries(from: weather, cityName: cityName)
                if let first = timeline.first {
                    latestEntry = first
                }
                SharedLocationStore.save(entries: timeline)
                WidgetCenter.shared.reloadAllTimelines()
                publishDashboardSnapshot(makeDashboardSnapshot(from: weather, cityName: displayCityName))
                return
            } catch {
                print("[WeatherService] WeatherKit failed; using Open-Meteo fallback: \(error)")
            }
        }

        do {
            let fallback = try await fetchOpenMeteoBundle(for: location, cityName: resolvedCityName)
            guard generation == refreshGeneration else { return }

            if let first = fallback.entries.first {
                latestEntry = first
            }
            SharedLocationStore.save(entries: fallback.entries)
            WidgetCenter.shared.reloadAllTimelines()
            publishDashboardSnapshot(fallback.snapshot)
        } catch {
            guard generation == refreshGeneration else { return }
            print("[WeatherService] Open-Meteo failed: \(error)")
        }
    }

    func applyResolvedCityName(_ cityName: String?) {
        guard let cityName, !cityName.isEmpty else { return }

        latestEntry = GlanceWidgetEntry(
            date: latestEntry.date,
            cityName: cityName,
            currentTemperature: latestEntry.currentTemperature,
            currentCondition: latestEntry.currentCondition,
            inlineSummary: latestEntry.inlineSummary,
            hours: latestEntry.hours,
            mood: latestEntry.mood,
            feelsLikeTemperature: latestEntry.feelsLikeTemperature,
            windSpeed: latestEntry.windSpeed,
            sunriseTime: latestEntry.sunriseTime,
            sunsetTime: latestEntry.sunsetTime,
            isDaylight: latestEntry.isDaylight
        )

        dashboardSnapshot = dashboardSnapshot.replacing(cityName: cityName)
    }

    func prepareForDashboardRefreshIfStale() {
        guard hasLoadedDashboardSnapshot else { return }
        guard let dashboardSnapshotPublishedAt else {
            hasLoadedDashboardSnapshot = false
            return
        }

        if Date().timeIntervalSince(dashboardSnapshotPublishedAt) > dashboardSnapshotStaleInterval {
            hasLoadedDashboardSnapshot = false
        }
    }

    private func publishDashboardSnapshot(_ snapshot: AppWeatherSnapshot) {
        dashboardSnapshot = snapshot
        dashboardSnapshotPublishedAt = Date()
        hasLoadedDashboardSnapshot = true
    }

    private func fetchWeatherKitForecast(for location: CLLocation) async throws -> Weather {
        let weather = try await service.weather(for: location)
        WeatherUsageStore.record(.weatherKit)
        return weather
    }

    private func fetchOpenMeteoBundle(
        for location: CLLocation,
        cityName: String?
    ) async throws -> ForecastBundle {
        let bundle = try await openMeteoService.fetchForecastBundle(for: location, cityName: cityName)
        WeatherUsageStore.record(.openMeteo)
        return bundle
    }

    private func makeDashboardSnapshot(from weather: Weather, cityName: String?) -> AppWeatherSnapshot {
        let currentCondition = WeatherCondition.from(symbolName: weather.currentWeather.symbolName)
        let today = weather.dailyForecast.first
        let hourly = makeUpcomingHourlyForecast(from: weather, now: Date())

        let daily = Array(weather.dailyForecast.prefix(7)).enumerated().map { index, day in
            AppDailyForecast(
                dayLabel: dayLabel(for: day.date, index: index),
                condition: WeatherCondition.from(symbolName: day.symbolName),
                highTemperature: fahrenheitValue(day.highTemperature),
                lowTemperature: fahrenheitValue(day.lowTemperature),
                precipitationChance: percentage(from: day.precipitationChance)
            )
        }

        let humidity = percentageString(from: weather.currentWeather.humidity)
        let feelsLike = fahrenheitValue(weather.currentWeather.apparentTemperature)
        let dewPoint = degreesString(from: weather.currentWeather.dewPoint)
        let windSpeed = milesPerHourString(from: weather.currentWeather.wind.speed)
        let pressure = pressureString(from: weather.currentWeather.pressure)
        let visibility = milesString(from: weather.currentWeather.visibility)
        let uvIndex = "\(weather.currentWeather.uvIndex.value)"
        let uvLabel = uvDetailLabel(for: weather.currentWeather.uvIndex.value)

        let sunrise = formatTime(today?.sun.sunrise)
        let sunset = formatTime(today?.sun.sunset)

        let aqiValue = proxyAQI(from: weather.currentWeather.visibility)
        let aqiLabel = aqiValue <= 50 ? "Good" : aqiValue <= 100 ? "Moderate" : "Unhealthy"

        let overviewMetrics = [
            AppMetric(title: "Air Quality", value: "\(aqiValue)", detail: aqiLabel),
            AppMetric(title: "UV Index",    value: uvIndex,        detail: uvLabel),
            AppMetric(title: "Sunrise",     value: sunrise,        detail: nil),
            AppMetric(title: "Sunset",      value: sunset,         detail: nil),
        ]

        let detailMetrics = [
            AppMetric(title: "Humidity", value: humidity, detail: nil),
            AppMetric(title: "Dew Point", value: dewPoint, detail: nil),
            AppMetric(title: "Wind", value: windSpeed, detail: weather.currentWeather.wind.compassDirection.abbreviation),
            AppMetric(title: "Pressure", value: pressure, detail: nil),
            AppMetric(title: "Visibility", value: visibility, detail: nil),
            AppMetric(title: "Feels Like", value: "\(feelsLike)°", detail: nil),
        ]

        let highestTemp = daily.map(\.highTemperature).max() ?? feelsLike
        let lowestTemp = daily.map(\.lowTemperature).min() ?? feelsLike
        let rainyHour = hourly.first(where: { ($0.precipitationChance ?? 0) >= 25 })
        let spotlightTitle = rainyHour == nil ? "Stable Conditions" : "Rain Outlook"
        let spotlightValue = rainyHour == nil
            ? "Clear stretch through the next few hours"
            : "Rain risk builds around \(rainyHour?.timeLabel ?? "--")"
        let spotlightSubtitle = "Expected range \(lowestTemp)° to \(highestTemp)° with \(currentCondition.accessibilityLabel)."

        return AppWeatherSnapshot(
            cityName: cityName ?? "Current Location",
            currentTemperature: fahrenheitValue(weather.currentWeather.temperature),
            condition: currentCondition,
            conditionDescription: currentCondition.accessibilityLabel.capitalized,
            feelsLikeTemperature: feelsLike,
            highTemperature: today.map { fahrenheitValue($0.highTemperature) } ?? feelsLike,
            lowTemperature: today.map { fahrenheitValue($0.lowTemperature) } ?? feelsLike,
            hourly: hourly,
            daily: daily,
            overviewMetrics: overviewMetrics,
            detailMetrics: detailMetrics,
            spotlightTitle: spotlightTitle,
            spotlightValue: spotlightValue,
            spotlightSubtitle: spotlightSubtitle,
            mood: WeatherMood.from(condition: currentCondition)
        )
    }

    private func fahrenheitValue(_ temperature: Measurement<UnitTemperature>) -> Int {
        Int(temperature.converted(to: .fahrenheit).value.rounded())
    }

    private func degreesString(from temperature: Measurement<UnitTemperature>) -> String {
        "\(fahrenheitValue(temperature))°"
    }

    private func percentage(from value: Double) -> Int? {
        let percent = Int((value * 100).rounded())
        return percent > 0 ? percent : nil
    }

    private func percentageString(from value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func milesPerHourString(from speed: Measurement<UnitSpeed>) -> String {
        "\(Int(speed.converted(to: .milesPerHour).value.rounded())) mph"
    }

    private func pressureString(from pressure: Measurement<UnitPressure>) -> String {
        let value = pressure.converted(to: .inchesOfMercury).value
        return String(format: "%.2f in", value)
    }

    private func milesString(from length: Measurement<UnitLength>) -> String {
        "\(Int(length.converted(to: .miles).value.rounded())) mi"
    }

    private func formatTime(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func compactSunEventTime(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.amSymbol = "A"
        formatter.pmSymbol = "P"
        formatter.dateFormat = "h:mma"
        return formatter.string(from: date)
    }

    private func isDaylight(at date: Date, sunrise: Date?, sunset: Date?) -> Bool? {
        guard let sunrise, let sunset else { return nil }
        return date >= sunrise && date < sunset
    }

    private func detailedHourLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date).replacingOccurrences(of: "AM", with: "AM")
            .replacingOccurrences(of: "PM", with: "PM")
    }

    private func makeUpcomingHourlyForecast(from weather: Weather, now: Date) -> [AppHourlyForecast] {
        let startOfHour = calendar.date(bySetting: .minute, value: 0, of: now) ?? now
        let upcomingHours = weather.hourlyForecast
            .filter { $0.date > startOfHour }
            .prefix(23)

        let current = AppHourlyForecast(
            timeLabel: "Now",
            condition: WeatherCondition.from(symbolName: weather.currentWeather.symbolName),
            temperature: fahrenheitValue(weather.currentWeather.temperature),
            feelsLikeTemperature: fahrenheitValue(weather.currentWeather.apparentTemperature),
            precipitationChance: nil
        )

        let future = upcomingHours.map { hour in
            AppHourlyForecast(
                timeLabel: detailedHourLabel(for: hour.date),
                condition: WeatherCondition.from(symbolName: hour.symbolName),
                temperature: fahrenheitValue(hour.temperature),
                feelsLikeTemperature: fahrenheitValue(hour.apparentTemperature),
                precipitationChance: percentage(from: hour.precipitationChance)
            )
        }

        return [current] + future
    }

    private func dayLabel(for date: Date, index: Int) -> String {
        if index == 0 { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    /// Derives a rough AQI proxy from visibility — used until WeatherKit regional air quality is available.
    private func proxyAQI(from visibility: Measurement<UnitLength>) -> Int {
        let miles = visibility.converted(to: .miles).value
        if miles >= 10 { return 28 }
        if miles >= 7  { return 45 }
        if miles >= 4  { return 85 }
        return 125
    }

    private func uvDetailLabel(for value: Int) -> String {
        switch value {
        case 0...2:
            return "Low"
        case 3...5:
            return "Moderate"
        case 6...7:
            return "High"
        case 8...10:
            return "Very High"
        default:
            return "Extreme"
        }
    }

    private func shouldSkipRefresh(for location: CLLocation, cityName: String?) -> Bool {
        guard let lastRefreshFingerprint else { return false }

        let sameCity = normalizedCityName(cityName) == normalizedCityName(lastRefreshFingerprint.cityName)
        let movedDistance = CLLocation(
            latitude: lastRefreshFingerprint.latitude,
            longitude: lastRefreshFingerprint.longitude
        ).distance(from: location)
        let elapsed = Date().timeIntervalSince(lastRefreshFingerprint.timestamp)

        return sameCity && movedDistance < 75 && elapsed < 45
    }

    private func updateRefreshFingerprint(for location: CLLocation, cityName: String?) {
        lastRefreshFingerprint = RefreshFingerprint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            cityName: normalizedCityName(cityName),
            timestamp: Date()
        )
    }

    private func normalizedCityName(_ cityName: String?) -> String? {
        cityName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private enum WeatherServiceError: Error {
    case proAccessRequired
}
