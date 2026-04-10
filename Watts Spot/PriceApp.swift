import SwiftUI
import UserNotifications
import UIKit
import SpotPriceKit
import BackgroundTasks

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        // Register background refresh tasks for widget auto-update
        BackgroundRefreshManager.shared.registerBackgroundTasks()
        
        // Schedule the first background refresh
        BackgroundRefreshManager.shared.scheduleBackgroundRefresh()
        
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background refresh when app enters background
        BackgroundRefreshManager.shared.scheduleBackgroundRefresh()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Cancel pending background tasks when app terminates
        BackgroundRefreshManager.shared.cancelBackgroundRefresh()
    }
}

@main
struct SpotPriceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
