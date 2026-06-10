import Foundation
import WidgetKit

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var hasProAccess: Bool = true
    @Published private(set) var isLifetimeUnlocked: Bool = true
    @Published private(set) var isTrialExpired: Bool = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var statusText: String = EntitlementStore.accessSummary
    @Published private(set) var trialStatusText: String = "Paid app"
    @Published var errorMessage: String?

    var displayPrice: String {
        "Included"
    }

    init() {
        EntitlementStore.ensureTrialStarted()
        refreshAccessState()
    }

    func configure() async {
        refreshAccessState()
    }

    func refreshAccessState() {
        EntitlementStore.ensureTrialStarted()
        hasProAccess = true
        isLifetimeUnlocked = true
        isTrialExpired = false
        statusText = EntitlementStore.accessSummary
        trialStatusText = "Paid app"
        errorMessage = nil
    }

    func loadProducts() async {
        refreshAccessState()
    }

    func purchaseLifetimeUnlock() async {
        refreshAccessState()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func restorePurchases() async {
        refreshAccessState()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
