import XCTest
@testable import OpenDevUtils

/// Tests for the JSON tree view model: parsing (including bool/number
/// discrimination and fragments) and the flattened, foldable row layout.
final class JSONTreeViewTests: XCTestCase {

    private func parse(_ json: String,
                       maxCharacters: Int = JSONTreeParser.maxTreeCharacters) throws -> JSONTreeNode {
        try XCTUnwrap(JSONTreeParser.parse(json, maxCharacters: maxCharacters),
                      "failed to parse: \(json)")
    }

    // MARK: - Parsing

    func testObjectKeysAreSorted() throws {
        let root = try parse(#"{"b": 1, "a": 2}"#)
        guard case .object(let members) = root else { return XCTFail("expected object") }
        XCTAssertEqual(members.map(\.key), ["a", "b"])
    }

    /// Regression: `1 as? Bool` also succeeds for NSNumber, so booleans must
    /// be detected via CFBoolean.
    func testBoolsAreNotNumbers() throws {
        let root = try parse("[true, false, 1, 0]")
        guard case .array(let items) = root else { return XCTFail("expected array") }
        XCTAssertEqual(items[0], .bool(true))
        XCTAssertEqual(items[1], .bool(false))
        XCTAssertEqual(items[2], .number("1"))
        XCTAssertEqual(items[3], .number("0"))
    }

    func testScalarTypes() throws {
        let root = try parse(#"{"s": "hi", "n": 8.95, "z": null}"#)
        guard case .object(let members) = root else { return XCTFail("expected object") }
        XCTAssertEqual(members.map(\.key), ["n", "s", "z"])
        XCTAssertEqual(members[0].value, .number("8.95"))
        XCTAssertEqual(members[1].value, .string("hi"))
        XCTAssertEqual(members[2].value, .null)
    }

    func testTopLevelFragments() throws {
        XCTAssertEqual(try parse("19.95"), .number("19.95"))
        XCTAssertEqual(try parse(#""hello""#), .string("hello"))
        XCTAssertEqual(try parse("null"), .null)
    }

    func testInvalidJSONReturnsNil() {
        XCTAssertNil(JSONTreeParser.parse("{oops"))
        XCTAssertNil(JSONTreeParser.parse(""))
        // Placeholder text shown in the results pane when nothing matched.
        XCTAssertNil(JSONTreeParser.parse("No results"))
    }

    func testOversizedDocumentReturnsNil() {
        XCTAssertNil(JSONTreeParser.parse("[1,2,3]", maxCharacters: 5))
    }

    // MARK: - Visible rows / folding

    /// `{"a": {"b": 1, "c": 2}, "d": 3}`
    private var sample: JSONTreeNode {
        try! parse(#"{"a": {"b": 1, "c": 2}, "d": 3}"#)
    }

    func testAllExpandedRows() {
        let rows = JSONTreeLayout.visibleRows(root: sample, collapsed: [])
        XCTAssertEqual(rows.map(\.path), ["root", "root/0", "root/0/0", "root/0/1", "root/1"])
        XCTAssertEqual(rows.map(\.depth), [0, 1, 2, 2, 1])
        XCTAssertEqual(rows[0].kind, .object(expanded: true))
        XCTAssertEqual(rows[1].kind, .object(expanded: true))
        XCTAssertEqual(rows[2].kind, .leaf(.number("1")))
        XCTAssertEqual(rows[3].kind, .leaf(.number("2")))
        XCTAssertEqual(rows[4].key, "d")
        XCTAssertEqual(rows[4].kind, .leaf(.number("3")))
    }

    func testCollapsedContainerHidesChildren() {
        let rows = JSONTreeLayout.visibleRows(root: sample, collapsed: ["root/0"])
        XCTAssertEqual(rows.map(\.path), ["root", "root/0", "root/1"])
        XCTAssertEqual(rows[1].kind, .object(expanded: false))
    }

    func testDefaultCollapsedOpensTwoLevels() {
        // {"a": {"b": {"c": 1}}} — the container at depth 2 starts closed.
        let root = try! parse(#"{"a": {"b": {"c": 1}}}"#)
        let collapsed = JSONTreeLayout.defaultCollapsed(root: root)
        XCTAssertEqual(collapsed, ["root/0/0"])
        let rows = JSONTreeLayout.visibleRows(root: root, collapsed: collapsed)
        XCTAssertEqual(rows.map(\.path), ["root", "root/0", "root/0/0"])
    }

    func testArrayRowsCarryIndices() {
        let root = try! parse("[10, {\"x\": 1}]")
        let rows = JSONTreeLayout.visibleRows(root: root, collapsed: [])
        XCTAssertEqual(rows.map(\.path), ["root", "root/0", "root/1", "root/1/0"])
        XCTAssertNil(rows[0].index)
        XCTAssertEqual(rows[1].index, 0)
        XCTAssertEqual(rows[1].kind, .leaf(.number("10")))
        XCTAssertEqual(rows[2].index, 1)
        XCTAssertEqual(rows[3].key, "x")
    }

    func testContainerPathsCollectsEveryContainer() {
        let root = try! parse(#"{"a": {"b": [1]}, "c": 2}"#)
        XCTAssertEqual(JSONTreeLayout.containerPaths(root: root),
                       ["root", "root/0", "root/0/0"])
        XCTAssertEqual(JSONTreeLayout.containerPaths(root: root, minDepth: 1),
                       ["root/0", "root/0/0"])
    }

    /// Path segments are child indices, never key names, so a key containing
    /// a slash cannot collide with a nested path.
    func testKeysWithSlashDoNotCollideWithIndexPaths() {
        let root = try! parse(#"{"a/b": 1}"#)
        let rows = JSONTreeLayout.visibleRows(root: root, collapsed: [])
        XCTAssertEqual(rows.map(\.path), ["root", "root/0"])
        XCTAssertEqual(rows[1].key, "a/b")
    }

    // MARK: - String display

    func testDisplayStringEscapesControlCharacters() {
        XCTAssertEqual(JSONTreeLayout.displayString("a\nb\tc\"d\\e"),
                       #"a\nb\tc\"d\\e"#)
    }

    func testDisplayStringTruncatesLongLeaves() {
        let result = JSONTreeLayout.displayString(String(repeating: "x", count: 30), limit: 10)
        XCTAssertEqual(result.count, 11)
        XCTAssertTrue(result.hasSuffix("…"))
    }
}
