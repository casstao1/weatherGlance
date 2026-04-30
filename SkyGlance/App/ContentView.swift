import SwiftUI
import CoreLocation
import WidgetKit
import UserNotifications

struct ContentView: View {
    @StateObject private var service = WeatherService.shared
    @StateObject private var locationManager = LocationManager()
    @StateObject private var purchaseManager = PurchaseManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    @AppStorage(
        SharedLocationStore.showFeelsLikeTemperaturesKey,
        store: SharedLocationStore.defaults
    ) private var showFeelsLikeTemperatures: Bool = false
    @State private var showSettings = false
    @State private var trialExpirationTask: Task<Void, Never>?
    private let trialReminderNotificationID = "com.castao.weatherGlance.trialReminder.oneDayRemaining"
    private let refreshTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
    private let entitlementTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if purchaseManager.hasProAccess {
                dashboardView
            } else {
                PaywallView(purchaseManager: purchaseManager)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(purchaseManager: purchaseManager) {
                purchaseManager.refreshAccessState()
                updateTrialSchedules()
                WidgetCenter.shared.reloadAllTimelines()
            }
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(24)
        }
        .task {
            await purchaseManager.configure()
            updateTrialSchedules()
            guard purchaseManager.hasProAccess else { return }
            startWeatherUpdates()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }

            Task {
                await purchaseManager.configure()
                updateTrialSchedules()
                guard purchaseManager.hasProAccess else {
                    WidgetCenter.shared.reloadAllTimelines()
                    return
                }

                startWeatherUpdates(forceRefreshExistingLocation: true)
            }
        }
        .onChange(of: purchaseManager.hasProAccess) { _, hasProAccess in
            WidgetCenter.shared.reloadAllTimelines()
            updateTrialSchedules()
            guard hasProAccess else { return }
            startWeatherUpdates(forceRefreshExistingLocation: true)
        }
        .onChange(of: purchaseManager.isLifetimeUnlocked) { _, _ in
            updateTrialSchedules()
        }
        .onChange(of: locationManager.location) { _, newLocation in
            guard purchaseManager.hasProAccess, let loc = newLocation else { return }
            Task {
                await service.refresh(
                    for: loc,
                    cityName: locationManager.cityName
                )
            }
        }
        .onChange(of: locationManager.cityName) { _, newCityName in
            guard purchaseManager.hasProAccess else { return }
            service.applyResolvedCityName(newCityName)
        }
        .onReceive(refreshTimer) { _ in
            purchaseManager.refreshAccessState()
            guard scenePhase == .active, purchaseManager.hasProAccess else { return }
            refreshCurrentLocation()
        }
        .onReceive(entitlementTimer) { _ in
            purchaseManager.refreshAccessState()
            updateTrialSchedules()
        }
        .onChange(of: showFeelsLikeTemperatures) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onDisappear {
            trialExpirationTask?.cancel()
        }
    }

    private var dashboardView: some View {
        let snapshot = service.dashboardSnapshot
        let theme = GlanceThemeResolver.widgetGlassTheme(colorScheme: .dark)

        return AppDashboardView(
            snapshot: snapshot,
            theme: theme,
            useCelsius: useCelsius,
            showFeelsLikeTemperatures: showFeelsLikeTemperatures,
            onSettingsTapped: { showSettings = true }
        )
    }

    private func refreshCurrentLocation() {
        guard purchaseManager.hasProAccess, let location = locationManager.location else { return }
        Task {
            await service.refresh(for: location, cityName: locationManager.cityName, force: true)
        }
    }

    private func startWeatherUpdates(forceRefreshExistingLocation: Bool = false) {
        let restoredCachedLocation = locationManager.restoreCachedLocationIfAvailable()
        locationManager.begin()

        if forceRefreshExistingLocation, restoredCachedLocation == nil {
            refreshCurrentLocation()
        }
    }

    private func updateTrialSchedules() {
        scheduleTrialExpirationRefresh()

        Task {
            await scheduleTrialReminderNotification()
        }
    }

    private func scheduleTrialExpirationRefresh() {
        trialExpirationTask?.cancel()

        guard purchaseManager.hasProAccess, !purchaseManager.isLifetimeUnlocked else {
            trialExpirationTask = nil
            return
        }

        let secondsUntilExpiration = max(0, EntitlementStore.trialEndDate.timeIntervalSinceNow + 1)
        let nanosecondsUntilExpiration = UInt64(secondsUntilExpiration * 1_000_000_000)

        trialExpirationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: nanosecondsUntilExpiration)
            guard !Task.isCancelled else { return }

            purchaseManager.refreshAccessState()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func scheduleTrialReminderNotification() async {
        let center = UNUserNotificationCenter.current()

        guard purchaseManager.hasProAccess,
              !purchaseManager.isLifetimeUnlocked,
              EntitlementStore.isTrialActive
        else {
            removeTrialReminderNotification(center: center)
            return
        }

        let reminderDate = EntitlementStore.trialEndDate.addingTimeInterval(-86_400)
        guard reminderDate > Date() else {
            removeTrialReminderNotification(center: center)
            return
        }

        guard await canSendTrialReminderNotification(center: center) else {
            removeTrialReminderNotification(center: center)
            return
        }

        removeTrialReminderNotification(center: center)

        let content = UNMutableNotificationContent()
        content.title = "SkyGlance trial ends tomorrow"
        content.body = "Unlock lifetime access to keep using the app and all widgets."
        content.sound = .default
        content.threadIdentifier = "trial"

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: trialReminderNotificationID,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    private func canSendTrialReminderNotification(center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func removeTrialReminderNotification(center: UNUserNotificationCenter) {
        center.removePendingNotificationRequests(withIdentifiers: [trialReminderNotificationID])
        center.removeDeliveredNotifications(withIdentifiers: [trialReminderNotificationID])
    }
}

// MARK: – Lightweight Location Manager

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var cityName: String?
    @Published var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var stopUpdatesTask: Task<Void, Never>?
    private var requestStartedAt: Date?
    private var bestLocationThisRequest: CLLocation?
    private var lastWidgetReloadAt: Date?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .other
        manager.pausesLocationUpdatesAutomatically = false
    }

    func begin() {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            requestPreciseLocationIfNeeded()
            requestFreshLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    @discardableResult
    func restoreCachedLocationIfAvailable() -> (location: CLLocation, cityName: String?)? {
        guard location == nil, let cached = SharedLocationStore.load() else {
            return nil
        }

        cityName = cached.cityName
        location = cached.location
        return cached
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            let freshLocations = locations
                .filter { candidate in
                    candidate.horizontalAccuracy >= 0 &&
                    abs(candidate.timestamp.timeIntervalSinceNow) < 30 &&
                    isFromCurrentRequest(candidate)
                }
                .sorted { lhs, rhs in
                    if lhs.horizontalAccuracy == rhs.horizontalAccuracy {
                        return lhs.timestamp > rhs.timestamp
                    }
                    return lhs.horizontalAccuracy < rhs.horizontalAccuracy
                }

            guard let bestLocation = freshLocations.first else { return }
            let selectedLocation = selectBestLocation(bestLocation)
            guard shouldPublish(selectedLocation) else { return }

            if shouldResetCityName(for: selectedLocation) {
                self.cityName = nil
            }

            self.location = selectedLocation
            SharedLocationStore.save(location: selectedLocation, cityName: self.cityName)
            reloadWidgetsIfNeeded()

            if selectedLocation.horizontalAccuracy > 0, selectedLocation.horizontalAccuracy <= 30 {
                stopUpdatingLocation()
            }

            geocoder.cancelGeocode()
            if let placemark = try? await geocoder.reverseGeocodeLocation(selectedLocation).first {
                let resolvedName = resolvedCityName(from: placemark)
                let didChangeCity = self.cityName != resolvedName
                self.cityName = resolvedName
                SharedLocationStore.save(location: selectedLocation, cityName: self.cityName)
                if didChangeCity {
                    reloadWidgetsIfNeeded(force: true)
                }
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus

            switch authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                requestPreciseLocationIfNeeded()
                requestFreshLocation()
            case .denied, .restricted, .notDetermined:
                stopUpdatingLocation()
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        print("[LocationManager] \(error)")
    }

    private func requestFreshLocation() {
        stopUpdatesTask?.cancel()
        requestStartedAt = Date()
        bestLocationThisRequest = nil
        manager.startUpdatingLocation()
        manager.requestLocation()
        stopUpdatesTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(12))
            stopUpdatingLocation()
        }
    }

    private func stopUpdatingLocation() {
        stopUpdatesTask?.cancel()
        stopUpdatesTask = nil
        manager.stopUpdatingLocation()
    }

    private func requestPreciseLocationIfNeeded() {
        guard #available(iOS 14.0, *), manager.accuracyAuthorization == .reducedAccuracy else {
            return
        }

        manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "skyGlancePreciseLocation")
    }

    private func isFromCurrentRequest(_ candidate: CLLocation) -> Bool {
        guard let requestStartedAt else { return true }
        return candidate.timestamp >= requestStartedAt.addingTimeInterval(-2)
    }

    private func selectBestLocation(_ candidate: CLLocation) -> CLLocation {
        guard let currentBest = bestLocationThisRequest else {
            bestLocationThisRequest = candidate
            return candidate
        }

        let improvedAccuracy = candidate.horizontalAccuracy + 10 < currentBest.horizontalAccuracy
        let isNewer = candidate.timestamp > currentBest.timestamp

        if improvedAccuracy || (isNewer && candidate.horizontalAccuracy <= currentBest.horizontalAccuracy + 15) {
            bestLocationThisRequest = candidate
            return candidate
        }

        return currentBest
    }

    private func shouldPublish(_ newLocation: CLLocation) -> Bool {
        guard let currentLocation = location else { return true }

        if currentLocation.horizontalAccuracy < 0 {
            return true
        }

        let movedDistance = newLocation.distance(from: currentLocation)
        let accuracyImprovement = currentLocation.horizontalAccuracy - newLocation.horizontalAccuracy
        let isNewer = newLocation.timestamp > currentLocation.timestamp

        if movedDistance >= 20 {
            return true
        }

        if accuracyImprovement >= 15 {
            return true
        }

        return isNewer && newLocation.horizontalAccuracy <= max(60, currentLocation.horizontalAccuracy)
    }
    private func shouldResetCityName(for newLocation: CLLocation) -> Bool {
        guard let currentLocation = location else { return cityName != nil }
        return newLocation.distance(from: currentLocation) >= 500
    }

    private func resolvedCityName(from placemark: CLPlacemark) -> String? {
        placemark.locality
            ?? placemark.subLocality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? placemark.name
    }

    private func reloadWidgetsIfNeeded(force: Bool = false) {
        let now = Date()
        if !force, let lastWidgetReloadAt, now.timeIntervalSince(lastWidgetReloadAt) < 60 {
            return
        }

        lastWidgetReloadAt = now
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    ContentView()
}
