import XCTest
@testable import OpenDevUtils

/// Tests for URL encoding/decoding (URLTool logic extracted into URLEncoder).
/// Covers review findings:
/// - component encoding used `.urlQueryAllowed` which keeps `& = + ? #` etc.,
///   producing broken query values
/// - full URL encoding only touched the path and could double-encode
/// - decode failures were silent
final class URLEncoderTests: XCTestCase {

    // MARK: - Component encoding (encodeURIComponent equivalent)

    func testComponentEncodesReservedQueryCharacters() {
        // Regression: `.urlQueryAllowed` left these untouched.
        XCTAssertEqual(URLEncoder.encodeComponent("a&b=c"), "a%26b%3Dc")
        XCTAssertEqual(URLEncoder.encodeComponent("a+b"), "a%2Bb")
        XCTAssertEqual(URLEncoder.encodeComponent("a?b#c"), "a%3Fb%23c")
        XCTAssertEqual(URLEncoder.encodeComponent("a/b"), "a%2Fb")
        XCTAssertEqual(URLEncoder.encodeComponent("a:b;c"), "a%3Ab%3Bc")
    }

    func testComponentKeepsUnreservedCharacters() {
        XCTAssertEqual(URLEncoder.encodeComponent("Az09-_.~"), "Az09-_.~")
        XCTAssertEqual(URLEncoder.encodeComponent("!*'()"), "!*'()")
    }

    func testComponentEncodesSpaceAndNonASCII() {
        XCTAssertEqual(URLEncoder.encodeComponent("a b"), "a%20b")
        XCTAssertEqual(URLEncoder.encodeComponent("中文"), "%E4%B8%AD%E6%96%87")
    }

    func testComponentRoundTrip() {
        let original = "key=value & more/中文?#%"
        XCTAssertEqual(try URLEncoder.decode(URLEncoder.encodeComponent(original)), original)
    }

    // MARK: - Full URL encoding

    func testFullURLEncodesSpacesAndNonASCII() {
        let out = URLEncoder.encodeFullURL("https://ex.com/a b?x=中 文")
        XCTAssertFalse(out.contains(" "), out)
        XCTAssertFalse(out.contains("中"), out)
        XCTAssertTrue(out.hasPrefix("https://ex.com/a%20b?x="), out)
    }

    /// Regression: existing percent-escapes must not become `%2520`.
    func testFullURLDoesNotDoubleEncode() {
        XCTAssertEqual(URLEncoder.encodeFullURL("https://ex.com/a%20b"), "https://ex.com/a%20b")
    }

    func testFullURLKeepsStructure() {
        let out = URLEncoder.encodeFullURL("https://ex.com/p?a=1&b=2#frag")
        XCTAssertEqual(out, "https://ex.com/p?a=1&b=2#frag")
    }

    func testFullURLEncodesBarePercent() {
        // A `%` not followed by two hex digits is not a valid escape.
        XCTAssertEqual(URLEncoder.encodeFullURL("https://ex.com/100%"), "https://ex.com/100%25")
    }

    // MARK: - Decoding

    func testDecodeValidSequence() {
        XCTAssertEqual(try URLEncoder.decode("a%20b"), "a b")
        XCTAssertEqual(try URLEncoder.decode("%E4%B8%AD"), "中")
    }

    /// Regression: invalid escapes used to silently return the input.
    func testDecodeInvalidSequenceThrows() {
        XCTAssertThrowsError(try URLEncoder.decode("100%zz"))
        XCTAssertThrowsError(try URLEncoder.decode("%"))
        XCTAssertThrowsError(try URLEncoder.decode("%e4%b8"))
    }

    func testDecodePassesThroughPlainText() {
        XCTAssertEqual(try URLEncoder.decode("plain text"), "plain text")
    }
}
