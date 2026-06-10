import Foundation

struct EntitlementStore {
    static let lifetimeProductID = "com.castao.weatherGlance.lifetime"
    static let lifetimeUnlockedKey = "monetization.lifetimeUnlocked"
    static let trialStartDateKey = "monetization.trialStartDate"
    static let latestSeenDateKey = "monetization.latestSeenDate"
    static let trialStorageMigrationDateKey = "monetization.trialStorageV4MigrationDate"
    static let trialExpirationLockedDateKey = "monetization.trialExpirationLockedDate"
#if DEBUG
    static let debugForceExpiredKey = "debug.monetization.forceExpired"
#endif
    static let trialDuration: TimeInterval = 7 * 24 * 60 * 60

    private static var defaults: UserDefaults {
        SharedLocationStore.defaults
    }

    static func ensureTrialStarted(now: Date = Date()) {
        clearLegacyTrialState()
    }

    static var isLifetimeUnlocked: Bool {
        true
    }

    static var trialStartDate: Date? {
        nil
    }

    static var trialEndDate: Date {
        Date.distantFuture
    }

    static var isTrialActive: Bool {
        false
    }

    static var hasProAccess: Bool {
        true
    }

    static var trialDaysRemaining: Int {
        0
    }

    static var trialRemainingText: String {
        "Paid app"
    }

    static var accessSummary: String {
        "Paid app"
    }

    static func setLifetimeUnlocked(_ unlocked: Bool) {
        defaults.set(true, forKey: lifetimeUnlockedKey)
        defaults.synchronize()
    }

    private static func clearLegacyTrialState() {
        defaults.set(true, forKey: lifetimeUnlockedKey)
        defaults.removeObject(forKey: trialStartDateKey)
        defaults.removeObject(forKey: latestSeenDateKey)
        defaults.removeObject(forKey: trialStorageMigrationDateKey)
        defaults.removeObject(forKey: trialExpirationLockedDateKey)
#if DEBUG
        defaults.set(false, forKey: debugForceExpiredKey)
#endif
        defaults.synchronize()
    }

#if DEBUG
    static var debugForceExpired: Bool {
        false
    }

    static func debugExpireTrial(now: Date = Date()) {
        clearLegacyTrialState()
    }

    static func debugResetTrial(now: Date = Date()) {
        clearLegacyTrialState()
    }

    static func debugRecoverFromExpiredTestTrial(now: Date = Date()) {
        clearLegacyTrialState()
    }

    static func debugClearForcedExpiration() {
        clearLegacyTrialState()
    }
#endif
}
