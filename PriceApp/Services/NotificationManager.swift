import Foundation
import UserNotifications

final class NotificationManager {
    private enum Constants {
        static let enabledKey = "notificationsEnabled"
        static let cheapestNotificationDayKey = "cheapestNotificationDay"
        static let dailyAvailabilityIdentifier = "daily-price-availability"
        static let cheapestNotificationIdentifier = "cheapest-price-slot"
    }

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let timeZone: TimeZone

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults

        var calendar = Calendar(identifier: .gregorian)
        let vienna = TimeZone(identifier: "Europe/Vienna") ?? .current
        calendar.timeZone = vienna

        self.calendar = calendar
        self.timeZone = vienna
    }

    var isEnabled: Bool {
        defaults.bool(forKey: Constants.enabledKey)
    }

    func setEnabled(_ enabled: Bool, tomorrowEntries: [SpotPrice], now: Date) async throws -> Bool {
        if enabled {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                defaults.set(false, forKey: Constants.enabledKey)
                await removePendingNotifications()
                return false
            }

            defaults.set(true, forKey: Constants.enabledKey)
            try await syncNotifications(withTomorrowEntries: tomorrowEntries, now: now)
            return true
        } else {
            defaults.set(false, forKey: Constants.enabledKey)
            await removePendingNotifications()
            return false
        }
    }

    func syncNotifications(withTomorrowEntries tomorrowEntries: [SpotPrice], now: Date) async throws {
        guard isEnabled else {
            await removePendingNotifications()
            return
        }

        try await scheduleDailyAvailabilityReminder()

        guard let cheapest = tomorrowEntries.min(by: { $0.pricePerMWh < $1.pricePerMWh }) else {
            return
        }

        let notificationDay = dayIdentifier(for: cheapest.timestamp)
        guard defaults.string(forKey: Constants.cheapestNotificationDayKey) != notificationDay else {
            return
        }

        try await scheduleCheapestSlotNotification(for: cheapest, now: now)
        defaults.set(notificationDay, forKey: Constants.cheapestNotificationDayKey)
    }

    private func scheduleDailyAvailabilityReminder() async throws {
        center.removePendingNotificationRequests(withIdentifiers: [Constants.dailyAvailabilityIdentifier])

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.hour = 14
        components.minute = 5

        let content = UNMutableNotificationContent()
        content.title = L10n.text("notifications.daily_title")
        content.body = L10n.text("notifications.daily_body")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Constants.dailyAvailabilityIdentifier,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    private func scheduleCheapestSlotNotification(for cheapest: SpotPrice, now: Date) async throws {
        center.removePendingNotificationRequests(withIdentifiers: [Constants.cheapestNotificationIdentifier])

        let triggerDate = now.addingTimeInterval(2)
        let interval = max(triggerDate.timeIntervalSinceNow, 1)

        let content = UNMutableNotificationContent()
        content.title = L10n.text("notifications.cheapest_title")
        content.body = L10n.format("notifications.cheapest_body", cheapest.intervalLabel, cheapest.priceText)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Constants.cheapestNotificationIdentifier,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    private func removePendingNotifications() async {
        center.removePendingNotificationRequests(
            withIdentifiers: [
                Constants.dailyAvailabilityIdentifier,
                Constants.cheapestNotificationIdentifier
            ]
        )
    }

    private func dayIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(year)-\(month)-\(day)"
    }
}
