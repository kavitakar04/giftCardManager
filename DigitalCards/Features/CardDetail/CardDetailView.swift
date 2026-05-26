import SwiftData
import SwiftUI
import UIKit

struct CardDetailView: View {
    let cardID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var environment: AppEnvironment

    @State private var card: StoredCard?
    @State private var revealedSecrets: CardSecrets?
    @State private var showEditBalance = false
    @State private var showWalletExport = false
    @State private var errorMessage: ErrorMessage?

    private var repository: SwiftDataCardRepository {
        SwiftDataCardRepository(context: modelContext, encryptionService: environment.encryptionService)
    }

    var body: some View {
        Group {
            if let card {
                let merchant = environment.merchantCatalog.merchant(id: card.merchantID)

                ScrollView {
                    VStack(spacing: 20) {
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

                        Text(card.balanceStatus == .userEntered
                             ? "Balance is user-entered"
                             : "Balance not entered yet")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        actionPills(card: card)
                        detailsSection(card: card)
                        managementSection()
                    }
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                .background(Color.dcBackground.ignoresSafeArea())
                .navigationTitle(card.displayName)
                .navigationBarTitleDisplayMode(.inline)
                .dcNavBar()
                .sheet(isPresented: $showEditBalance) {
                    EditBalanceView(cardID: cardID, onSave: loadCard).environmentObject(environment)
                }
                .sheet(isPresented: $showWalletExport) {
                    WalletExportView(cardID: cardID).environmentObject(environment)
                }
            } else {
                ZStack {
                    Color.dcBackground.ignoresSafeArea()
                    ContentUnavailableView("Card Not Found", systemImage: "wallet.pass")
                }
                .dcNavBar()
            }
        }
        .onAppear(perform: loadCard)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { revealedSecrets = nil }
        }
        .alert(item: $errorMessage) { msg in
            Alert(title: Text("Error"), message: Text(msg.text), dismissButton: .default(Text("OK")))
        }
    }

    private func actionPills(card: StoredCard) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                NavigationLink {
                    BarcodeCheckoutView(cardID: cardID).environmentObject(environment)
                } label: {
                    Label("Show Barcode", systemImage: "barcode")
                }
                .buttonStyle(.glassPill)

                Button { revealSecrets() } label: {
                    Label("Reveal", systemImage: "lock.open")
                }
                .buttonStyle(.glassPill)

                Button { copyCardNumber() } label: {
                    Label("Copy Number", systemImage: "doc.on.doc")
                }
                .buttonStyle(.glassPill)

                if card.pinCiphertext != nil {
                    Button { copyPIN() } label: {
                        Label("Copy PIN", systemImage: "key")
                    }
                    .buttonStyle(.glassPill)
                }
            }
            .padding(.horizontal)
        }
    }

    private func detailsSection(card: StoredCard) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Card Details")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)

            VStack(spacing: 0) {
                DetailRow(
                    label: "Card Number",
                    value: revealedSecrets?.cardNumber ?? "Ending \(card.cardNumberLast4)"
                )
                if let pin = revealedSecrets?.pin {
                    DetailRow(label: "PIN", value: pin)
                } else if card.pinCiphertext != nil {
                    DetailRow(label: "PIN", value: "Hidden")
                }
                DetailRow(label: "Barcode Format", value: card.barcodeFormat.displayName)
                DetailRow(
                    label: "Balance Updated",
                    value: card.lastBalanceUpdateAt?.shortDisplay ?? "Never",
                    isLast: true
                )
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

    private func managementSection() -> some View {
        VStack(spacing: 10) {
            Button { showEditBalance = true } label: {
                Label("Edit Balance", systemImage: "dollarsign.circle")
            }
            .buttonStyle(.solidCTA)

            Button { showWalletExport = true } label: {
                Label("Add to Apple Wallet", systemImage: "wallet.pass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassPill)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }

    private func loadCard() {
        do { card = try repository.getCard(id: cardID) }
        catch { errorMessage = ErrorMessage(text: error.localizedDescription) }
    }

    private func revealSecrets() {
        Task {
            do {
                try await environment.authenticationService.authenticate(reason: "Reveal this gift card's protected details.")
                guard let card else { return }
                revealedSecrets = try repository.decryptSecrets(for: card)
            } catch { errorMessage = ErrorMessage(text: error.localizedDescription) }
        }
    }

    private func copyCardNumber() {
        Task {
            do {
                try await environment.authenticationService.authenticate(reason: "Copy this gift card number.")
                guard let card else { return }
                UIPasteboard.general.string = try repository.decryptSecrets(for: card).cardNumber
            } catch { errorMessage = ErrorMessage(text: error.localizedDescription) }
        }
    }

    private func copyPIN() {
        Task {
            do {
                try await environment.authenticationService.authenticate(reason: "Copy this gift card PIN.")
                guard let card else { return }
                UIPasteboard.general.string = try repository.decryptSecrets(for: card).pin
            } catch { errorMessage = ErrorMessage(text: error.localizedDescription) }
        }
    }
}

private struct EditBalanceView: View {
    let cardID: UUID
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var environment: AppEnvironment

    @State private var balanceText = ""
    @State private var currency = "USD"
    @State private var errorMessage: ErrorMessage?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dcBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        GlassSection("Manual Balance") {
                            GlassField {
                                TextField("Balance (e.g. 25.00)", text: $balanceText)
                                    .keyboardType(.decimalPad)
                            }
                            GlassField {
                                TextField("Currency", text: $currency)
                                    .textInputAutocapitalization(.characters)
                            }
                            Text("Manual balances are user-entered and not verified with the merchant.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Edit Balance")
            .navigationBarTitleDisplayMode(.inline)
            .dcNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.tint(.dcNeonBlue)
                }
            }
            .alert(item: $errorMessage) { msg in
                Alert(title: Text("Could Not Save"), message: Text(msg.text), dismissButton: .default(Text("OK")))
            }
            .onAppear { load() }
        }
        .preferredColorScheme(.dark)
    }

    private func load() {
        do {
            let repo = SwiftDataCardRepository(context: modelContext, encryptionService: environment.encryptionService)
            let card = try repo.getCard(id: cardID)
            currency = card.currency
            if let balance = card.currentBalanceMinorUnits {
                balanceText = String(format: "%.2f", Double(balance) / 100)
            }
        } catch { errorMessage = ErrorMessage(text: error.localizedDescription) }
    }

    private func save() {
        let trimmed = balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let minorUnits = trimmed.isEmpty ? nil : MoneyFormatter.minorUnits(from: trimmed)
        if !trimmed.isEmpty && minorUnits == nil {
            errorMessage = ErrorMessage(text: "Enter a valid balance amount.")
            return
        }
        do {
            let repo = SwiftDataCardRepository(context: modelContext, encryptionService: environment.encryptionService)
            _ = try repo.updateManualBalance(
                id: cardID,
                minorUnits: minorUnits,
                currency: currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "USD" : currency.uppercased()
            )
            onSave()
            dismiss()
        } catch { errorMessage = ErrorMessage(text: error.localizedDescription) }
    }
}
