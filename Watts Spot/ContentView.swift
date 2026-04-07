import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PriceViewModel()
    @State private var selectedDay: PriceDay = .today
    @AppStorage("selectedRegionCode") private var selectedRegionCode = "AT"
    @AppStorage(L10n.selectedLanguageDefaultsKey) private var selectedLanguageCode = AppLanguage.system.rawValue
    
    private var selectedLocale: Locale {
        guard let language = AppLanguage(rawValue: selectedLanguageCode) else {
            return Locale(identifier: "en")
        }

        return Locale(identifier: language.resolvedLanguageCode)
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    var body: some View {
        TabView {
            HomeView(
                viewModel: viewModel,
                selectedDay: $selectedDay,
                selectedRegionCode: selectedRegionCode
            )
            .tabItem {
                Label(L10n.text("app.home_tab"), systemImage: "bolt.fill")
            }

            DetailsView(viewModel: viewModel, selectedDay: $selectedDay)
                .tabItem {
                    Label(L10n.text("app.details_tab"), systemImage: "list.bullet.rectangle")
                }

            SettingsView(
                viewModel: viewModel,
                selectedRegionCode: $selectedRegionCode,
                selectedLanguageCode: $selectedLanguageCode,
                reloadPrices: {
                    await viewModel.loadPrices(regionCode: selectedRegionCode)
                }
            )
            .tabItem {
                Label(L10n.text("app.settings_tab"), systemImage: "gearshape")
            }
        }
        .environment(\.locale, selectedLocale)
        .id(selectedLanguageCode)
        .task {
            await viewModel.loadPrices(regionCode: selectedRegionCode)
        }
        .onChange(of: selectedRegionCode) { _, newValue in
            Task {
                await viewModel.loadPrices(regionCode: newValue)
            }
        }
        .onChange(of: viewModel.availableDays) { _, availableDays in
            if !availableDays.contains(selectedDay) {
                selectedDay = .today
            }
        }
        .alert(L10n.text("app.load_error_title"), isPresented: isShowingError) {
            Button(L10n.text("common.ok")) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    ContentView()
}
