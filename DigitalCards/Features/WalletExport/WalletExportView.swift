import PassKit
import SwiftData
import SwiftUI

struct WalletExportView: View {
    let cardID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var environment: AppEnvironment

    @State private var card: StoredCard?
    @State private var isExporting = false
    @State private var passSheet: PassSheet?
    @State private var errorMessage: ErrorMessage?

    private var repository: SwiftDataCardRepository {
        SwiftDataCardRepository(context: modelContext, encryptionService: environment.encryptionService)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dcBackground.ignoresSafeArea()

                if let card {
                    let merchant = environment.merchantCatalog.merchant(id: card.merchantID)

                    ScrollView {
                        VStack(spacing: 24) {
                            GiftCardView(
                                merchant: merchant,
                                displayName: card.displayName,
                                balanceText: MoneyFormatter.string(
                                    minorUnits: card.currentBalanceMinorUnits,
                                    currency: card.currency
                                ),
                                last4: card.cardNumberLast4
                            )
                            .padding(.horizontal)
                            .padding(.top, 8)

                            Text("The Wallet pass includes the barcode, balance, and PIN when this card has one.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            Button {
                                exportPass()
                            } label: {
                                if isExporting {
                                    ProgressView().tint(.white)
                                } else {
                                    Label("Generate Wallet Pass", systemImage: "wallet.pass")
                                }
                            }
                            .buttonStyle(.solidCTA)
                            .disabled(isExporting)
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 40)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    ContentUnavailableView("Card Not Found", systemImage: "wallet.pass")
                }
            }
            .navigationTitle("Apple Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .dcNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $passSheet) { sheet in
                AddPassViewController(pass: sheet.pass)
            }
            .alert(item: $errorMessage) { msg in
                Alert(title: Text("Wallet Export Failed"), message: Text(msg.text), dismissButton: .default(Text("OK")))
            }
            .onAppear { loadCard() }
        }
        .preferredColorScheme(.dark)
    }

    private func loadCard() {
        do { card = try repository.getCard(id: cardID) }
        catch { errorMessage = ErrorMessage(text: error.localizedDescription) }
    }

    private func exportPass() {
        Task {
            isExporting = true
            defer { isExporting = false }
            do {
                try await environment.authenticationService.authenticate(reason: "Add this gift card to Apple Wallet.")
                guard let card else { return }
                let merchant = environment.merchantCatalog.merchant(id: card.merchantID)
                let secrets = try repository.decryptSecrets(for: card)
                let serialNumber = try repository.ensureWalletSerialNumber(id: card.id)
                let request = environment.walletPassService.buildPassRequest(
                    card: card, secrets: secrets, merchant: merchant, serialNumber: serialNumber
                )
                let data = try await environment.walletPassService.requestSignedPass(request)
                let pass = try environment.walletPassService.makePass(from: data)
                passSheet = PassSheet(pass: pass)
            } catch { errorMessage = ErrorMessage(text: error.localizedDescription) }
        }
    }
}

struct PassSheet: Identifiable {
    let id = UUID()
    let pass: PKPass
}
