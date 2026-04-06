import Foundation

enum L10n {
    static let selectedLanguageDefaultsKey = "selectedLanguageCode"

    private static let fallbackLanguageCode = "en"
    private static let tableName = "Translations"

    static func text(_ key: String) -> String {
        dictionary[key] ?? fallbackDictionary[key] ?? key
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let template = text(key)
        return String(format: template, locale: Locale.current, arguments: arguments)
    }

    static var supportedLanguages: [AppLanguage] {
        AppLanguage.allCases
    }

    private static var dictionary: [String: String] {
        loadDictionary(for: preferredLanguageCode) ?? fallbackDictionary
    }

    private static var fallbackDictionary: [String: String] {
        loadDictionary(for: fallbackLanguageCode) ?? [:]
    }

    private static var preferredLanguageCode: String {
        let defaults = UserDefaults.standard
        if
            let selectedLanguageCode = defaults.string(forKey: selectedLanguageDefaultsKey),
            let selectedLanguage = AppLanguage(rawValue: selectedLanguageCode),
            selectedLanguage != .system
        {
            return selectedLanguage.resolvedLanguageCode
        }

        return Locale.preferredLanguages
            .compactMap { Locale(identifier: $0).language.languageCode?.identifier }
            .first ?? fallbackLanguageCode
    }

    private static func loadDictionary(for languageCode: String) -> [String: String]? {
        guard
            let url = BundleToken.bundle.url(forResource: "\(tableName)-\(languageCode)", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let dictionary = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return nil
        }

        return dictionary
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case german = "de"

    var id: String { rawValue }

    var resolvedLanguageCode: String {
        switch self {
        case .system:
            return Locale.preferredLanguages
                .compactMap { Locale(identifier: $0).language.languageCode?.identifier }
                .first ?? "en"
        case .english, .german:
            return rawValue
        }
    }

    var titleKey: String {
        switch self {
        case .system:
            return "settings.language_system"
        case .english:
            return "settings.language_en"
        case .german:
            return "settings.language_de"
        }
    }
}

private final class BundleToken {
    static let bundle = Bundle(for: BundleToken.self)
}
