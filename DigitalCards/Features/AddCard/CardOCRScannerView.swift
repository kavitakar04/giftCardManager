import SwiftUI
import Vision
import VisionKit

@available(iOS 16.0, *)
struct CardOCRScannerView: UIViewControllerRepresentable {
    let onUpdate: ([String], ScannedBarcode?) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        guard DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
            let controller = UIViewController()
            controller.view.backgroundColor = .systemBackground
            return controller
        }

        let controller = DataScannerViewController(
            recognizedDataTypes: [
                .text(languages: ["en-US"]),
                .barcode(symbologies: [.qr, .pdf417, .aztec, .code128, .ean13, .ean8, .upce])
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator

        do {
            try controller.startScanning()
        } catch {
            onError(error.localizedDescription)
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onUpdate: onUpdate, onError: onError)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onUpdate: ([String], ScannedBarcode?) -> Void
        let onError: (String) -> Void

        init(onUpdate: @escaping ([String], ScannedBarcode?) -> Void, onError: @escaping (String) -> Void) {
            self.onUpdate = onUpdate
            self.onError = onError
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            publish(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            publish(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            publish(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            onError(error.localizedDescription)
        }

        private func publish(_ items: [RecognizedItem]) {
            var textBlocks: [String] = []
            var barcode: ScannedBarcode?

            for item in items {
                switch item {
                case .text(let text):
                    textBlocks.append(text.transcript)
                case .barcode(let code):
                    guard barcode == nil,
                          let value = code.payloadStringValue,
                          let format = BarcodeFormat(symbology: code.observation.symbology) else {
                        continue
                    }
                    barcode = ScannedBarcode(value: value, format: format)
                @unknown default:
                    continue
                }
            }

            onUpdate(textBlocks, barcode)
        }
    }
}

extension BarcodeFormat {
    init?(symbology: VNBarcodeSymbology) {
        switch symbology {
        case .qr:
            self = .qr
        case .pdf417:
            self = .pdf417
        case .aztec:
            self = .aztec
        case .code128:
            self = .code128
        case .ean13:
            self = .ean13
        case .ean8:
            self = .ean8
        case .upce:
            self = .upce
        default:
            return nil
        }
    }
}

struct CardOCRScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var environment: AppEnvironment

    @State private var textBlocks: [String] = []
    @State private var barcode: ScannedBarcode?
    @State private var errorMessage: ErrorMessage?

    let onResult: (CardOCRResult) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    CardOCRScannerView(
                        onUpdate: { textBlocks, barcode in
                            self.textBlocks = textBlocks
                            self.barcode = barcode
                        },
                        onError: { message in
                            errorMessage = ErrorMessage(text: message)
                        }
                    )
                    .ignoresSafeArea()
                } else {
                    ContentUnavailableView(
                        "Card Scanning Unavailable",
                        systemImage: "text.viewfinder",
                        description: Text("Use manual entry or barcode-only scanning on this device.")
                    )
                }

                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scan the front or back of the card")
                            .font(.headline)
                        Text("OCR stays on device. Review all detected details before saving.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack {
                            Label("\(textBlocks.count)", systemImage: "text.viewfinder")
                            if let barcode {
                                Label(barcode.format.displayName, systemImage: "barcode")
                            }
                            Spacer()
                            Button("Use Results") {
                                let result = environment.ocrService.recognize(
                                    textBlocks: textBlocks,
                                    barcode: barcode,
                                    catalog: environment.merchantCatalog
                                )
                                onResult(result)
                                clearSensitiveState()
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(textBlocks.isEmpty && barcode == nil)
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
                    .privacySensitive()
                }
            }
            .navigationTitle("Scan Card Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        clearSensitiveState()
                        dismiss()
                    }
                }
            }
            .alert(item: $errorMessage) { message in
                Alert(title: Text("Scanner Error"), message: Text(message.text), dismissButton: .default(Text("OK")))
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    clearSensitiveState()
                }
            }
        }
    }

    private func clearSensitiveState() {
        textBlocks = []
        barcode = nil
    }
}
