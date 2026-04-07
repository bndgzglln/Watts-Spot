import SwiftUI
import SpotPriceKit

struct PriceDetailRow: View {
    let entry: SpotPrice
    let accent: Color
    let isCurrent: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent)
                .frame(width: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.intervalLabel)
                        .font(.subheadline.weight(.semibold))

                    if isCurrent {
                        Text(L10n.text("detail.live"))
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.08), in: Capsule())
                    }
                }
            }

            Spacer()

            Text(entry.priceText)
                .font(.body.weight(.bold))
        }
        .padding(.vertical, 6)
    }
}
