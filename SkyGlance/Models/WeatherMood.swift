import Foundation

enum WeatherMood: String, Codable, Hashable {
    case warm
    case dark
    case neutral
    case cool

    static func from(condition: WeatherCondition) -> WeatherMood {
        switch condition {
        case .sunny, .mostlySunny:
            return .warm
        case .rain, .heavyRain, .lightRain:
            return .dark
        case .cloudy, .partlyCloudy:
            return .neutral
        case .snow:
            return .cool
        case .clearNight, .partlyCloudyNight:
            return .neutral
        }
    }
}
