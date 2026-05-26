import SwiftUI

// MARK: - Color Tokens
extension Color {
    static let dcBackground = Color(hex: "#0F0F1A")
    static let dcSurface = Color(hex: "#141421")
    static let dcSurfaceHigh = Color(hex: "#202032")
    static let dcNeonBlue   = Color(hex: "#00AAFF")   // accent only
    static let dcNeonMagenta = Color(hex: "#FF3EBF")
    static let dcElectricViolet = Color(hex: "#7C5CFF")
    static let dcCyberGold = Color(hex: "#FFB300")
    static let dcTextSecondary = Color(hex: "#9CA3AF")
}

// MARK: - Font Tokens
// Use system semantic styles (.headline, .body, .subheadline, .caption) everywhere possible.
// Only define custom sizes where semantics don't cover it.
extension Font {
    static let dcBalance = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let dcLargeBalance = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let dcTitle = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let dcCardName = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let dcBody = Font.system(size: 15, weight: .medium, design: .rounded)
    static let dcCaption = Font.system(size: 13, weight: .medium, design: .rounded)
    static let dcLabel = Font.system(size: 12, weight: .medium, design: .rounded)
    static let dcCardBalance = Font.system(size: 26, weight: .bold)   // hero balance on card
    static let dcCardNumber  = Font.system(size: 13, design: .monospaced)  // •••• 1234
}

// MARK: - Nav Bar
extension View {
    func dcNavBar() -> some View {
        self
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    func neonGlow(_ color: Color, radius: CGFloat = 12) -> some View {
        self.shadow(color: color.opacity(0.35), radius: radius, x: 0, y: radius / 3)
    }
}

// MARK: - Button Styles

struct GlassPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.white.opacity(configuration.isPressed ? 0.06 : 0.1))
                    .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

struct SolidCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.dcNeonBlue.opacity(configuration.isPressed ? 0.75 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassPillButtonStyle {
    static var glassPill: GlassPillButtonStyle { GlassPillButtonStyle() }
}

extension ButtonStyle where Self == SolidCTAButtonStyle {
    static var solidCTA: SolidCTAButtonStyle { SolidCTAButtonStyle() }
}

struct NeonPillButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dcBody)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(color.opacity(configuration.isPressed ? 0.08 : 0.14))
                    .overlay(Capsule().stroke(color.opacity(0.45), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

struct NeonProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dcBody)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.dcNeonBlue.opacity(configuration.isPressed ? 0.75 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == NeonPillButtonStyle {
    static func neonPill(_ color: Color = .dcNeonBlue) -> NeonPillButtonStyle {
        NeonPillButtonStyle(color: color)
    }
}

extension ButtonStyle where Self == NeonProminentButtonStyle {
    static var neonProminent: NeonProminentButtonStyle { NeonProminentButtonStyle() }
}

// MARK: - Form Components

struct GlassSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
            VStack(spacing: 8) {
                content
            }
        }
    }
}

struct GlassField<Field: View>: View {
    let field: Field

    init(@ViewBuilder field: () -> Field) {
        self.field = field()
    }

    var body: some View {
        field
            .font(.body)
            .foregroundStyle(.white)
            .tint(.dcNeonBlue)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            )
    }
}

typealias NeonFormSection<Content: View> = GlassSection<Content>
typealias NeonField<Field: View> = GlassField<Field>

// MARK: - Detail Row
// Matches iOS Settings / Wallet row style: subdued label left, value right.

struct DetailRow: View {
    let label: String
    let value: String
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            if !isLast {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }
}

struct BalanceHistorySection: View {
    let title: String
    let entries: [BalanceAdjustment]
    var showCardName = false
    var emptyMessage = "No balance history yet."
    var limit: Int?

    private var visibleEntries: [BalanceAdjustment] {
        guard let limit else { return entries }
        return Array(entries.prefix(limit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)

            VStack(spacing: 0) {
                if visibleEntries.isEmpty {
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else {
                    ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                        BalanceHistoryRow(entry: entry, showCardName: showCardName)
                        if index < visibleEntries.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
        }
    }
}

private struct BalanceHistoryRow: View {
    let entry: BalanceAdjustment
    let showCardName: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.statusLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if showCardName {
                        Text("\(entry.cardDisplayName) •••• \(entry.cardNumberLast4)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                Text(entry.changeText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(entry.createdAt.shortDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                Text(entry.balanceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            if let note = entry.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}
