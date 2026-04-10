import SwiftUI
import SpotPriceKit

struct HomeView: View {
    @ObservedObject var viewModel: PriceViewModel
    @Binding var selectedDay: PriceDay
    let selectedRegionCode: String
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedChartEntry: SpotPrice?

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
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
                .refreshable {
                    await viewModel.manualRefresh(regionCode: selectedRegionCode)
                }
            }
            .navigationTitle(L10n.text("home.navigation_title"))
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.15, green: 0.15, blue: 0.17), Color(red: 0.12, green: 0.14, blue: 0.18)]
                : [Color(red: 0.96, green: 0.98, blue: 0.95), Color(red: 0.87, green: 0.93, blue: 0.96)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
                tint: viewModel.tomorrowEntries.isEmpty ? .gray : .orange
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
        let averagePrice = entries.isEmpty ? 0.0 : entries.map(\.pricePerKWh).reduce(0, +) / Double(entries.count)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDay.title)
                    .font(.title3.weight(.semibold))
                
                if let selected = selectedChartEntry {
                    Text(selected.priceText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(selected.intervalLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !entries.isEmpty {
                    Text(L10n.format("price.avg_suffix", (averagePrice * 100).formatted(.number.precision(.fractionLength(2)))))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            PriceChartSection(
                entries: entries,
                selectedEntry: $selectedChartEntry,
                colorForEntry: { entry in
                    viewModel.color(for: entry, within: entries)
                },
                showNowLine: selectedDay == .today,
                chartDate: selectedDay == .today ? Date() : Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            )
        }
        .padding(18)
        .background(colorScheme == .dark
            ? Color(uiColor: .secondarySystemBackground).opacity(0.8)
            : Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.white.opacity(0.45), lineWidth: 1)
        )
    }
}
