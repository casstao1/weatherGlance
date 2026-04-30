import Foundation
import CoreLocation

struct SharedLocationStore {
    static let suiteName = "group.com.castao.weatherGlance"
    static let showFeelsLikeTemperaturesKey = "showFeelsLikeTemperatures"

    static let defaults: UserDefaults = {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) != nil else {
            return .standard
        }

        return UserDefaults(suiteName: suiteName) ?? .standard
    }()

    private static let locationKey = "shared.location.snapshot"
    private static let timelineKey = "shared.widget.timeline"
    private static let timelineSavedAtKey = "shared.widget.timelineSavedAt"

    private struct Snapshot: Codable {
        let latitude: Double
        let longitude: Double
        let cityName: String?
        let timestamp: Date?
    }

    static func save(location: CLLocation, cityName: String?) {
        let snapshot = Snapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            cityName: cityName,
            timestamp: Date()
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        Self.defaults.set(data, forKey: locationKey)
    }

    static func load() -> (location: CLLocation, cityName: String?)? {
        guard
            let data = defaults.data(forKey: locationKey),
            let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else {
            return nil
        }

        return (
            CLLocation(latitude: snapshot.latitude, longitude: snapshot.longitude),
            snapshot.cityName
        )
    }

    static func loadFresh(maxAge: TimeInterval) -> (location: CLLocation, cityName: String?)? {
        guard
            let data = defaults.data(forKey: locationKey),
            let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
            let timestamp = snapshot.timestamp,
            abs(timestamp.timeIntervalSinceNow) <= maxAge
        else {
            return nil
        }

        return (
            CLLocation(latitude: snapshot.latitude, longitude: snapshot.longitude),
            snapshot.cityName
        )
    }

    static func save(entries: [GlanceWidgetEntry]) {
        guard
            let data = try? JSONEncoder().encode(entries)
        else {
            return
        }

        Self.defaults.set(data, forKey: timelineKey)
        Self.defaults.set(Date(), forKey: timelineSavedAtKey)
    }

    static func loadEntries() -> [GlanceWidgetEntry]? {
        guard
            let data = defaults.data(forKey: timelineKey),
            let entries = try? JSONDecoder().decode([GlanceWidgetEntry].self, from: data),
            !entries.isEmpty
        else {
            return nil
        }

        return entries
    }

    static func loadFreshEntries(maxAge: TimeInterval) -> [GlanceWidgetEntry]? {
        guard
            let savedAt = defaults.object(forKey: timelineSavedAtKey) as? Date,
            abs(savedAt.timeIntervalSinceNow) <= maxAge
        else {
            return nil
        }

        return loadEntries()
    }
}
