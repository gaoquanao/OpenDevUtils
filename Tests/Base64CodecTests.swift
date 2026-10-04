import XCTest
@testable import OpenDevUtils

/// Tests for Base64Codec (the logic behind the Base64 tool, which previously
/// had no implementation at all — output was never produced).
final class Base64CodecTests: XCTestCase {

    // MARK: - Encode

    func testEncodeSimple() {
        let result = Base64Codec.process("Hello", encode: true)
        XCTAssertEqual(result, .success("SGVsbG8="))
    }

    func testEncodeEmpty() {
        XCTAssertEqual(Base64Codec.process("", encode: true), .success(""))
    }

    func testEncodeUnicode() {
        guard case .success(let encoded) = Base64Codec.process("你好", encode: true) else {
            return XCTFail("encode failed")
        }
        let decoded = Data(base64Encoded: encoded)
        XCTAssertEqual(decoded.flatMap { String(data: $0, encoding: .utf8) }, "你好")
    }

    // MARK: - Decode

    func testDecodeSimple() {
        let result = Base64Codec.process("SGVsbG8=", encode: false)
        XCTAssertEqual(result, .success("Hello"))
    }

    /// Regression: base64 copied from logs/HTML is usually line-wrapped.
    func testDecodeIgnoresLineBreaksAndSpaces() {
        XCTAssertEqual(Base64Codec.process("SGVs\nbG8=", encode: false), .success("Hello"))
        XCTAssertEqual(Base64Codec.process("SGVs bG8=", encode: false), .success("Hello"))
        XCTAssertEqual(Base64Codec.process("  SGVsbG8= \n", encode: false), .success("Hello"))
    }

    func testDecodeUnpaddedBase64() {
        XCTAssertEqual(Base64Codec.process("SGVsbG8", encode: false), .success("Hello"))
    }

    func testDecodeInvalidDataFails() {
        let result = Base64Codec.process("not@valid!", encode: false)
        guard case .failure(.invalidData) = result else {
            return XCTFail("Expected .invalidData, got \(result)")
        }
    }

    func testDecodeNonUTF8Fails() {
        let bytes = Data([0xFF, 0xFE])
        let result = Base64Codec.process(bytes.base64EncodedString(), encode: false)
        guard case .failure(.notUTF8) = result else {
            return XCTFail("Expected .notUTF8, got \(result)")
        }
    }

    // MARK: - Round trip

    func testRoundTripMultilineUnicode() {
        let original = "Line1\nLine2 — 你好，世界 🎉"
        guard case .success(let encoded) = Base64Codec.process(original, encode: true) else {
            return XCTFail("encode failed")
        }
        let wrapped = encoded.replacingOccurrences(of: "=", with: "=\n")
        let result = Base64Codec.process(wrapped, encode: false)
        XCTAssertEqual(result, .success(original))
    }

    // MARK: - Size limit

    func testTooLargeInputRejected() {
        let result = Base64Codec.process(String(repeating: "a", count: 11),
                                         encode: true, limit: 10)
        guard case .failure(.tooLarge) = result else {
            return XCTFail("Expected .tooLarge, got \(result)")
        }
    }

    func testWithinLimitAccepted() {
        XCTAssertEqual(Base64Codec.process(String(repeating: "a", count: 9),
                                           encode: true, limit: 10),
                       .success(String(repeating: "a", count: 9).data(using: .utf8)!.base64EncodedString()))
    }
}
