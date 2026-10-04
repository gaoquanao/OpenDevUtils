import XCTest
@testable import OpenDevUtils

/// Tests for MarkdownRenderer — markdown → HTML extracted from
/// MarkdownPreviewTool so the conversion is testable and can be cached.
/// Review findings addressed:
/// - global `\n` → `<br>` replacement corrupted `<pre>` code blocks
/// - non-code text was never HTML-escaped (`<`, `&` parsed as markup)
/// - emphasis ran before inline code, so `` `**x**` `` became formatted
/// - block elements were wrapped in a single `<p>`
final class MarkdownRendererTests: XCTestCase {

    private func render(_ md: String) -> String {
        MarkdownRenderer.render(md)
    }

    // MARK: - Escaping

    func testPlainTextIsHTMLEscaped() {
        let html = render("a < b & c")
        XCTAssertTrue(html.contains("a &lt; b &amp; c"), html)
        XCTAssertFalse(html.contains("a < b"), html)
    }

    func testAngleBracketsAreNotParsedAsTags() {
        let html = render("use Array<T> here")
        XCTAssertTrue(html.contains("Array&lt;T&gt;"), html)
        XCTAssertFalse(html.contains("<T>"), html)
    }

    func testInlineCodeIsEscaped() {
        let html = render("`<b>bold</b>`")
        XCTAssertTrue(html.contains("<code>&lt;b&gt;bold&lt;/b&gt;</code>"), html)
        XCTAssertFalse(html.contains("<b>bold</b>"), html)
    }

    func testCodeBlockIsEscaped() {
        let html = render("```\nif (a < b) { go() }\n```")
        XCTAssertTrue(html.contains("if (a &lt; b) { go() }"), html)
    }

    // MARK: - Code blocks vs newlines

    /// Regression: blank lines inside a fenced block were replaced with
    /// `</p><p>` and single newlines with `<br>`, destroying the block.
    func testCodeBlockKeepsRawNewlines() {
        let html = render("```\nfoo\n\nbar\n```")
        XCTAssertTrue(html.contains("<pre><code>foo\n\nbar</code></pre>"), html)
        XCTAssertFalse(html.contains("foo<br>"), html)
        XCTAssertFalse(html.contains("</p><p>bar"), html)
    }

    func testCodeBlockWithLanguageGetsClass() {
        let html = render("```swift\nlet a = 1\n```")
        XCTAssertTrue(html.contains("language-swift"), html)
    }

    // MARK: - Inline formatting order

    /// Regression: emphasis ran before inline code.
    func testEmphasisDoesNotApplyInsideCodeSpans() {
        let html = render("`**not bold**`")
        XCTAssertTrue(html.contains("<code>**not bold**</code>"), html)
        XCTAssertFalse(html.contains("<strong>"), html)
    }

    func testBoldAndItalic() {
        let html = render("**bold** and *italic*")
        XCTAssertTrue(html.contains("<strong>bold</strong>"), html)
        XCTAssertTrue(html.contains("<em>italic</em>"), html)
    }

    func testLink() {
        let html = render("[text](https://example.com)")
        XCTAssertTrue(html.contains("<a href=\"https://example.com\">text</a>"), html)
    }

    func testImage() {
        let html = render("![alt](https://example.com/i.png)")
        XCTAssertTrue(html.contains("<img src=\"https://example.com/i.png\" alt=\"alt\""), html)
    }

    // MARK: - Block structure

    func testHeadingIsBlockElementNotInsideParagraph() {
        let html = render("# Title")
        XCTAssertTrue(html.contains("<h1>Title</h1>"), html)
        XCTAssertFalse(html.contains("<p><h1>"), html)
    }

    func testParagraphsAreSeparated() {
        let html = render("one\n\ntwo")
        XCTAssertTrue(html.contains("<p>one</p>"), html)
        XCTAssertTrue(html.contains("<p>two</p>"), html)
    }

    func testSingleNewlineBecomesBreakInsideParagraph() {
        let html = render("line1\nline2")
        XCTAssertTrue(html.contains("line1<br>line2"), html)
    }

    func testUnorderedList() {
        let html = render("- a\n- b")
        XCTAssertTrue(html.contains("<ul>"), html)
        XCTAssertTrue(html.contains("<li>a</li>"), html)
        XCTAssertTrue(html.contains("</ul>"), html)
    }

    func testOrderedList() {
        let html = render("1. one\n2. two")
        XCTAssertTrue(html.contains("<ol>"), html)
        XCTAssertTrue(html.contains("<li>one</li>"), html)
    }

    func testBlockquote() {
        let html = render("> quoted")
        XCTAssertTrue(html.contains("<blockquote>quoted</blockquote>"), html)
    }

    func testHorizontalRule() {
        XCTAssertTrue(render("---").contains("<hr>"))
        XCTAssertTrue(render("***").contains("<hr>"))
    }

    /// Lists/headings must not be swallowed by paragraph wrapping.
    func testListIsNotWrappedInParagraph() {
        let html = render("- a\n- b\n\nafter")
        XCTAssertFalse(html.contains("<p><ul>"), html)
        XCTAssertTrue(html.contains("<p>after</p>"), html)
    }

    // MARK: - Document shell

    func testOutputIsFullHTMLDocument() {
        let html = render("hi")
        XCTAssertTrue(html.contains("<!DOCTYPE html>"), html)
        XCTAssertTrue(html.contains("<meta charset=\"utf-8\">"), html)
        XCTAssertTrue(html.contains("<body>"), html)
    }

    func testEmptyInputProducesValidDocument() {
        let html = render("")
        XCTAssertTrue(html.contains("<!DOCTYPE html>"), html)
        XCTAssertFalse(html.contains("<p></p>"), html)
    }

    /// The renderer must be deterministic (it is cached by content).
    func testDeterministic() {
        let md = "# t\n\ntext `code`\n- a"
        XCTAssertEqual(render(md), render(md))
    }
}
