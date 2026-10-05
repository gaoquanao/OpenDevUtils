import SwiftUI

// MARK: - Tree model

/// Immutable node tree for the read-only JSON viewer (per-type syntax
/// highlighting plus collapsible objects/arrays). Built off the main thread.
indirect enum JSONTreeNode: Equatable {
    struct Member: Equatable {
        let key: String
        let value: JSONTreeNode
    }

    case object([Member])
    case array([JSONTreeNode])
    case string(String)
    case number(String) // literal as re-parsed from the pane's own text
    case bool(Bool)
    case null

    var isContainer: Bool {
        switch self {
        case .object, .array: return true
        default: return false
        }
    }
}

// MARK: - Parsing

enum JSONTreeParser {
    /// Documents larger than this are shown as plain text instead: building
    /// the node tree would stall for seconds and multiply memory for a
    /// document no human folds through anyway.
    static let maxTreeCharacters = 5_000_000

    static func parse(_ text: String, maxCharacters: Int = maxTreeCharacters) -> JSONTreeNode? {
        guard text.count <= maxCharacters, let data = text.data(using: .utf8) else { return nil }
        guard let any = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }
        return convert(any)
    }

    static func convert(_ any: Any) -> JSONTreeNode {
        switch any {
        case let dict as [String: Any]:
            // Sorted so the tree matches the `.sortedKeys` text output.
            let members = dict.keys.sorted().compactMap { key -> JSONTreeNode.Member? in
                guard let value = dict[key] else { return nil }
                return JSONTreeNode.Member(key: key, value: convert(value))
            }
            return .object(members)
        case let array as [Any]:
            return .array(array.map { convert($0) })
        case let number as NSNumber:
            // NSNumber bridges Bool *and* the numeric types, so CFBoolean is
            // the only reliable discriminator (`1 as? Bool` also succeeds).
            if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            // NSNumber.stringValue renders doubles with %0.16g and leaks
            // binary artifacts ("8.95" → "8.949999999999999"), while the
            // pane's own text shows "8.95". Use Swift's shortest round-trip
            // form for floats; exact stringValue for integers and decimals.
            if let decimal = number as? NSDecimalNumber {
                return .number(decimal.stringValue)
            }
            let objCType = String(cString: number.objCType)
            if objCType == "f" || objCType == "d" {
                return .number(String(number.doubleValue))
            }
            return .number(number.stringValue)
        case let string as String:
            return .string(string)
        case is NSNull:
            return .null
        default:
            return .null
        }
    }
}

// MARK: - Row layout

struct JSONTreeRow: Identifiable, Equatable {
    enum Leaf: Equatable {
        case string(String)
        case number(String)
        case bool(Bool)
        case null
    }

    enum Kind: Equatable {
        case object(expanded: Bool)
        case array(expanded: Bool)
        case leaf(Leaf)
    }

    let path: String
    let depth: Int
    let key: String?
    let index: Int?
    let kind: Kind

    var id: String { path }
}

enum JSONTreeLayout {
    /// Flattens the visible portion of the tree. Paths are built from child
    /// indices (`root/0/2`) so keys containing dots or slashes cannot collide.
    static func visibleRows(root: JSONTreeNode, collapsed: Set<String>) -> [JSONTreeRow] {
        var rows: [JSONTreeRow] = []
        append(root, key: nil, index: nil, path: "root", depth: 0,
               collapsed: collapsed, into: &rows)
        return rows
    }

    private static func append(_ node: JSONTreeNode,
                               key: String?,
                               index: Int?,
                               path: String,
                               depth: Int,
                               collapsed: Set<String>,
                               into rows: inout [JSONTreeRow]) {
        switch node {
        case .object(let members):
            let expanded = !collapsed.contains(path)
            rows.append(JSONTreeRow(path: path, depth: depth, key: key, index: index,
                                    kind: .object(expanded: expanded)))
            guard expanded else { return }
            for (i, member) in members.enumerated() {
                append(member.value, key: member.key, index: nil,
                       path: "\(path)/\(i)", depth: depth + 1,
                       collapsed: collapsed, into: &rows)
            }
        case .array(let items):
            let expanded = !collapsed.contains(path)
            rows.append(JSONTreeRow(path: path, depth: depth, key: key, index: index,
                                    kind: .array(expanded: expanded)))
            guard expanded else { return }
            for (i, item) in items.enumerated() {
                append(item, key: nil, index: i,
                       path: "\(path)/\(i)", depth: depth + 1,
                       collapsed: collapsed, into: &rows)
            }
        case .string(let value):
            rows.append(JSONTreeRow(path: path, depth: depth, key: key, index: index,
                                    kind: .leaf(.string(value))))
        case .number(let value):
            rows.append(JSONTreeRow(path: path, depth: depth, key: key, index: index,
                                    kind: .leaf(.number(value))))
        case .bool(let value):
            rows.append(JSONTreeRow(path: path, depth: depth, key: key, index: index,
                                    kind: .leaf(.bool(value))))
        case .null:
            rows.append(JSONTreeRow(path: path, depth: depth, key: key, index: index,
                                    kind: .leaf(.null)))
        }
    }

    /// All container paths at `minDepth` or deeper.
    static func containerPaths(root: JSONTreeNode, minDepth: Int = 0) -> Set<String> {
        var paths = Set<String>()
        collect(root, path: "root", depth: 0, minDepth: minDepth, into: &paths)
        return paths
    }

    private static func collect(_ node: JSONTreeNode,
                                path: String,
                                depth: Int,
                                minDepth: Int,
                                into paths: inout Set<String>) {
        guard node.isContainer else { return }
        if depth >= minDepth { paths.insert(path) }
        switch node {
        case .object(let members):
            for (i, member) in members.enumerated() {
                collect(member.value, path: "\(path)/\(i)", depth: depth + 1,
                        minDepth: minDepth, into: &paths)
            }
        case .array(let items):
            for (i, item) in items.enumerated() {
                collect(item, path: "\(path)/\(i)", depth: depth + 1,
                        minDepth: minDepth, into: &paths)
            }
        default:
            break
        }
    }

    /// Root and its direct children start open; deeper containers start
    /// closed so the first view shows structure without drowning in rows.
    static func defaultCollapsed(root: JSONTreeNode) -> Set<String> {
        containerPaths(root: root, minDepth: 2)
    }

    /// Escapes control characters so a value with embedded newlines stays on
    /// one row, and caps pathological leaves (a 1MB base64 blob) — Copy
    /// always carries the full value.
    static func displayString(_ value: String, limit: Int = 10_000) -> String {
        var text = value
        var truncated = false
        if text.count > limit {
            text = String(text.prefix(limit))
            truncated = true
        }
        text = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return text + (truncated ? "…" : "")
    }
}

// MARK: - View

/// Display mode shared by the JSON output panes: the structured tree with
/// highlighting + folding, or the raw pretty-printed text.
enum JSONOutputMode: Hashable {
    case text
    case tree
}

/// Read-only JSON viewer with per-type syntax highlighting and collapsible
/// objects/arrays. Parsing happens off the main thread; when the document is
/// not valid JSON (e.g. an empty pane or "no results") or is too large, the
/// view degrades to the same plain-text preview the text mode shows.
struct JSONTreeView: View {
    let text: String
    /// The parent bumps these to run expand-all / collapse-all.
    var expandAllToken: Int = 0
    var collapseAllToken: Int = 0

    @State private var root: JSONTreeNode?
    @State private var isParsing = false
    @State private var isTooLarge = false
    @State private var collapsed: Set<String> = []
    @State private var parseVersion = 0

    var body: some View {
        content
            .onAppear { parseText() }
            .onChange(of: text) { _ in parseText() }
            .onChange(of: expandAllToken) { _ in collapsed.removeAll() }
            .onChange(of: collapseAllToken) { _ in collapseAll() }
    }

    @ViewBuilder
    private var content: some View {
        if let root {
            treeContent(root)
        } else if isParsing {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            plainFallback
        }
    }

    private func treeContent(_ root: JSONTreeNode) -> some View {
        let rows = JSONTreeLayout.visibleRows(root: root, collapsed: collapsed)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(rows) { row in
                    JSONTreeRowView(row: row) { toggle(row.path) }
                        .padding(.leading, CGFloat(row.depth) * 16)
                }
            }
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var plainFallback: some View {
        let preview = JSONProcessor.preview(text)
        return VStack(spacing: 4) {
            if isTooLarge {
                Text(L(.treeViewTooLarge))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ScrollView {
                Text(preview.display)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
        }
    }

    private func parseText() {
        parseVersion += 1
        let version = parseVersion
        let snapshot = text

        guard !snapshot.isEmpty else {
            root = nil
            isParsing = false
            isTooLarge = false
            collapsed = []
            return
        }

        isParsing = true
        DispatchQueue.global(qos: .userInitiated).async {
            let parsed = JSONTreeParser.parse(snapshot)
            let tooLarge = snapshot.count > JSONTreeParser.maxTreeCharacters
            DispatchQueue.main.async {
                guard version == parseVersion else { return }
                isParsing = false
                if let parsed {
                    root = parsed
                    isTooLarge = false
                    collapsed = JSONTreeLayout.defaultCollapsed(root: parsed)
                } else {
                    root = nil
                    isTooLarge = tooLarge
                }
            }
        }
    }

    private func toggle(_ path: String) {
        if collapsed.contains(path) {
            collapsed.remove(path)
        } else {
            collapsed.insert(path)
        }
    }

    private func collapseAll() {
        guard let root else { return }
        collapsed = JSONTreeLayout.containerPaths(root: root)
    }
}

// MARK: - Row view

private struct JSONTreeRowView: View {
    let row: JSONTreeRow
    let toggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            disclosure

            if let key = row.key {
                Text("\"\(key)\"")
                    .foregroundStyle(Color.orange)
                Text(":")
                    .foregroundStyle(Color.secondary)
                    .padding(.trailing, 4)
            } else if let index = row.index {
                Text("[\(index)]")
                    .foregroundStyle(Color.secondary)
                    .padding(.trailing, 4)
            }

            value
        }
    }

    @ViewBuilder
    private var disclosure: some View {
        switch row.kind {
        case .object(let expanded), .array(let expanded):
            Button(action: toggle) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.secondary)
        case .leaf:
            Color.clear
                .frame(width: 14, height: 14)
        }
    }

    @ViewBuilder
    private var value: some View {
        switch row.kind {
        case .object(let expanded):
            Text(expanded ? "{" : "{…}")
                .foregroundStyle(Color.secondary)
        case .array(let expanded):
            Text(expanded ? "[" : "[…]")
                .foregroundStyle(Color.secondary)
        case .leaf(let leaf):
            leafValue(leaf)
        }
    }

    @ViewBuilder
    private func leafValue(_ leaf: JSONTreeRow.Leaf) -> some View {
        switch leaf {
        case .string(let string):
            Text("\"\(JSONTreeLayout.displayString(string))\"")
                .foregroundStyle(Color.green)
        case .number(let number):
            Text(number)
                .foregroundStyle(Color.cyan)
        case .bool(let flag):
            Text(flag ? "true" : "false")
                .foregroundStyle(Color.pink)
        case .null:
            Text("null")
                .foregroundStyle(Color.secondary)
                .italic()
        }
    }
}
