import XCTest
@testable import OpenDevUtils

final class TokenCounterTests: XCTestCase {
    
    struct TokenStats {
        let text: String
        let charsPerToken: Double
        
        var characters: Int { text.count }
        var bytes: Int { text.utf8.count }
        
        var words: Int {
            text.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }.count
        }
        
        var lines: Int {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? 0 : trimmed.components(separatedBy: "\n").count
        }
        
        var chineseChars: Int {
            text.unicodeScalars.filter {
                ($0.value >= 0x4E00 && $0.value <= 0x9FFF) ||
                ($0.value >= 0x3400 && $0.value <= 0x4DBF)
            }.count
        }
        
        var englishWords: Int {
            text.components(separatedBy: .alphanumerics.inverted)
                .filter { !$0.isEmpty && $0.range(of: "[a-zA-Z]", options: .regularExpression) != nil }.count
        }
        
        var estimatedTokens: Int {
            if text.isEmpty { return 0 }
            let chineseTokenCount = chineseChars * 2
            let remaining = text.replacingOccurrences(
                of: "[\\p{Han}\\p{Hiragana}\\p{Katakana}\\p{Hangul}]",
                with: "", options: .regularExpression
            )
            let remainingTokens = Int(ceil(Double(remaining.count) / charsPerToken))
            return chineseTokenCount + remainingTokens
        }
    }
    
    func testEmptyText() {
        let stats = TokenStats(text: "", charsPerToken: 4.0)
        XCTAssertEqual(stats.characters, 0)
        XCTAssertEqual(stats.words, 0)
        XCTAssertEqual(stats.lines, 0)
        XCTAssertEqual(stats.estimatedTokens, 0)
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
