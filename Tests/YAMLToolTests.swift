import XCTest
@testable import OpenDevUtils

final class YAMLToolTests: XCTestCase {
    
    // MARK: - YAML Emitter Tests (all pass)
    
    func testEmitString() {
        let output = YAMLEmit.emit("hello")
        XCTAssertEqual(output, "hello")
    }
    
    func testEmitInteger() {
        let output = YAMLEmit.emit(42)
        XCTAssertEqual(output, "42")
    }
    
    func testEmitDouble() {
        let output = YAMLEmit.emit(3.14)
        XCTAssertEqual(output, "3.14")
    }
    
    func testEmitBool() {
        XCTAssertEqual(YAMLEmit.emit(true), "true")
        XCTAssertEqual(YAMLEmit.emit(false), "false")
    }
    
    func testEmitNull() {
        let output = YAMLEmit.emit(NSNull())
        XCTAssertEqual(output, "null")
    }
    
    func testEmitSimpleDict() {
        let dict: [String: Any] = ["name": "test", "value": 42]
        let output = YAMLEmit.emit(dict)
        XCTAssertTrue(output.contains("name: test"))
        XCTAssertTrue(output.contains("value: 42"))
    }
    
    func testEmitArray() {
        let arr = ["apple", "banana", "cherry"]
        let output = YAMLEmit.emit(arr)
        XCTAssertTrue(output.contains("- apple"))
        XCTAssertTrue(output.contains("- banana"))
        XCTAssertTrue(output.contains("- cherry"))
    }
    
    func testEmitNestedDict() {
        let dict: [String: Any] = [
            "user": [
                "name": "Alice",
                "age": 30
            ]
        ]
        let output = YAMLEmit.emit(dict)
        XCTAssertTrue(output.contains("user:"))
        XCTAssertTrue(output.contains("name: Alice"))
    }
    
    func testEmitStringWithSpecialChars() {
        let dict: [String: Any] = ["key": "value: with colon"]
        let output = YAMLEmit.emit(dict)
        XCTAssertTrue(output.contains("\"value: with colon\""))
    }
    
    func testEmitEmptyDict() {
        let dict: [String: Any] = [:]
        let output = YAMLEmit.emit(dict)
        XCTAssertTrue(output.isEmpty)
    }
    
    func testEmitNestedArray() {
        let dict: [String: Any] = [
            "items": ["a", "b", "c"]
        ]
        let output = YAMLEmit.emit(dict)
        XCTAssertTrue(output.contains("items:"))
        XCTAssertTrue(output.contains("- a"))
    }
}
