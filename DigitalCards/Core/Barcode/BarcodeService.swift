import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

enum BarcodeError: Error, LocalizedError {
    case unsupportedFormat
    case emptyValue
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "This barcode format cannot be displayed in Phase 1."
        case .emptyValue:
            return "Barcode value is required."
        case .renderingFailed:
            return "The barcode could not be rendered."
        }
    }
}

protocol BarcodeServicing {
    func render(value: String, format: BarcodeFormat) throws -> UIImage
    func validate(value: String, format: BarcodeFormat) -> ValidationResult
}

struct CoreImageBarcodeService: BarcodeServicing {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    func render(value: String, format: BarcodeFormat) throws -> UIImage {
        let validation = validate(value: value, format: format)
        guard validation.isValid else {
            throw format.isRenderableInPhase1 ? BarcodeError.emptyValue : BarcodeError.unsupportedFormat
        }

        let message = Data(value.utf8)
        let outputImage: CIImage?

        switch format {
        case .qr:
            let filter = CIFilter.qrCodeGenerator()
            filter.message = message
            filter.correctionLevel = "M"
            outputImage = filter.outputImage
        case .pdf417:
            let filter = CIFilter.pdf417BarcodeGenerator()
            filter.message = message
            outputImage = filter.outputImage
        case .aztec:
            let filter = CIFilter.aztecCodeGenerator()
            filter.message = message
            outputImage = filter.outputImage
        case .code128:
            let filter = CIFilter.code128BarcodeGenerator()
            filter.message = message
            outputImage = filter.outputImage
        case .ean13, .ean8, .upce:
            throw BarcodeError.unsupportedFormat
        }

        guard let outputImage else {
            throw BarcodeError.renderingFailed
        }

        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            throw BarcodeError.renderingFailed
        }
        return UIImage(cgImage: cgImage)
    }

    func validate(value: String, format: BarcodeFormat) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ValidationResult(isValid: false, message: "Barcode value is required.")
        }
        guard format.isRenderableInPhase1 else {
            return ValidationResult(isValid: false, message: "\(format.displayName) can be scanned but not rendered in Phase 1.")
        }
        return .valid
    }
}

extension BarcodeFormat {
    init?(metadataObjectType: AVMetadataObject.ObjectType) {
        switch metadataObjectType {
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

    var metadataObjectType: AVMetadataObject.ObjectType? {
        switch self {
        case .qr: return .qr
        case .pdf417: return .pdf417
        case .aztec: return .aztec
        case .code128: return .code128
        case .ean13: return .ean13
        case .ean8: return .ean8
        case .upce: return .upce
        }
    }
}
