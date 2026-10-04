import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// QR generation and decoding extracted from `QRCodeTool`. Fixes review
/// findings:
/// - the "Scan" mode was never implemented (no decode at all)
/// - generation failures left the previous (stale) QR code on screen, so
///   callers must clear state when `generate` returns nil
/// - a fresh `CIContext` was created on every keystroke
enum QRCoder {

    /// QR version 40 with EC level M holds 2331 bytes; anything larger makes
    /// CIQRCodeGenerator fail, so we reject it up front.
    private static let maxPayloadBytes = 2331

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Generate

    static func generate(from string: String, scale: CGFloat = 10) -> CGImage? {
        guard !string.isEmpty else { return nil }
        let data = Data(string.utf8)
        guard data.count <= maxPayloadBytes else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"

        guard let output = filter.outputImage, output.extent.width > 0 else { return nil }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return context.createCGImage(scaled, from: scaled.extent)
    }

    // MARK: - Decode

    static func decode(_ cgImage: CGImage) -> String? {
        guard let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                        context: context,
                                        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else {
            return nil
        }
        let image = CIImage(cgImage: cgImage)
        let features = detector.features(in: image)
        for feature in features {
            if let qr = feature as? CIQRCodeFeature, let message = qr.messageString {
                return message
            }
        }
        return nil
    }
}
