import SwiftUI

struct SettingsView: View {
    private let appleWeatherAttributionURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    @ObservedObject var purchaseManager: PurchaseManager
    @AppStorage("useCelsius") var useCelsius: Bool = false
    @AppStorage(
        SharedLocationStore.showFeelsLikeTemperaturesKey,
        store: SharedLocationStore.defaults
    ) var showFeelsLikeTemperatures: Bool = false
    var onEntitlementsChanged: (() -> Void)? = nil
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
    SettingsView(purchaseManager: PurchaseManager())
}
