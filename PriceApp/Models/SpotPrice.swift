import Foundation

struct PriceResponse: Decodable {
    let unixSeconds: [Int]
    let price: [Double]
    let unit: String

    enum CodingKeys: String, CodingKey {
        case unixSeconds = "unix_seconds"
        case price
        case unit
    }
}

struct SpotPrice: Identifiable, Hashable {
    let timestamp: Date
    let pricePerMWh: Double

    var id: Date { timestamp }

    var intervalEnd: Date {
        timestamp.addingTimeInterval(15 * 60)
    }

    var pricePerKWh: Double {
        pricePerMWh / 1000.0
    }

    var priceText: String {
        "\(priceValueText) ct/kWh"
    }

    var priceValueText: String {
        let cents = pricePerKWh * 100
        return cents.formatted(.number.precision(.fractionLength(2)))
    }

    var intervalLabel: String {
        "\(timestamp.formatted(.dateTime.hour().minute())) - \(intervalEnd.formatted(.dateTime.hour().minute()))"
    }

    var shortTimeLabel: String {
        timestamp.formatted(.dateTime.hour().minute())
    }

    var cheapestNotificationLabel: String {
        "\(timestamp.formatted(.dateTime.hour().minute()))"
    }
}

enum PriceDay: String, CaseIterable, Identifiable {
    case today
    case tomorrow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return L10n.text("price.today")
        case .tomorrow: return L10n.text("price.day_ahead")
        }
    }
}
