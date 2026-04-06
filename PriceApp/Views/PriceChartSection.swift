import Charts
import SwiftUI

struct PriceChartSection: View {
    let entries: [SpotPrice]
    let colorForEntry: (SpotPrice) -> Color

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(L10n.text("chart.empty_title"), systemImage: "chart.xyaxis.line", description: Text(L10n.text("chart.empty_description")))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else {
            Chart(entries) { entry in
                BarMark(
                    x: .value("Time", entry.timestamp),
                    y: .value("Price", entry.pricePerKWh * 100)
                )
                .foregroundStyle(colorForEntry(entry))
                .cornerRadius(4)
            }
            .chartYAxisLabel("ct/kWh")
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .frame(height: 260)

            HStack {
                Label(L10n.text("chart.low"), systemImage: "circle.fill")
                    .foregroundStyle(Color.green)

                Spacer()

                Label(L10n.text("chart.mid"), systemImage: "circle.fill")
                    .foregroundStyle(Color.gray)

                Spacer()

                Label(L10n.text("chart.high"), systemImage: "circle.fill")
                    .foregroundStyle(Color.red)
            }
            .font(.caption.weight(.medium))
        }
    }
}
