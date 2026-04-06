import SwiftUI

@MainActor
final class PriceViewModel: ObservableObject {
    struct LowPriceWindow: Identifiable {
        let start: Date
        let end: Date
        let averagePricePerKWh: Double
        let minPricePerKWh: Double

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
        notificationManager: NotificationManager = NotificationManager()
    ) {
        self.api = api
        self.notificationManager = notificationManager
        self.notificationsEnabled = notificationManager.isEnabled
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna") ?? .current
        self.calendar = calendar
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

    func loadPrices(regionCode: String = "AT", now: Date = .now) async {
        isLoading = true
        defer { isLoading = false }

        do {
            currentRegionCode = regionCode
            let prices = try await api.fetchPrices(for: regionCode)
            distribute(prices, now: now)
            try await notificationManager.syncNotifications(
                withTomorrowEntries: tomorrowEntries,
                now: now
            )
            notificationsEnabled = notificationManager.isEnabled
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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
                    minPricePerKWh: cheapestEntry.pricePerKWh
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
        let comparisonEntries = (entries?.isEmpty == false ? entries : nil) ?? (todayEntries + tomorrowEntries)
        guard
            let minPrice = comparisonEntries.map(\.pricePerMWh).min(),
            let maxPrice = comparisonEntries.map(\.pricePerMWh).max(),
            maxPrice > minPrice
        else {
            return Color.green
        }

        let ratio = min(max((entry.pricePerMWh - minPrice) / (maxPrice - minPrice), 0), 1)
        if ratio < 0.5 {
            let localRatio = ratio / 0.5
            return Color(
                red: 0.18 + (0.42 * localRatio),
                green: 0.70 - (0.08 * localRatio),
                blue: 0.28 - (0.02 * localRatio)
            )
        }

        let localRatio = (ratio - 0.5) / 0.5
        return Color(
            red: 0.60 + (0.26 * localRatio),
            green: 0.62 - (0.38 * localRatio),
            blue: 0.26 - (0.10 * localRatio)
        )
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
            let minPrice = entries.map(\.pricePerKWh).min()
        else {
            return nil
        }

        let average = entries.map(\.pricePerKWh).reduce(0, +) / Double(entries.count)
        return LowPriceWindow(
            start: first.timestamp,
            end: last.intervalEnd,
            averagePricePerKWh: average,
            minPricePerKWh: minPrice
        )
    }
}
