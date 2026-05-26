# Digital Cards

Digital Cards is a digital gift-card wallet. It lets users scan a physical gift card, save its barcode or card number, add it to Apple Wallet as a pass, and track the remaining balance.

This is not "Apple Pay for gift cards." Apple Pay is mainly for payment cards and merchant payment flows. For gift cards, the Apple-native surface is usually Apple Wallet with PassKit, specifically a `storeCard` pass. Apple's Wallet documentation describes the `storeCard` pass style as suitable for loyalty cards, discount cards, points cards, and gift cards. If an account carries a balance, the current balance should be shown on the pass.

References:

- [Apple Wallet Developer Guide: Pass Design and Creation](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/PassKit_PG/Creating.html)
- [Subway Stored Value Balance Inquiry](https://wbiprod.storedvalue.com/wbir/clients/subway.us)

## Current Implementation

Phase 1 has been scaffolded as:

- A native SwiftUI iOS app in `DigitalCards.xcodeproj`
- Local SwiftData persistence for saved cards
- CryptoKit and Keychain-backed field encryption
- AVFoundation barcode scanning
- VisionKit on-device OCR for card number, PIN, merchant, and barcode capture
- Core Image barcode rendering for QR, PDF417, Aztec, and Code 128
- Manual balance tracking
- LocalAuthentication gates for sensitive reveal actions
- Apple Wallet export client code
- A minimal Node signing API in `services/wallet-signer`

Build and test the iOS app:

```sh
xcodebuild -project DigitalCards.xcodeproj \
  -scheme DigitalCards \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' \
  -derivedDataPath ./DerivedData \
  test
```

Do not disable simulator code signing for the test command. The app uses Keychain-backed encryption, and an unsigned simulator app can return Keychain entitlement errors such as `-34018`.

Run the Wallet signing service tests:

```sh
cd services/wallet-signer
npm test
```

Start the Wallet signing service after installing dependencies and configuring certificates:

```sh
cd services/wallet-signer
npm install
cp .env.example .env
npm start
```

## Product Concept

A user opens the app, scans the card's printed details with OCR, scans its barcode, or manually enters the card number and PIN. The app then creates a digital version of the card. The digital card can be stored inside the app and optionally added to Apple Wallet. The user can see the brand, card number, barcode, current balance, last refresh time, and redemption instructions.

For example, a Subway card would be entered using the card number and PIN or security code. The app would then check the card's balance through Subway's stored-value balance inquiry page. That page appears to be a balance inquiry page for Subway stored-value cards, meaning it is likely intended to let someone submit card credentials and retrieve the remaining value.

## Core User Flow

The basic flow is:

1. A user receives or already owns a physical gift card.
2. They open the app and tap **Add Card**.
3. The app asks them to scan the barcode, scan the card number using OCR, or type the number manually.
4. If the card requires a PIN, the app asks for that too.
5. The app identifies the merchant automatically from the card format or barcode, or manually from a merchant picker.
6. The app stores the card securely, generates a barcode image, and creates a wallet-compatible pass.
7. The user can use the pass in store by showing the barcode, or copy the card number for online checkout.

Balance tracking is separate. For merchants with a public balance-check flow, the app can query the balance after the user adds credentials. For merchants without an accessible balance lookup, the app lets the user manually update the balance.

## Main Specs

### 1. Card Ingestion

The app needs a way to capture physical card data.

Inputs:

- **Barcode scan:** Scan QR, Code 128, PDF417, UPC-style, or other barcode formats depending on the merchant.
- **OCR scan:** Use the camera to read the printed card number and PIN.
- **Manual entry:** Provide a fallback for cards that do not scan cleanly.
- **Photo capture:** Optionally save front and back images of the card for reference.
- **Merchant selection:** Let the user choose Subway, Starbucks, Target, or another merchant, or let the app guess based on barcode or card-number pattern.

The barcode alone may not be enough. Many gift cards have both a card number and a PIN or security code, and balance checks often require both.

### 2. Digital Card Record

Internally, each card should have a structured record:

```text
Card
- id
- user_id
- merchant_id
- display_name
- card_number_encrypted
- pin_encrypted
- barcode_value_encrypted
- barcode_format
- current_balance
- currency
- last_balance_check_at
- last_balance_check_status
- wallet_pass_serial_number
- created_at
- archived_at
```

Sensitive fields should be encrypted. Gift card numbers and PINs are effectively cash-equivalent credentials, so they should be treated like payment secrets.

### 3. Apple Wallet Pass Generation

For iOS, the app should generate an Apple Wallet pass using PassKit. The pass would likely be a `storeCard` pass, not an Apple Pay card.

Apple Wallet passes are defined by a `pass.json` file plus images and metadata. Each pass needs a `passTypeIdentifier`, `serialNumber`, `teamIdentifier`, `organizationName`, and `description`. Apple identifies passes by the combination of pass type identifier and serial number, and updates replace the old pass when those identifiers match.

For a gift card pass, the front of the card might show:

```text
Subway Gift Card
Balance: $18.42
Card ending: 1234
Last updated: May 26
```

The back of the pass could show:

```text
Full card number
PIN, hidden or omitted for safety
Terms
Support link
Manual balance refresh link
```

The pass should include a barcode because Apple's Wallet documentation describes barcodes as the standard way to link a pass to the underlying record or allow scanning at the point of sale. Apple supports barcode formats including QR, PDF417, Aztec, and Code 128 on iOS, though watchOS does not support Code 128 as the only barcode fallback.

### 4. Barcode Display And Redemption

The key redemption feature is simple: the app must reproduce the same scannable value that appears on the physical gift card.

There are two cases:

- **In-store redemption:** The cashier scans the barcode from the phone. This depends on the merchant's scanner. Apple notes that many laser scanners cannot reliably read barcodes from LCD screens, so optical scanners are preferred.
- **Online redemption:** The user copies the card number and PIN from the app, or taps a merchant checkout link.

The app should not assume every physical gift card can be converted into a universally accepted tap-to-pay card. Most of the value is in storing the card cleanly, making it scannable, and keeping the balance visible.

### 5. Balance Tracking

Balance tracking is the hardest and most merchant-specific part.

For Subway, the linked page is a balance inquiry page, so the app could potentially support Subway by submitting the card number and PIN and parsing the returned balance. That is not the same thing as having an official API. The product would need to verify whether Subway or the stored-value provider permits automated access. Scraping balance pages can break, trigger bot protection, or violate terms.

A good architecture would use a merchant adapter layer:

```text
BalanceProvider
- merchant_id
- required_fields: card_number, pin
- check_balance(card_number, pin) -> balance, currency, status
- supports_auto_refresh: true/false
- refresh_limit
```

For Subway:

```text
SubwayBalanceProvider
- Input: card number + PIN/security code
- Method: balance inquiry flow
- Output: current balance, possibly card status
```

For unsupported merchants:

```text
ManualBalanceProvider
- User enters starting balance
- User manually adjusts balance after purchases
```

The product should distinguish between:

- **Verified balance:** Pulled from the merchant or stored-value provider.
- **User-entered balance:** Manually entered by the user.
- **Stale balance:** Last checked too long ago or failed to refresh.

### 6. Pass Updates

When the app gets a new balance, it should update the Wallet pass. Apple's model is that the pass is a copy of server-side data, and the server keeps the true up-to-date record. The barcode or serial number links the pass back to the server's records, and updates can replace the old pass content.

After a balance refresh:

```text
Old pass: Subway Gift Card - $25.00
User spends $6.58
Balance refresh finds: $18.42
Server updates pass record
Apple Wallet pass now shows: $18.42
```

The app can also add push or update notifications, such as "Subway balance updated to $18.42."

## Technical Model

The app has three layers.

### Capture

The user gives the app the gift-card credentials by scanning the barcode, scanning the printed card number, or typing it manually.

### Normalization

The app converts the messy real-world card into a structured internal object: merchant, card number, PIN, barcode format, balance, and display metadata.

### Representation

The app creates a mobile version of the card. Inside the app, it is a card object with a barcode. In Apple Wallet, it becomes a signed PassKit `.pkpass` file with card fields, branding, and barcode data.

Balance tracking runs as a separate process. The app periodically or manually calls a merchant-specific balance lookup method. For Subway, that likely means using the stored-value balance inquiry flow. The returned value updates the database and then updates the Apple Wallet pass.

## Phase 1 Implementation Spec

Phase 1 is an iOS-first, local MVP that proves the core card wallet experience: add a gift card, store it securely, show a scannable barcode, manually track the balance, and export a static Apple Wallet `storeCard` pass.

Automated merchant balance checks are not part of Phase 1. The Phase 1 code should still include a clean provider interface so Subway or other merchant-specific balance integrations can be added later without rewriting the card model.

### Phase 1 Goals

- Add gift cards through barcode scan or manual entry.
- Save card number, PIN, barcode payload, barcode format, merchant, and balance.
- Encrypt cash-equivalent card credentials at rest.
- Show a card library with balance and last updated state.
- Show a full-screen barcode view for checkout.
- Let users reveal sensitive fields after device authentication, then long-press a revealed value to copy it.
- Let users manually update balances.
- Generate an Apple Wallet `storeCard` pass for a saved card.

### Phase 1 Non-Goals

- No automated Subway balance scraping.
- No recurring background balance refresh.
- No multi-user accounts.
- No cloud sync.
- No Android implementation.
- No tap-to-pay or Apple Pay payment-card provisioning.
- No official merchant API integrations.
- No pass push-update server.

## Recommended Phase 1 Stack

This project should start as a native iOS app because camera scanning, local credential protection, Face ID, and Apple Wallet export are core product surfaces.

- **App:** SwiftUI
- **Camera barcode scanning:** AVFoundation `AVCaptureMetadataOutput`
- **OCR card scanning:** VisionKit `DataScannerViewController` for on-device text and barcode recognition, followed by user confirmation
- **Local persistence:** SwiftData or SQLite through a repository abstraction
- **Sensitive-field encryption:** CryptoKit `AES.GCM`
- **Encryption key storage:** iOS Keychain
- **Biometric/passcode gate:** LocalAuthentication
- **Barcode rendering:** Core Image where supported, with a renderer abstraction per barcode type
- **Wallet export:** PassKit in app, backed by a minimal pass-signing service or local development signer

The app should keep business logic out of SwiftUI views. Views should call view models, view models should call services, and services should call repositories.

```text
DigitalCards
- App
  - DigitalCardsApp
  - AppRouter
- Features
  - CardLibrary
  - AddCard
  - CardDetail
  - BarcodeCheckout
  - WalletExport
- Core
  - Models
  - Persistence
  - Security
  - Barcode
  - OCR
  - Merchants
  - Balance
  - Wallet
```

## What Needs To Be Implemented In Phase 1

### 1. App Shell And Navigation

Implement the base iOS application structure.

Required screens:

- **Card Library:** List saved cards grouped or sorted by merchant.
- **Add Card:** Merchant picker, barcode scanner entry point, and manual entry form.
- **Card Detail:** Brand, masked card number, balance, last updated time, barcode preview, and actions.
- **Barcode Checkout:** Full-screen high-contrast barcode display with brightness guidance.
- **Edit Balance:** Manual balance update form.
- **Wallet Export:** Preview pass fields and launch Apple Wallet add flow.
- **Security Prompt:** LocalAuthentication gate before revealing card number or PIN.

Required navigation:

- Card Library -> Add Card
- Card Library -> Card Detail
- Card Detail -> Barcode Checkout
- Card Detail -> Edit Balance
- Card Detail -> Wallet Export
- Card Detail -> Reveal sensitive data after authentication -> Long-press a revealed value to copy

### 2. Merchant Catalog

Implement a local merchant catalog first. Do not depend on a backend catalog in Phase 1.

Required fields:

```text
Merchant
- id
- display_name
- aliases
- brand_color_hex
- supported_barcode_formats
- requires_pin
- default_currency
- balance_mode: manual
- redemption_notes
- support_url
```

Starter merchants:

- Subway
- Starbucks
- Target
- Amazon
- Other

Use merchant names and colors only in Phase 1. Do not ship merchant logos unless licensing is handled.

The `Other` merchant must support arbitrary card numbers, optional PINs, manual balances, and user-selected barcode format.

### 3. Card Ingestion

Implement three reliable ingestion paths in Phase 1.

**Secure OCR scan**

- Use VisionKit `DataScannerViewController` to recognize printed text and supported barcodes on device.
- Recognize merchant text, card number candidates, PIN/security-code candidates, and a barcode payload in a single camera flow.
- Keep raw OCR text and candidate values in transient SwiftUI state only.
- Do not persist card photos, raw camera frames, or raw OCR transcripts in Phase 1.
- Do not send OCR text to a backend, analytics service, logging pipeline, or the Wallet signing service.
- Normalize OCR output locally into candidates with confidence scores.
- Identify merchants from a local alias list in the merchant catalog.
- Always show a confirmation screen before applying OCR results to the Add Card form.
- Mark OCR candidate values and card-entry fields as privacy-sensitive.
- Clear transient OCR text and barcode values when the scanner is dismissed, results are applied, or the app backgrounds.
- Treat confirmed OCR output the same as manually entered secrets: encrypt card number, PIN, and barcode payload before persistence.

**Barcode scan**

- Request camera permission with a clear `NSCameraUsageDescription`.
- Use `AVCaptureSession` with `AVCaptureMetadataOutput`.
- Support scan detection for QR, PDF417, Aztec, Code 128, EAN-13, EAN-8, and UPC-E where iOS exposes them.
- Store the scanned barcode payload and detected format.
- Let the user edit or discard the scanned value before saving.

**Manual entry**

- Merchant selection is required.
- Card number is required.
- PIN is optional unless the selected merchant requires it.
- Barcode value defaults to the card number but can be overridden.
- Barcode format defaults to Code 128 for generic gift cards, but the user can choose another supported format.
- Starting balance is optional and should be marked as user-entered.

Manual entry remains the fallback when OCR is unavailable, the device does not support live text scanning, camera permission is denied, or confidence is too low.

### 4. Digital Card Model

Implement a local card record with encrypted sensitive fields.

```text
Card
- id: UUID
- merchant_id: String
- display_name: String
- card_number_ciphertext: Data
- pin_ciphertext: Data?
- barcode_value_ciphertext: Data
- barcode_format: BarcodeFormat
- current_balance_minor_units: Int?
- currency: String
- balance_source: manual | unknown
- balance_status: user_entered | missing | stale
- last_balance_update_at: Date?
- card_number_last4: String
- wallet_pass_serial_number: String?
- created_at: Date
- updated_at: Date
- archived_at: Date?
```

Store money as minor units, such as cents, instead of floating-point decimals. Display formatting should use the card currency and the user's locale.

The app should never use the decrypted card number as a row identifier. Use a generated UUID for local identity and a separate stable serial number for Wallet passes.

### 5. Persistence

Implement a repository layer so the storage engine can change later.

```text
CardRepository
- listActiveCards() -> [CardSummary]
- getCard(id) -> Card
- createCard(input) -> Card
- updateCard(id, patch) -> Card
- archiveCard(id)
- updateManualBalance(id, amount, currency) -> Card
```

`CardSummary` should contain only display-safe values:

```text
CardSummary
- id
- merchant_id
- display_name
- card_number_last4
- current_balance_minor_units
- currency
- balance_status
- last_balance_update_at
```

This prevents list screens from needing decrypted secrets.

### 6. Security

Implement field-level encryption before any card is persisted.

Required behavior:

- Generate one app encryption key on first launch.
- Store the key in Keychain with device-only accessibility.
- Encrypt `card_number`, `pin`, and `barcode_value` with CryptoKit `AES.GCM`.
- Store the nonce, ciphertext, and tag together.
- Keep OCR text and OCR-derived candidates on device only.
- Never store raw OCR transcripts or card photos in Phase 1.
- Clear transient OCR buffers when scanning ends, the user cancels, or the app backgrounds.
- Never write decrypted values to logs.
- Never write OCR candidate values to logs.
- Mask card numbers by default.
- Require LocalAuthentication before revealing card numbers and PINs.
- Clear decrypted values from view state when the app backgrounds.

Recommended Keychain accessibility:

```text
kSecAttrAccessibleWhenUnlockedThisDeviceOnly
```

The PIN should not be included on the Apple Wallet pass in Phase 1. Users can reveal it inside the app after authentication.

### 7. Barcode Rendering And Checkout

Implement a barcode service that can produce a display image from a stored barcode payload.

```text
BarcodeService
- scan() -> ScannedBarcode
- render(value, format) -> BarcodeImage
- validate(value, format) -> ValidationResult
```

Phase 1 render support should include:

- QR
- PDF417
- Aztec
- Code 128

EAN and UPC formats may be scan-only in Phase 1 unless a tested renderer is added. If a scanned format cannot be rendered, the save flow must warn the user and require choosing a renderable fallback.

Checkout screen requirements:

- Full-screen barcode on a white background.
- Merchant name and masked card ending.
- No decorative card container around the barcode.
- Tap to increase brightness while the screen is open.
- Keep the screen awake during checkout.
- Provide an authenticated copy action for card number when needed for checkout.

### 8. Manual Balance Tracking

Implement manual balances for Phase 1.

```text
BalanceProvider
- merchant_id
- required_fields
- supports_auto_refresh
- check_balance(card) -> BalanceResult
```

Only this provider is active in Phase 1:

```text
ManualBalanceProvider
- supports_auto_refresh: false
- check_balance: unavailable
- update_balance(user_amount) -> saved manual balance
```

Balance states:

- **Missing:** No balance has been entered.
- **User-entered:** User manually entered or edited the value.
- **Stale:** Reserved for future automatic checks; not required for manual-only Phase 1 unless the UI uses it for old manual values.

The UI should label manual balances as user-entered so users do not confuse them with merchant-verified values.

### 9. Apple Wallet Export

Implement Wallet export as a static `storeCard` pass.

Important security requirement: do not ship the Pass Type ID certificate private key inside the iOS app. The private key belongs on a server or local development signing tool.

Phase 1 can use either:

- A minimal pass-signing service for development and production readiness.
- A local development signer for prototype builds only.

Recommended service contract:

```text
POST /api/wallet/passes
Request: PassRequest
Response: application/vnd.apple.pkpass
```

The signing service should:

- Validate the requested barcode format against PassKit-supported formats.
- Build `pass.json` with `formatVersion`, `passTypeIdentifier`, `serialNumber`, `teamIdentifier`, `organizationName`, `description`, `storeCard`, and barcode fields.
- Add required pass images and icon assets.
- Build `manifest.json` with file hashes.
- Sign the manifest with the Pass Type ID certificate.
- Return the final `.pkpass` archive.
- Avoid logging card numbers, barcode payloads, or PINs.
- Avoid storing pass requests in Phase 1 unless retention is explicitly required.

The app-side Wallet service should look like:

```text
WalletPassService
- buildPassRequest(card_id) -> PassRequest
- requestSignedPass(passRequest) -> Data
- presentAddPassesViewController(pkpassData)
```

The pass request should include only fields required to create the pass:

```text
PassRequest
- serial_number
- merchant_display_name
- card_number_last4
- barcode_value
- barcode_format
- current_balance_minor_units
- currency
- last_balance_update_at
```

Phase 1 pass contents:

```text
storeCard
- primary field: balance or "Balance not entered"
- secondary field: merchant name
- auxiliary field: card ending
- back field: redemption notes
- barcode: saved barcode payload
```

Do not include the PIN on the pass. If online checkout requires a PIN, the user should reveal it in the app after authentication.

Phase 1 does not need Apple Wallet push updates. If a manual balance changes, the app can generate a replacement pass using the same `passTypeIdentifier` and `serialNumber`.

### 10. Error Handling

Implement user-facing errors for the common failure cases.

- Camera permission denied.
- OCR unavailable or no usable card details detected.
- Barcode scanned but unsupported for rendering.
- Required PIN missing.
- Invalid balance amount.
- Encryption key unavailable.
- Local authentication failed.
- Pass signing failed.
- Apple Wallet unavailable.

Errors should be actionable and should not expose sensitive card data.

### 11. Testing

Phase 1 should include focused tests around the parts that can lose money-equivalent data.

Required unit tests:

- Encrypt and decrypt card number, PIN, and barcode payload.
- Decryption fails with the wrong key.
- Card summaries never expose encrypted fields or plaintext secrets.
- Manual balance stores minor units correctly.
- Barcode validation rejects unsupported format/value combinations.
- Wallet pass request masks card number and excludes PIN.
- OCR detects known merchants from aliases and extracts plausible card/PIN candidates.
- OCR ignores support phone numbers and other non-card identifier lines.

Required integration or UI tests:

- Add a manual card.
- Add an OCR-scanned card with review/confirmation.
- Add a scanned barcode card with manual confirmation.
- Open card detail and show masked values.
- Reveal card number after authentication.
- Update manual balance.
- Generate a Wallet export request.

Manual device checks:

- Camera scanner detects at least one QR barcode and one Code 128 barcode.
- Full-screen barcode is readable by another phone camera.
- Apple Wallet accepts a generated development pass.

### 12. Acceptance Criteria

Phase 1 is complete when:

- A user can add a card with merchant, card number, optional PIN, barcode value, barcode format, and optional starting balance.
- Sensitive fields are encrypted before persistence.
- The card library shows saved cards without decrypting secrets.
- A user can open a card and display a scannable barcode.
- A user can manually update the balance and see the updated value immediately.
- Revealing card number and PIN requires device authentication; revealed values can be copied by long-pressing the value row.
- A static Apple Wallet `storeCard` pass can be generated and added to Wallet.
- The PIN is never included in the Wallet pass.
- The app handles unsupported barcode formats without saving an unusable card.

## Important Caveat

The core product is feasible. The risk is not generating wallet passes; Apple Wallet supports store-card-style passes for gift cards. The real challenge is balance automation, because every merchant has a different balance system, and many do not provide public APIs. Subway may be accessible through the stored-value inquiry page, but production use would need careful legal and terms review plus a robust fallback when the page changes.
