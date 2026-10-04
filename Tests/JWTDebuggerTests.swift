import XCTest
@testable import OpenDevUtils

final class JWTDebuggerTests: XCTestCase {
    
    func testBase64URLDecode() {
        // Test standard base64url decoding
        let input = "SGVsbG8gV29ybGQ"
        let base64 = input.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = base64.padding(toLength: ((base64.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        let data = Data(base64Encoded: padded)
        XCTAssertNotNil(data)
        let decoded = String(data: data!, encoding: .utf8)
        XCTAssertEqual(decoded, "Hello World")
    }
    
    func testBase64URLDecodeWithPadding() {
        let input = "SGVsbG8"
        let base64 = input.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = base64.padding(toLength: ((base64.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        let data = Data(base64Encoded: padded)
        XCTAssertNotNil(data)
    }
    
    func testBase64URLEncodeDecodeRoundTrip() {
        let original = "Hello World"
        let data = original.data(using: .utf8)!
        let base64 = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        var padded = base64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        padded = padded.padding(toLength: ((padded.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        
        let decodedData = Data(base64Encoded: padded)
        XCTAssertNotNil(decodedData)
        let decoded = String(data: decodedData!, encoding: .utf8)
        XCTAssertEqual(decoded, original)
    }
    
    func testJWTStructure() {
        // A JWT has 3 parts separated by dots
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc123"
        let parts = jwt.components(separatedBy: ".")
        XCTAssertEqual(parts.count, 3)
    }
    
    func testJWTPayloadExtraction() {
        // Create a simple payload
        let payload: [String: Any] = [
            "sub": "1234567890",
            "name": "John Doe",
            "iat": 1516239022
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        XCTAssertFalse(base64.isEmpty)
        
        // Decode back
        var padded = base64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        padded = padded.padding(toLength: ((padded.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        
        let decodedData = Data(base64Encoded: padded)
        XCTAssertNotNil(decodedData)
        
        let decodedJSON = try! JSONSerialization.jsonObject(with: decodedData!) as! [String: Any]
        XCTAssertEqual(decodedJSON["sub"] as? String, "1234567890")
        XCTAssertEqual(decodedJSON["name"] as? String, "John Doe")
    }
    
    func testJWTHeaderExtraction() {
        let header: [String: Any] = [
            "alg": "HS256",
            "typ": "JWT"
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: header)
        let base64 = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        XCTAssertFalse(base64.isEmpty)
        
        // Verify decoding
        var padded = base64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        padded = padded.padding(toLength: ((padded.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        
        let decodedData = Data(base64Encoded: padded)!
        let decodedJSON = try! JSONSerialization.jsonObject(with: decodedData) as! [String: Any]
        XCTAssertEqual(decodedJSON["alg"] as? String, "HS256")
        XCTAssertEqual(decodedJSON["typ"] as? String, "JWT")
    }
    
    func testExpiredToken() {
        let exp = 1516239022 // 2018-01-18
        let date = Date(timeIntervalSince1970: TimeInterval(exp))
        XCTAssertTrue(date < Date())
    }
    
    func testFutureToken() {
        let exp = 9999999999 // Far future
        let date = Date(timeIntervalSince1970: TimeInterval(exp))
        XCTAssertTrue(date > Date())
    }

    // MARK: - Production base64url decoder (JWTDebuggerTool.base64URLDecode)

    func testProductionDecodeSimple() {
        let original = Data(#"{"sub":"123"}"#.utf8)
        let encoded = original.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        XCTAssertEqual(JWTDebuggerTool.base64URLDecode(encoded), original)
    }

    /// Regression: line-wrapped tokens used to fail decoding.
    func testProductionDecodeStripsWhitespace() {
        let original = Data(#"{"sub":"1234567890"}"#.utf8)
        var encoded = original.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        encoded.insert("\n", at: encoded.index(encoded.startIndex, offsetBy: 5))
        encoded = " " + encoded + " \t"
        XCTAssertEqual(JWTDebuggerTool.base64URLDecode(encoded), original)
    }

    func testProductionDecodeHandlesPadding() {
        let original = Data("Hello".utf8)
        XCTAssertEqual(JWTDebuggerTool.base64URLDecode("SGVsbG8="), original)
        XCTAssertEqual(JWTDebuggerTool.base64URLDecode("SGVsbG8"), original)
    }

    func testProductionDecodeInvalidReturnsNil() {
        XCTAssertNil(JWTDebuggerTool.base64URLDecode("!!!not-base64!!!"))
        XCTAssertNil(JWTDebuggerTool.base64URLDecode(""))
    }
}
