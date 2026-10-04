import XCTest
@testable import OpenDevUtils

/// Tests for curl command parsing and code generation (CurlConverterTool).
/// Covers URL extraction after headers, long options (`--request`/`--header`/
/// `--data`), JSON bodies containing quotes, and the generated Python code.
final class CurlConverterTests: XCTestCase {

    // MARK: - parseCurl

    func testParseSimpleURL() {
        let parsed = CurlConverterTool.parseCurl("curl https://api.example.com/users")
        XCTAssertEqual(parsed.url, "https://api.example.com/users")
        XCTAssertEqual(parsed.method, "GET")
        XCTAssertTrue(parsed.headers.isEmpty)
        XCTAssertTrue(parsed.body.isEmpty)
    }

    func testParseQuotedURL() {
        let parsed = CurlConverterTool.parseCurl("curl 'https://api.example.com/a b'")
        XCTAssertEqual(parsed.url, "https://api.example.com/a b")
    }

    /// Regression: URL extraction used to be "first quoted string in the
    /// command", so a header value before the URL was reported as the URL.
    func testParseURLAfterHeader() {
        let parsed = CurlConverterTool.parseCurl(
            "curl -H 'Content-Type: application/json' https://api.example.com/v1")
        XCTAssertEqual(parsed.url, "https://api.example.com/v1")
        XCTAssertEqual(parsed.headers.count, 1)
        XCTAssertEqual(parsed.headers[0].0, "Content-Type")
        XCTAssertEqual(parsed.headers[0].1, "application/json")
    }

    func testParseUnquotedURLWithFlags() {
        let parsed = CurlConverterTool.parseCurl("curl -sSL https://example.com -o out.txt")
        XCTAssertEqual(parsed.url, "https://example.com")
        XCTAssertTrue(parsed.insecure == false)
    }

    func testParseMethodShortOption() {
        let parsed = CurlConverterTool.parseCurl("curl -X POST https://example.com")
        XCTAssertEqual(parsed.method, "POST")
        XCTAssertEqual(parsed.url, "https://example.com")
    }

    /// Regression: only `-X` (uppercase, short) was recognized.
    func testParseMethodLongOption() {
        let parsed = CurlConverterTool.parseCurl("curl --request PUT https://example.com")
        XCTAssertEqual(parsed.method, "PUT")
        XCTAssertEqual(parsed.url, "https://example.com")
    }

    func testParseMethodAttachedShortOption() {
        let parsed = CurlConverterTool.parseCurl("curl -XDELETE https://example.com")
        XCTAssertEqual(parsed.method, "DELETE")
        XCTAssertEqual(parsed.url, "https://example.com")
    }

    func testParseHeaderLongOption() {
        let parsed = CurlConverterTool.parseCurl(
            "curl --header 'Accept: application/json' https://example.com")
        XCTAssertEqual(parsed.headers.count, 1)
        XCTAssertEqual(parsed.headers[0].0, "Accept")
        XCTAssertEqual(parsed.headers[0].1, "application/json")
        XCTAssertEqual(parsed.url, "https://example.com")
    }

    func testParseMultipleHeaders() {
        let parsed = CurlConverterTool.parseCurl(
            "curl -H 'A: 1' -H \"B: two\" https://example.com")
        XCTAssertEqual(parsed.headers.count, 2)
        XCTAssertEqual(parsed.headers[0].0, "A")
        XCTAssertEqual(parsed.headers[1].0, "B")
        XCTAssertEqual(parsed.headers[1].1, "two")
    }

    /// Regression: `-d '{"a":"b"}'` was truncated to `{` because the regex
    /// stopped at the first quote character.
    func testParseJSONBodyWithQuotes() {
        let parsed = CurlConverterTool.parseCurl(
            #"curl -X POST -H 'Content-Type: application/json' -d '{"a":"b","n":1}' https://api.example.com"#)
        XCTAssertEqual(parsed.body, #"{"a":"b","n":1}"#)
        XCTAssertEqual(parsed.method, "POST")
        XCTAssertEqual(parsed.url, "https://api.example.com")
    }

    func testParseDataLongOption() {
        let parsed = CurlConverterTool.parseCurl(
            #"curl --data-raw '{"x":1}' https://example.com"#)
        XCTAssertEqual(parsed.body, #"{"x":1}"#)
        XCTAssertEqual(parsed.method, "POST", "-d implies POST when method was GET")
    }

    func testParseInsecureFlag() {
        XCTAssertTrue(CurlConverterTool.parseCurl("curl -k https://example.com").insecure)
        XCTAssertTrue(CurlConverterTool.parseCurl("curl --insecure https://example.com").insecure)
        XCTAssertFalse(CurlConverterTool.parseCurl("curl https://example.com").insecure)
    }

    func testParseLineContinuation() {
        let parsed = CurlConverterTool.parseCurl("curl \\\n  https://example.com")
        XCTAssertEqual(parsed.url, "https://example.com")
    }

    /// Regression: URL/header values containing flag-like substrings
    /// (`-X `, `-d `) used to be misdetected by whole-command substring
    /// matching — parsing is token based now.
    func testFlagLikeSubstringInURLIsNotMisdetected() {
        let parsed = CurlConverterTool.parseCurl("curl 'https://x/-d test' -H 'X: -d 1'")
        XCTAssertEqual(parsed.url, "https://x/-d test")
        XCTAssertEqual(parsed.method, "GET")
        XCTAssertTrue(parsed.body.isEmpty)
        XCTAssertEqual(parsed.headers.count, 1)
        XCTAssertEqual(parsed.headers[0].1, "-d 1")
    }

    func testEqualsFormLongOptions() {
        let parsed = CurlConverterTool.parseCurl(
            "curl --header='Accept: text/plain' --request=POST https://example.com")
        XCTAssertEqual(parsed.headers.count, 1)
        XCTAssertEqual(parsed.headers[0].0, "Accept")
        XCTAssertEqual(parsed.method, "POST")
        XCTAssertEqual(parsed.url, "https://example.com")
    }

    /// `insecure` at the end of the command (no trailing space) must still
    /// be detected — PHP output depends on it.
    func testInsecureAsLastToken() {
        XCTAssertTrue(CurlConverterTool.parseCurl("curl https://example.com -k").insecure)
    }

    /// Non-cURL input must be detectable so the UI can warn instead of
    /// emitting code that dereferences `URL(string: "")!`.
    func testMissingURLIsDetectable() {
        XCTAssertTrue(CurlConverterTool.parseCurl("curl -X POST").url.isEmpty)
        XCTAssertFalse(CurlConverterTool.parseCurl("curl https://x.com").url.isEmpty)
    }

    // MARK: - Generation

    /// Regression: without headers the generator emitted
    /// `headers=headers={}` → invalid Python.
    func testPythonWithoutHeadersIsSyntacticallyValidParams() {
        let parsed = CurlConverterTool.parseCurl("curl https://example.com")
        let python = CurlConverterTool.generatePython(parsed)
        XCTAssertFalse(python.contains("headers=headers={}"), python)
        XCTAssertTrue(python.contains("headers={}"), python)
    }

    func testPythonWithHeadersUsesHeadersDict() {
        let parsed = CurlConverterTool.parseCurl("curl -H 'X-A: 1' https://example.com")
        let python = CurlConverterTool.generatePython(parsed)
        XCTAssertTrue(python.contains("headers = {"), python)
        XCTAssertTrue(python.contains("headers=headers"), python)
        XCTAssertFalse(python.contains("headers=headers={}"), python)
    }

    func testPythonJSONBody() {
        let parsed = CurlConverterTool.parseCurl(#"curl -d '{"a":1}' https://example.com"#)
        let python = CurlConverterTool.generatePython(parsed)
        XCTAssertTrue(python.contains(#"data="{\"a\":1}""#), python)
        XCTAssertTrue(python.contains("requests.post("), python)
    }

    func testJavaScriptRawJSONBodyIsLiteral() {
        let parsed = CurlConverterTool.parseCurl(#"curl -d '{"a":1}' https://example.com"#)
        let js = CurlConverterTool.generateJavaScript(parsed)
        XCTAssertFalse(js.contains("JSON.stringify({"), "raw JSON body must be embedded as-is: \(js)")
        XCTAssertTrue(js.contains("body: {\"a\":1}"), js)
    }

    func testJavaScriptPlainTextBodyIsQuoted() {
        let parsed = CurlConverterTool.parseCurl("curl -d 'a=1&b=2' https://example.com")
        let js = CurlConverterTool.generateJavaScript(parsed)
        XCTAssertTrue(js.contains("body: \"a=1&b=2\""), js)
    }
}
