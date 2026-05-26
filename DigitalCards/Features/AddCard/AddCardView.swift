import AVFoundation
import SwiftData
import SwiftUI

struct AddCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var environment: AppEnvironment

    @State private var selectedMerchantID: String
    @State private var displayName: String
    @State private var cardNumber = ""
    @State private var pin = ""
    @State private var barcodeValue = ""
    @State private var barcodeFormat: BarcodeFormat = .code128
    @State private var startingBalance = ""
    @State private var currency = "USD"
    @State private var showOCRScanner = false
    @State private var showScanner = false
    @State private var pendingOCRResult: CardOCRResult?
    @State private var scanWarning: String?
    @State private var errorMessage: ErrorMessage?

    private var selectedMerchant: Merchant {
        environment.merchantCatalog.merchant(id: selectedMerchantID)
    }

    init(initialMerchantID: String? = nil) {
        let fallbackMerchant = MerchantCatalog.phase1.all.first ?? MerchantCatalog.other
        let merchant = initialMerchantID.map { MerchantCatalog.phase1.merchant(id: $0) } ?? fallbackMerchant
        _selectedMerchantID = State(initialValue: merchant.id)
        _displayName = State(initialValue: merchant.displayName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dcBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        GlassSection("Merchant") {
                            GlassMenuField(
                                displayText: selectedMerchant.displayName,
                                menu: {
                                    Picker("Merchant", selection: $selectedMerchantID) {
                                        ForEach(environment.merchantCatalog.all) { m in
                                            Text(m.displayName).tag(m.id)
                                        }
                                    }
                                }
                            )
                            GlassField { TextField("Display name", text: $displayName) }
                        }

                        GlassSection("Card") {
                            Button {
                                showOCRScanner = true
                            } label: {
                                Label("Scan Card with Camera", systemImage: "text.viewfinder")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassPill)

                            GlassField {
                                TextField("Card number", text: $cardNumber)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.asciiCapable)
                                    .privacySensitive()
                            }

                            GlassField {
                                if selectedMerchant.requiresPin {
                                    SecureField("PIN", text: $pin)
                                        .keyboardType(.asciiCapable)
                                        .privacySensitive()
                                } else {
                                    TextField("PIN (optional)", text: $pin)
                                        .keyboardType(.asciiCapable)
                                        .privacySensitive()
                                }
                            }
                        }

                        GlassSection("Barcode") {
                            GlassField {
                                TextField("Barcode value", text: $barcodeValue)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.asciiCapable)
                                    .privacySensitive()
                            }

                            GlassMenuField(
                                displayText: barcodeFormat.displayName,
                                menu: {
                                    Picker("Format", selection: $barcodeFormat) {
                                        ForEach(
                                            selectedMerchant.supportedBarcodeFormats.filter(\.isRenderableInPhase1)
                                        ) { format in
                                            Text(format.displayName).tag(format)
                                        }
                                    }
                                }
                            )

                            Button {
                                showScanner = true
                            } label: {
                                Label("Scan Barcode", systemImage: "barcode.viewfinder")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassPill)

                            if let warning = scanWarning {
                                Label(warning, systemImage: "exclamationmark.triangle")
                                    .font(.footnote)
                                    .foregroundStyle(.yellow)
                            }
                        }

                        GlassSection("Balance") {
                            GlassField {
                                TextField("Starting balance (e.g. 25.00)", text: $startingBalance)
                                    .keyboardType(.decimalPad)
                            }
                            GlassField {
                                TextField("Currency (e.g. USD)", text: $currency)
                                    .textInputAutocapitalization(.characters)
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .dcNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCard() }.tint(.dcNeonBlue)
                }
            }
            .onChange(of: selectedMerchantID) { _, _ in applySelectedMerchantDefaults() }
            .onChange(of: displayName) { _, newValue in sanitizeDisplayName(newValue) }
            .onChange(of: cardNumber) { _, newValue in sanitizeCardNumber(newValue) }
            .onChange(of: pin) { _, newValue in sanitizePIN(newValue) }
            .onChange(of: barcodeValue) { _, newValue in sanitizeBarcodeValue(newValue) }
            .onChange(of: startingBalance) { _, newValue in sanitizeStartingBalance(newValue) }
            .onChange(of: currency) { _, newValue in sanitizeCurrency(newValue) }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active { pendingOCRResult = nil }
            }
            .sheet(isPresented: $showOCRScanner) {
                CardOCRScannerSheet { result in pendingOCRResult = result }
                    .environmentObject(environment)
            }
            .sheet(item: $pendingOCRResult) { result in
                OCRConfirmationView(result: result) { confirmation in
                    applyOCRConfirmation(confirmation)
                }
                .environmentObject(environment)
            }
            .sheet(isPresented: $showScanner) {
                ScannerPermissionView { scanned in
                    barcodeValue = InputSanitizer.barcodeValue(scanned.value)
                    if scanned.format.isRenderableInPhase1,
                       selectedMerchant.supportedBarcodeFormats.contains(scanned.format) {
                        barcodeFormat = scanned.format
                        scanWarning = nil
                    } else {
                        barcodeFormat = selectedMerchant.supportedBarcodeFormats.first(where: \.isRenderableInPhase1) ?? .code128
                        scanWarning = "\(scanned.format.displayName) was scanned but cannot be rendered. A compatible format was selected."
                    }
                    if cardNumber.isEmpty { cardNumber = InputSanitizer.cardNumber(scanned.value) }
                    showScanner = false
                }
            }
            .alert(item: $errorMessage) { msg in
                Alert(title: Text("Could Not Save"), message: Text(msg.text), dismissButton: .default(Text("OK")))
            }
            .onAppear { applySelectedMerchantDefaults() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers

    private func applySelectedMerchantDefaults() {
        let merchant = selectedMerchant
        if displayName.isEmpty || environment.merchantCatalog.all.contains(where: { $0.displayName == displayName }) {
            displayName = InputSanitizer.displayName(merchant.displayName)
        }
        currency = InputSanitizer.currency(merchant.defaultCurrency)
        if !merchant.supportedBarcodeFormats.contains(barcodeFormat) || !barcodeFormat.isRenderableInPhase1 {
            barcodeFormat = merchant.supportedBarcodeFormats.first(where: \.isRenderableInPhase1) ?? .code128
        }
    }

    private func applyOCRConfirmation(_ confirmation: CardOCRConfirmation) {
        selectedMerchantID = confirmation.merchantID
        displayName = InputSanitizer.displayName(confirmation.displayName)
        cardNumber = InputSanitizer.cardNumber(confirmation.cardNumber)
        pin = InputSanitizer.pin(confirmation.pin ?? "")
        if let barcodeValue = confirmation.barcodeValue, let detectedFormat = confirmation.barcodeFormat {
            self.barcodeValue = InputSanitizer.barcodeValue(barcodeValue)
            if detectedFormat.isRenderableInPhase1,
               environment.merchantCatalog.merchant(id: confirmation.merchantID).supportedBarcodeFormats.contains(detectedFormat) {
                barcodeFormat = detectedFormat
                scanWarning = nil
            } else {
                barcodeFormat = environment.merchantCatalog
                    .merchant(id: confirmation.merchantID)
                    .supportedBarcodeFormats.first(where: \.isRenderableInPhase1) ?? .code128
                scanWarning = "\(detectedFormat.displayName) detected but not renderable. A compatible format was selected."
            }
        } else if barcodeValue.isEmpty {
            barcodeValue = InputSanitizer.barcodeValue(confirmation.cardNumber)
        }
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

    private func sanitizeBarcodeValue(_ value: String) {
        let sanitized = InputSanitizer.barcodeValue(value)
        if sanitized != value { barcodeValue = sanitized }
    }

    private func sanitizeStartingBalance(_ value: String) {
        let sanitized = InputSanitizer.balance(value)
        if sanitized != value { startingBalance = sanitized }
    }

    private func sanitizeCurrency(_ value: String) {
        let sanitized = InputSanitizer.currency(value)
        if sanitized != value { currency = sanitized }
    }

    private func saveCard() {
        let trimmedCardNumber = InputSanitizer.cardNumber(cardNumber).trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBarcode = InputSanitizer
            .barcodeValue(barcodeValue.isEmpty ? cardNumber : barcodeValue)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPIN = InputSanitizer.pin(pin).trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCurrency = InputSanitizer.currency(currency)

        guard !trimmedCardNumber.isEmpty else { errorMessage = ErrorMessage(text: "Card number is required."); return }
        guard !trimmedBarcode.isEmpty else { errorMessage = ErrorMessage(text: "Barcode value is required."); return }
        guard barcodeFormat.isRenderableInPhase1 else {
            errorMessage = ErrorMessage(text: "Choose QR, PDF417, Aztec, or Code 128.")
            return
        }

        let trimmedBalance = InputSanitizer.balance(startingBalance).trimmingCharacters(in: .whitespacesAndNewlines)
        let balance = trimmedBalance.isEmpty ? nil : MoneyFormatter.minorUnits(from: trimmedBalance)
        if !trimmedBalance.isEmpty && balance == nil {
            errorMessage = ErrorMessage(text: "Enter a valid balance amount.")
            return
        }
        let sanitizedDisplayName = InputSanitizer.displayName(displayName)

        do {
            let repo = SwiftDataCardRepository(context: modelContext, encryptionService: environment.encryptionService)
            _ = try repo.createCard(
                CardCreateInput(
                    merchantID: selectedMerchant.id,
                    displayName: sanitizedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? selectedMerchant.displayName : sanitizedDisplayName,
                    cardNumber: trimmedCardNumber,
                    pin: trimmedPIN.isEmpty ? nil : trimmedPIN,
                    barcodeValue: trimmedBarcode,
                    barcodeFormat: barcodeFormat,
                    startingBalanceMinorUnits: balance,
                    currency: normalizedCurrency.isEmpty ? selectedMerchant.defaultCurrency : normalizedCurrency
                ),
                merchant: selectedMerchant
            )
            dismiss()
        } catch { errorMessage = ErrorMessage(text: error.localizedDescription) }
    }
}

// MARK: - Glass Menu Field

private struct GlassMenuField<MenuContent: View>: View {
    let displayText: String
    @ViewBuilder let menu: MenuContent

    var body: some View {
        Menu {
            menu
        } label: {
            HStack {
                Text(displayText)
                    .font(.body)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
}

// MARK: - Scanner Permission

private struct ScannerPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    let onScan: (ScannedBarcode) -> Void

    var body: some View {
        ZStack {
            Color.dcBackground.ignoresSafeArea()
            switch authorizationStatus {
            case .authorized:
                BarcodeScannerView(onScan: onScan).ignoresSafeArea()
            case .denied, .restricted:
                ContentUnavailableView(
                    "Camera Access Needed",
                    systemImage: "camera",
                    description: Text("Enable camera access in Settings to scan gift card barcodes.")
                )
            case .notDetermined:
                ProgressView()
                    .task {
                        let granted = await AVCaptureDevice.requestAccess(for: .video)
                        authorizationStatus = granted ? .authorized : .denied
                    }
            @unknown default:
                ContentUnavailableView("Camera Unavailable", systemImage: "camera")
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .dcNavBar()
    }
}
