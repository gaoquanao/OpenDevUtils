import XCTest
@testable import OpenDevUtils

/// Tests for RegexRunner — the engine extracted from RegexTool so limits can
/// be enforced (and tested) independently of the UI.
/// Review findings addressed:
/// - match results were unbounded (memory blow-up on `.` over large input)
/// - no way to stop after a time budget (ReDoS mitigation between matches)
/// - everything ran synchronously on the main thread
final class RegexRunnerTests: XCTestCase {

    func testBasicMatchWithGroups() {
        let result = RegexRunner.run(pattern: #"a(b)c"#, input: "abc abc")
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.matches.count, 2)
        XCTAssertEqual(result.matches[0].text, "abc")
        XCTAssertEqual(result.matches[0].groups, ["b"])
        XCTAssertFalse(result.truncated)
        XCTAssertFalse(result.timedOut)
    }

    func testOptionsAreApplied() {
        let result = RegexRunner.run(pattern: "abc", input: "ABC", options: [.caseInsensitive])
        XCTAssertEqual(result.matches.count, 1)
    }

    func testInvalidPatternReportsInvalidPattern() {
        let result = RegexRunner.run(pattern: "(", input: "x")
        XCTAssertEqual(result.status, .invalidPattern)
        XCTAssertTrue(result.matches.isEmpty)
    }

    func testMatchCapTruncates() {
        let input = String(repeating: "x", count: 500)
        let result = RegexRunner.run(pattern: "x", input: input, maxMatches: 10)
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.matches.count, 10)
        XCTAssertTrue(result.truncated)
    }

    func testInputSizeLimit() {
        let input = String(repeating: "a", count: 100)
        let result = RegexRunner.run(pattern: "a", input: input, maxInputBytes: 10)
        XCTAssertEqual(result.status, .tooLarge)
        XCTAssertTrue(result.matches.isEmpty)
    }

    /// A deadline in the past must abort between matches instead of
    /// collecting millions of results.
    func testDeadlineStopsMatching() {
        let input = String(repeating: "a", count: 1000)
        let result = RegexRunner.run(pattern: "a", input: input, deadline: Date.distantPast)
        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.timedOut)
        XCTAssertTrue(result.matches.count < 1000, "expected early stop, got \(result.matches.count)")
    }

    func testNoMatchIsSuccessWithEmptyMatches() {
        let result = RegexRunner.run(pattern: "z+", input: "aaa")
        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.matches.isEmpty)
        XCTAssertFalse(result.truncated)
        XCTAssertFalse(result.timedOut)
    }

    /// Zero-width matches must not loop forever or explode the result set.
    func testZeroWidthMatchesAreCapped() {
        let input = String(repeating: "b", count: 50)
        let result = RegexRunner.run(pattern: "a*", input: input, maxMatches: 100)
        XCTAssertLessThanOrEqual(result.matches.count, 100)
        XCTAssertEqual(result.status, .success)
    }

    func testUTF16RangesAreCaptured() {
        let result = RegexRunner.run(pattern: #"[一-龥]+"#, input: "中文abc")
        XCTAssertEqual(result.matches.count, 1)
        XCTAssertEqual(result.matches[0].text, "中文")
        XCTAssertEqual(result.matches[0].range, NSRange(location: 0, length: 2))
    }
}
