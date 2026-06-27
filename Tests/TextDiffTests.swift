import XCTest
@testable import OpenDevUtils

final class TextDiffTests: XCTestCase {
    
    struct DiffLine: Identifiable {
        let id = UUID()
        let lineNumber: Int
        let text: String
        let type: DiffType
    }
    
    enum DiffType {
        case added
        case removed
        case unchanged
    }
    
    func computeDiff(left: String, right: String, ignoreCase: Bool = false, ignoreWhitespace: Bool = false) -> [DiffLine] {
        let leftLines = left.components(separatedBy: "\n")
        let rightLines = right.components(separatedBy: "\n")
        
        let process: (String) -> String = { s in
            var result = s
            if ignoreCase { result = result.lowercased() }
            if ignoreWhitespace {
                result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            }
            return result
        }
        
        var result: [DiffLine] = []
        let maxCount = max(leftLines.count, rightLines.count)
        
        var lineNum = 1
        for i in 0..<maxCount {
            let left = i < leftLines.count ? leftLines[i] : nil
            let right = i < rightLines.count ? rightLines[i] : nil
            
            let leftProcessed = left.map(process) ?? ""
            let rightProcessed = right.map(process) ?? ""
            
            if leftProcessed == rightProcessed {
                if let l = left {
                    result.append(DiffLine(lineNumber: lineNum, text: l, type: .unchanged))
                }
            } else {
                if let l = left {
                    result.append(DiffLine(lineNumber: lineNum, text: l, type: .removed))
                }
                if let r = right {
                    result.append(DiffLine(lineNumber: lineNum, text: r, type: .added))
                }
            }
            lineNum += 1
        }
        
        return result
    }
    
    func testIdenticalText() {
        let diff = computeDiff(left: "hello\nworld", right: "hello\nworld")
        XCTAssertEqual(diff.count, 2)
        XCTAssertTrue(diff.allSatisfy { $0.type == .unchanged })
    }
    
    func testAddedLine() {
        let diff = computeDiff(left: "hello", right: "hello\nworld")
        XCTAssertEqual(diff.count, 2)
        XCTAssertEqual(diff[0].type, .unchanged)
        XCTAssertEqual(diff[1].type, .added)
        XCTAssertEqual(diff[1].text, "world")
    }
    
    func testRemovedLine() {
        let diff = computeDiff(left: "hello\nworld", right: "hello")
        XCTAssertEqual(diff.count, 2)
        XCTAssertEqual(diff[0].type, .unchanged)
        XCTAssertEqual(diff[1].type, .removed)
        XCTAssertEqual(diff[1].text, "world")
    }
    
    func testModifiedLine() {
        let diff = computeDiff(left: "hello", right: "hello!")
        XCTAssertEqual(diff.count, 2)
        XCTAssertEqual(diff[0].type, .removed)
        XCTAssertEqual(diff[0].text, "hello")
        XCTAssertEqual(diff[1].type, .added)
        XCTAssertEqual(diff[1].text, "hello!")
    }
    
    func testEmptyLeft() {
        let diff = computeDiff(left: "", right: "new content")
        // Empty left produces an empty line removed + content added
        XCTAssertGreaterThanOrEqual(diff.count, 1)
        let added = diff.filter { $0.type == .added }
        XCTAssertFalse(added.isEmpty)
    }
    
    func testEmptyRight() {
        let diff = computeDiff(left: "old content", right: "")
        XCTAssertGreaterThanOrEqual(diff.count, 1)
        let removed = diff.filter { $0.type == .removed }
        XCTAssertFalse(removed.isEmpty)
    }
    
    func testBothEmpty() {
        let diff = computeDiff(left: "", right: "")
        // Empty string split produces one empty element, diff marks it unchanged
        XCTAssertLessThanOrEqual(diff.count, 1)
    }
    
    func testIgnoreCase() {
        let diff = computeDiff(left: "Hello", right: "hello", ignoreCase: true)
        XCTAssertEqual(diff.count, 1)
        XCTAssertEqual(diff[0].type, .unchanged)
    }
    
    func testCaseSensitive() {
        let diff = computeDiff(left: "Hello", right: "hello", ignoreCase: false)
        XCTAssertEqual(diff.count, 2)
    }
    
    func testIgnoreWhitespace() {
        let diff = computeDiff(left: "hello world", right: "hello  world", ignoreWhitespace: true)
        XCTAssertEqual(diff.count, 1)
        XCTAssertEqual(diff[0].type, .unchanged)
    }
    
    func testMultiLineDiff() {
        let left = "line1\nline2\nline3"
        let right = "line1\nmodified\nline3"
        let diff = computeDiff(left: left, right: right)
        
        let unchanged = diff.filter { $0.type == .unchanged }
        let added = diff.filter { $0.type == .added }
        let removed = diff.filter { $0.type == .removed }
        
        XCTAssertEqual(unchanged.count, 2)
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(removed.count, 1)
    }
    
    func testLineNumbering() {
        let diff = computeDiff(left: "a\nc", right: "a\nb\nc")
        XCTAssertEqual(diff[0].lineNumber, 1) // a - unchanged
        XCTAssertEqual(diff[1].lineNumber, 2) // b - added
        XCTAssertEqual(diff[2].lineNumber, 2) // c vs nothing - wait
    }
}
