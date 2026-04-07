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
            case .accessoryCircular:
                lockScreenCircularWidget
            case .accessoryRectangular:
                lockScreenRectangularWidget
            case .accessoryInline:
                lockScreenInlineWidget
            @unknown default:
                smallWidget
            }
        }
        .containerBackground(for: .widget) {
            if family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline {
                // Lock screen widgets don't need custom background
            } else {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(red: 0.15, green: 0.15, blue: 0.17), Color(red: 0.12, green: 0.14, blue: 0.18)]
                        : [Color(red: 0.97, green: 0.99, blue: 0.97), Color(red: 0.90, green: 0.95, blue: 0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var smallWidget: some View {
        GeometryReader { geometry in
            if
                let current = entry.currentPrice,
                let minPrice = entry.minPrice,
                let maxPrice = entry.maxPrice
            {
                let width = geometry.size.width
                let height = geometry.size.height
                let gaugeSize = min(width, height) * 0.8
                let lineWidth: CGFloat = 12
                let ratio = normalizedRatio(for: current.pricePerMWh, min: minPrice.pricePerMWh, max: maxPrice.pricePerMWh)

                VStack(spacing: 0) {
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

                        Text(current.priceValueText)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    .frame(width: gaugeSize, height: gaugeSize)

                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("min")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text(minPrice.priceValueText)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("max")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text(maxPrice.priceValueText)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    Text(current.shortTimeLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(width: width, height: height)
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
                    .foregroundStyle(price.pricePerKWh >= 0 ? Color.orange : Color.green)
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
        .padding(10)
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

    // MARK: - Lock Screen Widgets

    @ViewBuilder
    private var lockScreenCircularWidget: some View {
        if let current = entry.currentPrice,
           let minPrice = entry.minPrice,
           let maxPrice = entry.maxPrice {
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let ratio = normalizedRatio(for: current.pricePerMWh, min: minPrice.pricePerMWh, max: maxPrice.pricePerMWh)
                
                ZStack {
                    // Full gauge arc (no background, fills the circular space)
                    DialArcShape(startRatio: 0, endRatio: 1)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.green, .yellow, .red]),
                                center: .center,
                                startAngle: .degrees(150),
                                endAngle: .degrees(390)
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: size, height: size)
                    
                    // Current value arc overlaid
                    DialArcShape(startRatio: 0, endRatio: ratio)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.green, .yellow, .red]),
                                center: .center,
                                startAngle: .degrees(150),
                                endAngle: .degrees(390)
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: size, height: size)
                    
                    // Current price indicator dot at the end of the arc
                    CurrentPriceIndicatorShape(ratio: ratio)
                        .fill(Color.white)
                        .frame(width: size, height: size)
                    
                    // Price text centered, fits inside the gauge
                    VStack(spacing: 0) {
                        Text(current.priceValueText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        
                        Text("ct")
                            .font(.system(size: 7))
                            .foregroundStyle(.secondary)
                    }
                    .padding(8) // Ensure text stays within gauge bounds
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        } else {
            ZStack {
                Image(systemName: "bolt.slash")
                    .font(.title3)
            }
        }
    }

    @ViewBuilder
    private var lockScreenRectangularWidget: some View {
        if let current = entry.currentPrice,
           let minPrice = entry.minPrice,
           let maxPrice = entry.maxPrice {
            HStack(spacing: 4) {
                // Left side: Current price (2/3 of width) with trend indicator
                VStack(alignment: .center, spacing: 2) {
                    Text(current.priceValueText)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    
                    // Trend indicator - arrow showing if next timeslot is more/less expensive
                    HStack(spacing: 2) {
                        if let nextPrice = nextPriceEntry(for: current) {
                            let isNextMoreExpensive = nextPrice.pricePerMWh > current.pricePerMWh
                            Image(systemName: isNextMoreExpensive ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(isNextMoreExpensive ? .red : .green)
                            
                            Text(nextPrice.priceValueText)
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .minimumScaleFactor(0.6)
                        } else {
                            Text("--")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider()
                    .frame(height: 36)
                
                // Right side: Max (top) and Min (bottom) stacked (1/3 of width)
                VStack(alignment: .center, spacing: 4) {
                    // Max price on top
                    VStack(alignment: .center, spacing: 0) {
                        Text(maxPrice.priceValueText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.red)
                        
                        Text("max")
                            .font(.system(size: 7))
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                        .frame(width: 30)
                    
                    // Min price on bottom
                    VStack(alignment: .center, spacing: 0) {
                        Text(minPrice.priceValueText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.green)
                        
                        Text("min")
                            .font(.system(size: 7))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 6)
        } else if let current = entry.currentPrice {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(current.priceText)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    
                    Text(current.intervalLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
        } else {
            HStack {
                Image(systemName: "bolt.slash")
                Text(L10n.text("widget.no_live_data"))
                    .font(.caption)
            }
        }
    }
    
    private func nextPriceEntry(for current: SpotPrice) -> SpotPrice? {
        guard let currentIndex = entry.todayEntries.firstIndex(where: { $0.id == current.id }),
              currentIndex + 1 < entry.todayEntries.count else {
            return nil
        }
        return entry.todayEntries[currentIndex + 1]
    }

    @ViewBuilder
    private var lockScreenInlineWidget: some View {
        if let current = entry.currentPrice {
            Text("\(Image(systemName: "bolt.fill")) \(current.priceText)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
        } else {
            Text("\(Image(systemName: "bolt.slash")) --")
        }
    }
}

struct DialArcShape: Shape {
    let startRatio: Double
    let endRatio: Double

    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 0
        let drawingRect = rect.insetBy(dx: inset, dy: inset)
        let startAngle = Angle.degrees(150 + (240 * startRatio))
        let endAngle = Angle.degrees(150 + (240 * endRatio))

        var path = Path()
        path.addArc(
            center: CGPoint(x: drawingRect.midX, y: drawingRect.midY + 2),
            radius: min(drawingRect.width, drawingRect.height) / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

struct CurrentPriceIndicatorShape: Shape {
    let ratio: Double

    func path(in rect: CGRect) -> Path {
        let drawingRect = rect
        let angle = Angle.degrees(150 + (240 * ratio))
        let radius = min(drawingRect.width, drawingRect.height) / 2
        let center = CGPoint(x: drawingRect.midX, y: drawingRect.midY + 2)
        let radians = CGFloat(angle.radians)

        // Calculate position on the arc
        let indicatorX = center.x + cos(radians) * radius
        let indicatorY = center.y + sin(radians) * radius

        var path = Path()
        path.addEllipse(in: CGRect(
            x: indicatorX - 3,
            y: indicatorY - 3,
            width: 6,
            height: 6
        ))
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
