import SwiftUI

struct DetailsView: View {
    @ObservedObject var viewModel: PriceViewModel
    @Binding var selectedDay: PriceDay

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.97, green: 0.97, blue: 0.96), Color(red: 0.91, green: 0.94, blue: 0.97)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
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

    private var detailSection: some View {
        let entries = viewModel.entries(for: selectedDay)

        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("details.price_details"))
                .font(.title3.weight(.semibold))

            ForEach(entries) { entry in
                PriceDetailRow(
                    entry: entry,
                    accent: viewModel.color(for: entry, within: entries),
                    isCurrent: selectedDay == .today && entry.id == viewModel.currentPrice?.id
                )
            }
        }
        .padding(18)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.45), lineWidth: 1)
        )
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
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.45), lineWidth: 1)
        )
    }
}
