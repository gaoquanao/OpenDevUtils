import XCTest
@testable import OpenDevUtils

/// Tests for the syntax highlighter tokenizer (extracted from the SwiftUI
/// view so it can be tested and cached). Review findings addressed:
/// - regexes were recompiled per token per line inside the inner loop
/// - Go string rule was `"[^"]*`` (required a trailing backtick) — strings
///   were never highlighted
/// - force unwraps (`bestMatch!.range!`)
/// - string rules didn't handle backslash escapes
final class SyntaxHighlighterTests: XCTestCase {

    private func kinds(_ line: String, _ language: String) -> [SyntaxHighlighter.TokenKind: Int] {
        var counts: [SyntaxHighlighter.TokenKind: Int] = [:]
        for token in SyntaxHighlighter.tokens(line: line, language: language) {
            counts[token.kind, default: 0] += 1
        }
        return counts
    }

    // MARK: - Invariant: tokens reconstruct the original line

    func testTokensReconstructLineForAllLanguages() {
        let line = #"let x = "a\"b" // c ( ) 123 .foo("#
        for language in ["Swift", "Python", "JavaScript", "Go", "PHP", "Java", "Shell"] {
            let tokens = SyntaxHighlighter.tokens(line: line, language: language)
            XCTAssertEqual(tokens.map(\.text).joined(), line, language)
        }
    }

    func testEmptyLineProducesNoTokens() {
        XCTAssertTrue(SyntaxHighlighter.tokens(line: "", language: "Swift").isEmpty)
    }

    func testUnknownLanguageIsPlain() {
        let tokens = SyntaxHighlighter.tokens(line: "hello world", language: "Brainfuck")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .plain)
    }

    // MARK: - Swift

    func testSwiftKeyword() {
        let counts = kinds("let value = 1", "Swift")
        XCTAssertEqual(counts[.keyword], 1)
    }

    func testSwiftStringWithEscape() {
        // Regression: `[^"]*` stopped at the escaped quote.
        let tokens = SyntaxHighlighter.tokens(line: #"let s = "a\"b""#, language: "Swift")
        let strings = tokens.filter { $0.kind == .string }
        XCTAssertEqual(strings.count, 1, "expected one string token, got \(strings)")
        XCTAssertEqual(strings[0].text, #""a\"b""#)
    }

    func testSwiftComment() {
        let counts = kinds("// trailing comment", "Swift")
        XCTAssertEqual(counts[.comment], 1)
    }

    func testSwiftStringBeforeCommentRuleWins() {
        // `http://x` inside a string must not be split by the comment rule.
        let tokens = SyntaxHighlighter.tokens(line: #"let u = "http://x""#, language: "Swift")
        let strings = tokens.filter { $0.kind == .string }
        XCTAssertEqual(strings.count, 1, "\(strings)")
    }

    // MARK: - Go (regression: string rule never matched)

    func testGoStringsAreHighlighted() {
        let tokens = SyntaxHighlighter.tokens(line: #"req.Header.Set("A", "b")"#, language: "Go")
        let strings = tokens.filter { $0.kind == .string }
        XCTAssertEqual(strings.count, 2, "Go strings must be highlighted: \(strings)")
        XCTAssertEqual(strings[0].text, #""A""#)
    }

    func testGoRawString() {
        let tokens = SyntaxHighlighter.tokens(line: "s := `raw`", language: "Go")
        XCTAssertTrue(tokens.contains { $0.kind == .string && $0.text == "`raw`" }, "\(tokens)")
    }

    // MARK: - Shell (curl input highlighting)

    func testShellKeywordAndString() {
        let tokens = SyntaxHighlighter.tokens(line: "curl -H 'A: 1' https://x", language: "Shell")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "curl" }, "\(tokens)")
        XCTAssertTrue(tokens.contains { $0.kind == .string && $0.text == "'A: 1'" }, "\(tokens)")
    }

    func testShellFlagIsHighlighted() {
        let tokens = SyntaxHighlighter.tokens(line: "curl --header \"A: b\"", language: "Shell")
        XCTAssertTrue(tokens.contains { $0.text == "--header" && $0.kind != .plain }, "\(tokens)")
    }

    func testShellComment() {
        let tokens = SyntaxHighlighter.tokens(line: "# fetch it", language: "Shell")
        XCTAssertTrue(tokens.contains { $0.kind == .comment }, "\(tokens)")
    }

    // MARK: - Python / JS / PHP / Java basics

    func testPythonKeywordAndComment() {
        let counts = kinds("def f():  # note", "Python")
        XCTAssertEqual(counts[.keyword], 1)
        XCTAssertEqual(counts[.comment], 1)
    }

    func testJavaScriptStringTemplate() {
        let counts = kinds("const s = `tpl`", "JavaScript")
        XCTAssertEqual(counts[.string], 1)
    }

    func testPHPVariable() {
        let counts = kinds("$ch = curl_init();", "PHP")
        XCTAssertEqual(counts[.variable], 1)
    }

    func testJavaKeyword() {
        let counts = kinds("public class Main {}", "Java")
        XCTAssertEqual(counts[.keyword] ?? 0, 2)
    }

    // MARK: - Performance guards

    /// Tokenizing must not recompile regexes per call — verified indirectly
    /// via a large workload completing quickly.
    func testTokenizingLargeInputIsFast() {
        let lines = Array(repeating: #"let a = "x" + b.c(1) // c"#, count: 2000)
        let start = Date()
        for line in lines {
            _ = SyntaxHighlighter.tokens(line: line, language: "Swift")
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 5.0, "2000 lines took \(elapsed)s")
    }

    /// Line caching: same input twice returns equal results (and hits cache).
    func testLineCacheReturnsSameResult() {
        let line = #"print("hi")"#
        let first = SyntaxHighlighter.tokens(line: line, language: "Python")
        let second = SyntaxHighlighter.tokens(line: line, language: "Python")
        XCTAssertEqual(first.map(\.text), second.map(\.text))
        XCTAssertEqual(first.map(\.kind), second.map(\.kind))
    }
}
