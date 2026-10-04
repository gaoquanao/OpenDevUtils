import XCTest
@testable import OpenDevUtils

/// Tests for YAMLParse — the parser side of YAMLTool (existing tests only
/// covered YAMLEmit). Review findings addressed:
/// - top-level single-line `key: value` pairs were silently dropped → `{}`
/// - a sibling key after `key:` was consumed as that key's value
/// - nesting deeper than one level was silently discarded
/// - tab indentation / unparseable lines were ignored instead of reported
/// - anchors/aliases and multi-document input were unsupported
final class YAMLParseTests: XCTestCase {

    private func dict(_ yaml: String, file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let obj = try YAMLParse.parse(yaml)
        guard let d = obj as? [String: Any] else {
            XCTFail("expected dictionary, got \(type(of: obj))", file: file, line: line)
            return [:]
        }
        return d
    }

    // MARK: - Top-level flat mapping (critical regression)

    /// Regression: this returned `[:]` because `else { i += 1 }` skipped
    /// every line that wasn't `key:` or `- `.
    func testTopLevelFlatPairs() throws {
        let d = try dict("name: Alice\nage: 30")
        XCTAssertEqual(d["name"] as? String, "Alice")
        XCTAssertEqual(d["age"] as? Int, 30)
    }

    func testTopLevelPairsWithoutTrailingNewline() throws {
        let d = try dict("a: 1")
        XCTAssertEqual(d["a"] as? Int, 1)
    }

    /// Regression: `b: 1` right after `a:` was swallowed as a's value.
    func testSiblingKeyAfterEmptyValue() throws {
        let d = try dict("a:\nb: 1")
        XCTAssertTrue(d["a"] is NSNull, "a should be null, got \(String(describing: d["a"]))")
        XCTAssertEqual(d["b"] as? Int, 1)
    }

    // MARK: - Scalars

    func testScalarTypes() throws {
        let d = try dict("""
        s: text
        i: 42
        f: 3.5
        t: true
        fa: false
        n: null
        tilde: ~
        """)
        XCTAssertEqual(d["s"] as? String, "text")
        XCTAssertEqual(d["i"] as? Int, 42)
        XCTAssertEqual(d["f"] as? Double, 3.5)
        XCTAssertEqual(d["t"] as? Bool, true)
        XCTAssertEqual(d["fa"] as? Bool, false)
        XCTAssertTrue(d["n"] is NSNull)
        XCTAssertTrue(d["tilde"] is NSNull)
    }

    func testQuotedStrings() throws {
        let d = try dict("""
        a: "123"
        b: 'true'
        c: "with: colon"
        """)
        XCTAssertEqual(d["a"] as? String, "123")
        XCTAssertEqual(d["b"] as? String, "true")
        XCTAssertEqual(d["c"] as? String, "with: colon")
    }

    func testValueWithHashKeepsText() throws {
        let d = try dict("url: https://x.com/a#b")
        XCTAssertEqual(d["url"] as? String, "https://x.com/a#b")
    }

    // MARK: - Comments & whitespace

    func testCommentsAreSkipped() throws {
        let d = try dict("""
        # leading comment
        a: 1

        b: 2 # trailing comment
        """)
        XCTAssertEqual(d["a"] as? Int, 1)
        XCTAssertEqual(d["b"] as? Int, 2, "trailing comment must be stripped")
    }

    func testLeadingWhitespaceIndentation() throws {
        let d = try dict("""
        root:
          child: 1
          other: 2
        """)
        let child = try XCTUnwrap(d["root"] as? [String: Any])
        XCTAssertEqual(child["child"] as? Int, 1)
        XCTAssertEqual(child["other"] as? Int, 2)
    }

    // MARK: - Nesting

    /// Regression: level-3 nesting was silently dropped.
    func testDeepNesting() throws {
        let d = try dict("""
        a:
          b:
            c:
              d: deep
        """)
        let a = try XCTUnwrap(d["a"] as? [String: Any])
        let b = try XCTUnwrap(a["b"] as? [String: Any])
        let c = try XCTUnwrap(b["c"] as? [String: Any])
        XCTAssertEqual(c["d"] as? String, "deep")
    }

    func testNestedMapAlongsideScalar() throws {
        let d = try dict("""
        name: top
        meta:
          k: v
        after: 1
        """)
        XCTAssertEqual(d["name"] as? String, "top")
        let meta = try XCTUnwrap(d["meta"] as? [String: Any])
        XCTAssertEqual(meta["k"] as? String, "v")
        XCTAssertEqual(d["after"] as? Int, 1)
    }

    // MARK: - Sequences

    func testScalarSequence() throws {
        let d = try dict("list:\n  - a\n  - b\n  - 3")
        let list = try XCTUnwrap(d["list"] as? [Any])
        XCTAssertEqual(list.count, 3)
        XCTAssertEqual(list[0] as? String, "a")
        XCTAssertEqual(list[2] as? Int, 3)
    }

    /// Sequence at the same indent as its key (very common style).
    func testSequenceAtSameIndentAsKey() throws {
        let d = try dict("list:\n- a\n- b")
        let list = try XCTUnwrap(d["list"] as? [Any])
        XCTAssertEqual(list as? [String], ["a", "b"])
    }

    func testSequenceOfMappings() throws {
        let d = try dict("""
        users:
          - name: a
            id: 1
          - name: b
            id: 2
        """)
        let users = try XCTUnwrap(d["users"] as? [Any])
        XCTAssertEqual(users.count, 2)
        let first = try XCTUnwrap(users[0] as? [String: Any])
        XCTAssertEqual(first["name"] as? String, "a")
        XCTAssertEqual(first["id"] as? Int, 1)
        let second = try XCTUnwrap(users[1] as? [String: Any])
        XCTAssertEqual(second["name"] as? String, "b")
    }

    func testTopLevelSequence() throws {
        let obj = try YAMLParse.parse("- a\n- b")
        let list = try XCTUnwrap(obj as? [Any])
        XCTAssertEqual(list as? [String], ["a", "b"])
    }

    func testTopLevelSequenceOfMappings() throws {
        let obj = try YAMLParse.parse("- k: 1\n- k: 2")
        let list = try XCTUnwrap(obj as? [Any])
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual((list[0] as? [String: Any])?["k"] as? Int, 1)
    }

    func testNestedSequenceInMappingInSequence() throws {
        let d = try dict("""
        items:
          - tags:
              - x
              - y
        """)
        let items = try XCTUnwrap(d["items"] as? [Any])
        let first = try XCTUnwrap(items[0] as? [String: Any])
        let tags = try XCTUnwrap(first["tags"] as? [Any])
        XCTAssertEqual(tags as? [String], ["x", "y"])
    }

    // MARK: - Errors

    func testTabIndentationThrows() {
        XCTAssertThrowsError(try YAMLParse.parse("a:\n\tb: 1"))
    }

    func testUnparseableLineThrows() {
        XCTAssertThrowsError(try YAMLParse.parse("just some text without colon"))
    }

    func testMissingAliasThrows() {
        XCTAssertThrowsError(try YAMLParse.parse("a: *nope"))
    }

    // MARK: - Anchors & aliases

    func testScalarAnchorAlias() throws {
        let d = try dict("a: &x hello\nb: *x")
        XCTAssertEqual(d["a"] as? String, "hello")
        XCTAssertEqual(d["b"] as? String, "hello")
    }

    func testMappingAnchorAlias() throws {
        let d = try dict("""
        base: &b
          k: v
        copy: *b
        """)
        let copy = try XCTUnwrap(d["copy"] as? [String: Any])
        XCTAssertEqual(copy["k"] as? String, "v")
    }

    func testMergeKey() throws {
        let d = try dict("""
        base: &b
          a: 1
          b: 2
        child:
          <<: *b
          b: 99
        """)
        let child = try XCTUnwrap(d["child"] as? [String: Any])
        XCTAssertEqual(child["a"] as? Int, 1, "merged key missing")
        XCTAssertEqual(child["b"] as? Int, 99, "explicit key must win over merge")
    }

    // MARK: - Multi-document

    func testMultiDocumentReturnsArray() throws {
        let obj = try YAMLParse.parse("---\na: 1\n---\nb: 2\n")
        let docs = try XCTUnwrap(obj as? [Any])
        XCTAssertEqual(docs.count, 2)
        XCTAssertEqual((docs[0] as? [String: Any])?["a"] as? Int, 1)
        XCTAssertEqual((docs[1] as? [String: Any])?["b"] as? Int, 2)
    }

    func testSingleDocumentMarkerIsNotAnArray() throws {
        let d = try dict("---\na: 1\n")
        XCTAssertEqual(d["a"] as? Int, 1)
    }

    // MARK: - Round trip through the tool's JSON path

    func testParseOutputIsJSONSerializable() throws {
        let d = try dict("""
        name: Alice
        tags: [a, b]
        meta:
          n: 1
        """)
        XCTAssertTrue(JSONSerialization.isValidJSONObject(d))
    }
}
