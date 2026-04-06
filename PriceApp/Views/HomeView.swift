import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: PriceViewModel
    @Binding var selectedDay: PriceDay
    let selectedRegionCode: String

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.96, green: 0.98, blue: 0.95), Color(red: 0.87, green: 0.93, blue: 0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        summarySection
                        dayPicker
                        chartSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle(L10n.text("home.navigation_title"))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.format("home.header_subtitle", PriceRegionCatalog.displayName(for: selectedRegionCode)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var summarySection: some View {
        VStack(spacing: 14) {
            PriceSummaryCard(
                title: L10n.text("home.current_price_title"),
                subtitle: viewModel.currentPrice?.intervalLabel ?? L10n.text("home.current_price_waiting"),
                valueText: viewModel.currentPrice.map(\.priceText) ?? L10n.text("price.unavailable"),
                detailText: L10n.text("home.current_price_detail"),
                tint: viewModel.currentPrice.flatMap { viewModel.color(for: $0, within: viewModel.todayEntries) } ?? .gray
            )

            PriceSummaryCard(
                title: L10n.text("home.day_ahead_title"),
                subtitle: viewModel.tomorrowLabel,
                valueText: viewModel.dayAheadAverageText,
                detailText: viewModel.dayAheadSummaryText,
                tint: .orange
            )
        }
    }

    private var dayPicker: some View {
        Picker(L10n.text("home.day_picker"), selection: $selectedDay) {
            ForEach(viewModel.availableDays) { day in
                Text(day.title).tag(day)
            }
        }
        .pickerStyle(.segmented)
    }

    private var chartSection: some View {
        let entries = viewModel.entries(for: selectedDay)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDay.title)
                    .font(.title3.weight(.semibold))

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            PriceChartSection(
                entries: entries,
                colorForEntry: { entry in
                    viewModel.color(for: entry, within: entries)
                }
            )
        }
        .padding(18)
        .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.45), lineWidth: 1)
        )
    }
}
