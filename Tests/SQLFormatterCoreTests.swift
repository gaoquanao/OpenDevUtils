import XCTest
@testable import OpenDevUtils

/// Tests for SQL formatting core (SQLFormatterTool's logic extracted into a
/// testable type). Covers the bugs reported in review:
/// - string literals / comments were rewritten as keywords and got newlines
///   injected into them (user data corruption)
/// - indent level only ever grew (any line containing `(` raised it, only
///   lines starting with `)` lowered it)
final class SQLFormatterCoreTests: XCTestCase {

    private func fmt(_ sql: String,
                     indentSize: Int = 2,
                     keywordCase: SQLFormatterCore.KeywordCase = .upper) -> String {
        SQLFormatterCore.format(sql, indentSize: indentSize, keywordCase: keywordCase)
    }

    // MARK: - Literal & comment protection

    /// Regression: `WHERE note = 'john and mary'` used to become
    /// `WHERE note = 'john\nAND mary'` — a newline injected inside the string.
    func testStringLiteralIsNotRewrittenOrSplit() {
        let out = fmt("select * from t where note = 'john and mary'")
        XCTAssertTrue(out.contains("'john and mary'"), out)
        XCTAssertFalse(out.contains("john\nAND"), out)
        XCTAssertFalse(out.contains("john\nand"), out.lowercased())
    }

    /// Regression: keywords inside literals were case-transformed.
    func testKeywordCaseDoesNotTouchLiterals() {
        let out = fmt("select name from t where name = 'Select From'", keywordCase: .upper)
        XCTAssertTrue(out.contains("'Select From'"), out)
    }

    /// Regression: line comments were rewritten and split.
    func testLineCommentIsPreserved() {
        let out = fmt("select a from t -- this is a select\nwhere a = 1")
        XCTAssertTrue(out.contains("-- this is a select"), out)
        XCTAssertFalse(out.contains("-- this is a\nSELECT"), out)
    }

    func testBlockCommentIsPreserved() {
        let out = fmt("select a /* select from */ from t")
        XCTAssertTrue(out.contains("/* select from */"), out)
    }

    func testQuotedIdentifierIsPreserved() {
        let out = fmt("select \"Order\" from t", keywordCase: .lower)
        XCTAssertTrue(out.contains("\"Order\""), out)
        XCTAssertTrue(out.contains("from"), out)
    }

    /// Parens inside string literals must not affect indentation.
    func testParenInsideLiteralDoesNotAffectIndent() {
        let out = fmt("select a from t where b in ('x)y') and c = 1")
        for line in out.components(separatedBy: "\n") {
            let leading = line.prefix(while: { $0 == " " }).count
            XCTAssertLessThanOrEqual(leading, 2, out)
        }
    }

    // MARK: - Keyword case

    func testKeywordCaseUpper() {
        let out = fmt("select a from t")
        XCTAssertTrue(out.contains("SELECT"), out)
        XCTAssertTrue(out.contains("FROM"), out)
    }

    func testKeywordCaseLower() {
        let out = fmt("SELECT a FROM t", keywordCase: .lower)
        XCTAssertTrue(out.contains("select"), out)
        XCTAssertTrue(out.contains("from"), out)
    }

    func testKeywordCaseCapitalize() {
        let out = fmt("select a from t", keywordCase: .capitalize)
        XCTAssertTrue(out.contains("Select"), out)
        XCTAssertFalse(out.contains("SELECT"), out)
    }

    /// `SET` must not shadow `SELECT` (alternatives are matched with \b so
    /// ordering matters less, but regression-guard the whole-word match).
    func testShortKeywordDoesNotTruncateLongerOne() {
        let out = fmt("select a from t")
        XCTAssertTrue(out.contains("SELECT"), out)
        XCTAssertFalse(out.contains("SETLECT"), out)
        // `SET` must not shadow `SELECT` — the whole keyword is uppercased.
        XCTAssertTrue(out.contains("SELECT a"), out)
    }

    // MARK: - Indentation

    /// Regression: every line containing `(` raised the indent level forever,
    /// so multi-statement SQL ended up with dozens of leading spaces.
    func testIndentDoesNotRunAway() {
        let sql = "select count(*), name from t; select count(*), name from t2"
        let out = fmt(sql)
        for line in out.components(separatedBy: "\n") {
            let leading = line.prefix(while: { $0 == " " }).count
            XCTAssertLessThanOrEqual(leading, 4, out)
        }
    }

    func testIndentIncreasesInsideParensAndClosesBack() {
        let out = fmt("select a from (select b from t) x")
        let lines = out.components(separatedBy: "\n").filter { !$0.isEmpty }
        // Opening a subquery increases indent; the closing line returns to 0.
        XCTAssertTrue(lines.contains { $0.hasPrefix("  ") }, out)
        XCTAssertTrue(lines.last?.hasPrefix("  ") != true, out)
    }

    func testIndentSizeIsRespected() {
        let out = fmt("select a from (select b from t) x", indentSize: 4)
        XCTAssertTrue(out.contains("\n    "), out)
    }

    func testClosingParenLineIsDedented() {
        let out = fmt("select a from (select b from t)")
        let lines = out.components(separatedBy: "\n")
        if let close = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(")") }) {
            XCTAssertFalse(close.hasPrefix("   "), out)
        }
    }

    // MARK: - Misc

    func testEmptyInputReturnsEmpty() {
        XCTAssertEqual(fmt(""), "")
        XCTAssertEqual(fmt("   "), "")
    }

    func testNewlinesInsertedBeforeMajorKeywords() {
        let out = fmt("select a, b from t where a = 1")
        let lines = out.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        XCTAssertTrue(lines.contains { $0.hasPrefix("WHERE") }, out)
        XCTAssertTrue(lines.contains { $0.hasPrefix("FROM") }, out)
    }

    /// The placeholder machinery must not leak control characters.
    func testNoPlaceholderLeakage() {
        let out = fmt("select 'a b', \"c d\" from t where x = 'e f'")
        XCTAssertFalse(out.contains("\u{1}"), out.unicodeScalars.map(String.init).joined(separator: " "))
    }

    func testMultilineInputKeepsLiteralIntact() {
        let out = fmt("select a from t\nwhere b = 'x\ny'")
        XCTAssertTrue(out.contains("'x\ny'"), out)
    }
}
