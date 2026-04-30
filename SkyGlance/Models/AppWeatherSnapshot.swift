import Foundation

struct AppWeatherSnapshot {
    let cityName: String
    let currentTemperature: Int
    let condition: WeatherCondition
    let conditionDescription: String
    let feelsLikeTemperature: Int
    let highTemperature: Int
    let lowTemperature: Int
    let hourly: [AppHourlyForecast]
    let daily: [AppDailyForecast]
    let overviewMetrics: [AppMetric]
    let detailMetrics: [AppMetric]
    let spotlightTitle: String
    let spotlightValue: String
    let spotlightSubtitle: String
    let mood: WeatherMood

    static let placeholder = AppWeatherSnapshot(
        cityName: "Locating...",
        currentTemperature: 72,
        condition: .sunny,
        conditionDescription: "Sunny",
        feelsLikeTemperature: 72,
        highTemperature: 78,
        lowTemperature: 56,
        hourly: [
            AppHourlyForecast(timeLabel: "Now", condition: .sunny, temperature: 72, precipitationChance: nil),
            AppHourlyForecast(timeLabel: "10 AM", condition: .mostlySunny, temperature: 74, precipitationChance: nil),
            AppHourlyForecast(timeLabel: "11 AM", condition: .cloudy, temperature: 76, precipitationChance: nil),
            AppHourlyForecast(timeLabel: "12 PM", condition: .cloudy, temperature: 77, precipitationChance: nil),
            AppHourlyForecast(timeLabel: "1 PM", condition: .rain, temperature: 78, precipitationChance: 30),
            AppHourlyForecast(timeLabel: "2 PM", condition: .sunny, temperature: 78, precipitationChance: 10),
        ],
        daily: [
            AppDailyForecast(dayLabel: "Today", condition: .sunny,   highTemperature: 78, lowTemperature: 56, precipitationChance: nil),
            AppDailyForecast(dayLabel: "Tue",   condition: .sunny,   highTemperature: 80, lowTemperature: 58, precipitationChance: nil),
            AppDailyForecast(dayLabel: "Wed",   condition: .cloudy,  highTemperature: 76, lowTemperature: 55, precipitationChance: nil),
            AppDailyForecast(dayLabel: "Thu",   condition: .rain,    highTemperature: 68, lowTemperature: 52, precipitationChance: 80),
            AppDailyForecast(dayLabel: "Fri",   condition: .cloudy,  highTemperature: 66, lowTemperature: 51, precipitationChance: nil),
            AppDailyForecast(dayLabel: "Sat",   condition: .sunny,   highTemperature: 72, lowTemperature: 53, precipitationChance: nil),
            AppDailyForecast(dayLabel: "Sun",   condition: .sunny,   highTemperature: 75, lowTemperature: 54, precipitationChance: nil),
        ],
        overviewMetrics: [
            AppMetric(title: "Air Quality", value: "28", detail: "Good"),
            AppMetric(title: "UV Index",    value: "6",  detail: "High"),
            AppMetric(title: "Sunrise",     value: "5:48 AM", detail: nil),
            AppMetric(title: "Sunset",      value: "8:29 PM", detail: nil),
        ],
        detailMetrics: [
            AppMetric(title: "Humidity", value: "45%", detail: nil),
            AppMetric(title: "Dew Point", value: "52°", detail: nil),
            AppMetric(title: "Wind", value: "7 mph", detail: "NW"),
            AppMetric(title: "Pressure", value: "30.12 in", detail: nil),
            AppMetric(title: "Visibility", value: "10 mi", detail: nil),
            AppMetric(title: "Feels Like", value: "72°", detail: nil),
        ],
        spotlightTitle: "Weather Window",
        spotlightValue: "Best conditions from 10 AM to 2 PM",
        spotlightSubtitle: "Mostly sunny with only a light rain risk later in the afternoon.",
        mood: .warm
    )

    func replacing(cityName: String) -> AppWeatherSnapshot {
        AppWeatherSnapshot(
            cityName: cityName,
            currentTemperature: currentTemperature,
            condition: condition,
            conditionDescription: conditionDescription,
            feelsLikeTemperature: feelsLikeTemperature,
            highTemperature: highTemperature,
            lowTemperature: lowTemperature,
            hourly: hourly,
            daily: daily,
            overviewMetrics: overviewMetrics,
            detailMetrics: detailMetrics,
            spotlightTitle: spotlightTitle,
            spotlightValue: spotlightValue,
            spotlightSubtitle: spotlightSubtitle,
            mood: mood
        )
    }
}

struct AppHourlyForecast: Identifiable, Hashable {
    let id = UUID()
    let timeLabel: String
    let condition: WeatherCondition
    let temperature: Int
    let feelsLikeTemperature: Int?
    let precipitationChance: Int?

    init(
        timeLabel: String,
        condition: WeatherCondition,
        temperature: Int,
        feelsLikeTemperature: Int? = nil,
        precipitationChance: Int?
    ) {
        self.timeLabel = timeLabel
        self.condition = condition
        self.temperature = temperature
        self.feelsLikeTemperature = feelsLikeTemperature
        self.precipitationChance = precipitationChance
    }

    func displayTemperature(showFeelsLike: Bool) -> Int {
        showFeelsLike ? feelsLikeTemperature ?? temperature : temperature
    }
}

struct AppDailyForecast: Identifiable, Hashable {
    let id = UUID()
    let dayLabel: String
    let condition: WeatherCondition
    let highTemperature: Int
    let lowTemperature: Int
    let precipitationChance: Int?
}

struct AppMetric: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String?
}
