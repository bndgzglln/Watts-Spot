import BackgroundTasks
import WidgetKit
import SpotPriceKit
import UIKit

/// Manages background refresh tasks for keeping widgets up-to-date
/// even when the app is not in the foreground
final class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()
    
    private let api = EnergyChartsAPI()
    private let taskIdentifier = "com.modeleven.Watts-Spot.widgetRefresh"
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna") ?? .current
        return calendar
    }()
    
    private init() {}
    
    /// Registers background refresh tasks with the system
    /// Call this in AppDelegate's didFinishLaunching
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { [weak self] task in
            self?.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    /// Schedules the next background refresh task
    /// Call this after completing a background refresh or when the app enters background
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        
        // Calculate optimal refresh time
        // Refresh every 15 minutes during active hours, less frequently at night
        request.earliestBeginDate = calculateNextRefreshDate()
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("[BackgroundRefreshManager] Scheduled next refresh for \(request.earliestBeginDate ?? Date())")
        } catch {
            print("[BackgroundRefreshManager] Failed to schedule background refresh: \(error.localizedDescription)")
        }
    }
    
    /// Cancels all pending background refresh tasks
    func cancelBackgroundRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    }
    
    /// Handles the background refresh task
    /// - Always reloads widget timelines (every 5 min during day, 30 min at night)
    /// - Only calls API when cache manager determines it's necessary
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh immediately
        scheduleBackgroundRefresh()
        
        // Create a background task assertion to keep the app alive during fetch
        let backgroundTask = UIApplication.shared.beginBackgroundTask { [weak task] in
            task?.setTaskCompleted(success: false)
        }
        
        // Set up expiration handler
        task.expirationHandler = { [weak self] in
            print("[BackgroundRefreshManager] Background task expired")
            Task {
                await self?.api.cancelPendingRequests()
            }
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }
        
        // Perform the background refresh
        Task {
            let now = Date()
            let shouldFetchAPI = PriceCacheManager.shared.shouldFetchFromAPI(regionCode: "AT", now: now)
            
            if shouldFetchAPI {
                print("[BackgroundRefreshManager] Fetching fresh data from API")
                PriceCacheManager.shared.recordFetchAttempt()
                
                do {
                    let prices = try await api.fetchPrices(for: "AT")
                    PriceCacheManager.shared.cachePrices(prices, regionCode: "AT")
                    
                    // Reload widgets with fresh data
                    await MainActor.run {
                        WidgetCenter.shared.reloadTimelines(ofKind: "CurrentPriceWidget")
                    }
                    
                    print("[BackgroundRefreshManager] Successfully fetched and cached data")
                    task.setTaskCompleted(success: true)
                } catch is CancellationError {
                    print("[BackgroundRefreshManager] Background task was cancelled")
                    task.setTaskCompleted(success: false)
                } catch {
                    print("[BackgroundRefreshManager] API fetch failed: \(error.localizedDescription)")
                    // Still reload widgets - they will use cached data
                    await MainActor.run {
                        WidgetCenter.shared.reloadTimelines(ofKind: "CurrentPriceWidget")
                    }
                    task.setTaskCompleted(success: true)
                }
            } else {
                print("[BackgroundRefreshManager] Using cached data, reloading widgets only")
                // Just reload widgets - they will use cached data
                await MainActor.run {
                    WidgetCenter.shared.reloadTimelines(ofKind: "CurrentPriceWidget")
                }
                task.setTaskCompleted(success: true)
            }
            
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }
    }
    
    /// Calculates the optimal next refresh time based on current time
    /// - Active hours (6:00 - 22:00): Every 5 minutes for widget updates
    /// - Night hours (22:00 - 6:00): Reduced frequency for battery saving
    /// - API calls only happen at 14:00 or when retrying for tomorrow's data
    private func calculateNextRefreshDate() -> Date {
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        
        // During active hours (6:00 - 22:00), refresh every 5 minutes
        if currentHour >= 6 && currentHour < 22 {
            // Round to next 5-minute boundary
            let nextFiveMin = ((currentMinute / 5) + 1) * 5
            if nextFiveMin < 60 {
                return calendar.date(bySettingHour: currentHour, minute: nextFiveMin, second: 0, of: now) 
                    ?? now.addingTimeInterval(5 * 60)
            } else {
                return calendar.date(bySettingHour: currentHour + 1, minute: 0, second: 0, of: now) 
                    ?? now.addingTimeInterval(5 * 60)
            }
        }
        // During night hours (22:00 - 6:00), refresh every 30 minutes to save battery
        else {
            // Round to next 30-minute boundary
            let nextHalfHour = currentMinute < 30 ? 30 : 0
            let nextHour = currentMinute < 30 ? currentHour : currentHour + 1
            
            if nextHour < 24 {
                return calendar.date(bySettingHour: nextHour, minute: nextHalfHour, second: 0, of: now) 
                    ?? now.addingTimeInterval(30 * 60)
            } else {
                // Wrap to next day
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
                return calendar.date(bySettingHour: 6, minute: 0, second: 0, of: tomorrow) 
                    ?? now.addingTimeInterval(30 * 60)
            }
        }
    }
}
