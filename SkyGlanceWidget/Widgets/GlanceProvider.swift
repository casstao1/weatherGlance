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

    private struct TimelineResult {
        let entries: [GlanceWidgetEntry]
        let nextRefresh: Date
    }

    private static let freshCacheMaxAge: TimeInterval = 55 * 60
    private static let failedRefreshRetryInterval: TimeInterval = 15 * 60

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
            let now = Date()
            let result = await fetchTimelineResult(now: now)
            let nextRefresh = WidgetAccessPolicy.nextRefreshDate(default: result.nextRefresh)
            let timeline = Timeline(entries: result.entries, policy: .after(nextRefresh))
            completion(timeline)
        }
    }

    // MARK: – Private

    private func fetchEntries() async -> [GlanceWidgetEntry] {
        await fetchTimelineResult(now: Date()).entries
    }

    private func fetchTimelineResult(now: Date) async -> TimelineResult {
        guard WidgetAccessPolicy.canRenderWeather else {
            return TimelineResult(
                entries: [.placeholder],
                nextRefresh: nextHourlyRefresh(after: now)
            )
        }

        if let cachedEntries = SharedLocationStore.loadFreshEntries(
            maxAge: Self.freshCacheMaxAge,
            now: now
        ) {
            return TimelineResult(
                entries: usableTimelineEntries(from: cachedEntries, now: now) ?? cachedEntries,
                nextRefresh: nextHourlyRefresh(after: now)
            )
        }

        if let refreshedEntries = await fetchFreshEntries() {
            return TimelineResult(
                entries: usableTimelineEntries(from: refreshedEntries, now: now) ?? refreshedEntries,
                nextRefresh: nextHourlyRefresh(after: now)
            )
        }

        if let staleEntries = SharedLocationStore.loadEntries() {
            return TimelineResult(
                entries: usableTimelineEntries(from: staleEntries, now: now) ?? [staleEntryForCurrentTimeline(from: staleEntries, now: now)],
                nextRefresh: now.addingTimeInterval(Self.failedRefreshRetryInterval)
            )
        }

        return TimelineResult(
            entries: [.placeholder],
            nextRefresh: now.addingTimeInterval(Self.failedRefreshRetryInterval)
        )
    }

    private func fetchFreshEntries() async -> [GlanceWidgetEntry]? {
        guard let cachedLocation = SharedLocationStore.load() else {
            return nil
        }

        do {
            let bundle = try await OpenMeteoService().fetchForecastBundle(
                for: cachedLocation.location,
                cityName: cachedLocation.cityName
            )

            guard !bundle.entries.isEmpty else { return nil }
            SharedLocationStore.save(entries: bundle.entries)
            return bundle.entries
        } catch {
            print("[GlanceProvider] Background widget weather refresh failed: \(error)")
            return nil
        }
    }

    private func usableTimelineEntries(
        from entries: [GlanceWidgetEntry],
        now: Date
    ) -> [GlanceWidgetEntry]? {
        let calendar = Calendar.current
        let startOfCurrentHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let usableEntries = entries.filter { $0.date >= startOfCurrentHour }
        return usableEntries.isEmpty ? nil : usableEntries
    }

    private func staleEntryForCurrentTimeline(
        from entries: [GlanceWidgetEntry],
        now: Date
    ) -> GlanceWidgetEntry {
        let fallback = entries.last ?? .placeholder
        return GlanceWidgetEntry(
            date: now,
            cityName: fallback.cityName,
            currentTemperature: fallback.currentTemperature,
            currentCondition: fallback.currentCondition,
            inlineSummary: fallback.inlineSummary,
            hours: fallback.hours,
            mood: fallback.mood,
            feelsLikeTemperature: fallback.feelsLikeTemperature,
            windSpeed: fallback.windSpeed,
            sunriseTime: fallback.sunriseTime,
            sunsetTime: fallback.sunsetTime,
            isDaylight: fallback.isDaylight
        )
    }

    private func nextHourlyRefresh(after date: Date) -> Date {
        let calendar = Calendar.current
        let startOfHour = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        return calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? date.addingTimeInterval(60 * 60)
    }
}
