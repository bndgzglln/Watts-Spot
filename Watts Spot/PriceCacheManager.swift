import Foundation
import WidgetKit
import SpotPriceKit

/// Manages cached price data and determines when API calls are needed
@MainActor
final class PriceCacheManager {
    static let shared = PriceCacheManager()
    
    private let defaults = UserDefaults.standard
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna") ?? .current
        return calendar
    }()
    
    private enum Keys {
        static let cachedPrices = "cachedPrices"
        static let lastFetchDate = "lastFetchDate"
        static let lastFetchAttemptDate = "lastFetchAttemptDate"
        static let cachedRegionCode = "cachedRegionCode"
    }
    
    private init() {}
    
    /// Determines if an API call is needed based on cache state and time
    func shouldFetchFromAPI(regionCode: String, now: Date = Date()) -> Bool {
        // If region changed, always fetch
        let cachedRegion = defaults.string(forKey: Keys.cachedRegionCode)
        if cachedRegion != regionCode {
            return true
        }
        
        // If no cache exists, fetch
        guard let lastFetch = defaults.object(forKey: Keys.lastFetchDate) as? Date else {
            return true
        }
        
        let lastFetchDay = calendar.startOfDay(for: lastFetch)
        let today = calendar.startOfDay(for: now)
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        
        // Check if we have tomorrow's data cached
        let hasTomorrowData = hasTomorrowDataCached()
        
        // Primary fetch window: 14:00-15:00 - this is when tomorrow's data is usually published
        if currentHour == 14 {
            // If we haven't fetched today at 14:00+, or if we fetched before 14:00 today
            let lastFetchHour = calendar.component(.hour, from: lastFetch)
            if lastFetchDay < today || lastFetchHour < 14 {
                return true
            }
            
            // If we don't have tomorrow's data yet, keep retrying every 10 minutes
            if !hasTomorrowData {
                if let lastAttempt = defaults.object(forKey: Keys.lastFetchAttemptDate) as? Date {
                    let minutesSinceLastAttempt = now.timeIntervalSince(lastAttempt) / 60
                    return minutesSinceLastAttempt >= 10
                }
                return true
            }
        }
        
        // Retry window: 14:00-17:00 every 10 minutes if tomorrow data is missing
        if currentHour >= 14 && currentHour < 17 && !hasTomorrowData {
            if let lastAttempt = defaults.object(forKey: Keys.lastFetchAttemptDate) as? Date {
                let minutesSinceLastAttempt = now.timeIntervalSince(lastAttempt) / 60
                return minutesSinceLastAttempt >= 10
            }
            return true
        }
        
        // If it's a new day and we haven't fetched today
        if lastFetchDay < today {
            return true
        }
        
        return false
    }
    
    /// Returns cached prices if available
    func getCachedPrices() -> [SpotPrice]? {
        guard let data = defaults.data(forKey: Keys.cachedPrices) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let cached = try decoder.decode(CachedPrices.self, from: data)
            return cached.prices
        } catch {
            print("[PriceCacheManager] Failed to decode cached prices: \(error)")
            return nil
        }
    }
    
    /// Saves prices to cache
    func cachePrices(_ prices: [SpotPrice], regionCode: String) {
        let cached = CachedPrices(prices: prices, regionCode: regionCode, timestamp: Date())
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(cached)
            defaults.set(data, forKey: Keys.cachedPrices)
            defaults.set(Date(), forKey: Keys.lastFetchDate)
            defaults.set(regionCode, forKey: Keys.cachedRegionCode)
            print("[PriceCacheManager] Cached \(prices.count) prices")
        } catch {
            print("[PriceCacheManager] Failed to cache prices: \(error)")
        }
    }
    
    /// Records a fetch attempt (even if it fails)
    func recordFetchAttempt() {
        defaults.set(Date(), forKey: Keys.lastFetchAttemptDate)
    }
    
    /// Forces a refresh by clearing the last fetch date
    func forceRefresh() {
        defaults.removeObject(forKey: Keys.lastFetchDate)
        defaults.removeObject(forKey: Keys.lastFetchAttemptDate)
        print("[PriceCacheManager] Force refresh requested")
    }
    
    /// Clears all cached data
    func clearCache() {
        defaults.removeObject(forKey: Keys.cachedPrices)
        defaults.removeObject(forKey: Keys.lastFetchDate)
        defaults.removeObject(forKey: Keys.lastFetchAttemptDate)
        defaults.removeObject(forKey: Keys.cachedRegionCode)
        print("[PriceCacheManager] Cache cleared")
    }
    
    /// Checks if tomorrow's data is in the cache
    private func hasTomorrowDataCached() -> Bool {
        guard let prices = getCachedPrices(), !prices.isEmpty else {
            return false
        }
        
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Check if any price entries are for tomorrow
        return prices.contains { entry in
            let entryDay = calendar.startOfDay(for: entry.timestamp)
            return entryDay > today
        }
    }
    
    /// Returns the next scheduled API fetch time for display purposes
    func nextScheduledFetchTime(now: Date = Date()) -> String {
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        
        // If before 14:00, next fetch is at 14:00
        if currentHour < 14 {
            if let nextFetch = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: now) {
                return nextFetch.formatted(.dateTime.hour().minute())
            }
        }
        
        // If after 14:00 but still retrying for tomorrow data
        if !hasTomorrowDataCached() && currentHour < 17 {
            return "Retrying..."
        }
        
        // Otherwise, next fetch is tomorrow at 14:00
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           let nextFetch = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: tomorrow) {
            return nextFetch.formatted(.dateTime.hour().minute())
        }
        
        return "Unknown"
    }
}

// MARK: - Cached Prices Model

private struct CachedPrices: Codable {
    let prices: [SpotPrice]
    let regionCode: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case prices
        case regionCode
        case timestamp
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode prices as array of dictionaries
        let priceDicts = prices.map { [
            "timestamp": $0.timestamp.timeIntervalSince1970,
            "pricePerMWh": $0.pricePerMWh
        ] }
        let priceData = try JSONSerialization.data(withJSONObject: priceDicts)
        try container.encode(priceData, forKey: .prices)
        
        try container.encode(regionCode, forKey: .regionCode)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    init(prices: [SpotPrice], regionCode: String, timestamp: Date) {
        self.prices = prices
        self.regionCode = regionCode
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let priceData = try container.decode(Data.self, forKey: .prices)
        let priceDicts = try JSONSerialization.jsonObject(with: priceData) as? [[String: Double]] ?? []
        
        self.prices = priceDicts.compactMap { dict in
            guard let timestamp = dict["timestamp"],
                  let pricePerMWh = dict["pricePerMWh"] else { return nil }
            return SpotPrice(
                timestamp: Date(timeIntervalSince1970: timestamp),
                pricePerMWh: pricePerMWh
            )
        }
        
        self.regionCode = try container.decode(String.self, forKey: .regionCode)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
}
