import Foundation

struct MerchantCandidate: Identifiable, Equatable {
    var id: String { merchantID }
    let merchantID: String
    let displayName: String
    let confidence: Float
    let matchedText: String
}

struct SensitiveCandidate: Identifiable, Equatable {
    var id: String { "\(sourceLabel ?? "unknown"):\(value)" }
    let value: String
    let confidence: Float
    let sourceLabel: String?
}

struct CardOCRResult: Identifiable, Equatable {
    var id: String {
        [
            merchantCandidates.first?.merchantID,
            cardNumberCandidates.first?.value,
            pinCandidates.first?.value,
            barcode?.value
        ]
            .compactMap { $0 }
            .joined(separator: ":")
    }

    let merchantCandidates: [MerchantCandidate]
    let cardNumberCandidates: [SensitiveCandidate]
    let pinCandidates: [SensitiveCandidate]
    let barcode: ScannedBarcode?
}

protocol CardOCRServicing {
    func recognize(textBlocks: [String], barcode: ScannedBarcode?, catalog: MerchantCatalog) -> CardOCRResult
}

struct CardOCRService: CardOCRServicing {
    func recognize(textBlocks: [String], barcode: ScannedBarcode?, catalog: MerchantCatalog) -> CardOCRResult {
        let cleanedBlocks = textBlocks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return CardOCRResult(
            merchantCandidates: merchantCandidates(from: cleanedBlocks, catalog: catalog),
            cardNumberCandidates: cardNumberCandidates(from: cleanedBlocks, barcode: barcode),
            pinCandidates: pinCandidates(from: cleanedBlocks),
            barcode: barcode
        )
    }

    private func merchantCandidates(from textBlocks: [String], catalog: MerchantCatalog) -> [MerchantCandidate] {
        let normalizedAllText = normalizeWords(textBlocks.joined(separator: " "))

        let matches = catalog.all
            .filter { $0.id != MerchantCatalog.other.id }
            .compactMap { merchant -> MerchantCandidate? in
                let aliases = ([merchant.displayName] + merchant.aliases).map(normalizeWords)
                guard let matchedAlias = aliases.first(where: { !$0.isEmpty && normalizedAllText.contains($0) }) else {
                    return nil
                }

                let confidence = min(0.98, 0.72 + Float(matchedAlias.count) / 80)
                return MerchantCandidate(
                    merchantID: merchant.id,
                    displayName: merchant.displayName,
                    confidence: confidence,
                    matchedText: matchedAlias
                )
            }
            .sorted { $0.confidence > $1.confidence }

        if matches.isEmpty {
            return [
                MerchantCandidate(
                    merchantID: MerchantCatalog.other.id,
                    displayName: MerchantCatalog.other.displayName,
                    confidence: 0.1,
                    matchedText: "No merchant match"
                )
            ]
        }

        return matches
    }

    private func cardNumberCandidates(from textBlocks: [String], barcode: ScannedBarcode?) -> [SensitiveCandidate] {
        var candidates: [SensitiveCandidate] = []

        if let barcode {
            let value = sanitizeIdentifier(barcode.value)
            if isPlausibleCardNumber(value) {
                candidates.append(
                    SensitiveCandidate(value: value, confidence: 0.96, sourceLabel: "Barcode")
                )
            }
        }

        for block in textBlocks {
            let label = sourceLabel(for: block)
            if shouldIgnoreIdentifierLine(block) {
                continue
            }

            for value in identifierCandidates(in: block) where isPlausibleCardNumber(value) {
                let confidence: Float = lineLooksCardRelated(block) ? 0.88 : 0.7
                candidates.append(SensitiveCandidate(value: value, confidence: confidence, sourceLabel: label))
            }
        }

        return dedupe(candidates).sorted { $0.confidence > $1.confidence }
    }

    private func pinCandidates(from textBlocks: [String]) -> [SensitiveCandidate] {
        var candidates: [SensitiveCandidate] = []

        for block in textBlocks where lineLooksPINRelated(block) {
            let normalized = normalizeWords(block)
            let tokens = normalized.split(separator: " ").map(String.init)
            for token in tokens {
                let value = sanitizeIdentifier(token)
                guard isPlausiblePIN(value), !pinStopWords.contains(value) else {
                    continue
                }
                candidates.append(
                    SensitiveCandidate(
                        value: value,
                        confidence: 0.9,
                        sourceLabel: sourceLabel(for: block)
                    )
                )
            }
        }

        return dedupe(candidates).sorted { $0.confidence > $1.confidence }
    }

    private func identifierCandidates(in text: String) -> [String] {
        let tokens = normalizeWords(text)
            .split(separator: " ")
            .map { stripIdentifierLabelPrefix(String($0)) }
            .filter { !$0.isEmpty && !identifierStopWords.contains($0) && $0.contains(where: \.isNumber) }

        let value = sanitizeIdentifier(tokens.joined())
        guard !value.isEmpty else {
            return []
        }
        return [value]
    }

    private func stripIdentifierLabelPrefix(_ value: String) -> String {
        let prefixes = ["CARDNUMBER", "CARDNO", "GIFTCARD", "ACCOUNTNUMBER", "ACCTNUMBER", "CLAIMCODE"]
        for prefix in prefixes where value.hasPrefix(prefix) {
            return String(value.dropFirst(prefix.count))
        }
        return value
    }

    private func sanitizeIdentifier(_ value: String) -> String {
        value
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private func normalizeWords(_ value: String) -> String {
        let scalars = value.uppercased().unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(scalars)
            .split(separator: " ")
            .joined(separator: " ")
    }

    private func sourceLabel(for text: String) -> String? {
        let normalized = normalizeWords(text)
        if normalized.contains("PIN") { return "PIN" }
        if normalized.contains("SECURITY") { return "Security code" }
        if normalized.contains("ACCESS") { return "Access code" }
        if normalized.contains("CARD") { return "Card number" }
        return nil
    }

    private func lineLooksCardRelated(_ text: String) -> Bool {
        let normalized = normalizeWords(text)
        return ["CARD", "GIFT", "NUMBER", "ACCOUNT", "ACCT", "CLAIM"].contains { normalized.contains($0) }
    }

    private func lineLooksPINRelated(_ text: String) -> Bool {
        let normalized = normalizeWords(text)
        return ["PIN", "SECURITY CODE", "ACCESS CODE", "SCRATCH"].contains { normalized.contains($0) }
    }

    private func shouldIgnoreIdentifierLine(_ text: String) -> Bool {
        let normalized = normalizeWords(text)
        return ["PHONE", "CALL", "TEL", "WWW", "HTTP", "VALID THRU", "EXP", "DATE"].contains { normalized.contains($0) }
    }

    private func isPlausibleCardNumber(_ value: String) -> Bool {
        let length = value.count
        guard length >= 10 && length <= 30, value.contains(where: \.isNumber) else {
            return false
        }
        if value.allSatisfy(\.isNumber) {
            return length >= 12
        }
        return length >= 10
    }

    private func isPlausiblePIN(_ value: String) -> Bool {
        let length = value.count
        return length >= 3 && length <= 12 && value.contains(where: \.isNumber)
    }

    private func dedupe(_ candidates: [SensitiveCandidate]) -> [SensitiveCandidate] {
        var bestByValue: [String: SensitiveCandidate] = [:]
        for candidate in candidates {
            if let existing = bestByValue[candidate.value], existing.confidence >= candidate.confidence {
                continue
            }
            bestByValue[candidate.value] = candidate
        }
        return Array(bestByValue.values)
    }

    private var pinStopWords: Set<String> {
        ["PIN", "SECURITY", "CODE", "ACCESS", "SCRATCH"]
    }

    private var identifierStopWords: Set<String> {
        ["CARD", "GIFT", "NUMBER", "ACCOUNT", "ACCT", "CLAIM", "CODE"]
    }
}
