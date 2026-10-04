import XCTest
@testable import OpenDevUtils

/// Tests for the shared JSON processing pipeline used by JSON Editor (editor)
/// and JSONPath (viewer): parsing, pretty print / minify, size limits,
/// fragment (top-level scalar) support, query result formatting and
/// display truncation for large outputs.
final class JSONProcessorTests: XCTestCase {

    // MARK: - Pretty print / minify

    func testPrettyPrintObjectSortsKeys() {
        let result = JSONProcessor.prettyPrint(#"{"b":1,"a":2}"#)
        guard case .success(let output) = result else {
            return XCTFail("Expected success, got \(result)")
        }
        XCTAssertTrue(output.contains("\n"))
        XCTAssertNotNil(output.range(of: "\"a\""))
        XCTAssertNotNil(output.range(of: "\"b\""))
        if let a = output.range(of: "\"a\""), let b = output.range(of: "\"b\"") {
            XCTAssertLessThan(a.lowerBound, b.lowerBound, "keys should be sorted")
        }
    }

    func testMinifyObject() {
        let result = JSONProcessor.minify(#"{"a":   1}"#)
        guard case .success(let output) = result else {
            return XCTFail("Expected success, got \(result)")
        }
        XCTAssertEqual(output, #"{"a":1}"#)
    }

    func testPrettyPrintArray() {
        let result = JSONProcessor.prettyPrint("[1,2,3]")
        guard case .success(let output) = result else {
            return XCTFail("Expected success, got \(result)")
        }
        XCTAssertTrue(output.contains("1"))
        XCTAssertTrue(output.contains("3"))
    }

    // MARK: - Top-level scalars (fragments)

    func testPrettyPrintTopLevelNumber() {
        let result = JSONProcessor.prettyPrint("123")
        guard case .success(let output) = result else {
            return XCTFail("Top-level number must be accepted, got \(result)")
        }
        XCTAssertEqual(output, "123")
    }

    func testPrettyPrintTopLevelString() {
        let result = JSONProcessor.prettyPrint(#""hello""#)
        guard case .success(let output) = result else {
            return XCTFail("Top-level string must be accepted, got \(result)")
        }
        XCTAssertEqual(output, #""hello""#)
    }

    func testPrettyPrintTopLevelBoolAndNull() {
        if case .success(let output) = JSONProcessor.prettyPrint("true") {
            XCTAssertEqual(output, "true")
        } else {
            XCTFail("Top-level true must be accepted")
        }
        if case .success(let output) = JSONProcessor.prettyPrint("null") {
            XCTAssertEqual(output, "null")
        } else {
            XCTFail("Top-level null must be accepted")
        }
    }

    func testMinifyTopLevelStringWithWhitespace() {
        let result = JSONProcessor.minify("  \"hi\"  ")
        guard case .success(let output) = result else {
            return XCTFail("Expected success, got \(result)")
        }
        XCTAssertEqual(output, #""hi""#)
    }

    // MARK: - Invalid input & size limits

    func testInvalidJSONReportsError() {
        let result = JSONProcessor.minify(#"{"a": }"#)
        guard case .failure(let failure) = result else {
            return XCTFail("Expected failure")
        }
        guard case .invalid(let message) = failure else {
            return XCTFail("Expected .invalid, got \(failure)")
        }
        XCTAssertFalse(message.isEmpty)
    }

    func testEmptyInputFails() {
        if case .success = JSONProcessor.prettyPrint("") {
            XCTFail("Empty input must fail")
        }
    }

    func testCheckSizeWithinLimit() {
        XCTAssertNil(JSONProcessor.checkSize("{}", limit: 10))
    }

    func testCheckSizeOverLimit() {
        let failure = JSONProcessor.checkSize(String(repeating: "a", count: 11), limit: 10)
        XCTAssertNotNil(failure)
        guard case .tooLarge(let actual, let limit)? = failure else {
            return XCTFail("Expected .tooLarge, got \(String(describing: failure))")
        }
        XCTAssertEqual(actual, 11)
        XCTAssertEqual(limit, 10)
    }

    func testPrettyPrintRejectsOversizedInput() {
        let result = JSONProcessor.prettyPrint(String(repeating: "a", count: 11), limit: 10)
        guard case .failure(.tooLarge) = result else {
            return XCTFail("Expected .tooLarge failure, got \(result)")
        }
    }

    // MARK: - Serialize (fragment safe)

    func testSerializeArrayMinified() throws {
        let output = try JSONProcessor.serialize([1, 2], options: [])
        XCTAssertEqual(output, "[1,2]")
    }

    func testSerializeFragmentString() throws {
        let output = try JSONProcessor.serialize("red", options: [])
        XCTAssertEqual(output, #""red""#)
    }

    func testSerializeFragmentNumberPretty() throws {
        let output = try JSONProcessor.serialize(123, options: [.prettyPrinted])
        XCTAssertEqual(output, "123")
    }

    func testSerializeFragmentNull() throws {
        let output = try JSONProcessor.serialize(NSNull(), options: [])
        XCTAssertEqual(output, "null")
    }

    // MARK: - Query

    func testQueryScalarResultFormatsWithoutCrashing() throws {
        let json = #"{"store":{"bicycle":{"color":"red"}}}"#
        let result = JSONProcessor.query(json, path: "$.store.bicycle.color")
        guard case .success(let results) = result else {
            return XCTFail("Expected success, got \(result)")
        }
        XCTAssertEqual(results.count, 1)
        let formatted = try JSONProcessor.formatQueryResults(results)
        XCTAssertEqual(formatted, #""red""#)
    }

    func testQuerySingleObjectResult() throws {
        let json = #"{"store":{"bicycle":{"color":"red","price":19.95}}}"#
        let result = JSONProcessor.query(json, path: "$.store.bicycle")
        guard case .success(let results) = result else {
            return XCTFail("Expected success, got \(result)")
        }
        XCTAssertEqual(results.count, 1)
        let formatted = try JSONProcessor.formatQueryResults(results)
        XCTAssertTrue(formatted.hasPrefix("{"))
        XCTAssertTrue(formatted.contains("color"))
        XCTAssertTrue(formatted.contains("red"))
    }

    func testQueryMultipleResultsFormatAsArray() throws {
        let json = #"{"a":1,"b":2}"#
        let result = JSONProcessor.query(json, path: "$.*")
        guard case .success(let results) = result else {
            return XCTFail("Expected success, got \(result)")
        }
        XCTAssertEqual(results.count, 2)
        let formatted = try JSONProcessor.formatQueryResults(results)
        XCTAssertTrue(formatted.hasPrefix("["))
        XCTAssertTrue(formatted.contains("1"))
        XCTAssertTrue(formatted.contains("2"))
    }

    func testQueryEmptyResults() throws {
        let json = #"{"a":1}"#
        let result = JSONProcessor.query(json, path: "$.missing")
        // engine throws on missing key → failure is acceptable, empty success is acceptable
        switch result {
        case .success(let results):
            XCTAssertEqual(results.count, 0)
        case .failure(let failure):
            if case .invalid(let message) = failure { XCTAssertFalse(message.isEmpty) }
        }
    }

    func testQueryInvalidJSONFails() {
        let result = JSONProcessor.query(#"{"a": }"#, path: "$")
        guard case .failure(.invalid) = result else {
            return XCTFail("Expected .invalid failure, got \(result)")
        }
    }

    func testQueryInvalidPathFails() {
        let result = JSONProcessor.query(#"{"a":1}"#, path: "a")
        guard case .failure(.invalid(let message)) = result else {
            return XCTFail("Expected failure, got \(result)")
        }
        XCTAssertTrue(message.contains("Invalid JSONPath"))
    }

    func testQueryRejectsOversizedInput() {
        let result = JSONProcessor.query(String(repeating: "a", count: 11), path: "$", limit: 10)
        guard case .failure(.tooLarge) = result else {
            return XCTFail("Expected .tooLarge, got \(result)")
        }
    }

    // MARK: - Display preview (large output truncation)

    func testPreviewNoTruncation() {
        let preview = JSONProcessor.preview("hello", limit: 10)
        XCTAssertEqual(preview.display, "hello")
        XCTAssertFalse(preview.truncated)
        XCTAssertEqual(preview.totalCharacters, 5)
    }

    func testPreviewExactLimitNotTruncated() {
        let preview = JSONProcessor.preview("12345", limit: 5)
        XCTAssertFalse(preview.truncated)
        XCTAssertEqual(preview.display, "12345")
    }

    func testPreviewTruncates() {
        let preview = JSONProcessor.preview("123456789012345", limit: 10)
        XCTAssertTrue(preview.truncated)
        XCTAssertEqual(preview.display, "1234567890")
        XCTAssertEqual(preview.totalCharacters, 15)
    }

    func testPreviewUnicodeSafety() {
        let preview = JSONProcessor.preview("你好世界", limit: 2)
        XCTAssertTrue(preview.truncated)
        XCTAssertEqual(preview.display, "你好")
        XCTAssertEqual(preview.totalCharacters, 4)
    }

    // MARK: - Large input sanity

    func testLargeJSONRoundTrip() {
        var items: [String] = []
        for i in 0..<5000 {
            items.append(#"{"id":\#(i),"name":"item\#(i)"}"#)
        }
        let json = #"{"items":[\#(items.joined(separator: ", "))]}"#
        XCTAssertGreaterThan(json.utf8.count, 150_000)

        guard case .success(let pretty) = JSONProcessor.prettyPrint(json) else {
            return XCTFail("prettyPrint failed on 150KB+ input")
        }
        XCTAssertTrue(pretty.contains("item4999"))

        guard case .success(let minified) = JSONProcessor.minify(json) else {
            return XCTFail("minify failed on 150KB+ input")
        }
        XCTAssertLessThan(minified.utf8.count, json.utf8.count)
        XCTAssertTrue(minified.hasPrefix("{\"items\":["))
    }
}
