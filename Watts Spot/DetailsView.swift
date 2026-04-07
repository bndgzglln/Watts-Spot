import SwiftUI
import SpotPriceKit

struct DetailsView: View {
    @ObservedObject var viewModel: PriceViewModel
    @Binding var selectedDay: PriceDay
    @Environment(\.colorScheme) private var colorScheme
    @State private var showPastPrices = false

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Picker(L10n.text("details.day_picker"), selection: $selectedDay) {
                            ForEach(viewModel.availableDays) { day in
                                Text(day.title).tag(day)
                            }
                        }
                        .pickerStyle(.segmented)

                        cheapestSection
                        detailSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle(L10n.text("details.navigation_title"))
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.15, green: 0.15, blue: 0.17), Color(red: 0.12, green: 0.14, blue: 0.18)]
                : [Color(red: 0.97, green: 0.97, blue: 0.96), Color(red: 0.91, green: 0.94, blue: 0.97)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var detailSection: some View {
        let entries = viewModel.entries(for: selectedDay)
        let currentPriceId = viewModel.currentPrice?.id
        let (pastEntries, futureEntries) = splitEntries(entries, currentPriceId: currentPriceId, selectedDay: selectedDay)
        let showPastSection = selectedDay == .today && !pastEntries.isEmpty

        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("details.price_details"))
                .font(.title3.weight(.semibold))

            if entries.isEmpty {
                ContentUnavailableView(L10n.text("chart.empty_title"), systemImage: "chart.xyaxis.line", description: Text(L10n.text("chart.empty_description")))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                if showPastSection {
                    DisclosureGroup(
                        isExpanded: $showPastPrices,
                        content: {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(pastEntries) { entry in
                                    PriceDetailRow(
                                        entry: entry,
                                        accent: viewModel.color(for: entry, within: entries),
                                        isCurrent: false
                                    )
                                }
                            }
                            .padding(.top, 8)
                        },
                        label: {
                            Text(L10n.text("details.past_prices"))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    )
                    .disclosureGroupStyle(PastPricesDisclosureStyle())
                }

                ForEach(futureEntries) { entry in
                    PriceDetailRow(
                        entry: entry,
                        accent: viewModel.color(for: entry, within: entries),
                        isCurrent: selectedDay == .today && entry.id == currentPriceId
                    )
                }
            }
        }
        .padding(18)
        .background(colorScheme == .dark
            ? Color(uiColor: .secondarySystemBackground).opacity(0.8)
            : Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.white.opacity(0.45), lineWidth: 1)
        )
    }

    private func splitEntries(_ entries: [SpotPrice], currentPriceId: Date?, selectedDay: PriceDay) -> (past: [SpotPrice], future: [SpotPrice]) {
        // For tomorrow, show all entries as future (no past/future split)
        if selectedDay == .tomorrow {
            return ([], entries)
        }

        guard let currentPriceId = currentPriceId else {
            return ([], entries)
        }

        var past: [SpotPrice] = []
        var future: [SpotPrice] = []
        var foundCurrent = false

        for entry in entries {
            if entry.id == currentPriceId {
                foundCurrent = true
                future.append(entry)
            } else if foundCurrent {
                future.append(entry)
            } else {
                past.append(entry)
            }
        }

        return (past, future)
    }

    struct PastPricesDisclosureStyle: DisclosureGroupStyle {
        func makeBody(configuration: Configuration) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        configuration.isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        configuration.label
                    }
                }
                .buttonStyle(.plain)

                if configuration.isExpanded {
                    configuration.content
                }
            }
        }
    }

    private var cheapestSection: some View {
        let windows = viewModel.lowPriceWindows(for: selectedDay)
        let headline = selectedDay == .today ? L10n.text("details.best_low_price_today") : L10n.text("details.best_low_price_tomorrow")

        return VStack(alignment: .leading, spacing: 10) {
            Text(headline)
                .font(.headline)

            if let primaryWindow = windows.first {
                Text(primaryWindow.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text("\(primaryWindow.averagePriceText) • \(primaryWindow.minPriceText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(Array(windows.dropFirst().enumerated()), id: \.offset) { index, window in
                    Text(L10n.format("details.also_good", window.title, window.averagePriceText))
                        .font(.footnote)
                        .foregroundStyle(index == 0 ? .secondary : .tertiary)
                }
            } else {
                Text(L10n.text("details.no_data"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark
            ? Color(uiColor: .secondarySystemBackground).opacity(0.82)
            : Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.white.opacity(0.45), lineWidth: 1)
        )
    }
}
