import Charts
import SwiftUI
import SpotPriceKit

struct PriceChartSection: View {
    let entries: [SpotPrice]
    @Binding var selectedEntry: SpotPrice?
    let colorForEntry: (SpotPrice) -> Color
    var showNowLine: Bool = true
    @Environment(\.colorScheme) private var colorScheme
    
    private var averagePrice: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map(\.pricePerKWh).reduce(0, +) / Double(entries.count)
    }

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(L10n.text("chart.empty_title"), systemImage: "chart.xyaxis.line", description: Text(L10n.text("chart.empty_description")))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                chartView
                legendView
            }
        }
    }
    
    private var chartView: some View {
        Chart {
            ForEach(entries) { entry in
                BarMark(
                    x: .value("Time", entry.timestamp),
                    y: .value("Price", entry.pricePerKWh * 100)
                )
                .foregroundStyle(barColor(for: entry))
                .cornerRadius(4)
            }
            
            if let selected = selectedEntry {
                RuleMark(x: .value("Selected", selected.timestamp))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(.primary.opacity(0.5))
            }
            
            if showNowLine {
                RuleMark(x: .value("Now", Date()))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(nowLineColor)
            }
            
            RuleMark(y: .value("Average", averagePrice * 100))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(.orange)
        }
        .chartYAxisLabel("ct/kWh")
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateSelection(at: value.location, proxy: proxy, geometry: geometry)
                            }
                            .onEnded { _ in
                                selectedEntry = nil
                            }
                    )
            }
        }
        .chartXSelection(value: Binding(
            get: { selectedEntry?.timestamp },
            set: { newDate in
                if let newDate {
                    selectedEntry = entries.min(by: {
                        abs($0.timestamp.timeIntervalSince(newDate)) < abs($1.timestamp.timeIntervalSince(newDate))
                    })
                } else {
                    selectedEntry = nil
                }
            }
        ))
        .frame(height: 260)
    }
    
    private func barColor(for entry: SpotPrice) -> Color {
        if entry.id == selectedEntry?.id {
            return colorForEntry(entry).opacity(0.6)
        }
        return colorForEntry(entry)
    }
    
    private var nowLineColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.7)
    }
    
    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let origin = geometry[plotFrame].origin
        let adjustedLocation = CGPoint(x: location.x - origin.x, y: location.y - origin.y)
        
        guard let date: Date = proxy.value(atX: adjustedLocation.x) else { return }
        
        selectedEntry = entries.min(by: {
            abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date))
        })
    }
    
    private var legendView: some View {
        HStack {
            Label(L10n.text("chart.low"), systemImage: "circle.fill")
                .foregroundStyle(Color.green)

            Spacer()
            
            HStack(spacing: 4) {
                Rectangle()
                    .fill(.orange)
                    .frame(width: 16, height: 2)
                Text(L10n.format("price.avg_suffix", (averagePrice * 100).formatted(.number.precision(.fractionLength(2)))))
                    .font(.caption.weight(.medium))
            }

            Spacer()

            Label(L10n.text("chart.high"), systemImage: "circle.fill")
                .foregroundStyle(Color(red: 0.95, green: 0.05, blue: 0.05))
        }
        .font(.caption.weight(.medium))
    }
}
