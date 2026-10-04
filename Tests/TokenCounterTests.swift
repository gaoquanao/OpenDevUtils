import XCTest
@testable import OpenDevUtils

/// Tests run against the production `TokenStats` (the previous version of this
/// file contained a stale copy of the struct and therefore never covered the
/// shipped implementation).
final class TokenCounterTests: XCTestCase {

    func testEmptyText() {
        let stats = TokenStats(text: "", charsPerToken: 4.0)
        XCTAssertEqual(stats.characters, 0)
        XCTAssertEqual(stats.words, 0)
        XCTAssertEqual(stats.lines, 0)
        XCTAssertEqual(stats.estimatedTokens, 0)
        XCTAssertEqual(stats.estimatedTokensMax, 0)
    }

    func testSimpleEnglish() {
        let stats = TokenStats(text: "Hello World", charsPerToken: 4.0)
        XCTAssertEqual(stats.characters, 11)
        XCTAssertEqual(stats.words, 2)
        XCTAssertEqual(stats.lines, 1)
        XCTAssertEqual(stats.englishWords, 2)
    }

    func testMultiLine() {
        let stats = TokenStats(text: "line1\nline2\nline3", charsPerToken: 4.0)
        XCTAssertEqual(stats.lines, 3)
        XCTAssertEqual(stats.words, 3)
    }

    func testChineseCharacters() {
        let stats = TokenStats(text: "你好世界", charsPerToken: 4.0)
        XCTAssertEqual(stats.chineseChars, 4)
        XCTAssertEqual(stats.estimatedTokens, 8) // 4 chars * 2 tokens each
        XCTAssertEqual(stats.estimatedTokensMax, 12) // 4 chars * 3 tokens each
    }

    /// Regression: pure Japanese text used to be stripped from the "remaining"
    /// text but never counted anywhere → "0 ~ 0 tokens".
    func testJapaneseKanaIsCounted() {
        let stats = TokenStats(text: "こんにちは", charsPerToken: 4.0)
        XCTAssertEqual(stats.chineseChars, 0, "kana are not Han characters")
        XCTAssertEqual(stats.cjkChars, 5)
        XCTAssertGreaterThan(stats.estimatedTokens, 0)
        XCTAssertGreaterThan(stats.estimatedTokensMax, stats.estimatedTokens)
    }

    /// Regression: pure Korean text used to be stripped but never counted.
    func testHangulIsCounted() {
        let stats = TokenStats(text: "안녕하세요", charsPerToken: 4.0)
        XCTAssertEqual(stats.chineseChars, 0)
        XCTAssertEqual(stats.cjkChars, 5)
        XCTAssertGreaterThan(stats.estimatedTokens, 0)
    }

    func testMixedCJKAndLatin() {
        let stats = TokenStats(text: "Hello 世界 こんにちは", charsPerToken: 4.0)
        XCTAssertEqual(stats.chineseChars, 2)
        XCTAssertEqual(stats.cjkChars, 7)
        XCTAssertEqual(stats.englishWords, 1)
        // 7 CJK * 2 + remaining "Hello  " (7 chars → ceil(7/4) = 2)
        XCTAssertEqual(stats.estimatedTokens, 16)
    }

    func testMixedLanguages() {
        let stats = TokenStats(text: "Hello 你好", charsPerToken: 4.0)
        XCTAssertEqual(stats.chineseChars, 2)
        XCTAssertEqual(stats.englishWords, 1)
    }

    func testByteCount() {
        let stats = TokenStats(text: "Hello", charsPerToken: 4.0)
        XCTAssertEqual(stats.bytes, 5) // ASCII: 1 byte per char
    }

    func testPunctuationCount() {
        let stats = TokenStats(text: "hi, there!", charsPerToken: 4.0)
        XCTAssertEqual(stats.punctuation, 2)
    }

    func testTokenEstimationGPT4() {
        let stats = TokenStats(text: "The quick brown fox jumps over the lazy dog", charsPerToken: 3.5)
        XCTAssertGreaterThan(stats.estimatedTokens, 0)
        XCTAssertLessThan(stats.estimatedTokens, 20)
    }

    func testTokenEstimationGPT35() {
        let stats = TokenStats(text: "The quick brown fox jumps over the lazy dog", charsPerToken: 4.0)
        XCTAssertGreaterThan(stats.estimatedTokens, 0)
        XCTAssertLessThan(stats.estimatedTokens, 20)
    }

    func testMaxIsNeverBelowMin() {
        let samples = ["Hello 世界", "こんにちは", "plain english text", "🎉 emoji 🎉", "a"]
        for sample in samples {
            let stats = TokenStats(text: sample, charsPerToken: 3.5)
            XCTAssertGreaterThanOrEqual(stats.estimatedTokensMax, stats.estimatedTokens, sample)
        }
    }

    func testWhitespaceOnly() {
        let stats = TokenStats(text: "   \n  \n  ", charsPerToken: 4.0)
        XCTAssertEqual(stats.lines, 0)
        XCTAssertEqual(stats.words, 0)
    }

    func testLongText() {
        let longText = String(repeating: "word ", count: 1000)
        let stats = TokenStats(text: longText, charsPerToken: 4.0)
        XCTAssertEqual(stats.words, 1000)
        XCTAssertGreaterThan(stats.estimatedTokens, 0)
    }
}
