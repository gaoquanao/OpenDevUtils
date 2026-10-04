import XCTest
@testable import OpenDevUtils

/// Tests for the production JWT parsing logic (`JWTDecoder`). The previous
/// version of this file re-implemented base64url handling inline and never
/// exercised the shipped decoder.
final class JWTDebuggerTests: XCTestCase {

    // MARK: - Helpers

    /// Encodes arbitrary JSON as the base64url segment of a JWT (input
    /// construction only — decoding is always done by production code).
    private func segment(_ json: String) -> String {
        Data(json.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func token(header: String, payload: String, signature: String? = "sig") -> String {
        var parts = [segment(header), segment(payload)]
        if let signature { parts.append(signature) }
        return parts.joined(separator: ".")
    }

    // MARK: - Full token decoding

    func testDecodeFullToken() {
        let decoded = JWTDecoder.decode(token(
            header: #"{"alg":"HS256","typ":"JWT"}"#,
            payload: #"{"sub":"1234567890","name":"John Doe"}"#
        ))

        XCTAssertFalse(decoded.hasIssues)
        XCTAssertTrue(decoded.headerJSON.contains(#""alg" : "HS256""#))
        XCTAssertTrue(decoded.headerJSON.contains(#""typ" : "JWT""#))
        XCTAssertTrue(decoded.payloadJSON.contains(#""sub" : "1234567890""#))
        XCTAssertTrue(decoded.payloadJSON.contains(#""name" : "John Doe""#))
        XCTAssertEqual(decoded.signature, "sig")
        XCTAssertEqual(decoded.claimsNote, "")
    }

    /// Payload keys come out sorted (`.sortedKeys`), so Copy produces stable output.
    func testPayloadKeysAreSorted() {
        let decoded = JWTDecoder.decode(token(
            header: #"{"alg":"none"}"#,
            payload: #"{"zzz":1,"aaa":2}"#
        ))
        XCTAssertFalse(decoded.hasIssues)
        let aaaRange = decoded.payloadJSON.range(of: #""aaa""#)
        let zzzRange = decoded.payloadJSON.range(of: #""zzz""#)
        XCTAssertNotNil(aaaRange)
        XCTAssertNotNil(zzzRange)
        XCTAssertLessThan(aaaRange!.lowerBound, zzzRange!.lowerBound)
    }

    func testTokenWithoutSignature() {
        let decoded = JWTDecoder.decode(token(
            header: #"{"alg":"HS256"}"#,
            payload: #"{"sub":"1"}"#,
            signature: nil
        ))
        XCTAssertFalse(decoded.hasIssues)
        XCTAssertEqual(decoded.signature, "")
    }

    func testEmptyInputProducesEmptyResult() {
        let decoded = JWTDecoder.decode("   \n  ")
        XCTAssertFalse(decoded.hasIssues)
        XCTAssertEqual(decoded.headerJSON, "")
        XCTAssertEqual(decoded.payloadJSON, "")
    }

    // MARK: - Claim notes

    func testExpiryAndIssuedAtNotes() {
        let exp = 1_700_000_000.0  // 2023-11-14 22:13:20 UTC
        let iat = 1_516_239_022.0  // 2018-01-18 01:30:22 UTC
        let decoded = JWTDecoder.decode(token(
            header: #"{"alg":"HS256"}"#,
            payload: #"{"exp":1700000000,"iat":1516239022}"#
        ))

        XCTAssertFalse(decoded.hasIssues)
        // Dates render in UTC because the claim formatter uses en_US_POSIX
        // (Calendar.current is still the machine's, so pin expectations via
        // the shared formatter instead of hardcoding wall-clock strings).
        let expectedExp = JWTDecoder.claimDateFormatter.string(from: Date(timeIntervalSince1970: exp))
        let expectedIat = JWTDecoder.claimDateFormatter.string(from: Date(timeIntervalSince1970: iat))
        XCTAssertEqual(decoded.claimsNote, "exp: \(expectedExp)\niat: \(expectedIat)")
    }

    func testTokenWithoutTimeClaimsHasNoNotes() {
        let decoded = JWTDecoder.decode(token(
            header: #"{"alg":"HS256"}"#,
            payload: #"{"sub":"1"}"#
        ))
        XCTAssertEqual(decoded.claimsNote, "")
    }

    // MARK: - Malformed tokens

    func testSingleSegmentIsMalformed() {
        let decoded = JWTDecoder.decode("only-one-part")
        XCTAssertEqual(decoded.issues, [.malformed])
        XCTAssertEqual(decoded.headerJSON, "")
        XCTAssertEqual(decoded.payloadJSON, "")
    }

    func testInvalidHeaderSegment() {
        let decoded = JWTDecoder.decode("!!!not-base64!!!.\(segment(#"{"sub":"1"}"#)).sig")
        XCTAssertEqual(decoded.issues, [.invalidHeader])
        XCTAssertEqual(decoded.payloadJSON.contains(#""sub""#), true)
    }

    func testInvalidPayloadSegment() {
        let decoded = JWTDecoder.decode("\(segment(#"{"alg":"HS256"}"#)).!!!not-base64!!!.sig")
        XCTAssertEqual(decoded.issues, [.invalidPayload])
        XCTAssertFalse(decoded.headerJSON.isEmpty)
    }

    /// Header that decodes as base64 but is not JSON.
    func testHeaderNotJSON() {
        let notJSON = Data("plain text".utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let decoded = JWTDecoder.decode("\(notJSON).\(segment(#"{"sub":"1"}"#))")
        XCTAssertEqual(decoded.issues, [.invalidHeader])
    }

    // MARK: - base64url decoder

    func testBase64URLDecodeSimple() {
        let original = Data(#"{"sub":"123"}"#.utf8)
        let encoded = original.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        XCTAssertEqual(JWTDecoder.base64URLDecode(encoded), original)
    }

    /// Regression: line-wrapped tokens used to fail decoding.
    func testBase64URLDecodeStripsWhitespace() {
        let original = Data(#"{"sub":"1234567890"}"#.utf8)
        var encoded = original.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        encoded.insert("\n", at: encoded.index(encoded.startIndex, offsetBy: 5))
        encoded = " " + encoded + " \t"
        XCTAssertEqual(JWTDecoder.base64URLDecode(encoded), original)
    }

    func testBase64URLDecodeHandlesPadding() {
        let original = Data("Hello".utf8)
        XCTAssertEqual(JWTDecoder.base64URLDecode("SGVsbG8="), original)
        XCTAssertEqual(JWTDecoder.base64URLDecode("SGVsbG8"), original)
    }

    func testBase64URLDecodeURLSafeAlphabet() {
        // Bytes that map to '+' and '/' in standard base64…
        let original = Data([0xFB, 0xFF, 0xBF])   // standard: +/+
        let urlSafe = original.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        XCTAssertEqual(JWTDecoder.base64URLDecode(urlSafe), original)
    }

    func testBase64URLDecodeInvalidReturnsNil() {
        XCTAssertNil(JWTDecoder.base64URLDecode("!!!not-base64!!!"))
        XCTAssertNil(JWTDecoder.base64URLDecode(""))
        XCTAssertNil(JWTDecoder.base64URLDecode("   "))
    }
}
