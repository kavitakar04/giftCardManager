import SwiftUI

struct CardOCRConfirmation {
    let merchantID: String
    let displayName: String
    let cardNumber: String
    let pin: String?
    let barcodeValue: String?
    let barcodeFormat: BarcodeFormat?
}

struct OCRConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var environment: AppEnvironment

    let result: CardOCRResult
    let onConfirm: (CardOCRConfirmation) -> Void

    @State private var merchantID: String
    @State private var displayName: String
    @State private var cardNumber: String
    @State private var pin: String
    @State private var useDetectedBarcode: Bool
    @State private var errorMessage: ErrorMessage?

    init(result: CardOCRResult, onConfirm: @escaping (CardOCRConfirmation) -> Void) {
        self.result = result
        self.onConfirm = onConfirm

        let merchant = result.merchantCandidates.first
        _merchantID = State(initialValue: merchant?.merchantID ?? MerchantCatalog.other.id)
        _displayName = State(initialValue: InputSanitizer.displayName(merchant?.displayName ?? MerchantCatalog.other.displayName))
        _cardNumber = State(initialValue: InputSanitizer.cardNumber(result.cardNumberCandidates.first?.value ?? ""))
        _pin = State(initialValue: InputSanitizer.pin(result.pinCandidates.first?.value ?? ""))
        _useDetectedBarcode = State(initialValue: result.barcode?.format.isRenderableInPhase1 == true)
    }

    private var selectedMerchant: Merchant {
        environment.merchantCatalog.merchant(id: merchantID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Merchant") {
                    Picker("Merchant", selection: $merchantID) {
                        ForEach(environment.merchantCatalog.all) { merchant in
                            Text(merchant.displayName).tag(merchant.id)
                        }
                    }
                    TextField("Display name", text: $displayName)
                }

                if !result.merchantCandidates.isEmpty {
                    Section("Merchant Matches") {
                        ForEach(result.merchantCandidates) { candidate in
                            Button {
                                merchantID = candidate.merchantID
                                displayName = InputSanitizer.displayName(candidate.displayName)
                            } label: {
                                HStack {
                                    Text(candidate.displayName)
                                    Spacer()
                                    Text("\(Int(candidate.confidence * 100))%")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Card Number") {
                    TextField("Card number", text: $cardNumber)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                        .privacySensitive()

                    ForEach(result.cardNumberCandidates) { candidate in
                        Button(candidate.value) {
                            cardNumber = InputSanitizer.cardNumber(candidate.value)
                        }
                        .privacySensitive()
                    }
                }

                Section("PIN") {
                    SecureField(selectedMerchant.requiresPin ? "PIN" : "PIN (optional)", text: $pin)
                        .keyboardType(.asciiCapable)
                        .privacySensitive()

                    ForEach(result.pinCandidates) { candidate in
                        Button(candidate.sourceLabel ?? "Detected PIN") {
                            pin = InputSanitizer.pin(candidate.value)
                        }
                        .privacySensitive()
                    }
                }

                if let barcode = result.barcode {
                    Section("Detected Barcode") {
                        Toggle("Use detected barcode", isOn: $useDetectedBarcode)
                        LabeledContent("Format", value: barcode.format.displayName)
                        if !barcode.format.isRenderableInPhase1 {
                            Text("\(barcode.format.displayName) can be scanned but cannot be displayed in Phase 1. A renderable fallback will be required.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                    .privacySensitive()
                }
            }
            .navigationTitle("Review Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        clearSensitiveState()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        apply()
                    }
                }
            }
            .onChange(of: merchantID) { _, newValue in
                let merchant = environment.merchantCatalog.merchant(id: newValue)
                displayName = InputSanitizer.displayName(merchant.displayName)
            }
            .onChange(of: displayName) { _, newValue in sanitizeDisplayName(newValue) }
            .onChange(of: cardNumber) { _, newValue in sanitizeCardNumber(newValue) }
            .onChange(of: pin) { _, newValue in sanitizePIN(newValue) }
            .alert(item: $errorMessage) { message in
                Alert(title: Text("Review Needed"), message: Text(message.text), dismissButton: .default(Text("OK")))
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    clearSensitiveState()
                    dismiss()
                }
            }
        }
    }

    private func apply() {
        let trimmedCard = InputSanitizer.cardNumber(cardNumber).trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPIN = InputSanitizer.pin(pin).trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedDisplayName = InputSanitizer.displayName(displayName)
        guard !trimmedCard.isEmpty else {
            errorMessage = ErrorMessage(text: "Confirm or enter the card number before applying OCR results.")
            return
        }

        onConfirm(
            CardOCRConfirmation(
                merchantID: merchantID,
                displayName: sanitizedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? selectedMerchant.displayName : sanitizedDisplayName,
                cardNumber: trimmedCard,
                pin: trimmedPIN.isEmpty ? nil : trimmedPIN,
                barcodeValue: useDetectedBarcode ? result.barcode.map { InputSanitizer.barcodeValue($0.value) } : nil,
                barcodeFormat: useDetectedBarcode ? result.barcode?.format : nil
            )
        )
        clearSensitiveState()
        dismiss()
    }

    private func sanitizeDisplayName(_ value: String) {
        let sanitized = InputSanitizer.displayName(value)
        if sanitized != value { displayName = sanitized }
    }

    private func sanitizeCardNumber(_ value: String) {
        let sanitized = InputSanitizer.cardNumber(value)
        if sanitized != value { cardNumber = sanitized }
    }

    private func sanitizePIN(_ value: String) {
        let sanitized = InputSanitizer.pin(value)
        if sanitized != value { pin = sanitized }
    }

    private func clearSensitiveState() {
        cardNumber = ""
        pin = ""
    }
}
