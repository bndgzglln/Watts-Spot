import Foundation

public actor EnergyChartsAPI {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let calendar: Calendar
    private var currentTask: Task<[SpotPrice], Error>?

    public init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna") ?? .current
        self.calendar = calendar
    }

    public func fetchPrices(for regionCode: String, now: Date = .now) async throws -> [SpotPrice] {
        // Cancel any existing task before starting a new one
        currentTask?.cancel()
        
        let task = Task { [weak self] in
            guard let self = self else { throw APIError.invalidResponse }
            
            let start = self.calendar.startOfDay(for: now)
            let end = self.calendar.date(byAdding: .day, value: 2, to: start) ?? now.addingTimeInterval(48 * 60 * 60)

            var components = URLComponents(string: "https://api.energy-charts.info/price")!
            components.queryItems = [
                URLQueryItem(name: "bzn", value: regionCode),
                URLQueryItem(name: "start", value: String(Int(start.timeIntervalSince1970))),
                URLQueryItem(name: "end", value: String(Int(end.timeIntervalSince1970)))
            ]
            guard let url = components.url else {
                throw APIError.invalidResponse
            }
            
            // Check for cancellation before network request
            try Task.checkCancellation()
            
            let (data, response) = try await self.session.data(from: url)
            
            // Check for cancellation after network request
            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                throw APIError.invalidResponse
            }

            let decoded = try self.decoder.decode(PriceResponse.self, from: data)
            guard decoded.unixSeconds.count == decoded.price.count else {
                throw APIError.invalidPayload
            }

            return zip(decoded.unixSeconds, decoded.price)
                .map { seconds, price in
                    SpotPrice(timestamp: Date(timeIntervalSince1970: TimeInterval(seconds)), pricePerMWh: price)
                }
                .sorted { $0.timestamp < $1.timestamp }
        }
        
        currentTask = task
        
        do {
            let result = try await task.value
            currentTask = nil
            return result
        } catch {
            currentTask = nil
            throw error
        }
    }
    
    /// Cancels any in-flight price fetch requests
    public func cancelPendingRequests() {
        currentTask?.cancel()
        currentTask = nil
    }
}

extension EnergyChartsAPI {
    public enum APIError: LocalizedError {
        case invalidResponse
        case invalidPayload

        public var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return L10n.text("errors.api_invalid_response")
            case .invalidPayload:
                return L10n.text("errors.api_invalid_payload")
            }
        }
    }
}
