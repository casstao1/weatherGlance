import Foundation
import CoreLocation

struct OpenMeteoService {
    private let session: URLSession = .shared
    private let maxAttempts = 3

    func fetchForecastBundle(
        for location: CLLocation,
        cityName: String?
    ) async throws -> (entries: [GlanceWidgetEntry], snapshot: AppWeatherSnapshot) {
        let response = try await fetchResponse(for: location)
        let timezone = TimeZone(identifier: response.timezone) ?? .autoupdatingCurrent
        let calendar = calendar(in: timezone)
        let now = parseDateTime(response.current.time, timezone: timezone) ?? Date()
        let startOfCurrentHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now

        let hourlyPoints = makeHourlyPoints(from: response, timezone: timezone)
        let dailyPoints = makeDailyPoints(from: response, timezone: timezone)

        let entries = makeTimelineEntries(
            hourlyPoints: hourlyPoints,
            dailyPoints: dailyPoints,
            current: response.current,
            cityName: cityName,
            now: now,
            calendar: calendar,
            timezone: timezone
        )

        let snapshot = makeDashboardSnapshot(
            current: response.current,
            hourlyPoints: hourlyPoints,
            dailyPoints: dailyPoints,
            cityName: cityName ?? "Current Location",
            timezone: timezone,
            now: startOfCurrentHour
        )

        return (entries, snapshot)
    }

    private func fetchResponse(for location: CLLocation) async throws -> OpenMeteoForecastResponse {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(location.coordinate.longitude)),
            URLQueryItem(
                name: "current",
                value: [
                    "temperature_2m",
                    "apparent_temperature",
                    "relative_humidity_2m",
                    "weather_code",
                    "wind_speed_10m",
                    "wind_direction_10m",
                    "surface_pressure",
                    "visibility",
                    "is_day",
                ].joined(separator: ",")
            ),
            URLQueryItem(
                name: "hourly",
                value: [
                    "temperature_2m",
                    "apparent_temperature",
                    "weather_code",
                    "precipitation_probability",
                    "is_day",
                ].joined(separator: ",")
            ),
            URLQueryItem(
                name: "daily",
                value: [
                    "weather_code",
                    "temperature_2m_max",
                    "temperature_2m_min",
                    "sunrise",
                    "sunset",
                    "uv_index_max",
                ].joined(separator: ",")
            ),
            URLQueryItem(name: "forecast_days", value: "7"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]

        guard let url = components?.url else {
            throw OpenMeteoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SkyGlance/1.0", forHTTPHeaderField: "User-Agent")

        var lastError: Error = OpenMeteoError.invalidURL

        for attempt in 1...maxAttempts {
            do {
                WeatherUsageStore.record(.openMeteo)
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OpenMeteoError.invalidResponse
                }

                guard 200..<300 ~= httpResponse.statusCode else {
                    let bodySnippet = String(data: data.prefix(240), encoding: .utf8) ?? "<non-utf8 body>"
                    let error = OpenMeteoError.serverResponse(
                        statusCode: httpResponse.statusCode,
                        bodySnippet: bodySnippet
                    )

                    if shouldRetry(statusCode: httpResponse.statusCode, attempt: attempt) {
                        lastError = error
                        try await Task.sleep(for: .milliseconds(UInt64(400 * attempt)))
                        continue
                    }

                    throw error
                }

                return try JSONDecoder().decode(OpenMeteoForecastResponse.self, from: data)
            } catch {
                if shouldRetry(error: error, attempt: attempt) {
                    lastError = error
                    try await Task.sleep(for: .milliseconds(UInt64(400 * attempt)))
                    continue
                }

                throw error
            }
        }

        throw lastError
    }

    private func shouldRetry(statusCode: Int, attempt: Int) -> Bool {
        attempt < maxAttempts && (statusCode == 429 || statusCode >= 500)
    }

    private func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }

        return false
    }

    private func makeHourlyPoints(
        from response: OpenMeteoForecastResponse,
        timezone: TimeZone
    ) -> [OpenMeteoHourlyPoint] {
        let count = response.hourly.time.count
        return (0..<count).compactMap { index in
            guard
                let date = parseDateTime(response.hourly.time[safe: index], timezone: timezone),
                let temperature = response.hourly.temperature_2m[safe: index],
                let weatherCode = response.hourly.weather_code[safe: index]
            else {
                return nil
            }

            return OpenMeteoHourlyPoint(
                date: date,
                temperature: fahrenheit(fromCelsius: temperature),
                feelsLikeTemperature: response.hourly.apparent_temperature[safe: index].map { fahrenheit(fromCelsius: $0) },
                weatherCode: weatherCode,
                precipitationProbability: response.hourly.precipitation_probability[safe: index] ?? nil,
                isDay: (response.hourly.is_day[safe: index] ?? 1) == 1
            )
        }
    }

    private func makeDailyPoints(
        from response: OpenMeteoForecastResponse,
        timezone: TimeZone
    ) -> [OpenMeteoDailyPoint] {
        let count = response.daily.time.count
        return (0..<count).compactMap { index in
            guard
                let date = parseDate(response.daily.time[safe: index], timezone: timezone),
                let weatherCode = response.daily.weather_code[safe: index],
                let high = response.daily.temperature_2m_max[safe: index],
                let low = response.daily.temperature_2m_min[safe: index]
            else {
                return nil
            }

            return OpenMeteoDailyPoint(
                date: date,
                weatherCode: weatherCode,
                highTemperature: fahrenheit(fromCelsius: high),
                lowTemperature: fahrenheit(fromCelsius: low),
                sunrise: parseDateTime(response.daily.sunrise[safe: index], timezone: timezone),
                sunset: parseDateTime(response.daily.sunset[safe: index], timezone: timezone),
                uvIndexMax: response.daily.uv_index_max[safe: index] ?? nil
            )
        }
    }

    private func makeTimelineEntries(
        hourlyPoints: [OpenMeteoHourlyPoint],
        dailyPoints: [OpenMeteoDailyPoint],
        current: OpenMeteoCurrent,
        cityName: String?,
        now: Date,
        calendar: Calendar,
        timezone: TimeZone
    ) -> [GlanceWidgetEntry] {
        let startOfCurrentHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let feelsLike = fahrenheit(fromCelsius: current.apparent_temperature)
        let windSpeed = "\(milesPerHour(fromKilometersPerHour: current.wind_speed_10m)) mph"

        return (0..<12).compactMap { offset in
            guard let entryDate = calendar.date(byAdding: .hour, value: offset, to: startOfCurrentHour) else {
                return nil
            }

            let items: [HourForecastItem]
            if offset == 0 {
                let currentItem = HourForecastItem(
                    label: "Now",
                    condition: weatherCondition(for: current.weather_code, isDay: current.is_day == 1),
                    temperature: fahrenheit(fromCelsius: current.temperature_2m),
                    feelsLikeTemperature: feelsLike
                )

                let future = forecastItems(
                    from: hourlyPoints,
                    startingAt: startOfCurrentHour,
                    offsets: 1...5,
                    calendar: calendar
                )

                items = [currentItem] + future
            } else {
                items = forecastItems(
                    from: hourlyPoints,
                    startingAt: entryDate,
                    offsets: 0..<6,
                    calendar: calendar
                )
            }

            guard let currentItem = items.first else { return nil }
            let currentPoint = hourlyPoint(for: entryDate, in: hourlyPoints, calendar: calendar)
            let dailyPoint = dailyPoint(for: entryDate, in: dailyPoints, calendar: calendar)
            let temps = items.map(\.temperature)
            let inlineSummary: String
            if let first = temps.first, let last = temps.last, first != last {
                inlineSummary = "\(first)° → \(last)°"
            } else if let first = temps.first {
                inlineSummary = "\(first)°"
            } else {
                inlineSummary = "--"
            }

            return GlanceWidgetEntry(
                date: entryDate,
                cityName: cityName ?? "Current Location",
                currentTemperature: currentItem.temperature,
                currentCondition: currentItem.condition,
                inlineSummary: inlineSummary,
                hours: items,
                mood: WeatherMood.from(condition: currentItem.condition),
                feelsLikeTemperature: currentItem.feelsLikeTemperature ?? feelsLike,
                windSpeed: windSpeed,
                sunriseTime: compactSunEventTime(dailyPoint?.sunrise, timezone: timezone),
                sunsetTime: compactSunEventTime(dailyPoint?.sunset, timezone: timezone),
                isDaylight: offset == 0 ? current.is_day == 1 : currentPoint?.isDay
            )
        }
    }

    private func forecastItems<T: Sequence<Int>>(
        from hourlyPoints: [OpenMeteoHourlyPoint],
        startingAt startOfHour: Date,
        offsets: T,
        calendar: Calendar
    ) -> [HourForecastItem] {
        offsets.compactMap { offset in
            guard let targetDate = calendar.date(byAdding: .hour, value: offset, to: startOfHour),
                  let point = hourlyPoint(for: targetDate, in: hourlyPoints, calendar: calendar) else {
                return nil
            }

            return HourForecastItem(
                label: HourLabelFormatter.compactHourLabel(for: targetDate, now: startOfHour, calendar: calendar),
                condition: weatherCondition(for: point.weatherCode, isDay: point.isDay),
                temperature: point.temperature,
                feelsLikeTemperature: point.feelsLikeTemperature
            )
        }
    }

    private func hourlyPoint(
        for targetDate: Date,
        in hourlyPoints: [OpenMeteoHourlyPoint],
        calendar: Calendar
    ) -> OpenMeteoHourlyPoint? {
        if let exactHour = hourlyPoints.first(where: { calendar.isDate($0.date, equalTo: targetDate, toGranularity: .hour) }) {
            return exactHour
        }

        return hourlyPoints.first(where: { $0.date >= targetDate }) ?? hourlyPoints.last
    }

    private func dailyPoint(
        for targetDate: Date,
        in dailyPoints: [OpenMeteoDailyPoint],
        calendar: Calendar
    ) -> OpenMeteoDailyPoint? {
        dailyPoints.first(where: { calendar.isDate($0.date, inSameDayAs: targetDate) }) ?? dailyPoints.first
    }

    private func makeDashboardSnapshot(
        current: OpenMeteoCurrent,
        hourlyPoints: [OpenMeteoHourlyPoint],
        dailyPoints: [OpenMeteoDailyPoint],
        cityName: String,
        timezone: TimeZone,
        now: Date
    ) -> AppWeatherSnapshot {
        let currentCondition = weatherCondition(for: current.weather_code, isDay: current.is_day == 1)
        let currentTemperature = fahrenheit(fromCelsius: current.temperature_2m)
        let feelsLike = fahrenheit(fromCelsius: current.apparent_temperature)
        let today = dailyPoints.first

        let hourly: [AppHourlyForecast] = {
            let currentHour = AppHourlyForecast(
                timeLabel: "Now",
                condition: currentCondition,
                temperature: currentTemperature,
                feelsLikeTemperature: feelsLike,
                precipitationChance: nil
            )

            let future = hourlyPoints
                .filter { $0.date > now }
                .prefix(7)
                .map { point in
                    AppHourlyForecast(
                        timeLabel: detailedHourLabel(for: point.date, timezone: timezone),
                        condition: weatherCondition(for: point.weatherCode, isDay: point.isDay),
                        temperature: point.temperature,
                        feelsLikeTemperature: point.feelsLikeTemperature,
                        precipitationChance: point.precipitationProbability
                    )
                }

            return [currentHour] + future
        }()

        let daily: [AppDailyForecast] = dailyPoints.enumerated().map { index, point in
            AppDailyForecast(
                dayLabel: dayLabel(for: point.date, index: index, timezone: timezone),
                condition: weatherCondition(for: point.weatherCode, isDay: true),
                highTemperature: point.highTemperature,
                lowTemperature: point.lowTemperature,
                precipitationChance: nil
            )
        }

        let visibilityMiles = miles(fromMeters: current.visibility)
        let aqiValue = proxyAQI(fromVisibilityMiles: visibilityMiles)
        let aqiLabel = aqiValue <= 50 ? "Good" : aqiValue <= 100 ? "Moderate" : "Unhealthy"
        let uvValue = Int((today?.uvIndexMax ?? 0).rounded())
        let uvLabel = uvDetailLabel(for: uvValue)
        let windSpeed = milesPerHour(fromKilometersPerHour: current.wind_speed_10m)
        let pressureInches = inchesOfMercury(fromHectopascals: current.surface_pressure)

        let overviewMetrics = [
            AppMetric(title: "Air Quality", value: "\(aqiValue)", detail: aqiLabel),
            AppMetric(title: "UV Index", value: "\(uvValue)", detail: uvLabel),
            AppMetric(title: "Sunrise", value: formatTime(today?.sunrise, timezone: timezone), detail: nil),
            AppMetric(title: "Sunset", value: formatTime(today?.sunset, timezone: timezone), detail: nil),
        ]

        let detailMetrics = [
            AppMetric(title: "Humidity", value: "\(current.relative_humidity_2m)%", detail: nil),
            AppMetric(title: "Dew Point", value: "--", detail: nil),
            AppMetric(title: "Wind", value: "\(windSpeed) mph", detail: compassDirection(from: current.wind_direction_10m)),
            AppMetric(title: "Pressure", value: String(format: "%.2f in", pressureInches), detail: nil),
            AppMetric(title: "Visibility", value: "\(visibilityMiles) mi", detail: nil),
            AppMetric(title: "Feels Like", value: "\(feelsLike)°", detail: nil),
        ]

        let highestTemp = daily.map(\.highTemperature).max() ?? currentTemperature
        let lowestTemp = daily.map(\.lowTemperature).min() ?? currentTemperature
        let rainyHour = hourly.first(where: { ($0.precipitationChance ?? 0) >= 25 })
        let spotlightTitle = rainyHour == nil ? "Stable Conditions" : "Rain Outlook"
        let spotlightValue = rainyHour == nil
            ? "Clear stretch through the next few hours"
            : "Rain risk builds around \(rainyHour?.timeLabel ?? "--")"
        let spotlightSubtitle = "Expected range \(lowestTemp)° to \(highestTemp)° with \(currentCondition.accessibilityLabel)."

        return AppWeatherSnapshot(
            cityName: cityName,
            currentTemperature: currentTemperature,
            condition: currentCondition,
            conditionDescription: currentCondition.accessibilityLabel.capitalized,
            feelsLikeTemperature: feelsLike,
            highTemperature: today?.highTemperature ?? currentTemperature,
            lowTemperature: today?.lowTemperature ?? currentTemperature,
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

    private func parseDateTime(_ value: String?, timezone: TimeZone) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar(in: timezone)
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: value)
    }

    private func parseDate(_ value: String?, timezone: TimeZone) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar(in: timezone)
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func calendar(in timezone: TimeZone) -> Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = timezone
        return calendar
    }

    private func detailedHourLabel(for date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }

    private func dayLabel(for date: Date, index: Int, timezone: TimeZone) -> String {
        if index == 0 { return "Today" }
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date?, timezone: TimeZone) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func compactSunEventTime(_ date: Date?, timezone: TimeZone) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.amSymbol = "A"
        formatter.pmSymbol = "P"
        formatter.dateFormat = "h:mma"
        return formatter.string(from: date)
    }

    private func weatherCondition(for code: Int, isDay: Bool) -> WeatherCondition {
        switch code {
        case 0:
            return isDay ? .sunny : .clearNight
        case 1:
            return isDay ? .mostlySunny : .clearNight
        case 2:
            return isDay ? .partlyCloudy : .partlyCloudyNight
        case 3, 45, 48:
            return .cloudy
        case 51, 53, 55, 56, 57:
            return .lightRain
        case 61, 63, 66, 80, 81:
            return .rain
        case 65, 67, 82, 95, 96, 99:
            return .heavyRain
        case 71, 73, 75, 77, 85, 86:
            return .snow
        default:
            return .cloudy
        }
    }

    private func fahrenheit(fromCelsius value: Double) -> Int {
        Int((value * 9 / 5 + 32).rounded())
    }

    private func milesPerHour(fromKilometersPerHour value: Double) -> Int {
        Int((value * 0.621371).rounded())
    }

    private func inchesOfMercury(fromHectopascals value: Double) -> Double {
        value * 0.0295299830714
    }

    private func miles(fromMeters value: Double) -> Int {
        Int((value / 1609.344).rounded())
    }

    private func proxyAQI(fromVisibilityMiles miles: Int) -> Int {
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

    private func compassDirection(from degrees: Int) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let normalized = ((degrees % 360) + 360) % 360
        let index = Int((Double(normalized) / 45.0).rounded()) % directions.count
        return directions[index]
    }
}

private enum OpenMeteoError: Error {
    case invalidURL
    case invalidResponse
    case serverResponse(statusCode: Int, bodySnippet: String)
}

private struct OpenMeteoForecastResponse: Decodable {
    let timezone: String
    let current: OpenMeteoCurrent
    let hourly: OpenMeteoHourly
    let daily: OpenMeteoDaily
}

private struct OpenMeteoCurrent: Decodable {
    let time: String
    let temperature_2m: Double
    let apparent_temperature: Double
    let relative_humidity_2m: Int
    let weather_code: Int
    let wind_speed_10m: Double
    let wind_direction_10m: Int
    let surface_pressure: Double
    let visibility: Double
    let is_day: Int
}

private struct OpenMeteoHourly: Decodable {
    let time: [String]
    let temperature_2m: [Double]
    let apparent_temperature: [Double]
    let weather_code: [Int]
    let precipitation_probability: [Int?]
    let is_day: [Int]
}

private struct OpenMeteoDaily: Decodable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let sunrise: [String]
    let sunset: [String]
    let uv_index_max: [Double?]
}

private struct OpenMeteoHourlyPoint {
    let date: Date
    let temperature: Int
    let feelsLikeTemperature: Int?
    let weatherCode: Int
    let precipitationProbability: Int?
    let isDay: Bool
}

private struct OpenMeteoDailyPoint {
    let date: Date
    let weatherCode: Int
    let highTemperature: Int
    let lowTemperature: Int
    let sunrise: Date?
    let sunset: Date?
    let uvIndexMax: Double?
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
