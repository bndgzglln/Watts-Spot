import Foundation

public struct PriceResponse: Decodable {
    public let unixSeconds: [Int]
    public let price: [Double]
    public let unit: String

    public enum CodingKeys: String, CodingKey {
        case unixSeconds = "unix_seconds"
        case price
        case unit
    }
}

public struct SpotPrice: Identifiable, Hashable {
    public let timestamp: Date
    public let pricePerMWh: Double

    public var id: Date { timestamp }

    public var intervalEnd: Date {
        timestamp.addingTimeInterval(15 * 60)
    }

    public var pricePerKWh: Double {
        pricePerMWh / 1000.0
    }

    public var priceText: String {
        "\(priceValueText) ct/kWh"
    }

    public var priceValueText: String {
        let cents = pricePerKWh * 100
        return cents.formatted(.number.precision(.fractionLength(2)))
    }

    public var intervalLabel: String {
        "\(timestamp.formatted(.dateTime.hour().minute())) - \(intervalEnd.formatted(.dateTime.hour().minute()))"
    }

    public var shortTimeLabel: String {
        timestamp.formatted(.dateTime.hour().minute())
    }

    public var cheapestNotificationLabel: String {
        "\(timestamp.formatted(.dateTime.hour().minute()))"
    }
    
    public init(timestamp: Date, pricePerMWh: Double) {
        self.timestamp = timestamp
        self.pricePerMWh = pricePerMWh
    }
}

public enum PriceDay: String, CaseIterable, Identifiable {
    case today
    case tomorrow

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .today: return L10n.text("price.today")
        case .tomorrow: return L10n.text("price.day_ahead")
        }
    }
}
