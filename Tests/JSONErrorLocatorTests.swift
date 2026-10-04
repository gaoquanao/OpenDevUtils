import XCTest
@testable import OpenDevUtils

/// Tests for JSON parse error position reporting used by JSON Editor / JSONPath.
/// JSONSerialization reports `NSJSONSerializationErrorIndex` as a UTF-8 byte
/// offset, so line/column must be computed from UTF-8 bytes — otherwise
/// positions are wrong for CJK/emoji input and for errors at the very end
/// of the document (the common "truncated JSON" case).
final class JSONErrorLocatorTests: XCTestCase {

    func testValidJSONParses() {
        let (object, error) = tryParseJSON(#"{"a":1}"#)
        XCTAssertNotNil(object)
        XCTAssertNil(error)
    }

    func testTopLevelNumberAllowed() {
        let (object, error) = tryParseJSON("123")
        XCTAssertNotNil(object, "Top-level numbers are valid JSON")
        XCTAssertNil(error)
    }

    func testTopLevelStringAllowed() {
        let (object, error) = tryParseJSON(#""hello""#)
        XCTAssertNotNil(object, "Top-level strings are valid JSON")
        XCTAssertNil(error)
    }

    func testTopLevelBoolAllowed() {
        let (object, error) = tryParseJSON("true")
        XCTAssertNotNil(object)
        XCTAssertNil(error)
    }

    func testErrorPositionSimple() {
        let (_, error) = tryParseJSON(#"{"a": }"#)
        XCTAssertNotNil(error)
        // "{"a": }" → error at the `}` (byte offset 6, 1-based column 7)
        XCTAssertTrue(error!.hasPrefix("Line 1, Column 7"), "got: \(error!)")
    }

    func testErrorPositionAtEndOfInput() {
        // Truncated JSON: error index equals the input length.
        let (_, error) = tryParseJSON(#"{"a": 1"#)
        XCTAssertNotNil(error)
        XCTAssertTrue(error!.hasPrefix("Line 1, Column 8"), "got: \(error!)")
    }

    func testErrorPositionMultiline() {
        let input = "{\n  \"a\": }"
        let (_, error) = tryParseJSON(input)
        XCTAssertNotNil(error)
        XCTAssertTrue(error!.hasPrefix("Line 2, Column 8"), "got: \(error!)")
    }

    func testErrorPositionWithChineseCharacters() {
        // Byte offset 16; the prefix decodes to 14 Characters → column 15
        // (byte-based column would wrongly report 17).
        let input = "{\"名\": 1, \"b\": }"
        let (_, error) = tryParseJSON(input)
        XCTAssertNotNil(error)
        XCTAssertTrue(error!.hasPrefix("Line 1, Column 15"), "got: \(error!)")
    }

    func testErrorMessageStripsRawOffsetText() {
        let (_, error) = tryParseJSON(#"{"a": }"#)
        XCTAssertNotNil(error)
        XCTAssertFalse(error!.contains("around line"), "raw JSONSerialization position text should be stripped: \(error!)")
        XCTAssertFalse(error!.contains("around character"), "raw JSONSerialization position text should be stripped: \(error!)")
    }

    func testSnippetMarksErrorLine() {
        let (_, error) = tryParseJSON("{\n  \"a\": }")
        XCTAssertNotNil(error)
        XCTAssertTrue(error!.contains("→"), "snippet should mark the error line: \(error!)")
        XCTAssertTrue(error!.contains("\"a\": }"), "snippet should include the error line: \(error!)")
    }

    // MARK: - locate() with synthetic errors (legacy message formats)

    func testLocateWithLegacyCharacterOffset() {
        let input = "{\n  \"a\": }"
        let nsError = NSError(
            domain: NSCocoaErrorDomain,
            code: 3840,
            userInfo: [NSDebugDescriptionErrorKey: "Invalid value around character 9"]
        )
        let position = JSONErrorLocator(input: input, error: nsError).locate()
        XCTAssertNotNil(position)
        XCTAssertEqual(position?.line, 2)
        XCTAssertEqual(position?.column, 8)
    }

    func testLocateWithoutOffsetReturnsNil() {
        let nsError = NSError(
            domain: NSCocoaErrorDomain,
            code: 1,
            userInfo: [NSDebugDescriptionErrorKey: "Something went wrong"]
        )
        XCTAssertNil(JSONErrorLocator(input: "{}", error: nsError).locate())
    }
}
