import XCTest
import CoreImage
@testable import OpenDevUtils

/// Tests for QRCoder — generation and decoding extracted from QRCodeTool.
/// Review findings addressed:
/// - the "Scan" mode was never implemented (no decode at all)
/// - generation failures left the previous (stale) QR code on screen
/// - a fresh CIContext was created on every keystroke
final class QRCoderTests: XCTestCase {

    // MARK: - Generate + decode round trip

    func testGenerateAndDecodeRoundTrip() {
        guard let image = QRCoder.generate(from: "hello-123") else {
            return XCTFail("generation failed")
        }
        XCTAssertEqual(QRCoder.decode(image), "hello-123")
    }

    func testGenerateUnicodeRoundTrip() {
        guard let image = QRCoder.generate(from: "中文测试 🎉") else {
            return XCTFail("generation failed")
        }
        XCTAssertEqual(QRCoder.decode(image), "中文测试 🎉")
    }

    func testGenerateReturnsNilForEmptyInput() {
        XCTAssertNil(QRCoder.generate(from: ""))
    }

    /// Regression: generation used to silently keep the previous image.
    /// The caller clears state on nil, so nil must be returned on failure.
    func testGenerateHugeInputDoesNotCrash() {
        // CIQRCodeGenerator has a hard capacity limit; must return nil, not trap.
        let huge = String(repeating: "x", count: 100_000)
        XCTAssertNil(QRCoder.generate(from: huge))
    }

    // MARK: - Decode failures

    func testDecodeImageWithoutQRReturnsNil() {
        let context = CIContext()
        let ciImage = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        guard let cg = context.createCGImage(ciImage, from: ciImage.extent) else {
            return XCTFail("could not create test image")
        }
        XCTAssertNil(QRCoder.decode(cg))
    }

    /// Decoding a scaled-up QR (like screenshots) must still work.
    func testDecodeScaledImage() {
        guard let image = QRCoder.generate(from: "scale-test", scale: 4) else {
            return XCTFail("generation failed")
        }
        XCTAssertEqual(QRCoder.decode(image), "scale-test")
    }
}
