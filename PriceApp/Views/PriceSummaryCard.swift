import SwiftUI

struct PriceSummaryCard: View {
    let title: String
    let subtitle: String
    let valueText: String
    let detailText: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Circle()
                    .fill(tint.gradient)
                    .frame(width: 16, height: 16)
            }

            Text(valueText)
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text(detailText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.55), lineWidth: 1)
        )
    }
}
