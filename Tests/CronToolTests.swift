import XCTest
@testable import OpenDevUtils

/// Tests for cron field parsing/matching helpers used by CronTool.
/// Covers the `*/0` divide-by-zero crash, mixed range/list fields,
/// whitespace/newline splitting and Sunday (7) handling.
final class CronToolTests: XCTestCase {

    // MARK: - Field splitting

    func testSplitFieldsNormal() {
        let parts = CronTool.splitFields("*/5 0 1,15 * 1-5")
        XCTAssertEqual(parts, ["*/5", "0", "1,15", "*", "1-5"])
    }

    func testSplitFieldsCollapsesExtraWhitespace() {
        let parts = CronTool.splitFields("  */5   0  1,15   *   1-5  ")
        XCTAssertEqual(parts.count, 5)
        XCTAssertEqual(parts[0], "*/5")
        XCTAssertEqual(parts[4], "1-5")
    }

    func testSplitFieldsWithNewlines() {
        // Pasted expressions often carry trailing newlines (\n is not
        // in .whitespaces, so the old splitter produced a 6th "field").
        let parts = CronTool.splitFields("0\n0\n1\n*\n*")
        XCTAssertEqual(parts.count, 5)
        XCTAssertEqual(parts, ["0", "0", "1", "*", "*"])
    }

    func testSplitFieldsWithCRLF() {
        let parts = CronTool.splitFields("*/5 0 1,15 *\r\n1-5\r\n")
        XCTAssertEqual(parts.count, 5)
        XCTAssertEqual(parts[4], "1-5")
    }

    // MARK: - matchField

    func testMatchWildcard() {
        XCTAssertTrue(CronTool.matchField("*", value: 42, min: 0, max: 59))
    }

    func testMatchPlainValue() {
        XCTAssertTrue(CronTool.matchField("42", value: 42, min: 0, max: 59))
        XCTAssertFalse(CronTool.matchField("42", value: 41, min: 0, max: 59))
    }

    func testMatchStep() {
        XCTAssertTrue(CronTool.matchField("*/15", value: 30, min: 0, max: 59))
        XCTAssertTrue(CronTool.matchField("*/15", value: 45, min: 0, max: 59))
        XCTAssertFalse(CronTool.matchField("*/15", value: 31, min: 0, max: 59))
    }

    /// Regression: `*/0` (and `5-10/0`) used to reach `value % 0` → crash.
    func testMatchZeroStepDoesNotCrash() {
        XCTAssertFalse(CronTool.matchField("*/0", value: 0, min: 0, max: 59))
        XCTAssertFalse(CronTool.matchField("5-10/0", value: 5, min: 0, max: 59))
        XCTAssertFalse(CronTool.matchField("1/0", value: 1, min: 0, max: 59))
        XCTAssertFalse(CronTool.matchField("*/-1", value: 0, min: 0, max: 59))
    }

    func testMatchRangeWithStep() {
        XCTAssertTrue(CronTool.matchField("5-20/5", value: 10, min: 0, max: 59))
        XCTAssertFalse(CronTool.matchField("5-20/5", value: 11, min: 0, max: 59))
        XCTAssertFalse(CronTool.matchField("5-20/5", value: 25, min: 0, max: 59))
    }

    /// Regression: `1-5,10` used to be parsed as a plain range only when no
    /// comma was present; with a comma the range part silently stopped working.
    func testMatchMixedRangeAndList() {
        XCTAssertTrue(CronTool.matchField("1-5,10", value: 3, min: 0, max: 59))
        XCTAssertTrue(CronTool.matchField("1-5,10", value: 10, min: 0, max: 59))
        XCTAssertFalse(CronTool.matchField("1-5,10", value: 7, min: 0, max: 59))
        XCTAssertFalse(CronTool.matchField("1-5,10", value: 0, min: 0, max: 59))
    }

    func testMatchList() {
        XCTAssertTrue(CronTool.matchField("1,15", value: 15, min: 0, max: 59))
        XCTAssertFalse(CronTool.matchField("1,15", value: 2, min: 0, max: 59))
    }

    func testMatchRange() {
        XCTAssertTrue(CronTool.matchField("10-20", value: 15, min: 0, max: 59))
        XCTAssertFalse(CronTool.matchField("10-20", value: 21, min: 0, max: 59))
    }

    /// Standard cron: weekday 7 == Sunday == 0. `comps.weekday - 1` yields
    /// 0 for Sunday, so the literal `7` must be normalized.
    func testWeekdaySevenIsSunday() {
        XCTAssertTrue(CronTool.matchField("7", value: 0, min: 0, max: 7))
        XCTAssertTrue(CronTool.matchField("0", value: 0, min: 0, max: 7))
        XCTAssertFalse(CronTool.matchField("7", value: 1, min: 0, max: 7))
        XCTAssertTrue(CronTool.matchField("5", value: 5, min: 0, max: 7))
        XCTAssertTrue(CronTool.matchField("5-7", value: 0, min: 0, max: 7), "range spanning Sunday")
    }

    func testInvalidGarbageReturnsFalseNotCrash() {
        XCTAssertFalse(CronTool.matchField("abc", value: 1, min: 0, max: 59))
        XCTAssertFalse(CronTool.matchField("", value: 1, min: 0, max: 59))
        XCTAssertFalse(CronTool.matchField("1-2-3", value: 2, min: 0, max: 59))
    }
}
