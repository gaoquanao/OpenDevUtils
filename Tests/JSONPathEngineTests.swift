import XCTest
@testable import OpenDevUtils

final class JSONPathEngineTests: XCTestCase {
    let engine = JSONPathEngine()
    
    let sampleJSON: [String: Any] = [
        "store": [
            "book": [
                ["category": "reference", "author": "Nigel Rees", "title": "Sayings of the Century", "price": 8.95],
                ["category": "fiction", "author": "Evelyn Waugh", "title": "Sword of Honour", "price": 12.99],
                ["category": "fiction", "author": "Herman Melville", "title": "Moby Dick", "price": 8.99]
            ],
            "bicycle": ["color": "red", "price": 19.95]
        ]
    ]
    
    func testRootDollar() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$")
        XCTAssertEqual(results.count, 1)
    }
    
    func testChildAccess() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store")
        XCTAssertEqual(results.count, 1)
    }
    
    func testNestedChildAccess() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store.bicycle.color")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].value as? String, "red")
    }
    
    func testArrayAllElements() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store.book[*]")
        XCTAssertEqual(results.count, 3)
    }
    
    func testArrayByIndex() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store.book[0]")
        XCTAssertEqual(results.count, 1)
        let title = (results[0].value as? [String: Any])?["title"] as? String
        XCTAssertEqual(title, "Sayings of the Century")
    }
    
    func testArrayNegativeIndex() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store.book[-1]")
        XCTAssertEqual(results.count, 1)
        let title = (results[0].value as? [String: Any])?["title"] as? String
        XCTAssertEqual(title, "Moby Dick")
    }
    
    func testFilterGreaterThan() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store.book[?(@.price > 10)]")
        XCTAssertEqual(results.count, 1)
        let title = (results[0].value as? [String: Any])?["title"] as? String
        XCTAssertEqual(title, "Sword of Honour")
    }
    
    func testFilterLessThan() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store.book[?(@.price < 10)]")
        XCTAssertEqual(results.count, 2)
    }
    
    func testFilterEquals() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store.book[?(@.price == 8.95)]")
        XCTAssertEqual(results.count, 1)
    }
    
    func testWildcardRoot() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store[*]")
        XCTAssertEqual(results.count, 2)
    }
    
    func testChildByKey() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store.book[*].title")
        XCTAssertEqual(results.count, 3)
        let titles = results.map { $0.value as? String }
        XCTAssertTrue(titles.contains("Moby Dick"))
        XCTAssertTrue(titles.contains("Sword of Honour"))
        XCTAssertTrue(titles.contains("Sayings of the Century"))
    }
    
    func testInvalidPathThrows() {
        XCTAssertThrowsError(try engine.evaluate(json: sampleJSON, path: "store")) { error in
            XCTAssertTrue(error is JSONPathError)
        }
    }
    
    func testEmptyJSON() {
        XCTAssertThrowsError(try engine.evaluate(json: [String: Any](), path: "$.nonexistent")) { error in
            XCTAssertTrue(error is JSONPathError)
        }
    }

    // MARK: - Recursive descent (`..`)

    func testRecursiveDescentPrices() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$..price")
        XCTAssertEqual(results.count, 4)
        let prices = results.compactMap { $0.value as? Double }.sorted()
        XCTAssertEqual(prices, [8.95, 8.99, 12.99, 19.95])
    }

    func testRecursiveDescentTitles() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$..title")
        XCTAssertEqual(results.count, 3)
        let titles = results.compactMap { $0.value as? String }.sorted()
        XCTAssertEqual(titles, ["Moby Dick", "Sayings of the Century", "Sword of Honour"])
    }

    func testRecursiveDescentAsterisk() throws {
        // Root plus every nested node: store, book array, 3 books,
        // bicycle, and bicycle's values (color, price) etc. — just assert
        // it returns more than a plain child access.
        let results = try engine.evaluate(json: sampleJSON, path: "$..*")
        XCTAssertGreaterThan(results.count, 5)
    }

    // MARK: - Filters

    /// Regression: only `Double` was accepted, so documents with integer
    /// values (or values from native Swift literals) matched nothing.
    func testFilterOnNativeIntValues() throws {
        let json: [String: Any] = ["items": [["price": 10], ["price": 3]]]
        let results = try engine.evaluate(json: json, path: "$.items[?(@.price > 5)]")
        XCTAssertEqual(results.count, 1)
        let item = results[0].value as? [String: Any]
        XCTAssertEqual(item?["price"] as? Int, 10)
    }

    func testFilterOnJSONSerializationIntegers() throws {
        let json = try JSONSerialization.jsonObject(with: Data(#"{"items":[{"price":7},{"price":2}]}"#.utf8))
        let results = try engine.evaluate(json: json, path: "$.items[?(@.price >= 7)]")
        XCTAssertEqual(results.count, 1)
    }

    /// Compound filters used to silently evaluate only the first condition.
    func testCompoundFilterThrowsInsteadOfSilentlyWrongResults() {
        XCTAssertThrowsError(
            try engine.evaluate(json: sampleJSON, path: "$.store.book[?(@.price < 10 && @.price > 1)]")
        ) { error in
            guard let jsonPathError = error as? JSONPathError,
                  case .invalidExpression = jsonPathError else {
                  return XCTFail("Expected JSONPathError.invalidExpression, got \(error)")
            }
        }
    }

    /// Unknown operators used to be treated as "never matches".
    func testUnknownOperatorThrows() {
        XCTAssertThrowsError(
            try engine.evaluate(json: sampleJSON, path: "$.store.book[?(@.price <> 10)]")
        ) { error in
            guard let jsonPathError = error as? JSONPathError,
                  case .invalidExpression = jsonPathError else {
                  return XCTFail("Expected JSONPathError.invalidExpression, got \(error)")
            }
        }
    }

    func testStringComparisonInFilterIsExplicitlyRejected() {
        XCTAssertThrowsError(
            try engine.evaluate(json: sampleJSON, path: "$.store.book[?(@.category == 'fiction')]")
        )
    }

    // MARK: - Path validation

    func testEmptySegmentThrows() {
        XCTAssertThrowsError(try engine.evaluate(json: sampleJSON, path: "$.store.[0]")) { error in
            guard let jsonPathError = error as? JSONPathError,
                  case .invalidPath = jsonPathError else {
                  return XCTFail("Expected JSONPathError.invalidPath, got \(error)")
            }
        }
    }

    // MARK: - Remaining filter operators (`<=`, `>=`, `!=`)

    func testFilterLessThanOrEqual() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store.book[?(@.price <= 8.95)]")
        XCTAssertEqual(results.count, 1)
        let title = (results[0].value as? [String: Any])?["title"] as? String
        XCTAssertEqual(title, "Sayings of the Century")
    }

    func testFilterGreaterThanOrEqual() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store.book[?(@.price >= 8.99)]")
        XCTAssertEqual(results.count, 2)
        let titles = results.compactMap { ($0.value as? [String: Any])?["title"] as? String }.sorted()
        XCTAssertEqual(titles, ["Moby Dick", "Sword of Honour"])
    }

    func testFilterNotEquals() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store.book[?(@.price != 8.95)]")
        XCTAssertEqual(results.count, 2)
        let titles = results.compactMap { ($0.value as? [String: Any])?["title"] as? String }.sorted()
        XCTAssertEqual(titles, ["Moby Dick", "Sword of Honour"])
    }

    // MARK: - Bracket key access

    func testBracketKeyAccessWithDoubleQuotes() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$['store']['bicycle']['color']")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].value as? String, "red")
    }

    func testBracketKeyAccessWithSingleQuotes() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store.bicycle['price']")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].value as? Double, 19.95)
    }

    /// Bracket access over an array collects the key from every element.
    func testBracketKeyAccessOnArray() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store.book[*]['title']")
        XCTAssertEqual(results.count, 3)
    }

    // MARK: - Index bounds

    func testOutOfBoundsIndexThrows() {
        XCTAssertThrowsError(try engine.evaluate(json: sampleJSON, path: "$.store.book[10]")) { error in
            XCTAssertTrue(error is JSONPathError)
        }
        XCTAssertThrowsError(try engine.evaluate(json: sampleJSON, path: "$.store.book[-10]")) { error in
            XCTAssertTrue(error is JSONPathError)
        }
    }

    /// Filtering a non-array node yields no results rather than an error.
    func testFilterOnNonArrayReturnsEmpty() throws {
        let results = try engine.evaluate(json: sampleJSON, path: "$.store.bicycle[?(@.price < 10)]")
        XCTAssertTrue(results.isEmpty)
    }
}
