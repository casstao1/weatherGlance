import Foundation

struct HourForecastItem: Identifiable, Hashable, Codable {
    let id: UUID
    let label: String        // "Now", "10A", "11A", "12P", etc.
    let condition: WeatherCondition
    let temperature: Int
    let feelsLikeTemperature: Int?

    init(
        id: UUID = UUID(),
        label: String,
        condition: WeatherCondition,
        temperature: Int,
        feelsLikeTemperature: Int? = nil
    ) {
        self.id = id
        self.label = label
        self.condition = condition
        self.temperature = temperature
        self.feelsLikeTemperature = feelsLikeTemperature
    }

    func displayTemperature(showFeelsLike: Bool) -> Int {
        showFeelsLike ? feelsLikeTemperature ?? temperature : temperature
    }

    /// Full accessibility label for VoiceOver
    var accessibilityDescription: String {
        accessibilityDescription(showFeelsLike: false)
    }

    func accessibilityDescription(showFeelsLike: Bool) -> String {
        let timeLabel = label == "Now" ? "Now" : label
            .replacingOccurrences(of: "A", with: " AM")
            .replacingOccurrences(of: "P", with: " PM")
        let displayedTemperature = displayTemperature(showFeelsLike: showFeelsLike)
        return "\(timeLabel), \(condition.accessibilityLabel), \(displayedTemperature) degrees"
    }
}
