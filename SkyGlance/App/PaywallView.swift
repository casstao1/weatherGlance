import SwiftUI

struct PaywallView: View {
    @ObservedObject var purchaseManager: PurchaseManager
    var onDismiss: (() -> Void)?

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.11, blue: 0.16)
                .ignoresSafeArea()

            if let onDismiss {
                VStack {
                    HStack {
                        Spacer()

                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white.opacity(0.82))
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.12), in: Circle())
                        }
                        .accessibilityLabel("Close")
                    }
                    .padding(.top, 18)
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .zIndex(1)
            }

            VStack(spacing: 24) {
                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    Image(systemName: "cloud.sun")
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.white)

                    Text(paywallTitle)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)

                    Text(paywallSubtitle)
                        .font(.system(size: 16, weight: .regular))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.68))
                        .lineSpacing(3)
                        .padding(.horizontal, 10)
                }

                VStack(alignment: .leading, spacing: 14) {
                    PaywallFeatureRow(symbol: "rectangle.grid.2x2", title: "Home Screen and Lock Screen widgets")
                    PaywallFeatureRow(symbol: "thermometer.variable", title: "Feels-like temperature mode")
                    PaywallFeatureRow(symbol: "sunset", title: "Sunrise and sunset details")
                    PaywallFeatureRow(symbol: "arrow.clockwise", title: "Hourly forecast refreshes")
                }
                .padding(18)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(spacing: 12) {
                    Button {
                        Task {
                            await purchaseManager.purchaseLifetimeUnlock()
                        }
                    } label: {
                        HStack {
                            Spacer()

                            if purchaseManager.isPurchasing {
                                ProgressView()
                                    .tint(Color(red: 0.08, green: 0.11, blue: 0.16))
                            } else if purchaseManager.isLoadingProducts {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .tint(Color(red: 0.08, green: 0.11, blue: 0.16))

                                    Text("Loading Purchase")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            } else {
                                Text("Continue")
                                    .font(.system(size: 17, weight: .semibold))
                            }

                            Spacer()
                        }
                        .frame(height: 54)
                        .foregroundStyle(Color(red: 0.08, green: 0.11, blue: 0.16))
                        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .disabled(purchaseManager.isPurchasing || purchaseManager.isLoadingProducts)

                    Button {
                        Task {
                            await purchaseManager.restorePurchases()
                        }
                    } label: {
                        Text("Refresh Access")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                    }

                    Text("SkyGlance is unlocked with the paid app purchase.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.45))
                }

                if let errorMessage = purchaseManager.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .regular))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.58))
                        .padding(.horizontal)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
        }
        .task {
            await purchaseManager.configure()
        }
    }

    private var paywallTitle: String {
        "SkyGlance is unlocked"
    }

    private var paywallSubtitle: String {
        "Thanks for supporting SkyGlance. The app and widgets are included with the paid download."
    }
}

private struct PaywallFeatureRow: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 22)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
        }
    }
}

#Preview {
    PaywallView(purchaseManager: PurchaseManager())
}
