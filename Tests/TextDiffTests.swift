import XCTest
@testable import OpenDevUtils

/// Tests that exercise the production diff implementation (`DiffCalculator`).
/// The previous version of this file re-implemented a naive line comparison
/// and never touched the shipped LCS algorithm, which was broken.
final class TextDiffTests: XCTestCase {

    private func compute(left: String, right: String,
                         ignoreCase: Bool = false, ignoreWhitespace: Bool = false) -> [DiffLine] {
        DiffCalculator.compute(left: left, right: right,
                               ignoreCase: ignoreCase, ignoreWhitespace: ignoreWhitespace)
    }

    func testIdenticalText() {
        let diff = compute(left: "hello\nworld", right: "hello\nworld")
        XCTAssertEqual(diff.count, 2)
        XCTAssertTrue(diff.allSatisfy { $0.type == .unchanged })
        XCTAssertEqual(diff.map(\.lineNumber), [1, 2])
    }

    func testAddedLineAtEnd() {
        let diff = compute(left: "hello", right: "hello\nworld")
        XCTAssertEqual(diff.count, 2)
        XCTAssertEqual(diff[0].type, .unchanged)
        XCTAssertEqual(diff[0].text, "hello")
        XCTAssertEqual(diff[1].type, .added)
        XCTAssertEqual(diff[1].text, "world")
    }

    /// Regression: appending a line used to produce `+a +b -a`.
    func testAppendedLineKeepsOriginalUnchanged() {
        let diff = compute(left: "a", right: "a\nb")
        XCTAssertEqual(diff.map(\.type), [.unchanged, .added])
        XCTAssertEqual(diff.map(\.text), ["a", "b"])
    }

    func testRemovedLineAtEnd() {
        let diff = compute(left: "hello\nworld", right: "hello")
        XCTAssertEqual(diff.count, 2)
        XCTAssertEqual(diff[0].type, .unchanged)
        XCTAssertEqual(diff[1].type, .removed)
        XCTAssertEqual(diff[1].text, "world")
    }

    func testModifiedLine() {
        let diff = compute(left: "hello", right: "hello!")
        XCTAssertEqual(diff.count, 2)
        XCTAssertEqual(diff[0].type, .removed)
        XCTAssertEqual(diff[0].text, "hello")
        XCTAssertEqual(diff[1].type, .added)
        XCTAssertEqual(diff[1].text, "hello!")
    }

    /// Regression: modifying a middle line used to re-emit the unchanged
    /// leading lines as additions.
    func testModifiedMiddleLine() {
        let diff = compute(left: "line1\nline2\nline3",
                           right: "line1\nmodified\nline3")
        XCTAssertEqual(diff.map(\.type), [.unchanged, .removed, .added, .unchanged])
        XCTAssertEqual(diff.map(\.text), ["line1", "line2", "modified", "line3"])
    }

    func testEmptyLeft() {
        let diff = compute(left: "", right: "new content")
        XCTAssertEqual(diff.count, 1)
        XCTAssertEqual(diff[0].type, .added)
        XCTAssertEqual(diff[0].text, "new content")
    }

    func testEmptyRight() {
        let diff = compute(left: "old content", right: "")
        XCTAssertEqual(diff.count, 1)
        XCTAssertEqual(diff[0].type, .removed)
        XCTAssertEqual(diff[0].text, "old content")
    }

    func testBothEmpty() {
        XCTAssertTrue(compute(left: "", right: "").isEmpty)
    }

    func testIgnoreCase() {
        let diff = compute(left: "Hello", right: "hello", ignoreCase: true)
        XCTAssertEqual(diff.count, 1)
        XCTAssertEqual(diff[0].type, .unchanged)
    }

    func testCaseSensitive() {
        let diff = compute(left: "Hello", right: "hello", ignoreCase: false)
        XCTAssertEqual(diff.count, 2)
        XCTAssertEqual(diff.map(\.type), [.removed, .added])
    }

    func testIgnoreWhitespace() {
        let diff = compute(left: "hello world", right: "hello  world", ignoreWhitespace: true)
        XCTAssertEqual(diff.count, 1)
        XCTAssertEqual(diff[0].type, .unchanged)
    }

    func testMultiLineCounts() {
        let diff = compute(left: "line1\nline2\nline3",
                           right: "line1\nmodified\nline3")
        XCTAssertEqual(diff.filter { $0.type == .unchanged }.count, 2)
        XCTAssertEqual(diff.filter { $0.type == .added }.count, 1)
        XCTAssertEqual(diff.filter { $0.type == .removed }.count, 1)
    }

    func testLineNumberingIsSequential() {
        let diff = compute(left: "a\nc", right: "a\nb\nc")
        XCTAssertEqual(diff.map(\.text), ["a", "b", "c"])
        XCTAssertEqual(diff.map(\.type), [.unchanged, .added, .unchanged])
        XCTAssertEqual(diff.map(\.lineNumber), [1, 2, 3])
    }

    func testInsertInMiddle() {
        let diff = compute(left: "one\ntwo", right: "one\ninserted\ntwo")
        XCTAssertEqual(diff.map(\.type), [.unchanged, .added, .unchanged])
        XCTAssertEqual(diff.map(\.text), ["one", "inserted", "two"])
    }

    /// Inputs above the LCS cell budget must fall back to a block replace
    /// instead of computing an unbounded O(m·n) table (which froze the UI).
    func testOversizedInputUsesBoundedFallback() {
        let left = (0..<2500).map { "left-\($0)" }.joined(separator: "\n")
        let right = (0..<2500).map { "right-\($0)" }.joined(separator: "\n")

        let start = Date()
        let diff = compute(left: left, right: right)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(diff.count, 5000)
        XCTAssertEqual(diff.filter { $0.type == .removed }.count, 2500)
        XCTAssertEqual(diff.filter { $0.type == .added }.count, 2500)
        XCTAssertEqual(diff.first?.type, .removed)
        XCTAssertEqual(diff.last?.type, .added)
        XCTAssertLessThan(elapsed, 10, "fallback must stay fast")
    }
}
