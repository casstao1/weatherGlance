import SwiftUI
import UserNotifications

final class NotificationPresentationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresentationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

@main
struct SkyGlanceApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresentationDelegate.shared
        configureDebugTrialScenario()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func configureDebugTrialScenario() {
#if DEBUG
        let processInfo = ProcessInfo.processInfo
        let shouldForceExpiredTrial =
            processInfo.environment["SKYGLANCE_FORCE_TRIAL_EXPIRED"] == "1" ||
            processInfo.arguments.contains("-skyglanceForceTrialExpired")
        let shouldResetTrial =
            processInfo.environment["SKYGLANCE_RESET_TRIAL"] == "1" ||
            processInfo.arguments.contains("-skyglanceResetTrial")

        if shouldForceExpiredTrial {
            EntitlementStore.debugExpireTrial()
        } else if shouldResetTrial {
            EntitlementStore.debugResetTrial()
        }
#endif
    }
}
