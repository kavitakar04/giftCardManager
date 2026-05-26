import SwiftData
import SwiftUI
import UIKit

struct BarcodeCheckoutView: View {
    let cardID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var environment: AppEnvironment

    @State private var card: StoredCard?
    @State private var merchant: Merchant?
    @State private var barcodeImage: UIImage?
    @State private var originalBrightness = UIScreen.main.brightness
    @State private var errorMessage: ErrorMessage?

    private var repository: SwiftDataCardRepository {
        SwiftDataCardRepository(context: modelContext, encryptionService: environment.encryptionService)
    }

    private var brandColor: Color {
        Color(hex: merchant?.brandColorHex ?? "#0F0F1A")
    }

    var body: some View {
        ZStack {
            // Brand gradient fades into dark
            LinearGradient(
                colors: [brandColor.opacity(0.85), Color.dcBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Card identity
                if let card {
                    VStack(spacing: 4) {
                        Text(card.displayName)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("•••• \(card.cardNumberLast4)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                }

                Spacer()

                // Floating barcode card
                if let barcodeImage {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
                        .overlay(
                            Image(uiImage: barcodeImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .padding(24)
                        )
                        .padding(.horizontal, 24)
                        .frame(maxHeight: 320)
                } else {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.3)
                }

                Spacer()

                // Actions
                HStack(spacing: 12) {
                    Button {
                        UIScreen.main.brightness = 1.0
                    } label: {
                        Label("Brightness", systemImage: "sun.max")
                    }
                    .buttonStyle(.glassPill)

                    Button {
                        copyCardNumber()
                    } label: {
                        Label("Copy Number", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.glassPill)
                }
                .padding(.bottom, 36)
            }
        }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .dcNavBar()
        .onAppear {
            originalBrightness = UIScreen.main.brightness
            UIApplication.shared.isIdleTimerDisabled = true
            loadBarcode()
        }
        .onDisappear {
            UIScreen.main.brightness = originalBrightness
            UIApplication.shared.isIdleTimerDisabled = false
            barcodeImage = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { barcodeImage = nil } else { loadBarcode() }
        }
        .alert(item: $errorMessage) { msg in
            Alert(title: Text("Error"), message: Text(msg.text), dismissButton: .default(Text("OK")))
        }
    }

    private func loadBarcode() {
        do {
            let loaded = try repository.getCard(id: cardID)
            let secrets = try repository.decryptSecrets(for: loaded)
            card = loaded
            merchant = environment.merchantCatalog.merchant(id: loaded.merchantID)
            barcodeImage = try environment.barcodeService.render(value: secrets.barcodeValue, format: loaded.barcodeFormat)
        } catch { errorMessage = ErrorMessage(text: error.localizedDescription) }
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
}
