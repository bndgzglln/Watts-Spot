import Charts
import SwiftUI
import WidgetKit
import SpotPriceKit

struct CurrentPriceEntry: TimelineEntry {
    let date: Date
    let currentPrice: SpotPrice?
    let minPrice: SpotPrice?
    let maxPrice: SpotPrice?
    let todayEntries: [SpotPrice]
}

struct CurrentPriceProvider: TimelineProvider {
    private let api = EnergyChartsAPI()
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna") ?? .current
        return calendar
    }()

    func placeholder(in context: Context) -> CurrentPriceEntry {
        let now = Date()
        let sampleEntries = (0..<24).map { hour -> SpotPrice in
            SpotPrice(
                timestamp: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now,
                pricePerMWh: 40 + Double((hour * 7) % 70)
            )
        }
        let low = sampleEntries.min(by: { $0.pricePerMWh < $1.pricePerMWh })
        let high = sampleEntries.max(by: { $0.pricePerMWh < $1.pricePerMWh })
        let current = sampleEntries[12]
        return CurrentPriceEntry(date: now, currentPrice: current, minPrice: low, maxPrice: high, todayEntries: sampleEntries)
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrentPriceEntry) -> Void) {
        Task {
            completion(await makeEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrentPriceEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            let nextRefresh = calendar.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private func makeEntry() async -> CurrentPriceEntry {
        let now = Date()

        do {
            let prices = try await api.fetchPrices(for: "AT")
            let todayEntries = displayedDayEntries(from: prices, now: now)
            let current = todayEntries.last(where: { $0.timestamp <= now && $0.intervalEnd > now })
                ?? todayEntries.first(where: { $0.timestamp > now })
                ?? todayEntries.last

            return CurrentPriceEntry(
                date: now,
                currentPrice: current,
                minPrice: todayEntries.min(by: { $0.pricePerMWh < $1.pricePerMWh }),
                maxPrice: todayEntries.max(by: { $0.pricePerMWh < $1.pricePerMWh }),
                todayEntries: todayEntries
            )
        } catch {
            return CurrentPriceEntry(date: now, currentPrice: nil, minPrice: nil, maxPrice: nil, todayEntries: [])
        }
    }

    private func displayedDayEntries(from prices: [SpotPrice], now: Date) -> [SpotPrice] {
        let groupedByDay = Dictionary(grouping: prices) { calendar.startOfDay(for: $0.timestamp) }
        let sortedDays = groupedByDay.keys.sorted()
        let todayStart = calendar.startOfDay(for: now)

        let selectedDay = sortedDays.first(where: { $0 == todayStart })
            ?? sortedDays.last(where: { $0 <= todayStart })
            ?? sortedDays.first

        return (selectedDay.flatMap { groupedByDay[$0] } ?? []).sorted(by: { $0.timestamp < $1.timestamp })
    }
}

struct CurrentPriceWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    let entry: CurrentPriceProvider.Entry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallWidget
            case .systemMedium, .systemLarge:
                largeWidget
            default:
                smallWidget
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.15, green: 0.15, blue: 0.17), Color(red: 0.12, green: 0.14, blue: 0.18)]
                    : [Color(red: 0.97, green: 0.99, blue: 0.97), Color(red: 0.90, green: 0.95, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var smallWidget: some View {
        GeometryReader { geometry in
            if
                let current = entry.currentPrice,
                let minPrice = entry.minPrice,
                let maxPrice = entry.maxPrice
            {
                let size = min(geometry.size.width, geometry.size.height)
                let lineWidth = size * 0.12
                let ratio = normalizedRatio(for: current.pricePerMWh, min: minPrice.pricePerMWh, max: maxPrice.pricePerMWh)

                ZStack {
                    DialArcShape(startRatio: 0, endRatio: 1)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.green, .gray, .red]),
                                center: .center,
                                startAngle: .degrees(150),
                                endAngle: .degrees(390)
                            ),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .opacity(0.22)

                    DialArcShape(startRatio: 0, endRatio: ratio)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.green, .gray, .red]),
                                center: .center,
                                startAngle: .degrees(150),
                                endAngle: .degrees(390)
                            ),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )

                    VStack(spacing: 2) {
                        Text(current.priceValueText)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .frame(maxWidth: size * 0.50)

                        Text(current.shortTimeLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .allowsTightening(true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack {
                        Spacer()

                        HStack(alignment: .bottom) {
                            Text(minPrice.priceValueText)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.green)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                                .allowsTightening(true)
                                .frame(maxWidth: size * 0.35, alignment: .leading)

                            Spacer()

                            Text(maxPrice.priceValueText)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.red)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                                .allowsTightening(true)
                                .frame(maxWidth: size * 0.35, alignment: .trailing)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                unavailableView
            }
        }
    }

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("widget.today"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(L10n.text("widget.spot_price"))
                        .font(.headline.weight(.bold))
                }

                Spacer()

                if let current = entry.currentPrice {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(current.priceText)
                            .font(.headline.weight(.bold))
                            .monospacedDigit()
                        Text(current.intervalLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if entry.todayEntries.isEmpty {
                unavailableView
            } else {
                Chart(entry.todayEntries) { price in
                    BarMark(
                        x: .value("Time", price.timestamp),
                        y: .value("Price", price.pricePerKWh * 100)
                    )
                    .foregroundStyle(barStyle(for: price))
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                        AxisGridLine().foregroundStyle(.clear)
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour(), centered: true)
                    }
                }
                .chartYAxis(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private var unavailableView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("widget.current_price"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(L10n.text("widget.no_live_data"))
                .font(.headline)
            Text(L10n.text("widget.refresh_hint"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func barStyle(for price: SpotPrice) -> some ShapeStyle {
        let fill = chartColor(
            for: price.pricePerMWh,
            minPrice: entry.minPrice?.pricePerMWh ?? price.pricePerMWh,
            maxPrice: entry.maxPrice?.pricePerMWh ?? price.pricePerMWh
        )

        if price.id == entry.currentPrice?.id {
            return AnyShapeStyle(colorScheme == .dark ? Color.white.opacity(0.3) : Color.white)
        }

        return AnyShapeStyle(fill)
    }

    private func normalizedRatio(for price: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 0 }
        return Swift.min(Swift.max((price - min) / (max - min), 0), 1)
    }

    private func dialPoint(center: CGPoint, radius: CGFloat, ratio: Double) -> CGPoint {
        let angle = Angle.degrees(150 + (240 * ratio))
        let radians = CGFloat(angle.radians)
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }

    private func chartColor(for price: Double, minPrice: Double, maxPrice: Double) -> Color {
        let priceInCents = price / 10
        
        if priceInCents <= 0 {
            return Color.green
        }
        
        let normalizedRatio = min(priceInCents / 30.0, 1.0)
        
        let red = 0.6 + (0.35 * normalizedRatio)
        let green = 0.35 * (1 - normalizedRatio)
        let blue = 0.05 * (1 - normalizedRatio)
        
        return Color(red: red, green: green, blue: blue)
    }
}

struct DialArcShape: Shape {
    let startRatio: Double
    let endRatio: Double

    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = min(rect.width, rect.height) * 0.13
        let drawingRect = rect.insetBy(dx: inset, dy: inset)
        let startAngle = Angle.degrees(150 + (240 * startRatio))
        let endAngle = Angle.degrees(150 + (240 * endRatio))

        var path = Path()
        path.addArc(
            center: CGPoint(x: drawingRect.midX, y: drawingRect.midY + 8),
            radius: min(drawingRect.width, drawingRect.height) / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

struct CurrentPriceWidget: Widget {
    let kind = "CurrentPriceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrentPriceProvider()) { entry in
            CurrentPriceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(L10n.text("widget.configuration_name"))
        .description(L10n.text("widget.configuration_description"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
