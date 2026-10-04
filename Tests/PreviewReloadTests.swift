import XCTest
@testable import OpenDevUtils

/// Tests for the preview reload gate used by HTMLWebView.
/// Review findings: `updateNSView` reloaded the page on every SwiftUI update
/// (id was never read), so previews reloaded on every keystroke, losing
/// scroll position and flashing white.
final class PreviewReloadTests: XCTestCase {

    func testFirstLoadReloads() {
        var gate = ReloadGate()
        let id = UUID()
        XCTAssertTrue(gate.shouldReload(id: id, html: "<html>1</html>"))
    }

    func testUnchangedContentDoesNotReload() {
        var gate = ReloadGate()
        let id = UUID()
        _ = gate.shouldReload(id: id, html: "<html>1</html>")
        XCTAssertFalse(gate.shouldReload(id: id, html: "<html>1</html>"))
    }

    func testChangedHTMLReloads() {
        var gate = ReloadGate()
        let id = UUID()
        _ = gate.shouldReload(id: id, html: "<html>1</html>")
        XCTAssertTrue(gate.shouldReload(id: id, html: "<html>2</html>"))
    }

    /// The explicit Refresh button changes the id → must reload even if the
    /// html string happens to be identical.
    func testNewIDForcesReload() {
        var gate = ReloadGate()
        let id1 = UUID()
        _ = gate.shouldReload(id: id1, html: "<html>1</html>")
        XCTAssertTrue(gate.shouldReload(id: UUID(), html: "<html>1</html>"))
    }

    func testReloadStateUpdatesAfterReload() {
        var gate = ReloadGate()
        let id1 = UUID()
        _ = gate.shouldReload(id: id1, html: "a")
        let id2 = UUID()
        _ = gate.shouldReload(id: id2, html: "b")
        // Going back to the previous pair must count as a change again.
        XCTAssertTrue(gate.shouldReload(id: id1, html: "a"))
    }
}
