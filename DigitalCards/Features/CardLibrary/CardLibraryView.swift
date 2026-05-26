import SwiftData
import SwiftUI

struct CardLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var environment: AppEnvironment
    @Query(
        filter: #Predicate<StoredCard> { $0.archivedAt == nil },
        sort: [SortDescriptor(\StoredCard.displayName), SortDescriptor(\StoredCard.updatedAt, order: .reverse)]
    ) private var cards: [StoredCard]

    @State private var isAddingCard = false
    @State private var errorMessage: ErrorMessage?

    private var totalBalanceText: String? {
        CardBalanceCalculator.displayText(for: cards.map(\.summary))
    }

    private var merchantGroups: [MerchantCardGroup] {
        Dictionary(grouping: cards, by: { $0.merchantID })
            .map { merchantID, cards in
                MerchantCardGroup(
                    merchant: environment.merchantCatalog.merchant(id: merchantID),
                    cards: cards
                )
            }
            .sorted { lhs, rhs in
                let merchantOrder = lhs.merchant.displayName.localizedCaseInsensitiveCompare(rhs.merchant.displayName)
                if merchantOrder == .orderedSame {
                    return lhs.id < rhs.id
                }
                return merchantOrder == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.dcBackground.ignoresSafeArea()

                if cards.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            headerView
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .padding(.bottom, 20)

                            LazyVStack(spacing: 14) {
                                ForEach(merchantGroups) { group in
                                    merchantSection(group)
                                }
                            }
                            .padding(.bottom, 100)
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                fabButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 28)
            }
            .navigationTitle("My Cards")
            .dcNavBar()
            .sheet(isPresented: $isAddingCard) {
                AddCardView().environmentObject(environment)
            }
            .alert(item: $errorMessage) { msg in
                Alert(title: Text("Error"), message: Text(msg.text), dismissButton: .default(Text("OK")))
            }
            .safeAreaInset(edge: .bottom) {
                if let err = environment.startupError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.9))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var headerView: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(cards.count) card\(cards.count == 1 ? "" : "s")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let total = totalBalanceText {
                    Text("Net Balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(total)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 56))
                .foregroundStyle(Color.dcNeonBlue)
                .padding(.bottom, 4)

            Text("No Cards Yet")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text("Add a gift card to securely store its barcode, balance, and details.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                isAddingCard = true
            } label: {
                Label("Add Your First Card", systemImage: "plus")
            }
            .buttonStyle(.solidCTA)
            .padding(.horizontal, 40)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fabButton: some View {
        Button { isAddingCard = true } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Color.dcNeonBlue))
                .shadow(color: Color.dcNeonBlue.opacity(0.4), radius: 12, x: 0, y: 4)
        }
    }

    private func merchantSection(_ group: MerchantCardGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.merchant.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(group.cardCountText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Net Balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(group.netBalanceText ?? "No balance")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .minimumScaleFactor(0.75)
                }
            }
            .padding(.horizontal)

            ForEach(group.cards) { card in
                NavigationLink {
                    CardDetailView(cardID: card.id)
                        .environmentObject(environment)
                } label: {
                    GiftCardView(
                        merchant: group.merchant,
                        displayName: card.displayName,
                        balanceText: MoneyFormatter.string(
                            minorUnits: card.currentBalanceMinorUnits,
                            currency: card.currency
                        ),
                        last4: card.cardNumberLast4,
                        isCompact: group.cards.count > 1
                    )
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MerchantCardGroup: Identifiable {
    let merchant: Merchant
    let cards: [StoredCard]

    var id: String { merchant.id }

    var cardCountText: String {
        "\(cards.count) card\(cards.count == 1 ? "" : "s")"
    }

    var netBalanceText: String? {
        CardBalanceCalculator.displayText(for: cards.map(\.summary))
    }
}
