import Foundation
import WidgetKit

struct GlanceWidgetEntry: TimelineEntry, Codable {
    let date: Date
    let cityName: String?
    let currentTemperature: Int
    let currentCondition: WeatherCondition
    let inlineSummary: String
    let hours: [HourForecastItem]
    let mood: WeatherMood
    let feelsLikeTemperature: Int?
    let windSpeed: String?
    let sunriseTime: String?
    let sunsetTime: String?
    let isDaylight: Bool?

    init(
        date: Date,
        cityName: String?,
        currentTemperature: Int,
        currentCondition: WeatherCondition,
        inlineSummary: String,
        hours: [HourForecastItem],
        mood: WeatherMood,
        feelsLikeTemperature: Int? = nil,
        windSpeed: String? = nil,
        sunriseTime: String? = nil,
        sunsetTime: String? = nil,
        isDaylight: Bool? = nil
    ) {
        self.date = date
        self.cityName = cityName
        self.currentTemperature = currentTemperature
        self.currentCondition = currentCondition
        self.inlineSummary = inlineSummary
        self.hours = hours
        self.mood = mood
        self.feelsLikeTemperature = feelsLikeTemperature
        self.windSpeed = windSpeed
        self.sunriseTime = sunriseTime
        self.sunsetTime = sunsetTime
        self.isDaylight = isDaylight
    }

    /// Mock entry for previews and placeholder rendering
    static var placeholder: GlanceWidgetEntry {
        GlanceWidgetEntry(
            date: Date(),
            cityName: "San Francisco",
            currentTemperature: 72,
            currentCondition: .sunny,
            inlineSummary: "72° → 78°",
            hours: [
                HourForecastItem(label: "Now", condition: .sunny,        temperature: 72),
                HourForecastItem(label: "10A", condition: .mostlySunny,  temperature: 74),
                HourForecastItem(label: "11A", condition: .partlyCloudy, temperature: 76),
                HourForecastItem(label: "12P", condition: .cloudy,       temperature: 77),
                HourForecastItem(label: "1P",  condition: .lightRain,    temperature: 78),
                HourForecastItem(label: "2P",  condition: .sunny,        temperature: 78),
            ],
            mood: .warm,
            feelsLikeTemperature: 72,
            windSpeed: "6 mph",
            sunriseTime: "6:14A",
            sunsetTime: "7:49P",
            isDaylight: true
        )
    }

    /// 5-hour slice used by the lock screen and other compact forecast surfaces.
    var hourItems: [HourForecastItem] {
        Array(hours.prefix(5))
    }

    var feelsLikeLabel: String {
        if let feelsLikeTemperature {
            return "Feels like \(feelsLikeTemperature)°"
        }

        return inlineSummary
    }

    func displayCurrentTemperature(showFeelsLike: Bool) -> Int {
        showFeelsLike ? feelsLikeTemperature ?? currentTemperature : currentTemperature
    }

    func secondaryTemperatureLabel(showFeelsLike: Bool) -> String {
        if showFeelsLike, feelsLikeTemperature != nil {
            return "Actual \(currentTemperature)°"
        }

        return feelsLikeLabel
    }

    var windSpeedLabel: String {
        windSpeed ?? "--"
    }

    var homeSunEventSymbol: String {
        isNighttimeForAppearance ? "sunrise" : "sunset"
    }

    var homeSunEventTime: String {
        if isNighttimeForAppearance {
            return sunriseTime ?? "--"
        }

        return sunsetTime ?? "--"
    }

    var isNighttimeForAppearance: Bool {
        if let isDaylight {
            return !isDaylight
        }

        if currentCondition.isNightVariant {
            return true
        }

        let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
        return hour < 6 || hour >= 18
    }
}
