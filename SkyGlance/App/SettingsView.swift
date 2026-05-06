import SwiftUI
import CoreLocation
import WidgetKit

struct SettingsView: View {
    private let appleWeatherAttributionURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    @ObservedObject var purchaseManager: PurchaseManager
    @ObservedObject var locationManager: LocationManager
    @AppStorage("useCelsius") var useCelsius: Bool = false
    @AppStorage(
        SharedLocationStore.showFeelsLikeTemperaturesKey,
        store: SharedLocationStore.defaults
    ) var showFeelsLikeTemperatures: Bool = false
    @AppStorage(
        SharedLocationStore.homeWidgetDarkModeKey,
        store: SharedLocationStore.defaults
    ) var legacyHomeWidgetDarkMode: Bool = false
    @AppStorage(
        SharedLocationStore.homeWidgetAppearanceModeKey,
        store: SharedLocationStore.defaults
    ) var homeWidgetAppearanceModeRawValue: String = ""
    var onEntitlementsChanged: (() -> Void)? = nil
    var onWeatherLocationChanged: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.13, green: 0.17, blue: 0.24)
                    .ignoresSafeArea()

                List {
                    // Temperature Units
                    Section {
                        Picker("Temperature Unit", selection: $useCelsius) {
                            Text("Fahrenheit (°F)").tag(false)
                            Text("Celsius (°C)").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.white.opacity(0.08))

                        Toggle(isOn: $showFeelsLikeTemperatures) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Show Feels Like")
                                    .foregroundStyle(.white.opacity(0.9))

                                Text("Use apparent temperatures in the main and hourly weather views.")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tint(.white.opacity(0.75))
                        .listRowBackground(Color.white.opacity(0.08))
                    } header: {
                        Text("Temperature")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.system(size: 12, weight: .medium))
                            .textCase(nil)
                    }

                    Section {
                        SettingsValueRow(title: "Weather Location", value: weatherLocationName)
                            .listRowBackground(Color.white.opacity(0.08))

                        NavigationLink {
                            LocationSearchView(
                                locationManager: locationManager,
                                onLocationChanged: onWeatherLocationChanged
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Search Location")
                                    .foregroundStyle(.white.opacity(0.9))

                                Text(weatherLocationDetail)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.08))

                        if locationManager.isUsingManualLocation {
                            Button {
                                locationManager.useCurrentLocation()
                            } label: {
                                Text("Use Current Location")
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .listRowBackground(Color.white.opacity(0.08))
                        }
                    } header: {
                        Text("Location")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.system(size: 12, weight: .medium))
                            .textCase(nil)
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Home Screen Widget Appearance")
                                    .foregroundStyle(.white.opacity(0.9))

                                Text(selectedHomeWidgetAppearanceMode.settingsDetail)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Picker("Home Screen Widget Appearance", selection: homeWidgetAppearanceSelection) {
                                ForEach(HomeWidgetAppearanceMode.allCases) { mode in
                                    Text(mode.title).tag(mode.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .listRowBackground(Color.white.opacity(0.08))

                        NavigationLink {
                            WidgetInstructionsView()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Add SkyGlance Widgets")
                                    .foregroundStyle(.white.opacity(0.9))

                                Text("Home Screen and Lock Screen setup instructions.")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.08))
                    } header: {
                        Text("Widgets")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.system(size: 12, weight: .medium))
                            .textCase(nil)
                    }

                    if !purchaseManager.isLifetimeUnlocked {
                        Section {
                            SettingsValueRow(title: "Trial", value: trialStatusText)
                                .listRowBackground(Color.white.opacity(0.08))

                            Text(trialMessage)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.white.opacity(0.55))
                                .fixedSize(horizontal: false, vertical: true)
                                .listRowBackground(Color.white.opacity(0.08))

                            Button {
                                Task {
                                    await purchaseManager.purchaseLifetimeUnlock()
                                    onEntitlementsChanged?()
                                }
                            } label: {
                                HStack {
                                    if purchaseManager.isPurchasing || purchaseManager.isLoadingProducts {
                                        ProgressView()
                                            .tint(.white.opacity(0.85))
                                    }

                                    Text(purchaseButtonTitle)
                                        .foregroundStyle(.white.opacity(0.9))

                                    Spacer()
                                }
                            }
                            .disabled(purchaseManager.isPurchasing || purchaseManager.isLoadingProducts)
                            .listRowBackground(Color.white.opacity(0.08))

                            Button {
                                Task {
                                    await purchaseManager.restorePurchases()
                                    onEntitlementsChanged?()
                                }
                            } label: {
                                Text("Restore Purchase")
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .disabled(purchaseManager.isPurchasing)
                            .listRowBackground(Color.white.opacity(0.08))

                            if let errorMessage = purchaseManager.errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .listRowBackground(Color.white.opacity(0.08))
                            }
                        } header: {
                            Text("Purchase")
                                .foregroundStyle(.white.opacity(0.5))
                                .font(.system(size: 12, weight: .medium))
                                .textCase(nil)
                        }
                    }

                    // About
                    Section {
                        SettingsValueRow(title: "Data sources", value: "Open-Meteo /  Weather")
                            .listRowBackground(Color.white.opacity(0.08))

                        Link(destination: appleWeatherAttributionURL) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(" Weather legal attribution")
                                        .foregroundStyle(.white.opacity(0.9))

                                    Text("View Apple Weather trademark and legal source information.")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(.white.opacity(0.45))
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.08))

                        SettingsValueRow(
                            title: "Version",
                            value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                        )
                        .listRowBackground(Color.white.opacity(0.08))
                    } header: {
                        Text("About")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.system(size: 12, weight: .medium))
                            .textCase(nil)
                    }
                }
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
            }
        }
        .task {
            guard !purchaseManager.isLifetimeUnlocked else { return }
            await purchaseManager.loadProducts()
        }
    }

    private var selectedHomeWidgetAppearanceMode: HomeWidgetAppearanceMode {
        HomeWidgetAppearanceMode.resolved(
            rawValue: homeWidgetAppearanceModeRawValue,
            legacyDarkMode: legacyHomeWidgetDarkMode
        )
    }

    private var weatherLocationName: String {
        locationManager.cityName ?? "Current Location"
    }

    private var weatherLocationDetail: String {
        if locationManager.isUsingManualLocation {
            return "Using a saved location. Tap to search for another city."
        }

        return "Using your iPhone location. Tap to search for a city instead."
    }

    private var homeWidgetAppearanceSelection: Binding<String> {
        Binding {
            selectedHomeWidgetAppearanceMode.rawValue
        } set: { newValue in
            guard homeWidgetAppearanceModeRawValue != newValue else { return }
            homeWidgetAppearanceModeRawValue = newValue
            legacyHomeWidgetDarkMode = newValue == HomeWidgetAppearanceMode.dark.rawValue
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private var trialMessage: String {
        if purchaseManager.isTrialExpired {
            return "Your 7-day trial has ended. Unlock lifetime access once to keep using SkyGlance."
        }

        return "Your 7-day trial includes the app and all widgets. Unlock once to keep access forever."
    }

    private var trialStatusText: String {
        purchaseManager.trialStatusText
    }

    private var purchaseButtonTitle: String {
        if purchaseManager.isPurchasing {
            return "Purchasing..."
        }

        if purchaseManager.isLoadingProducts {
            return "Loading Purchase..."
        }

        return "Unlock Lifetime \(purchaseManager.displayPrice)"
    }
}

private struct LocationSearchView: View {
    @ObservedObject var locationManager: LocationManager
    var onLocationChanged: (() -> Void)?

    @StateObject private var searchModel = LocationSearchModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.13, green: 0.17, blue: 0.24)
                .ignoresSafeArea()

            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("City, ZIP, or address", text: $searchModel.query)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .submitLabel(.search)
                            .onSubmit {
                                Task { await searchModel.search() }
                            }
                            .padding(12)
                            .foregroundStyle(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white.opacity(0.10))
                            )

                        Button {
                            Task { await searchModel.search() }
                        } label: {
                            HStack {
                                if searchModel.isSearching {
                                    ProgressView()
                                        .tint(.white.opacity(0.85))
                                }

                                Text(searchModel.isSearching ? "Searching..." : "Search")
                                    .font(.system(size: 15, weight: .semibold))

                                Spacer()

                                Image(systemName: "magnifyingglass")
                            }
                            .foregroundStyle(.white.opacity(searchModel.canSearch ? 0.9 : 0.4))
                        }
                        .disabled(!searchModel.canSearch || searchModel.isSearching)
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                } header: {
                    Text("Set Weather Location")
                        .foregroundStyle(.white.opacity(0.5))
                        .font(.system(size: 12, weight: .medium))
                        .textCase(nil)
                }

                if locationManager.isUsingManualLocation {
                    Section {
                        Button {
                            locationManager.useCurrentLocation()
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Use Current Location")
                                    .foregroundStyle(.white.opacity(0.9))

                                Text("Switch back to your iPhone location for weather updates.")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.08))
                    }
                }

                if let errorMessage = searchModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                            .listRowBackground(Color.white.opacity(0.08))
                    }
                }

                if !searchModel.results.isEmpty {
                    Section {
                        ForEach(searchModel.results) { result in
                            Button {
                                locationManager.useManualLocation(result.location, cityName: result.cityName)
                                onLocationChanged?()
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.9))

                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundStyle(.white.opacity(0.48))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.white.opacity(0.08))
                        }
                    } header: {
                        Text("Results")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.system(size: 12, weight: .medium))
                            .textCase(nil)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(.white)
        }
        .navigationTitle("Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct LocationSearchResult: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let cityName: String
    let location: CLLocation

    init?(placemark: CLPlacemark, fallbackTitle: String) {
        guard let location = placemark.location else { return nil }

        let title = placemark.locality
            ?? placemark.name
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? fallbackTitle

        let subtitleParts = [
            placemark.administrativeArea,
            placemark.country
        ]
            .compactMap { $0 }
            .filter { !$0.isEmpty && $0 != title }

        self.id = "\(location.coordinate.latitude),\(location.coordinate.longitude),\(title)"
        self.title = title
        self.subtitle = subtitleParts.joined(separator: ", ")
        self.cityName = title
        self.location = location
    }
}

@MainActor
private final class LocationSearchModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [LocationSearchResult] = []
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?

    private let geocoder = CLGeocoder()

    var canSearch: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func search() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        geocoder.cancelGeocode()
        isSearching = true
        errorMessage = nil

        do {
            let placemarks = try await geocoder.geocodeAddressString(trimmedQuery)
            results = placemarks.compactMap {
                LocationSearchResult(placemark: $0, fallbackTitle: trimmedQuery)
            }

            if results.isEmpty {
                errorMessage = "No matching locations were found. Try a city, ZIP code, or full address."
            }
        } catch {
            results = []
            let nsError = error as NSError
            if nsError.domain == kCLErrorDomain,
               nsError.code == CLError.geocodeCanceled.rawValue {
                errorMessage = nil
            } else {
                errorMessage = "Could not search for that location. Check the spelling and try again."
            }
        }

        isSearching = false
    }
}

private struct WidgetInstructionsView: View {
    private let homeScreenSteps = [
        WidgetInstructionStep(
            title: "Touch and hold the Home Screen",
            detail: "Press an empty area until the app icons start to jiggle."
        ),
        WidgetInstructionStep(
            title: "Tap the + button",
            detail: "Use the add button in the top corner, then search for SkyGlance."
        ),
        WidgetInstructionStep(
            title: "Choose a widget size",
            detail: "Pick the small or medium SkyGlance widget, then tap Add Widget."
        ),
        WidgetInstructionStep(
            title: "Place it and tap Done",
            detail: "Move the widget where you want it. Open SkyGlance once after adding it so the forecast refreshes."
        )
    ]

    private let lockScreenSteps = [
        WidgetInstructionStep(
            title: "Open Lock Screen customization",
            detail: "Lock your iPhone, touch and hold the Lock Screen, then tap Customize."
        ),
        WidgetInstructionStep(
            title: "Choose Lock Screen",
            detail: "Tap the Lock Screen preview instead of the Home Screen preview."
        ),
        WidgetInstructionStep(
            title: "Tap a widget area",
            detail: "Tap below the time for circular or rectangular widgets, or above the time for the inline widget."
        ),
        WidgetInstructionStep(
            title: "Select SkyGlance",
            detail: "Choose the SkyGlance widget you want, then tap Done to save the Lock Screen."
        )
    ]

    var body: some View {
        ZStack {
            Color(red: 0.13, green: 0.17, blue: 0.24)
                .ignoresSafeArea()

            List {
                Section {
                    Text("SkyGlance includes Home Screen widgets for your forecast and Lock Screen widgets for quick weather at a glance.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                        .listRowBackground(Color.white.opacity(0.08))
                }

                WidgetInstructionSection(
                    title: "Home Screen Widget",
                    symbol: "square.grid.2x2",
                    steps: homeScreenSteps
                )

                WidgetInstructionSection(
                    title: "Lock Screen Widget",
                    symbol: "lock.rectangle",
                    steps: lockScreenSteps
                )

                Section {
                    WidgetInstructionTip(
                        title: "If SkyGlance does not appear",
                        detail: "Open SkyGlance once, allow location access, then wait a few seconds and try adding the widget again. Restarting the iPhone can also refresh the widget list after a new install."
                    )

                    WidgetInstructionTip(
                        title: "If the widget looks stale",
                        detail: "SkyGlance refreshes widget forecasts in the background when iOS allows. Opening the app still forces an immediate refresh."
                    )
                } header: {
                    Text("Troubleshooting")
                        .foregroundStyle(.white.opacity(0.5))
                        .font(.system(size: 12, weight: .medium))
                        .textCase(nil)
                }
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(.white)
        }
        .navigationTitle("Widget Instructions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct WidgetInstructionSection: View {
    let title: String
    let symbol: String
    let steps: [WidgetInstructionStep]

    var body: some View {
        Section {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.13, green: 0.17, blue: 0.24))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(.white.opacity(0.82)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))

                        Text(step.detail)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.white.opacity(0.08))
            }
        } header: {
            Label(title, systemImage: symbol)
                .foregroundStyle(.white.opacity(0.5))
                .font(.system(size: 12, weight: .medium))
                .textCase(nil)
        }
    }
}

private struct WidgetInstructionTip: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            Text(detail)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.white.opacity(0.08))
    }
}

private struct WidgetInstructionStep {
    let title: String
    let detail: String
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

#Preview {
    SettingsView(purchaseManager: PurchaseManager(), locationManager: LocationManager())
}
