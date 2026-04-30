import Foundation
import WeatherKit

/// Maps WeatherKit hourly forecast data into GlanceWidgetEntry objects.
struct TimelineMapper {

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Builds a GlanceWidgetEntry from the current WeatherKit forecast.
    func makeEntry(
        from forecast: Forecast<HourWeather>,
        currentWeather: CurrentWeather? = nil,
        cityName: String?,
        at date: Date,
        referenceDate: Date,
        feelsLikeTemperature: Int? = nil,
        windSpeed: String? = nil,
        sunriseTime: String? = nil,
        sunsetTime: String? = nil,
        isDaylight: Bool? = nil
    ) -> GlanceWidgetEntry {
        let startOfHour = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        let isCurrentEntry = calendar.isDate(date, equalTo: referenceDate, toGranularity: .hour)

        let items: [HourForecastItem]
        if isCurrentEntry, let currentWeather {
            let nextHours = forecastItems(
                from: forecast,
                startingAt: startOfHour,
                offsets: 1...5
            )

            let currentItem = HourForecastItem(
                label: "Now",
                condition: WeatherCondition.from(symbolName: currentWeather.symbolName),
                temperature: Int(currentWeather.temperature.converted(to: .fahrenheit).value.rounded()),
                feelsLikeTemperature: Int(currentWeather.apparentTemperature.converted(to: .fahrenheit).value.rounded())
            )

            items = [currentItem] + nextHours
        } else {
            items = forecastItems(
                from: forecast,
                startingAt: startOfHour,
                offsets: 0..<6
            )
        }

        let current = items.first
        let currentCondition = current?.condition ?? .sunny
        let currentTemp = current?.temperature ?? 0
        let mood = WeatherMood.from(condition: currentCondition)

        // Build inline summary, e.g. "72° → 78°"
        let temps = items.map { $0.temperature }
        let inlineSummary: String
        if let first = temps.first, let last = temps.last, first != last {
            inlineSummary = "\(first)° → \(last)°"
        } else if let first = temps.first {
            inlineSummary = "\(first)°"
        } else {
            inlineSummary = "--"
        }

        return GlanceWidgetEntry(
            date: date,
            cityName: cityName,
            currentTemperature: currentTemp,
            currentCondition: currentCondition,
            inlineSummary: inlineSummary,
            hours: items,
            mood: mood,
            feelsLikeTemperature: current?.feelsLikeTemperature ?? feelsLikeTemperature,
            windSpeed: windSpeed,
            sunriseTime: sunriseTime,
            sunsetTime: sunsetTime,
            isDaylight: isDaylight
        )
    }

    private func forecastItems<T: Sequence<Int>>(
        from forecast: Forecast<HourWeather>,
        startingAt startOfHour: Date,
        offsets: T
    ) -> [HourForecastItem] {
        offsets.compactMap { offset in
            guard let targetDate = calendar.date(byAdding: .hour, value: offset, to: startOfHour),
                  let hour = hourWeather(for: targetDate, in: forecast) else {
                return nil
            }

            let label = HourLabelFormatter.compactHourLabel(for: targetDate, now: startOfHour, calendar: calendar)
            let condition = WeatherCondition.from(symbolName: hour.symbolName)
            let temp = Int(hour.temperature.converted(to: .fahrenheit).value.rounded())
            let feelsLike = Int(hour.apparentTemperature.converted(to: .fahrenheit).value.rounded())
            return HourForecastItem(
                label: label,
                condition: condition,
                temperature: temp,
                feelsLikeTemperature: feelsLike
            )
        }
    }

    private func hourWeather(
        for targetDate: Date,
        in forecast: Forecast<HourWeather>
    ) -> HourWeather? {
        if let exactHour = forecast.first(where: { calendar.isDate($0.date, equalTo: targetDate, toGranularity: .hour) }) {
            return exactHour
        }

        return forecast.first(where: { $0.date >= targetDate }) ?? forecast.last
    }
}
