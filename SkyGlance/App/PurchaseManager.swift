import Foundation
import StoreKit
import WidgetKit

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var hasProAccess: Bool = EntitlementStore.hasProAccess
    @Published private(set) var isLifetimeUnlocked: Bool = EntitlementStore.isLifetimeUnlocked
    @Published private(set) var isTrialExpired: Bool = !EntitlementStore.isLifetimeUnlocked && !EntitlementStore.isTrialActive
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var statusText: String = EntitlementStore.accessSummary
    @Published private(set) var trialStatusText: String = PurchaseManager.makeTrialStatusText(
        isLifetimeUnlocked: EntitlementStore.isLifetimeUnlocked,
        isTrialActive: EntitlementStore.isTrialActive
    )
    @Published var errorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    var displayPrice: String {
        product?.displayPrice ?? "$7.99"
    }

    init() {
        EntitlementStore.ensureTrialStarted()
        refreshAccessState()

        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionResult: result)
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func configure() async {
        await refreshPurchasedEntitlements()
        await loadProducts()
        refreshAccessState()
    }

    func refreshAccessState() {
        let isLifetimeUnlocked = EntitlementStore.isLifetimeUnlocked
        let isTrialActive = EntitlementStore.isTrialActive

        hasProAccess = isLifetimeUnlocked || isTrialActive
        self.isLifetimeUnlocked = isLifetimeUnlocked
        isTrialExpired = !isLifetimeUnlocked && !isTrialActive
        statusText = EntitlementStore.accessSummary
        trialStatusText = Self.makeTrialStatusText(
            isLifetimeUnlocked: isLifetimeUnlocked,
            isTrialActive: isTrialActive
        )
    }

    func loadProducts() async {
        guard product == nil else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            product = try await Product.products(for: [EntitlementStore.lifetimeProductID]).first
            if product == nil {
#if DEBUG
                errorMessage = "Lifetime unlock is not available yet. Create the non-consumable product in App Store Connect with product ID \(EntitlementStore.lifetimeProductID), or attach a StoreKit configuration to the Debug scheme."
#else
                errorMessage = "Lifetime unlock is temporarily unavailable. Please try again later."
#endif
            } else {
                errorMessage = nil
            }
        } catch {
            errorMessage = "Could not load the lifetime unlock: \(error.localizedDescription)"
        }
    }

    func purchaseLifetimeUnlock() async {
        errorMessage = nil

        if product == nil {
            await loadProducts()
        }

        guard let product else {
            if errorMessage == nil {
#if DEBUG
                errorMessage = "Lifetime unlock is not available. Run the app from Xcode with the app scheme so the StoreKit test product is attached."
#else
                errorMessage = "Lifetime unlock is temporarily unavailable. Please try again later."
#endif
            }
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
#if DEBUG
                EntitlementStore.debugClearForcedExpiration()
#endif
                EntitlementStore.setLifetimeUnlocked(true)
                await transaction.finish()
                refreshAccessState()
                WidgetCenter.shared.reloadAllTimelines()
            case .pending:
                errorMessage = "Purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                errorMessage = "The purchase could not be completed."
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        errorMessage = nil

        do {
            try await AppStore.sync()
            await refreshPurchasedEntitlements(allowForcedExpiredOverride: true)
#if DEBUG
            if EntitlementStore.isLifetimeUnlocked {
                EntitlementStore.debugClearForcedExpiration()
            }
#endif
            refreshAccessState()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func refreshPurchasedEntitlements(allowForcedExpiredOverride: Bool = false) async {
#if DEBUG
        if EntitlementStore.debugForceExpired, !allowForcedExpiredOverride {
            EntitlementStore.setLifetimeUnlocked(false)
            return
        }
#endif

        var verifiedLifetimeUnlock = false

        for await result in Transaction.currentEntitlements {
            guard
                let transaction = try? checkVerified(result),
                transaction.productID == EntitlementStore.lifetimeProductID,
                transaction.revocationDate == nil
            else {
                continue
            }

            verifiedLifetimeUnlock = true
        }

        EntitlementStore.setLifetimeUnlocked(verifiedLifetimeUnlock)

        if verifiedLifetimeUnlock {
#if DEBUG
            EntitlementStore.debugClearForcedExpiration()
#endif
        }
    }

    private func handle(transactionResult result: VerificationResult<Transaction>) async {
        guard
            let transaction = try? checkVerified(result),
            transaction.productID == EntitlementStore.lifetimeProductID
        else {
            return
        }

        if transaction.revocationDate == nil {
#if DEBUG
            EntitlementStore.debugClearForcedExpiration()
#endif
            EntitlementStore.setLifetimeUnlocked(true)
        } else {
            await refreshPurchasedEntitlements()
        }

        await transaction.finish()
        refreshAccessState()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, _):
            throw PurchaseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private static func makeTrialStatusText(
        isLifetimeUnlocked: Bool,
        isTrialActive: Bool
    ) -> String {
        if isLifetimeUnlocked {
            return "Unlocked"
        }

        guard isTrialActive else {
            return "Ended"
        }

        return EntitlementStore.trialRemainingText
    }
}

private enum PurchaseError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        "The App Store could not verify this purchase."
    }
}
