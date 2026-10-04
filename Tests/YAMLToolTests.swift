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
    
    /// Regression: an empty mapping emitted an empty string, so the output
    /// pane went blank and Copy was disabled. `{}` round-trips correctly.
    func testEmitEmptyDict() {
        let dict: [String: Any] = [:]
        XCTAssertEqual(YAMLEmit.emit(dict), "{}")
    }

    func testEmitEmptyArray() {
        XCTAssertEqual(YAMLEmit.emit([Any]()), "[]")
    }

    func testEmitNestedEmptyContainers() {
        XCTAssertEqual(YAMLEmit.emit(["a": [String: Any]()]), "a: {}")
        XCTAssertEqual(YAMLEmit.emit(["a": [Any]()]), "a: []")
    }
    
    func testEmitNestedArray() {
        let dict: [String: Any] = [
            "items": ["a", "b", "c"]
        ]
        let output = YAMLEmit.emit(dict)
        XCTAssertTrue(output.contains("items:"))
        XCTAssertTrue(output.contains("- a"))
    }

    // MARK: - Values coming from JSONSerialization (NSNumber)

    /// Regression: `NSNumber(1) as? Bool` succeeds, so numbers parsed from
    /// JSON used to be emitted as `true`/`false` — silent data corruption.
    func testEmitJSONNumbersAreNotBools() {
        let json = #"{"a":0,"b":1,"c":2,"d":1.5}"#
        let obj = try! JSONSerialization.jsonObject(with: Data(json.utf8))
        let output = YAMLEmit.emit(obj)
        XCTAssertTrue(output.contains("a: 0"), output)
        XCTAssertTrue(output.contains("b: 1"), output)
        XCTAssertTrue(output.contains("c: 2"), output)
        XCTAssertTrue(output.contains("d: 1.5"), output)
        XCTAssertFalse(output.contains("true"), output)
        XCTAssertFalse(output.contains("false"), output)
    }

    func testEmitJSONBoolStaysBool() {
        let json = #"{"flag":true,"off":false}"#
        let obj = try! JSONSerialization.jsonObject(with: Data(json.utf8))
        let output = YAMLEmit.emit(obj)
        XCTAssertTrue(output.contains("flag: true"), output)
        XCTAssertTrue(output.contains("off: false"), output)
    }

    func testEmitJSONNull() {
        let json = #"{"v":null}"#
        let obj = try! JSONSerialization.jsonObject(with: Data(json.utf8))
        XCTAssertTrue(YAMLEmit.emit(obj).contains("v: null"))
    }

    // MARK: - Array of objects indentation

    /// Regression: continuation lines of an object inside an array were not
    /// indented under the `- ` marker, producing invalid YAML.
    func testEmitArrayOfObjectsIsValidYAML() {
        let dict: [String: Any] = ["items": [["a": 1, "b": 2]]]
        let output = YAMLEmit.emit(dict)
        XCTAssertEqual(output, "items:\n  - a: 1\n    b: 2")
    }

    func testEmitArrayOfObjectsWithNestedDict() {
        let dict: [String: Any] = ["items": [["name": "x", "meta": ["k": "v"]]]]
        let output = YAMLEmit.emit(dict)
        let lines = output.components(separatedBy: "\n")
        XCTAssertEqual(lines[0], "items:")
        // keys are emitted sorted: meta before name
        XCTAssertEqual(lines[1], "  - meta:")
        XCTAssertEqual(lines[2], "      k: v")
        XCTAssertEqual(lines[3], "    name: x")
    }

    func testEmitTopLevelArrayOfObjects() {
        let arr: [Any] = [["a": 1], ["b": 2]]
        let output = YAMLEmit.emit(arr)
        XCTAssertEqual(output, "- a: 1\n- b: 2")
    }

    // MARK: - Nested arrays (review finding: emitted Swift description)

    /// Regression: a nested array fell through to `"\(obj)"` and produced
    /// NSArray's debug description — completely invalid YAML.
    func testEmitNestedArrayDoesNotLeakSwiftDescription() {
        let dict: [String: Any] = ["m": [[1, 2], [3]]]
        let output = YAMLEmit.emit(dict)
        XCTAssertFalse(output.contains("("), output)
        XCTAssertFalse(output.contains("Swift."), output)
        XCTAssertTrue(output.contains("- 1"), output)
        XCTAssertTrue(output.contains("- 3"), output)
    }

    func testEmitNestedArrayInsideArray() {
        let output = YAMLEmit.emit([[1, 2], [3]])
        XCTAssertFalse(output.contains("description"), output)
        XCTAssertTrue(output.contains("- 1"), output)
    }

    // MARK: - String quoting (review finding: "123" lost its type)

    /// Regression: a string that looks like a number was emitted bare and
    /// parsed back as a number.
    func testEmitNumericLookingStringIsQuoted() {
        XCTAssertEqual(YAMLEmit.emit(["v": "123"]), "v: \"123\"")
        XCTAssertEqual(YAMLEmit.emit(["v": "1.5"]), "v: \"1.5\"")
    }

    func testEmitBooleanLookingStringIsQuoted() {
        XCTAssertEqual(YAMLEmit.emit(["v": "true"]), "v: \"true\"")
        XCTAssertEqual(YAMLEmit.emit(["v": "null"]), "v: \"null\"")
    }

    func testEmitStringWithNewlineIsEscaped() {
        let output = YAMLEmit.emit(["v": "a\nb"])
        XCTAssertTrue(output.contains("\\n"), output)
        XCTAssertEqual(output.components(separatedBy: "\n").count, 1, "must stay on one line: \(output)")
    }

    func testEmitStringWithBackslashIsEscaped() {
        let output = YAMLEmit.emit(["v": "a\\b"])
        XCTAssertTrue(output.contains("\\\\") || output.contains("a\\\\b"), output)
    }

    /// Bare strings that would be misinterpreted must be quoted, ordinary
    /// words must stay bare.
    func testEmitOrdinaryStringStaysBare() {
        XCTAssertEqual(YAMLEmit.emit(["v": "hello"]), "v: hello")
    }

    // MARK: - Round trip: emit then parse

    func testEmitParseRoundTripPreservesTypes() {
        let original: [String: Any] = [
            "name": "Alice",
            "age": 30,
            "score": 1.5,
            "active": true,
            "missing": NSNull(),
            "numeric": "123",
            "tags": ["a", "b"],
        ]
        let yaml = YAMLEmit.emit(original)
        guard let parsed = (try? YAMLParse.parse(yaml)) as? [String: Any] else {
            return XCTFail("round trip parse failed for:\n\(yaml)")
        }
        XCTAssertEqual(parsed["name"] as? String, "Alice")
        XCTAssertEqual(parsed["age"] as? Int, 30)
        XCTAssertEqual(parsed["score"] as? Double, 1.5)
        XCTAssertEqual(parsed["active"] as? Bool, true)
        XCTAssertTrue(parsed["missing"] is NSNull)
        XCTAssertEqual(parsed["numeric"] as? String, "123", "type must survive round trip")
        XCTAssertEqual(parsed["tags"] as? [String], ["a", "b"])
    }
}
