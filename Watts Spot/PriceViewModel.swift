import SwiftUI
import Combine
import WidgetKit
import SpotPriceKit

@MainActor
final class PriceViewModel: ObservableObject {
    struct LowPriceWindow: Identifiable {
        let start: Date
        let end: Date
        let averagePricePerKWh: Double
        let minPricePerKWh: Double
        let maxPricePerKWh: Double

        var id: Date { start }

        var title: String {
            "\(start.formatted(.dateTime.hour().minute())) - \(end.formatted(.dateTime.hour().minute()))"
        }

        var averagePriceText: String {
            L10n.format(
                "price.avg_suffix",
                (averagePricePerKWh * 100).formatted(.number.precision(.fractionLength(2)))
            )
        }

        var minPriceText: String {
            L10n.format(
                "price.low_suffix",
                (minPricePerKWh * 100).formatted(.number.precision(.fractionLength(2)))
            )
        }
        
        var maxPriceText: String {
            L10n.format(
                "price.high_suffix",
                (maxPricePerKWh * 100).formatted(.number.precision(.fractionLength(2)))
            )
        }
    }

    @Published var notificationsEnabled: Bool
    @Published private(set) var todayEntries: [SpotPrice] = []
    @Published private(set) var tomorrowEntries: [SpotPrice] = []
    @Published private(set) var currentPrice: SpotPrice?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let api: EnergyChartsAPI
    private let notificationManager: NotificationManager
    private let calendar: Calendar
    private(set) var currentRegionCode = "AT"

    init(
        api: EnergyChartsAPI = EnergyChartsAPI(),
        notificationManager: NotificationManager? = nil
    ) {
        let nm = notificationManager ?? NotificationManager(center: UNUserNotificationCenter.current(), defaults: .standard)
        self.api = api
        self.notificationManager = nm
        self.notificationsEnabled = nm.isEnabled
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna") ?? .current
        self.calendar = calendar
        
        // Load cached data immediately on initialization
        if let cachedPrices = PriceCacheManager.shared.getCachedPrices() {
            distribute(cachedPrices, now: Date())
        }
    }

    var availableDays: [PriceDay] {
        tomorrowEntries.isEmpty ? [.today] : [.today, .tomorrow]
    }

    var tomorrowLabel: String {
        guard let first = tomorrowEntries.first else {
            return L10n.text("price.not_published")
        }
        return first.timestamp.formatted(.dateTime.weekday(.wide).day().month())
    }

    var dayAheadAverageText: String {
        guard !tomorrowEntries.isEmpty else {
            return L10n.text("price.unavailable")
        }

        let average = tomorrowEntries.map(\.pricePerKWh).reduce(0, +) / Double(tomorrowEntries.count)
        return "\((average * 100).formatted(.number.precision(.fractionLength(2)))) ct/kWh"
    }

    var dayAheadSummaryText: String {
        guard
            let minValue = tomorrowEntries.min(by: { $0.pricePerMWh < $1.pricePerMWh }),
            let maxValue = tomorrowEntries.max(by: { $0.pricePerMWh < $1.pricePerMWh })
        else {
            return L10n.text("price.day_ahead_unpublished")
        }

        return L10n.format(
            "price.day_ahead_summary",
            minValue.priceText,
            minValue.timestamp.formatted(.dateTime.hour().minute()),
            maxValue.priceText,
            maxValue.timestamp.formatted(.dateTime.hour().minute())
        )
    }

    /// Loads prices from cache or API based on timing rules
    /// - Parameters:
    ///   - regionCode: The region to fetch prices for
    ///   - now: Current date
    ///   - forceRefresh: If true, always fetch from API (for manual refresh)
    func loadPrices(regionCode: String = "AT", now: Date = .now, forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        
        currentRegionCode = regionCode
        
        // Check if we should use cached data or fetch from API
        let shouldFetchAPI = forceRefresh || PriceCacheManager.shared.shouldFetchFromAPI(regionCode: regionCode, now: now)
        
        if !shouldFetchAPI {
            // Use cached data
            if let cachedPrices = PriceCacheManager.shared.getCachedPrices() {
                print("[PriceViewModel] Using cached prices")
                distribute(cachedPrices, now: now)
                // Still reload widgets to update UI
                WidgetCenter.shared.reloadTimelines(ofKind: "CurrentPriceWidget")
                errorMessage = nil
                return
            }
            // If cache is empty but we didn't think we needed API, fetch anyway
        }
        
        // Fetch from API
        do {
            print("[PriceViewModel] Fetching prices from API")
            PriceCacheManager.shared.recordFetchAttempt()
            let prices = try await api.fetchPrices(for: regionCode)
            
            // Cache the results
            PriceCacheManager.shared.cachePrices(prices, regionCode: regionCode)
            
            distribute(prices, now: now)
            try await notificationManager.syncNotifications(
                withTomorrowEntries: tomorrowEntries,
                now: now
            )
            notificationsEnabled = notificationManager.isEnabled
            errorMessage = nil
            
            // Reload widgets to reflect new data
            WidgetCenter.shared.reloadTimelines(ofKind: "CurrentPriceWidget")
            
        } catch {
            // If API fails, try to use cached data as fallback
            if let cachedPrices = PriceCacheManager.shared.getCachedPrices() {
                print("[PriceViewModel] API failed, using cached prices as fallback")
                distribute(cachedPrices, now: now)
                WidgetCenter.shared.reloadTimelines(ofKind: "CurrentPriceWidget")
                errorMessage = nil
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Performs a manual refresh - always fetches from API
    func manualRefresh(regionCode: String = "AT", now: Date = .now) async {
        PriceCacheManager.shared.forceRefresh()
        await loadPrices(regionCode: regionCode, now: now, forceRefresh: true)
    }
    
    /// Refreshes UI from cache without API call (for background updates)
    func refreshFromCache(now: Date = .now) {
        if let cachedPrices = PriceCacheManager.shared.getCachedPrices() {
            distribute(cachedPrices, now: now)
            WidgetCenter.shared.reloadTimelines(ofKind: "CurrentPriceWidget")
            print("[PriceViewModel] Refreshed from cache and reloaded widgets")
        }
    }

    func setNotificationsEnabled(_ isEnabled: Bool, now: Date = .now) async {
        do {
            let granted = try await notificationManager.setEnabled(
                isEnabled,
                tomorrowEntries: tomorrowEntries,
                now: now
            )
            notificationsEnabled = granted
            if isEnabled && !granted {
                errorMessage = L10n.text("errors.notifications_disabled")
            }
        } catch {
            notificationsEnabled = false
            errorMessage = error.localizedDescription
        }
    }

    var cheapestTomorrowEntry: SpotPrice? {
        tomorrowEntries.min(by: { $0.pricePerMWh < $1.pricePerMWh })
    }

    var notificationDescription: String {
        if notificationsEnabled {
            if let cheapestTomorrowEntry {
                return L10n.format("price.notification_enabled_with_slot", cheapestTomorrowEntry.intervalLabel)
            }
            return L10n.text("price.notification_enabled_waiting")
        }

        return L10n.text("price.notification_disabled")
    }

    func entries(for day: PriceDay) -> [SpotPrice] {
        switch day {
        case .today:
            return todayEntries
        case .tomorrow:
            return tomorrowEntries
        }
    }
    
    func entries(for filter: DayFilter) -> [SpotPrice] {
        switch filter {
        case .all:
            return todayEntries + tomorrowEntries
        case .today:
            return todayEntries
        case .tomorrow:
            return tomorrowEntries
        }
    }

    func lowPriceWindows(for day: PriceDay) -> [LowPriceWindow] {
        let dayEntries = entries(for: day)
        guard let minimumPrice = dayEntries.map(\.pricePerKWh).min() else {
            return []
        }

        let threshold = minimumPrice + max(0.005, minimumPrice * 0.12)
        var windows: [LowPriceWindow] = []
        var currentWindow: [SpotPrice] = []

        for entry in dayEntries {
            if entry.pricePerKWh <= threshold {
                if let previous = currentWindow.last, previous.intervalEnd != entry.timestamp {
                    if let window = makeWindow(from: currentWindow) {
                        windows.append(window)
                    }
                    currentWindow = [entry]
                } else {
                    currentWindow.append(entry)
                }
            } else if !currentWindow.isEmpty {
                if let window = makeWindow(from: currentWindow) {
                    windows.append(window)
                }
                currentWindow.removeAll()
            }
        }

        if let trailingWindow = makeWindow(from: currentWindow) {
            windows.append(trailingWindow)
        }

        if windows.isEmpty, let cheapestEntry = dayEntries.min(by: { $0.pricePerMWh < $1.pricePerMWh }) {
            return [
                LowPriceWindow(
                    start: cheapestEntry.timestamp,
                    end: cheapestEntry.intervalEnd,
                    averagePricePerKWh: cheapestEntry.pricePerKWh,
                    minPricePerKWh: cheapestEntry.pricePerKWh,
                    maxPricePerKWh: cheapestEntry.pricePerKWh
                )
            ]
        }

        return windows
            .sorted {
                if $0.averagePricePerKWh == $1.averagePricePerKWh {
                    return $0.start < $1.start
                }
                return $0.averagePricePerKWh < $1.averagePricePerKWh
            }
            .prefix(3)
            .map { $0 }
    }

    func color(for entry: SpotPrice, within entries: [SpotPrice]? = nil) -> Color {
        let priceInCents = entry.pricePerKWh * 100
        
        if priceInCents <= 0 {
            return Color.green
        }
        
        return .orange
    }

    private func distribute(_ entries: [SpotPrice], now: Date) {
        let groupedByDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.timestamp) }
        let sortedDays = groupedByDay.keys.sorted()
        let todayStart = calendar.startOfDay(for: now)

        let selectedToday: Date?
        let selectedTomorrow: Date?

        if let matchingToday = sortedDays.first(where: { $0 == todayStart }) {
            selectedToday = matchingToday
            selectedTomorrow = sortedDays.first(where: { $0 > matchingToday })
        } else if sortedDays.count >= 2 {
            selectedToday = sortedDays[sortedDays.count - 2]
            selectedTomorrow = sortedDays.last
        } else {
            selectedToday = sortedDays.first
            selectedTomorrow = nil
        }

        guard let selectedToday else {
            todayEntries = []
            tomorrowEntries = []
            currentPrice = nil
            return
        }
        todayEntries = (groupedByDay[selectedToday] ?? []).sorted(by: { $0.timestamp < $1.timestamp })

        if let selectedTomorrow {
            tomorrowEntries = (groupedByDay[selectedTomorrow] ?? []).sorted(by: { $0.timestamp < $1.timestamp })
        } else {
            tomorrowEntries = []
        }

        currentPrice = todayEntries.last(where: { $0.timestamp <= now && $0.intervalEnd > now })
            ?? todayEntries.first(where: { $0.timestamp > now })
            ?? todayEntries.last
    }

    private func makeWindow(from entries: [SpotPrice]) -> LowPriceWindow? {
        guard
            let first = entries.first,
            let last = entries.last,
            let minPrice = entries.map(\.pricePerKWh).min(),
            let maxPrice = entries.map(\.pricePerKWh).max()
        else {
            return nil
        }

        let average = entries.map(\.pricePerKWh).reduce(0, +) / Double(entries.count)
        return LowPriceWindow(
            start: first.timestamp,
            end: last.intervalEnd,
            averagePricePerKWh: average,
            minPricePerKWh: minPrice,
            maxPricePerKWh: maxPrice
        )
    }
}
