import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let merchantCatalog: MerchantCatalog
    let encryptionService: EncryptionService
    let authenticationService: AuthenticationServicing
    let barcodeService: BarcodeServicing
    let ocrService: CardOCRServicing
    let walletPassService: WalletPassService
    let balanceLookupService: BalanceLookupService
    @Published var startupError: String?

    init(
        merchantCatalog: MerchantCatalog = .phase1,
        encryptionService: EncryptionService,
        authenticationService: AuthenticationServicing = LocalAuthenticationService(),
        barcodeService: BarcodeServicing = CoreImageBarcodeService(),
        ocrService: CardOCRServicing = CardOCRService(),
        walletPassService: WalletPassService,
        balanceLookupService: BalanceLookupService? = nil
    ) {
        self.merchantCatalog = merchantCatalog
        self.encryptionService = encryptionService
        self.authenticationService = authenticationService
        self.barcodeService = barcodeService
        self.ocrService = ocrService
        self.walletPassService = walletPassService
        self.balanceLookupService = balanceLookupService ?? BalanceLookupService(baseURL: walletPassService.baseURL)
    }

    static func live() -> AppEnvironment {
        let signingBaseURLString = Bundle.main.object(forInfoDictionaryKey: "WALLET_SIGNING_BASE_URL") as? String
        let signingBaseURL = URL(string: signingBaseURLString ?? "http://localhost:3000")!

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let testKey = Data(repeating: 9, count: 32)
            return AppEnvironment(
                encryptionService: try! EncryptionService(keyStore: InMemoryKeyStore(key: testKey)),
                authenticationService: AllowingAuthenticationService(),
                walletPassService: WalletPassService(baseURL: signingBaseURL)
            )
        }

        do {
            return AppEnvironment(
                encryptionService: try EncryptionService(keyStore: KeychainKeyStore()),
                walletPassService: WalletPassService(baseURL: signingBaseURL)
            )
        } catch {
            fatalError("Secure key storage failed: \(error.localizedDescription)")
        }
    }
}
