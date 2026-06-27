import Foundation

enum JSONPathError: LocalizedError {
    case invalidPath(String)
    case invalidExpression(String)
    case notFound(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPath(let p): return "Invalid JSONPath: \(p)"
        case .invalidExpression(let e): return "Invalid expression: \(e)"
        case .notFound(let p): return "Path not found: \(p)"
        }
    }
}

class JSONPathEngine {
    private static let filterPattern = #"\?\(@\.(\w+)\s*([<>=!]+)\s*(-?[\d.]+)\)"#
    private static let filterRegex: NSRegularExpression = {
        guard let regex = try? NSRegularExpression(pattern: filterPattern) else {
            fatalError("Invalid filterPattern regex: \(filterPattern)")
        }
        return regex
    }()
    
    func evaluate(json: Any, path: String) throws -> [JSON] {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("$") else {
            throw JSONPathError.invalidPath("Path must start with $")
        }
        
        let tokens = try parsePath(trimmed)
        var current: [JSON] = [JSON(wrapped: json)]
        
        for token in tokens {
            var next: [JSON] = []
            for item in current {
                next.append(contentsOf: try applyToken(item, token: token))
            }
            current = next
        }
        return current
    }
    
    private func parsePath(_ path: String) throws -> [String] {
        var tokens: [String] = []
        var rest = path[path.index(after: path.startIndex)...] // skip $
        
        while !rest.isEmpty {
            if rest.first == "." {
                rest = rest.dropFirst()
                // find next . or [
                var end = rest.endIndex
                if let dotIdx = rest.firstIndex(of: ".") { end = dotIdx }
                if let bracketIdx = rest.firstIndex(of: "["), bracketIdx < end { end = bracketIdx }
                tokens.append(String(rest[..<end]))
                rest = rest[end...]
            } else if rest.first == "[" {
                guard let closeIdx = rest.firstIndex(of: "]") else {
                    throw JSONPathError.invalidExpression("Unclosed bracket")
                }
                let content = String(rest[rest.index(after: rest.startIndex)..<closeIdx])
                tokens.append("[\(content)]")
                rest = rest[rest.index(after: closeIdx)...]
            } else {
                throw JSONPathError.invalidExpression("Unexpected: \(rest.first!)")
            }
        }
        return tokens
    }
    
    private func applyToken(_ json: JSON, token: String) throws -> [JSON] {
        if token.hasPrefix("[") && token.hasSuffix("]") {
            let inner = String(token.dropFirst().dropLast())
            switch inner {
            case "*":
                return allChildren(json)
            case let expr where expr.contains("?"):
                return try filterArray(json, expr: expr)
            default:
                if let idx = Int(inner) {
                    return try arrayIndex(json, idx: idx)
                }
                let key = inner.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                return try childByKey(json, key: key)
            }
        }
        return try childByKey(json, key: token)
    }
    
    private func allChildren(_ json: JSON) -> [JSON] {
        if let arr = json.value as? [Any] {
            return arr.map { JSON(wrapped: $0) }
        }
        if let dict = json.value as? [String: Any] {
            return dict.values.map { JSON(wrapped: $0) }
        }
        return []
    }
    
    private func childByKey(_ json: JSON, key: String) throws -> [JSON] {
        if let dict = json.value as? [String: Any], let v = dict[key] {
            return [JSON(wrapped: v)]
        }
        if let arr = json.value as? [Any] {
            var results: [JSON] = []
            for elem in arr {
                if let dict = elem as? [String: Any], let v = dict[key] {
                    results.append(JSON(wrapped: v))
                }
            }
            return results
        }
        throw JSONPathError.notFound(key)
    }
    
    private func arrayIndex(_ json: JSON, idx: Int) throws -> [JSON] {
        guard let arr = json.value as? [Any] else {
            throw JSONPathError.notFound("Not an array")
        }
        let i = idx >= 0 ? idx : arr.count + idx
        guard i >= 0, i < arr.count else {
            throw JSONPathError.notFound("Index \(idx) out of bounds")
        }
        return [JSON(wrapped: arr[i])]
    }
    
    private func filterArray(_ json: JSON, expr: String) throws -> [JSON] {
        // e.g. ?(@.price < 10)
        let regex = Self.filterRegex
        guard let m = regex.firstMatch(in: expr, range: NSRange(expr.startIndex..., in: expr)) else {
            throw JSONPathError.invalidExpression(expr)
        }
        let key = String(expr[Range(m.range(at: 1), in: expr)!])
        let op = String(expr[Range(m.range(at: 2), in: expr)!])
        let numStr = String(expr[Range(m.range(at: 3), in: expr)!])
        guard let threshold = Double(numStr) else {
            throw JSONPathError.invalidExpression("Invalid number: \(numStr)")
        }
        
        guard let arr = json.value as? [Any] else { return [] }
        
        return arr.compactMap { elem -> JSON? in
            guard let dict = elem as? [String: Any],
                  let val = dict[key] as? Double else { return nil }
            let pass: Bool
            switch op {
            case "<":  pass = val < threshold
            case "<=": pass = val <= threshold
            case ">":  pass = val > threshold
            case ">=": pass = val >= threshold
            case "==": pass = val == threshold
            case "!=": pass = val != threshold
            default:   pass = false
            }
            return pass ? JSON(wrapped: elem) : nil
        }
    }
}

struct JSON: @unchecked Sendable {
    let value: Any
    init(wrapped: Any) { self.value = wrapped }
}
