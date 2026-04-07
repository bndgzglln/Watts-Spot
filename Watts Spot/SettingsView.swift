import SwiftUI
import SpotPriceKit

struct SettingsView: View {
    @ObservedObject var viewModel: PriceViewModel
    @Binding var selectedRegionCode: String
    @Binding var selectedLanguageCode: String
    let reloadPrices: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                notificationSection
                languageSection
                regionSection
            }
            .navigationTitle(L10n.text("settings.navigation_title"))
        }
    }

    private var notificationSection: some View {
        Section(L10n.text("settings.notifications_section")) {
            Toggle(
                L10n.text("settings.price_alerts"),
                isOn: Binding(
                    get: { viewModel.notificationsEnabled },
                    set: { newValue in
                        Task {
                            await viewModel.setNotificationsEnabled(newValue)
                        }
                    }
                )
            )

            Text(viewModel.notificationDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let cheapest = viewModel.cheapestTomorrowEntry, viewModel.notificationsEnabled {
                Text(L10n.format("settings.cheapest_tomorrow", cheapest.intervalLabel, cheapest.priceText))
                    .font(.footnote.weight(.semibold))
            }
        }
    }

    private var languageSection: some View {
        Section(L10n.text("settings.language_section")) {
            Picker(L10n.text("settings.language_picker"), selection: $selectedLanguageCode) {
                ForEach(L10n.supportedLanguages) { language in
                    Text(L10n.text(language.titleKey))
                        .tag(language.rawValue)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    private var regionSection: some View {
        Section(L10n.text("settings.region_section")) {
            Picker(L10n.text("settings.bidding_zone"), selection: $selectedRegionCode) {
                ForEach(PriceRegionCatalog.presets) { region in
                    Text("\(region.name) (\(region.code))")
                        .tag(region.code)
                }
            }
            .pickerStyle(.navigationLink)
            .onChange(of: selectedRegionCode) { _, _ in
                Task { await reloadPrices() }
            }
        }
    }
}
