import Foundation
import Security

struct EntitlementStore {
    static let lifetimeProductID = "com.castao.weatherGlance.lifetime"
    static let lifetimeUnlockedKey = "monetization.lifetimeUnlocked"
    static let trialStartDateKey = "monetization.trialStartDate"
    static let latestSeenDateKey = "monetization.latestSeenDate"
    static let trialStorageMigrationDateKey = "monetization.trialStorageV4MigrationDate"
#if DEBUG
    static let debugForceExpiredKey = "debug.monetization.forceExpired"
#endif
    static let trialDuration: TimeInterval = 7 * 24 * 60 * 60
    private static let clockRollbackTolerance: TimeInterval = 5 * 60
    private static let keychainService = "com.castao.weatherGlance.entitlements"
    private static let keychainTrialStartAccount = "trialStartDate.v4"
    private static let keychainLatestSeenAccount = "latestSeenDate"
    private static let keychainTrialStorageMigrationAccount = "trialStorageV4MigrationDate"

    private static var defaults: UserDefaults {
        SharedLocationStore.defaults
    }

    static func ensureTrialStarted(now: Date = Date()) {
        if shouldResetForTrialStorageMigration {
            writeTrialStartDate(now, latestSeenDate: now)
            markTrialStorageMigrationApplied(now)
            return
        }

        if let existingStartDate = persistedTrialStartDate {
            defaults.set(existingStartDate, forKey: trialStartDateKey)
            setKeychainDate(existingStartDate, account: keychainTrialStartAccount)
            markTrialStorageMigrationApplied(now)
            recordLatestSeenDate(now)
            return
        }

        writeTrialStartDate(now, latestSeenDate: now)
        markTrialStorageMigrationApplied(now)
    }

    static var isLifetimeUnlocked: Bool {
        defaults.bool(forKey: lifetimeUnlockedKey)
    }

    static var trialStartDate: Date? {
        persistedTrialStartDate
    }

    static var trialEndDate: Date {
        ensureTrialStarted()
        let startDate = trialStartDate ?? Date()
        return startDate.addingTimeInterval(trialDuration)
    }

    static var isTrialActive: Bool {
#if DEBUG
        if debugForceExpired {
            return false
        }
#endif
        ensureTrialStarted()
        let now = Date()
        guard !hasClockRollback(now: now), let trialStartDate else { return false }
        recordLatestSeenDate(now)
        return now < trialStartDate.addingTimeInterval(trialDuration)
    }

    static var hasProAccess: Bool {
#if DEBUG
        if debugForceExpired {
            return false
        }
#endif
        return isLifetimeUnlocked || isTrialActive
    }

    static var trialDaysRemaining: Int {
        guard !hasClockRollback(now: Date()) else { return 0 }
        let remaining = max(0, trialEndDate.timeIntervalSinceNow)
        return Int(ceil(remaining / 86_400))
    }

    static var trialRemainingText: String {
        guard !hasClockRollback(now: Date()) else { return "Ended" }

        let remaining = max(0, trialEndDate.timeIntervalSinceNow)
        guard remaining > 0 else { return "Ended" }

        let totalSeconds = Int(remaining)
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = max(1, (totalSeconds % 3_600) / 60)

        if days > 0 {
            return "\(days)d \(hours)h left"
        }

        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        }

        return "\(minutes)m left"
    }

    static var accessSummary: String {
#if DEBUG
        if debugForceExpired {
            return "Trial ended"
        }
#endif

        if isLifetimeUnlocked {
            return "Lifetime unlocked"
        }

        if hasClockRollback(now: Date()) {
            return "Trial ended"
        }

        if isTrialActive {
            return "Trial: \(trialRemainingText)"
        }

        return "Trial ended"
    }

    static func setLifetimeUnlocked(_ unlocked: Bool) {
        defaults.set(unlocked, forKey: lifetimeUnlockedKey)
        defaults.synchronize()
    }

    private static var persistedTrialStartDate: Date? {
        [defaults.object(forKey: trialStartDateKey) as? Date,
         keychainDate(account: keychainTrialStartAccount)]
            .compactMap { $0 }
            .min()
    }

    private static var latestSeenDate: Date? {
        [defaults.object(forKey: latestSeenDateKey) as? Date,
         keychainDate(account: keychainLatestSeenAccount)]
            .compactMap { $0 }
            .max()
    }

    private static var hasAppliedTrialStorageMigration: Bool {
        hasDefaultsTrialStorageMigration || hasKeychainTrialStorageMigration
    }

    private static var hasDefaultsTrialStorageMigration: Bool {
        defaults.object(forKey: trialStorageMigrationDateKey) as? Date != nil
    }

    private static var hasKeychainTrialStorageMigration: Bool {
        keychainDate(account: keychainTrialStorageMigrationAccount) != nil
    }

    private static var shouldResetForTrialStorageMigration: Bool {
#if DEBUG
        if debugForceExpired {
            return false
        }
#endif
        return !hasAppliedTrialStorageMigration && !isLifetimeUnlocked
    }

    private static func hasClockRollback(now: Date) -> Bool {
        guard let latestSeenDate else { return false }
        return now < latestSeenDate.addingTimeInterval(-clockRollbackTolerance)
    }

    private static func writeTrialStartDate(_ startDate: Date, latestSeenDate: Date) {
        defaults.set(startDate, forKey: trialStartDateKey)
        setKeychainDate(startDate, account: keychainTrialStartAccount)
        forceLatestSeenDate(latestSeenDate)
    }

    private static func markTrialStorageMigrationApplied(_ date: Date) {
        var didWriteDefaults = false

        if !hasDefaultsTrialStorageMigration {
            defaults.set(date, forKey: trialStorageMigrationDateKey)
            didWriteDefaults = true
        }

        if !hasKeychainTrialStorageMigration {
            setKeychainDate(date, account: keychainTrialStorageMigrationAccount)
        }

        if didWriteDefaults {
            defaults.synchronize()
        }
    }

    private static func recordLatestSeenDate(_ now: Date) {
        guard !hasClockRollback(now: now) else { return }

        if let latestSeenDate, latestSeenDate >= now {
            return
        }

        defaults.set(now, forKey: latestSeenDateKey)
        setKeychainDate(now, account: keychainLatestSeenAccount)
    }

    private static func forceLatestSeenDate(_ date: Date) {
        defaults.set(date, forKey: latestSeenDateKey)
        setKeychainDate(date, account: keychainLatestSeenAccount)
        defaults.synchronize()
    }

    private static func keychainDate(account: String) -> Date? {
        guard !isRunningInExtension else {
            return nil
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              let timestamp = TimeInterval(value)
        else {
            return nil
        }

        return Date(timeIntervalSince1970: timestamp)
    }

    private static func setKeychainDate(_ date: Date, account: String) {
        guard !isRunningInExtension else {
            return
        }

        guard let data = String(date.timeIntervalSince1970).data(using: .utf8) else {
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }

        if status != errSecItemNotFound {
            SecItemDelete(query as CFDictionary)
        }

        var newItem = query
        newItem[kSecValueData as String] = data
        SecItemAdd(newItem as CFDictionary, nil)
    }

    private static var isRunningInExtension: Bool {
        Bundle.main.bundlePath.hasSuffix(".appex")
    }

#if DEBUG
    static var debugForceExpired: Bool {
        defaults.bool(forKey: debugForceExpiredKey)
    }

    static func debugExpireTrial(now: Date = Date()) {
        let expiredStartDate = now.addingTimeInterval(-trialDuration - 60)
        defaults.set(true, forKey: debugForceExpiredKey)
        setLifetimeUnlocked(false)
        defaults.set(expiredStartDate, forKey: trialStartDateKey)
        setKeychainDate(expiredStartDate, account: keychainTrialStartAccount)
        markTrialStorageMigrationApplied(now)
        forceLatestSeenDate(now)
    }

    static func debugResetTrial(now: Date = Date()) {
        defaults.set(false, forKey: debugForceExpiredKey)
        defaults.set(now, forKey: trialStartDateKey)
        setKeychainDate(now, account: keychainTrialStartAccount)
        markTrialStorageMigrationApplied(now)
        forceLatestSeenDate(now)
    }

    static func debugRecoverFromExpiredTestTrial(now: Date = Date()) {
        guard !isLifetimeUnlocked else {
            defaults.set(false, forKey: debugForceExpiredKey)
            return
        }

        let isExpired = persistedTrialStartDate
            .map { now >= $0.addingTimeInterval(trialDuration) } ?? false

        guard debugForceExpired || isExpired || hasClockRollback(now: now) else { return }

        defaults.set(false, forKey: debugForceExpiredKey)
        defaults.set(now, forKey: trialStartDateKey)
        setKeychainDate(now, account: keychainTrialStartAccount)
        markTrialStorageMigrationApplied(now)
        forceLatestSeenDate(now)
    }

    static func debugClearForcedExpiration() {
        defaults.set(false, forKey: debugForceExpiredKey)
    }
#endif
}
