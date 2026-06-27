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
}
