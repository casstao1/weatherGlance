import Foundation
import CoreLocation

struct SharedLocationStore {
    static let suiteName = "group.com.castao.weatherGlance"
    static let showFeelsLikeTemperaturesKey = "showFeelsLikeTemperatures"
    static let homeWidgetDarkModeKey = "homeWidgetDarkMode"
    static let homeWidgetAppearanceModeKey = "homeWidgetAppearanceMode"

    static let defaults: UserDefaults = {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) != nil else {
            return .standard
        }

        return UserDefaults(suiteName: suiteName) ?? .standard
    }()

    private static let locationKey = "shared.location.snapshot"
    private static let manualLocationEnabledKey = "shared.location.manualEnabled"
    private static let timelineKey = "shared.widget.timeline"
    private static let timelineSavedAtKey = "shared.widget.timelineSavedAt"

    private struct Snapshot: Codable {
        let latitude: Double
        let longitude: Double
        let cityName: String?
        let timestamp: Date?
        let isManual: Bool?
    }

    static var isManualLocationEnabled: Bool {
        defaults.bool(forKey: manualLocationEnabledKey)
    }

    static func save(location: CLLocation, cityName: String?, isManual: Bool = false) {
        let snapshot = Snapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            cityName: cityName,
            timestamp: Date(),
            isManual: isManual
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        Self.defaults.set(data, forKey: locationKey)
        Self.defaults.set(isManual, forKey: manualLocationEnabledKey)
    }

    static func load() -> (location: CLLocation, cityName: String?)? {
        guard let snapshot = loadSnapshot() else { return nil }
        return locationTuple(from: snapshot)
    }

    static func loadManualLocation() -> (location: CLLocation, cityName: String?)? {
        guard
            isManualLocationEnabled,
            let snapshot = loadSnapshot(),
            snapshot.isManual == true
        else {
            return nil
        }

        return locationTuple(from: snapshot)
    }

    static func loadDeviceLocation() -> (location: CLLocation, cityName: String?)? {
        guard
            let snapshot = loadSnapshot(),
            snapshot.isManual != true
        else {
            return nil
        }

        return locationTuple(from: snapshot)
    }

    static func clearManualLocation() {
        defaults.set(false, forKey: manualLocationEnabledKey)
    }

    static func loadFresh(maxAge: TimeInterval) -> (location: CLLocation, cityName: String?)? {
        guard
            let snapshot = loadSnapshot(),
            let timestamp = snapshot.timestamp,
            abs(timestamp.timeIntervalSinceNow) <= maxAge
        else {
            return nil
        }

        return locationTuple(from: snapshot)
    }

    private static func loadSnapshot() -> Snapshot? {
        guard
            let data = defaults.data(forKey: locationKey),
            let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else {
            return nil
        }

        return snapshot
    }

    private static func locationTuple(from snapshot: Snapshot) -> (location: CLLocation, cityName: String?) {
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

    static func loadFreshEntries(maxAge: TimeInterval, now: Date = Date()) -> [GlanceWidgetEntry]? {
        guard
            let savedAt = defaults.object(forKey: timelineSavedAtKey) as? Date
        else {
            return nil
        }

        let age = now.timeIntervalSince(savedAt)
        guard age >= -60, age <= maxAge else {
            return nil
        }

        return loadEntries()
    }
}

enum HomeWidgetAppearanceMode: String, CaseIterable, Identifiable {
    case light
    case dark
    case automatic

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .automatic:
            return "Auto"
        }
    }

    var settingsDetail: String {
        switch self {
        case .light:
            return "Always use the light Home Screen widget."
        case .dark:
            return "Always flip the Home Screen widget to dark colors."
        case .automatic:
            return "Use light during daytime and dark after sunset."
        }
    }

    static func resolved(rawValue: String, legacyDarkMode: Bool) -> HomeWidgetAppearanceMode {
        if let mode = HomeWidgetAppearanceMode(rawValue: rawValue) {
            return mode
        }

        return legacyDarkMode ? .dark : .light
    }

    func isDark(for entry: GlanceWidgetEntry) -> Bool {
        switch self {
        case .light:
            return false
        case .dark:
            return true
        case .automatic:
            return entry.isNighttimeForAppearance
        }
    }
}
