import Foundation
import UserNotifications
import SpotPriceKit

final class SchedulerNotificationManager: @unchecked Sendable {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar
    private let timeZone: TimeZone
    
    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        
        var calendar = Calendar(identifier: .gregorian)
        let vienna = TimeZone(identifier: "Europe/Vienna") ?? .current
        calendar.timeZone = vienna
        self.calendar = calendar
        self.timeZone = vienna
    }
    
    func scheduleNotification(for shortcut: ApplianceShortcut, cheapestWindow: CheapestWindow) async throws {
        guard shortcut.notificationEnabled else { return }
        
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else { return }
        
        let notificationTime = calculateNotificationTime(
            windowStart: cheapestWindow.startTime,
            leadTimeMinutes: shortcut.notificationLeadTimeMinutes
        )
        
        let identifier = notificationIdentifier(for: shortcut.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let content = UNMutableNotificationContent()
        content.title = L10n.format("scheduler.notification_title", shortcut.name)
        content.body = L10n.format("scheduler.notification_body", 
                                   formatTime(cheapestWindow.startTime),
                                   formatTime(cheapestWindow.endTime),
                                   formatPrice(cheapestWindow.averagePricePerKWh))
        content.sound = .default
        content.categoryIdentifier = "APPLIANCE_REMINDER"
        
        switch shortcut.notificationRepeat {
        case .oneTime:
            try await scheduleOneTime(at: notificationTime, content: content, identifier: identifier)
        case .daily:
            try await scheduleRepeating(hour: calendar.component(.hour, from: notificationTime),
                                        minute: calendar.component(.minute, from: notificationTime),
                                        content: content, identifier: identifier, repeats: true)
        case .weekly:
            try await scheduleWeekly(on: calendar.component(.weekday, from: notificationTime),
                                      hour: calendar.component(.hour, from: notificationTime),
                                      minute: calendar.component(.minute, from: notificationTime),
                                      content: content, identifier: identifier)
        }
    }
    
    func cancelNotification(for shortcutId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(for: shortcutId)])
    }
    
    func cancelAllNotifications() async {
        let pending = await center.pendingNotificationRequests()
        let schedulerIds = pending
            .filter { $0.identifier.hasPrefix("scheduler-") }
            .map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: schedulerIds)
    }
    
    private func calculateNotificationTime(windowStart: Date, leadTimeMinutes: Int) -> Date {
        windowStart.addingTimeInterval(-Double(leadTimeMinutes * 60))
    }
    
    private func scheduleOneTime(at date: Date, content: UNMutableNotificationContent, identifier: String) async throws {
        guard date > Date() else { return }
        
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await center.add(request)
    }
    
    private func scheduleRepeating(hour: Int, minute: Int, content: UNMutableNotificationContent, identifier: String, repeats: Bool) async throws {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.hour = hour
        components.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await center.add(request)
    }
    
    private func scheduleWeekly(on weekday: Int, hour: Int, minute: Int, content: UNMutableNotificationContent, identifier: String) async throws {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await center.add(request)
    }
    
    private func notificationIdentifier(for shortcutId: UUID) -> String {
        "scheduler-\(shortcutId.uuidString)"
    }
    
    private func formatTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
    
    private func formatPrice(_ pricePerKWh: Double) -> String {
        let cents = pricePerKWh * 100
        return String(format: "%.2f ct/kWh", cents)
    }
}
