import SwiftUI
import CoreLocation
import WidgetKit
import StoreKit

struct ContentView: View {
    @StateObject private var service = WeatherService.shared
    @StateObject private var locationManager = LocationManager()
    @StateObject private var purchaseManager = PurchaseManager()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    @AppStorage("review.launchCountV1") private var reviewLaunchCount: Int = 0
    @AppStorage("review.lastPromptedVersionV1") private var lastReviewPromptedVersion: String = ""
    @AppStorage("review.widgetInteractionCountV1") private var widgetInteractionCount: Int = 0
    @AppStorage("review.didPromptAfterSecondWidgetInteractionV1") private var didPromptAfterSecondWidgetInteraction: Bool = false
    @AppStorage("review.didPromptAfterThirdWidgetInteractionV1") private var didPromptAfterThirdWidgetInteraction: Bool = false
    @AppStorage(
        SharedLocationStore.showFeelsLikeTemperaturesKey,
        store: SharedLocationStore.defaults
    ) private var showFeelsLikeTemperatures: Bool = false
    @State private var showSettings = false
    @State private var didCountThisLaunchForReview = false
    @State private var debugWidgetReplayTask: Task<Void, Never>?
    private let refreshTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
    private let entitlementTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if shouldShowDashboard {
                dashboardView
            } else {
                PaywallView(purchaseManager: purchaseManager)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                purchaseManager: purchaseManager,
                locationManager: locationManager,
                onEntitlementsChanged: {
                    purchaseManager.refreshAccessState()
                    WidgetCenter.shared.reloadAllTimelines()
                },
                onWeatherLocationChanged: {
                    refreshCurrentLocation()
                }
            )
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(24)
        }
        .task {
            startDebugWidgetReplayIfNeeded()
            await purchaseManager.configure()
            trackLaunchForReviewPromptIfNeeded()
            guard purchaseManager.hasProAccess else { return }
            startWeatherUpdates()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }

            Task {
                await purchaseManager.configure()
                trackLaunchForReviewPromptIfNeeded()
                guard purchaseManager.hasProAccess else {
                    WidgetCenter.shared.reloadAllTimelines()
                    return
                }

                service.prepareForDashboardRefreshIfStale()
                startWeatherUpdates(forceRefreshExistingLocation: true)
            }
        }
        .onChange(of: purchaseManager.hasProAccess) { _, hasProAccess in
            WidgetCenter.shared.reloadAllTimelines()
            trackLaunchForReviewPromptIfNeeded()
            guard hasProAccess else { return }
            startWeatherUpdates(forceRefreshExistingLocation: true)
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
        }
        .onChange(of: showFeelsLikeTemperatures) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }

    @ViewBuilder
    private var dashboardView: some View {
        let theme = GlanceThemeResolver.widgetGlassTheme(colorScheme: .dark)

        #if DEBUG
        if DebugWeatherReplayView.isEnabled {
            DebugWeatherReplayView(theme: theme, useCelsius: useCelsius)
                .transition(.opacity)
        } else if service.hasLoadedDashboardSnapshot {
            AppDashboardView(
                snapshot: service.dashboardSnapshot,
                theme: theme,
                useCelsius: useCelsius,
                showFeelsLikeTemperatures: showFeelsLikeTemperatures,
                onSettingsTapped: { showSettings = true }
            )
            .transition(.opacity)
        } else {
            SkyGlanceLoadingView()
                .transition(.opacity)
        }
        #else
        if service.hasLoadedDashboardSnapshot {
            AppDashboardView(
                snapshot: service.dashboardSnapshot,
                theme: theme,
                useCelsius: useCelsius,
                showFeelsLikeTemperatures: showFeelsLikeTemperatures,
                onSettingsTapped: { showSettings = true }
            )
            .transition(.opacity)
        } else {
            SkyGlanceLoadingView()
                .transition(.opacity)
        }
        #endif
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

    private func trackLaunchForReviewPromptIfNeeded() {
        guard !didCountThisLaunchForReview,
              purchaseManager.hasProAccess,
              !purchaseManager.isTrialExpired
        else {
            return
        }

        didCountThisLaunchForReview = true
        reviewLaunchCount += 1

        guard reviewLaunchCount >= 3,
              lastReviewPromptedVersion != currentAppVersion
        else {
            return
        }

        lastReviewPromptedVersion = currentAppVersion
        requestReview()
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "skyglance",
              url.host == "widget-interaction"
        else {
            return
        }

        widgetInteractionCount += 1

        if widgetInteractionCount == 2, !didPromptAfterSecondWidgetInteraction {
            didPromptAfterSecondWidgetInteraction = true
            requestReview()
        } else if widgetInteractionCount == 3, !didPromptAfterThirdWidgetInteraction {
            didPromptAfterThirdWidgetInteraction = true
            requestReview()
        }
    }

    private var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private var shouldShowDashboard: Bool {
        #if DEBUG
        purchaseManager.hasProAccess || DebugWeatherReplayView.isEnabled
        #else
        purchaseManager.hasProAccess
        #endif
    }

    private func startDebugWidgetReplayIfNeeded() {
        #if DEBUG
        guard DebugWeatherReplayView.isEnabled, debugWidgetReplayTask == nil else { return }
        debugWidgetReplayTask = DebugWidgetReplayController.start()
        #endif
    }

}

#if DEBUG
private enum DebugWidgetReplayController {
    private static let simulatedMinutes = 9 * 60
    private static let durationSeconds: TimeInterval = 20

    static func start() -> Task<Void, Never> {
        Task {
            SharedLocationStore.clearDebugWidgetReplay()

            let startDate = Date().addingTimeInterval(1)
            let interval = durationSeconds / Double(simulatedMinutes)
            let entries = (0..<simulatedMinutes).map { minute in
                makeWidgetEntry(
                    simulatedMinute: minute,
                    date: startDate.addingTimeInterval(Double(minute) * interval)
                )
            }
            SharedLocationStore.saveDebugWidgetReplay(
                entries: entries,
                activeUntil: startDate.addingTimeInterval(durationSeconds + 10)
            )
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    private static func makeWidgetEntry(simulatedMinute: Int, date: Date) -> GlanceWidgetEntry {
        let replayDate = replayDate(for: simulatedMinute)
        let condition = condition(for: simulatedMinute)
        let temperature = temperature(for: simulatedMinute)
        let remainingMinutes = max(0, simulatedMinutes - simulatedMinute - 1)

        return GlanceWidgetEntry(
            date: date,
            cityName: "NYC",
            currentTemperature: temperature,
            currentCondition: condition,
            inlineSummary: "\(remainingMinutes)m left",
            hours: minuteForecastItems(from: replayDate, simulatedMinute: simulatedMinute),
            mood: temperature >= 68 ? .warm : .cool,
            feelsLikeTemperature: temperature - 1,
            windSpeed: "\(windSpeed(for: simulatedMinute)) mph",
            sunriseTime: "5:27A",
            sunsetTime: "8:22P",
            isDaylight: replayDate < replaySunsetDate(for: replayDate)
        )
    }

    private static func minuteForecastItems(
        from date: Date,
        simulatedMinute: Int
    ) -> [HourForecastItem] {
        (0..<6).map { offset in
            let forecastMinute = min(simulatedMinute + offset * 60, simulatedMinutes - 1)
            let forecastDate = Calendar.current.date(byAdding: .hour, value: offset, to: date) ?? date
            return HourForecastItem(
                label: offset == 0 ? "Now" : hourLabel(for: forecastDate),
                condition: condition(for: forecastMinute),
                temperature: temperature(for: forecastMinute),
                feelsLikeTemperature: temperature(for: forecastMinute) - 1
            )
        }
    }

    private static func replayDate(for simulatedMinute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.day = (components.day ?? 1) - 1
        components.hour = 15
        components.minute = 0
        let start = Calendar.current.date(from: components) ?? Date()
        return Calendar.current.date(byAdding: .minute, value: simulatedMinute, to: start) ?? start
    }

    private static func replaySunsetDate(for date: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 20
        components.minute = 22
        components.second = 0
        return Calendar.current.date(from: components) ?? date
    }

    private static func minuteLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: date)
    }

    private static func hourLabel(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        return "\(hour12)\(hour < 12 ? "A" : "P")"
    }

    private static func temperature(for simulatedMinute: Int) -> Int {
        let progress = Double(simulatedMinute) / Double(max(simulatedMinutes - 1, 1))
        return 74 - Int((progress * 16).rounded())
    }

    private static func windSpeed(for simulatedMinute: Int) -> Int {
        let progress = Double(simulatedMinute) / Double(max(simulatedMinutes - 1, 1))
        return 5 + Int((sin(progress * .pi) * 9).rounded())
    }

    private static func condition(for simulatedMinute: Int) -> WeatherCondition {
        switch simulatedMinute {
        case 0..<90:
            return .mostlySunny
        case 90..<210:
            return .cloudy
        case 210..<330:
            return .rain
        case 330..<450:
            return .cloudy
        default:
            return .clearNight
        }
    }
}

private struct DebugWeatherReplayView: View {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-skyglanceReplayYesterday12h")
    }

    let theme: GlanceTheme
    let useCelsius: Bool

    @State private var frameIndex = 0
    private let frames = DebugWeatherReplayFactory.makeFrames()
    private let replayTimer = Timer.publish(every: 20.0 / 12.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .top) {
            AppDashboardView(
                snapshot: frames[frameIndex],
                theme: theme,
                useCelsius: useCelsius,
                showFeelsLikeTemperatures: false,
                onSettingsTapped: nil
            )

            VStack(spacing: 6) {
                Text("Yesterday Weather Replay")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("12 hours compressed into 20 seconds")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(.black.opacity(0.34))
                    .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
            )
            .padding(.top, 8)
        }
        .onReceive(replayTimer) { _ in
            frameIndex = min(frameIndex + 1, frames.count - 1)
        }
    }
}

private enum DebugWeatherReplayFactory {
    static func makeFrames() -> [AppWeatherSnapshot] {
        let labels = ["8 AM", "9 AM", "10 AM", "11 AM", "12 PM", "1 PM", "2 PM", "3 PM", "4 PM", "5 PM", "6 PM", "7 PM"]
        let temperatures = [58, 60, 63, 66, 69, 72, 74, 73, 70, 67, 64, 61]
        let feelsLike = [56, 59, 62, 66, 69, 71, 73, 72, 69, 66, 63, 60]
        let conditions: [WeatherCondition] = [.cloudy, .mostlySunny, .sunny, .sunny, .mostlySunny, .cloudy, .rain, .rain, .cloudy, .mostlySunny, .sunny, .clearNight]
        let descriptions = ["Cloudy", "Mostly Sunny", "Sunny", "Sunny", "Mostly Sunny", "Cloudy", "Light Rain", "Rain", "Cloudy", "Clearing", "Sunny", "Clear"]
        let rainChances: [Int?] = [nil, nil, nil, 5, 10, 30, 65, 70, 35, 15, nil, nil]

        return labels.indices.map { index in
            let hourly = (0..<8).map { offset in
                let sourceIndex = min(index + offset, labels.count - 1)
                return AppHourlyForecast(
                    timeLabel: offset == 0 ? "Now" : labels[sourceIndex],
                    condition: conditions[sourceIndex],
                    temperature: temperatures[sourceIndex],
                    feelsLikeTemperature: feelsLike[sourceIndex],
                    precipitationChance: rainChances[sourceIndex]
                )
            }

            return AppWeatherSnapshot(
                cityName: "New York",
                currentTemperature: temperatures[index],
                condition: conditions[index],
                conditionDescription: descriptions[index],
                feelsLikeTemperature: feelsLike[index],
                highTemperature: 74,
                lowTemperature: 56,
                hourly: hourly,
                daily: makeDailyForecast(currentIndex: index),
                overviewMetrics: [
                    AppMetric(title: "Air Quality", value: index < 7 ? "32" : "28", detail: "Good"),
                    AppMetric(title: "UV Index", value: index < 4 ? "3" : index < 8 ? "6" : "2", detail: index < 8 ? "Moderate" : "Low"),
                    AppMetric(title: "Sunrise", value: "5:27 AM", detail: nil),
                    AppMetric(title: "Sunset", value: "8:22 PM", detail: nil),
                ],
                detailMetrics: [
                    AppMetric(title: "Humidity", value: "\(humidity(for: index))%", detail: nil),
                    AppMetric(title: "Dew Point", value: "\(dewPoint(for: index))°", detail: nil),
                    AppMetric(title: "Wind", value: "\(windSpeed(for: index)) mph", detail: windDirection(for: index)),
                    AppMetric(title: "Pressure", value: pressure(for: index), detail: index < 6 ? "Steady" : "Falling"),
                    AppMetric(title: "Visibility", value: index == 7 ? "6 mi" : "10 mi", detail: nil),
                    AppMetric(title: "Feels Like", value: "\(feelsLike[index])°", detail: nil),
                ],
                spotlightTitle: "Replay Window",
                spotlightValue: "\(labels[index]) yesterday",
                spotlightSubtitle: spotlightSubtitle(for: index),
                mood: index < 6 ? .warm : .cool
            )
        }
    }

    private static func makeDailyForecast(currentIndex: Int) -> [AppDailyForecast] {
        [
            AppDailyForecast(dayLabel: "Yesterday", condition: currentIndex < 6 ? .mostlySunny : .rain, highTemperature: 74, lowTemperature: 56, precipitationChance: 70),
            AppDailyForecast(dayLabel: "Today", condition: .cloudy, highTemperature: 69, lowTemperature: 57, precipitationChance: 25),
            AppDailyForecast(dayLabel: "Fri", condition: .sunny, highTemperature: 76, lowTemperature: 59, precipitationChance: nil),
            AppDailyForecast(dayLabel: "Sat", condition: .mostlySunny, highTemperature: 79, lowTemperature: 61, precipitationChance: nil),
            AppDailyForecast(dayLabel: "Sun", condition: .cloudy, highTemperature: 72, lowTemperature: 58, precipitationChance: 20),
            AppDailyForecast(dayLabel: "Mon", condition: .rain, highTemperature: 68, lowTemperature: 55, precipitationChance: 60),
            AppDailyForecast(dayLabel: "Tue", condition: .sunny, highTemperature: 75, lowTemperature: 57, precipitationChance: nil),
        ]
    }

    private static func humidity(for index: Int) -> Int { [64, 60, 55, 50, 47, 52, 68, 74, 70, 62, 55, 58][index] }
    private static func dewPoint(for index: Int) -> Int { [46, 47, 48, 49, 50, 53, 58, 59, 57, 54, 50, 49][index] }
    private static func windSpeed(for index: Int) -> Int { [6, 7, 8, 8, 9, 11, 14, 15, 12, 9, 7, 6][index] }
    private static func windDirection(for index: Int) -> String { ["NW", "NW", "W", "W", "SW", "S", "SE", "SE", "E", "NE", "N", "NW"][index] }
    private static func pressure(for index: Int) -> String { ["30.11 in", "30.10 in", "30.08 in", "30.07 in", "30.05 in", "30.01 in", "29.96 in", "29.93 in", "29.97 in", "30.02 in", "30.06 in", "30.08 in"][index] }

    private static func spotlightSubtitle(for index: Int) -> String {
        if index < 5 {
            return "Morning warmed steadily with bright breaks and light wind."
        } else if index < 8 {
            return "A fast afternoon shower moved through with rising humidity."
        } else {
            return "Evening cleared out as temperatures eased back down."
        }
    }
}
#endif

private struct SkyGlanceLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            loadingBackground.ignoresSafeArea()

            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 76, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 12)
                .scaleEffect(isAnimating ? 1.03 : 0.97)
                .opacity(isAnimating ? 1.0 : 0.86)
                .animation(
                    .easeInOut(duration: 1.35).repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
    }

    private var loadingBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.24, blue: 0.43),
                    Color(red: 0.18, green: 0.42, blue: 0.68),
                    Color(red: 0.09, green: 0.18, blue: 0.32),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.white.opacity(0.22), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 420
            )
            RadialGradient(
                colors: [Color(red: 0.48, green: 0.76, blue: 1.0).opacity(0.24), Color.clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 340
            )
        }
    }
}

// MARK: – Lightweight Location Manager

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var cityName: String?
    @Published var isUsingManualLocation: Bool
    @Published var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var stopUpdatesTask: Task<Void, Never>?
    private var requestStartedAt: Date?
    private var bestLocationThisRequest: CLLocation?
    private var lastWidgetReloadAt: Date?
    private let travelLocationMinimumDistance: CLLocationDistance = 10_000

    override init() {
        authorizationStatus = manager.authorizationStatus
        isUsingManualLocation = SharedLocationStore.isManualLocationEnabled
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .other
        manager.pausesLocationUpdatesAutomatically = false
    }

    func begin() {
        authorizationStatus = manager.authorizationStatus
        isUsingManualLocation = SharedLocationStore.isManualLocationEnabled

        if isUsingManualLocation {
            if restoreManualLocationIfAvailable() != nil {
                stopUpdatingLocation()
                updateTravelTrackingMode()
                return
            }

            isUsingManualLocation = false
            SharedLocationStore.clearManualLocation()
        }

        switch authorizationStatus {
        case .authorizedAlways:
            requestPreciseLocationIfNeeded()
            updateTravelTrackingMode()
            requestFreshLocation()
        case .authorizedWhenInUse:
            requestPreciseLocationIfNeeded()
            requestAlwaysAuthorizationIfNeeded()
            updateTravelTrackingMode()
            requestFreshLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            updateTravelTrackingMode()
            break
        @unknown default:
            updateTravelTrackingMode()
            break
        }
    }

    @discardableResult
    func restoreCachedLocationIfAvailable() -> (location: CLLocation, cityName: String?)? {
        if let manualLocation = restoreManualLocationIfAvailable() {
            return manualLocation
        }

        guard location == nil, let cached = SharedLocationStore.loadDeviceLocation() else {
            return nil
        }

        cityName = cached.cityName
        location = cached.location
        return cached
    }

    @discardableResult
    func restoreManualLocationIfAvailable() -> (location: CLLocation, cityName: String?)? {
        guard let cached = SharedLocationStore.loadManualLocation() else {
            return nil
        }

        isUsingManualLocation = true
        cityName = cached.cityName
        location = cached.location
        return cached
    }

    func useManualLocation(_ newLocation: CLLocation, cityName newCityName: String?) {
        stopUpdatingLocation()
        isUsingManualLocation = true
        updateTravelTrackingMode()
        cityName = newCityName
        location = newLocation
        SharedLocationStore.save(location: newLocation, cityName: newCityName, isManual: true)
        reloadWidgetsIfNeeded(force: true)
    }

    func useCurrentLocation() {
        isUsingManualLocation = false
        cityName = nil
        SharedLocationStore.clearManualLocation()
        begin()
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard !isUsingManualLocation else {
                stopUpdatingLocation()
                return
            }

            let freshLocations = locations
                .filter { candidate in
                    candidate.horizontalAccuracy >= 0 &&
                    isUsableLocationUpdate(candidate)
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
            case .authorizedAlways:
                requestPreciseLocationIfNeeded()
                updateTravelTrackingMode()
                requestFreshLocation()
            case .authorizedWhenInUse:
                requestPreciseLocationIfNeeded()
                requestAlwaysAuthorizationIfNeeded()
                updateTravelTrackingMode()
                requestFreshLocation()
            case .denied, .restricted, .notDetermined:
                stopUpdatingLocation()
                updateTravelTrackingMode()
                break
            @unknown default:
                updateTravelTrackingMode()
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

    private func requestAlwaysAuthorizationIfNeeded() {
        guard manager.authorizationStatus == .authorizedWhenInUse else { return }
        manager.requestAlwaysAuthorization()
    }

    private func updateTravelTrackingMode() {
        guard !isUsingManualLocation else {
            manager.stopMonitoringSignificantLocationChanges()
            manager.allowsBackgroundLocationUpdates = false
            manager.pausesLocationUpdatesAutomatically = true
            return
        }

        if manager.authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = true
            manager.startMonitoringSignificantLocationChanges()
        } else {
            manager.stopMonitoringSignificantLocationChanges()
            manager.allowsBackgroundLocationUpdates = false
            manager.pausesLocationUpdatesAutomatically = false
        }
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

    private func isUsableLocationUpdate(_ candidate: CLLocation) -> Bool {
        if isFromCurrentRequest(candidate) {
            return abs(candidate.timestamp.timeIntervalSinceNow) < 30
        }

        // Significant-change updates can arrive outside an active foreground request.
        // Keep them fresh enough to avoid cached bootstrapping locations.
        return manager.authorizationStatus == .authorizedAlways &&
            abs(candidate.timestamp.timeIntervalSinceNow) < 5 * 60
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

        if !isFromCurrentRequest(newLocation) {
            return newLocation.distance(from: currentLocation) >= travelLocationMinimumDistance
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
