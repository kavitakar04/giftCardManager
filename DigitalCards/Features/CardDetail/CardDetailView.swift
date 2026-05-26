import SwiftData
import SwiftUI
import UIKit

struct CardDetailView: View {
    let cardID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var environment: AppEnvironment

    @State private var card: StoredCard?
    @State private var balanceHistory: [BalanceAdjustment] = []
    @State private var revealedSecrets: CardSecrets?
    @State private var showEditBalance = false
    @State private var showWalletExport = false
    @State private var showDeleteConfirmation = false
    @State private var shareSheet: GiftCardShareSheet?
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
                        BalanceHistorySection(title: "Balance History", entries: balanceHistory)
                        managementSection(card: card)
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
                .sheet(item: $shareSheet) { sheet in
                    GiftCardActivityView(activityItems: sheet.items)
                }
                .confirmationDialog(
                    deleteTitle(for: card),
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(deleteTitle(for: card), role: .destructive, action: deleteCard)
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(deleteMessage(for: card))
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

                Button { shareCard() } label: {
                    Label("Share Card", systemImage: "square.and.arrow.up")
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

    private func managementSection(card: StoredCard) -> some View {
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

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(deleteTitle(for: card), systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.destructiveGlass)
        }
        .padding(.horizontal)
    }

    private func deleteTitle(for card: StoredCard) -> String {
        card.currentBalanceMinorUnits == 0 ? "Delete Empty Card" : "Delete Card"
    }

    private func deleteMessage(for card: StoredCard) -> String {
        if card.currentBalanceMinorUnits == 0 {
            return "This card has a zero balance and will be removed from your active cards."
        }
        return "This card will be removed from your active cards."
    }

    private func loadCard() {
        do {
            try repository.backfillMissingBalanceHistory()
            card = try repository.getCard(id: cardID)
            balanceHistory = try repository.listBalanceHistory(cardID: cardID)
        }
        catch { errorMessage = ErrorMessage(text: error.localizedDescription) }
    }

    private func deleteCard() {
        do {
            try repository.archiveCard(id: cardID)
            dismiss()
        } catch {
            errorMessage = ErrorMessage(text: error.localizedDescription)
        }
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

    private func shareCard() {
        Task {
            do {
                try await environment.authenticationService.authenticate(reason: "Share this gift card's card number, PIN, and barcode.")
                guard let card else { return }

                let merchant = environment.merchantCatalog.merchant(id: card.merchantID)
                let secrets = try repository.decryptSecrets(for: card)
                var items: [Any] = [
                    GiftCardShareFormatter.message(card: card, merchant: merchant, secrets: secrets)
                ]

                if let barcodeImage = try? environment.barcodeService.render(
                    value: secrets.barcodeValue,
                    format: card.barcodeFormat
                ) {
                    items.append(barcodeImage)
                }

                shareSheet = GiftCardShareSheet(items: items)
            } catch {
                errorMessage = ErrorMessage(text: error.localizedDescription)
            }
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

struct GiftCardShareFormatter {
    static func message(card: StoredCard, merchant: Merchant, secrets: CardSecrets) -> String {
        var lines = [
            card.displayName,
            "Merchant: \(merchant.displayName)",
            "Balance: \(MoneyFormatter.string(minorUnits: card.currentBalanceMinorUnits, currency: card.currency))",
            "Card number: \(secrets.cardNumber)"
        ]

        if let pin = normalizedPIN(secrets.pin) {
            lines.append("PIN: \(pin)")
        }

        lines.append("Barcode value: \(secrets.barcodeValue)")
        lines.append("Barcode format: \(card.barcodeFormat.displayName)")

        let notes = merchant.redemptionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            lines.append("Redemption: \(notes)")
        }

        lines.append("Treat these details like cash.")
        return lines.joined(separator: "\n")
    }

    private static func normalizedPIN(_ pin: String?) -> String? {
        guard let trimmed = pin?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

private struct GiftCardShareSheet: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct GiftCardActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = controller.view
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
            .onChange(of: balanceText) { _, newValue in sanitizeBalance(newValue) }
            .onChange(of: currency) { _, newValue in sanitizeCurrency(newValue) }
        }
        .preferredColorScheme(.dark)
    }

    private func load() {
        do {
            let repo = SwiftDataCardRepository(context: modelContext, encryptionService: environment.encryptionService)
            let card = try repo.getCard(id: cardID)
            currency = InputSanitizer.currency(card.currency)
            if let balance = card.currentBalanceMinorUnits {
                balanceText = String(format: "%.2f", Double(balance) / 100)
            }
        } catch { errorMessage = ErrorMessage(text: error.localizedDescription) }
    }

    private func save() {
        let trimmed = InputSanitizer.balance(balanceText).trimmingCharacters(in: .whitespacesAndNewlines)
        let minorUnits = trimmed.isEmpty ? nil : MoneyFormatter.minorUnits(from: trimmed)
        if !trimmed.isEmpty && minorUnits == nil {
            errorMessage = ErrorMessage(text: "Enter a valid balance amount.")
            return
        }
        let normalizedCurrency = InputSanitizer.currency(currency)
        do {
            let repo = SwiftDataCardRepository(context: modelContext, encryptionService: environment.encryptionService)
            _ = try repo.updateManualBalance(
                id: cardID,
                minorUnits: minorUnits,
                currency: normalizedCurrency.isEmpty ? "USD" : normalizedCurrency
            )
            onSave()
            dismiss()
        } catch { errorMessage = ErrorMessage(text: error.localizedDescription) }
    }

    private func sanitizeBalance(_ value: String) {
        let sanitized = InputSanitizer.balance(value)
        if sanitized != value { balanceText = sanitized }
    }

    private func sanitizeCurrency(_ value: String) {
        let sanitized = InputSanitizer.currency(value)
        if sanitized != value { currency = sanitized }
    }
}
