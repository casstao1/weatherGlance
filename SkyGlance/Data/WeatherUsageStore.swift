import Foundation

struct WeatherUsageSnapshot {
    let weatherKitToday: Int
    let weatherKitMonth: Int
    let openMeteoToday: Int
    let openMeteoMonth: Int
    let lastWeatherKitCallAt: Date?
    let lastOpenMeteoCallAt: Date?

    var totalToday: Int {
        weatherKitToday + openMeteoToday
    }

    var totalMonth: Int {
        weatherKitMonth + openMeteoMonth
    }
}

struct WeatherUsageStore {
    enum Provider: String {
        case weatherKit
        case openMeteo
    }

    private static var defaults: UserDefaults {
        SharedLocationStore.defaults
    }

    static func record(_ provider: Provider, at date: Date = Date()) {
        increment(key: countKey(provider: provider, period: "day", suffix: daySuffix(for: date)), defaults: defaults)
        increment(key: countKey(provider: provider, period: "month", suffix: monthSuffix(for: date)), defaults: defaults)
        defaults.set(date, forKey: lastCallKey(provider: provider))
    }

    static func snapshot(at date: Date = Date()) -> WeatherUsageSnapshot {
        return WeatherUsageSnapshot(
            weatherKitToday: defaults.integer(forKey: countKey(provider: .weatherKit, period: "day", suffix: daySuffix(for: date))),
            weatherKitMonth: defaults.integer(forKey: countKey(provider: .weatherKit, period: "month", suffix: monthSuffix(for: date))),
            openMeteoToday: defaults.integer(forKey: countKey(provider: .openMeteo, period: "day", suffix: daySuffix(for: date))),
            openMeteoMonth: defaults.integer(forKey: countKey(provider: .openMeteo, period: "month", suffix: monthSuffix(for: date))),
            lastWeatherKitCallAt: defaults.object(forKey: lastCallKey(provider: .weatherKit)) as? Date,
            lastOpenMeteoCallAt: defaults.object(forKey: lastCallKey(provider: .openMeteo)) as? Date
        )
    }

    static func resetLocalCounters() {
        for (key, _) in defaults.dictionaryRepresentation() where key.hasPrefix("weatherUsage.") {
            defaults.removeObject(forKey: key)
        }
    }

    private static func increment(key: String, defaults: UserDefaults) {
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }

    private static func countKey(provider: Provider, period: String, suffix: String) -> String {
        "weatherUsage.\(provider.rawValue).\(period).\(suffix)"
    }

    private static func lastCallKey(provider: Provider) -> String {
        "weatherUsage.\(provider.rawValue).lastCallAt"
    }

    private static func daySuffix(for date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static func monthSuffix(for date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }
}
