import SwiftUI

struct GiftCardView: View {
    let merchant: Merchant
    let displayName: String
    let balanceText: String
    let last4: String
    var isCompact: Bool = false

    private var brandColor: Color { Color(hex: merchant.brandColorHex) }
    private var corner: CGFloat { isCompact ? 12 : 20 }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Solid brand color
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(brandColor)

            // Subtle plastic shimmer
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.14), .clear, .black.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Glass edge
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)

            // Text
            VStack(alignment: .leading, spacing: isCompact ? 1 : 4) {
                Spacer()
                Text(balanceText)
                    .font(isCompact ? .headline : .dcCardBalance)
                    .foregroundStyle(.white)
                Text(displayName)
                    .font(isCompact ? .caption : .headline)
                    .foregroundStyle(.white.opacity(0.8))
                Text("•••• \(last4.isEmpty ? "····" : last4)")
                    .font(.dcCardNumber)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(isCompact ? 10 : 20)
        }
        .aspectRatio(1.586, contentMode: .fit)
        .shadow(color: brandColor.opacity(0.45), radius: 16, x: 0, y: 6)
    }
}
