import Foundation

public struct PriceRegion: Identifiable, Hashable {
    public let code: String
    public let nameKey: String

    public var id: String { code }

    public var name: String {
        L10n.text(nameKey)
    }
    
    public init(code: String, nameKey: String) {
        self.code = code
        self.nameKey = nameKey
    }
}

public enum PriceRegionCatalog {
    public static let presets: [PriceRegion] = [
        PriceRegion(code: "AT", nameKey: "region.AT"),
        PriceRegion(code: "DE-LU", nameKey: "region.DE-LU"),
        PriceRegion(code: "BE", nameKey: "region.BE"),
        PriceRegion(code: "FR", nameKey: "region.FR"),
        PriceRegion(code: "NL", nameKey: "region.NL"),
        PriceRegion(code: "CH", nameKey: "region.CH"),
        PriceRegion(code: "CZ", nameKey: "region.CZ"),
        PriceRegion(code: "HU", nameKey: "region.HU"),
        PriceRegion(code: "PL", nameKey: "region.PL"),
        PriceRegion(code: "SI", nameKey: "region.SI")
    ]

    public static func displayName(for code: String) -> String {
        presets.first(where: { $0.code.caseInsensitiveCompare(code) == .orderedSame })?.name ?? code
    }
}
