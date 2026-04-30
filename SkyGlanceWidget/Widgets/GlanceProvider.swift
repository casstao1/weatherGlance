import WidgetKit

enum WidgetAccessPolicy {
    static var canRenderWeather: Bool {
        EntitlementStore.hasProAccess
    }

    static func nextRefreshDate(default defaultDate: Date) -> Date {
        guard canRenderWeather, !EntitlementStore.isLifetimeUnlocked else {
            return defaultDate
        }

        return min(defaultDate, EntitlementStore.trialEndDate.addingTimeInterval(1))
    }
}

/// Shared WidgetKit timeline provider used by all Glance widget variants.
struct GlanceProvider: TimelineProvider {

    typealias Entry = GlanceWidgetEntry

    func placeholder(in context: Context) -> GlanceWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (GlanceWidgetEntry) -> Void) {
        guard !context.isPreview else {
            completion(.placeholder)
            return
        }

        Task {
            let entry = await fetchEntries().first ?? .placeholder
            completion(entry)
        }
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<GlanceWidgetEntry>) -> Void) {
        Task {
            let entries = await fetchEntries()
            let calendar = Calendar.current
            let now = Date()
            let startOfHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            let defaultRefresh = calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? now
            let nextRefresh = WidgetAccessPolicy.nextRefreshDate(default: defaultRefresh)
            let timeline = Timeline(entries: entries, policy: .after(nextRefresh))
            completion(timeline)
        }
    }

    // MARK: – Private

    private func fetchEntries() async -> [GlanceWidgetEntry] {
        guard WidgetAccessPolicy.canRenderWeather else {
            return [.placeholder]
        }

        if let cachedEntries = SharedLocationStore.loadFreshEntries(maxAge: 90 * 60) {
            return cachedEntries
        }

        return SharedLocationStore.loadEntries() ?? [.placeholder]
    }
}
