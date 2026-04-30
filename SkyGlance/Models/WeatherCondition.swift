import Foundation

enum WeatherCondition: String, Codable, Hashable, CaseIterable {
    case sunny
    case mostlySunny
    case partlyCloudy
    case cloudy
    case lightRain
    case rain
    case heavyRain
    case snow
    case clearNight
    case partlyCloudyNight

    /// The SF Symbol name to use for this condition throughout the app and widgets.
    var sfSymbol: String {
        switch self {
        case .sunny:             return "sun.max.fill"
        case .mostlySunny:       return "cloud.sun.fill"
        case .partlyCloudy:      return "cloud.sun.fill"
        case .cloudy:            return "cloud.fill"
        case .lightRain:         return "cloud.drizzle.fill"
        case .rain:              return "cloud.rain.fill"
        case .heavyRain:         return "cloud.heavyrain.fill"
        case .snow:              return "cloud.snow.fill"
        case .clearNight:        return "moon.stars.fill"
        case .partlyCloudyNight: return "cloud.moon.fill"
        }
    }

    /// A monochrome line-symbol variant used by the Home Screen widgets.
    var widgetSymbol: String {
        switch self {
        case .sunny:
            return "sun.max"
        case .mostlySunny, .partlyCloudy:
            return "cloud.sun"
        case .cloudy:
            return "cloud"
        case .lightRain:
            return "cloud.drizzle"
        case .rain, .heavyRain:
            return "cloud.rain"
        case .snow:
            return "cloud.snow"
        case .clearNight:
            return "moon.stars"
        case .partlyCloudyNight:
            return "cloud.moon"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .sunny:             return "sunny"
        case .mostlySunny:       return "mostly sunny"
        case .partlyCloudy:      return "partly cloudy"
        case .cloudy:            return "cloudy"
        case .lightRain:         return "light rain"
        case .rain:              return "rain"
        case .heavyRain:         return "heavy rain"
        case .snow:              return "snow"
        case .clearNight:        return "clear night"
        case .partlyCloudyNight: return "partly cloudy"
        }
    }

    var isNightVariant: Bool {
        self == .clearNight || self == .partlyCloudyNight
    }

    static func from(symbolName: String) -> WeatherCondition {
        switch symbolName {
        case "clear":
            return .sunny
        case "clear-night":
            return .clearNight
        case "partly-cloudy-night":
            return .partlyCloudyNight
        case let value where value.contains("moon") && value.contains("cloud"):
            return .partlyCloudyNight
        case let value where value.contains("moon"):
            return .clearNight
        case let value where value.hasPrefix("sun.max"):
            return .sunny
        case let value where value.contains("sun") && value.contains("cloud"):
            return .mostlySunny
        case "partly-cloudy-day":
            return .partlyCloudy
        case let value where value.contains("cloud.sun"):
            return .partlyCloudy
        case let value where value.hasPrefix("cloud") && !value.contains("rain") && !value.contains("snow"):
            return .cloudy
        case let value where value.contains("drizzle"):
            return .lightRain
        case let value where value.contains("rain") && !value.contains("heavy"):
            return .rain
        case let value where value.contains("heavy") || value.contains("thunderstorm"):
            return .heavyRain
        case let value where value.contains("snow") || value.contains("sleet") || value.contains("hail"):
            return .snow
        default:
            return .cloudy
        }
    }
}
