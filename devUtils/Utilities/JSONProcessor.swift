import Foundation

/// Shared, testable JSON processing used by JSON Editor (editor) and
/// JSONPath (viewer). All heavy work here is synchronous and pure so the UI
/// can run it off the main thread.
enum JSONProcessor {

    /// 50 MB input cap (UTF-8 bytes).
    static let maxInputBytes = 50_000_000

    /// Max characters rendered in the output pane; the full result is always
    /// available through Copy. Keeps SwiftUI from laying out multi-MB text.
    static let defaultDisplayLimit = 120_000

    enum Failure: Equatable, Error {
        case tooLarge(actual: Int, limit: Int)
        case invalid(String)

        var message: String {
            switch self {
            case .tooLarge(let actual, let limit):
                return L(.jsonTooLarge, actual / 1_000_000, limit / 1_000_000)
            case .invalid(let detail):
                return detail
            }
        }
    }

    struct SerializationError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Read-only preview of (potentially huge) output.
    struct Preview: Equatable {
        let display: String
        let truncated: Bool
        let totalCharacters: Int
    }

    // MARK: - Size validation

    static func checkSize(_ input: String, limit: Int = maxInputBytes) -> Failure? {
        let bytes = input.utf8.count
        guard bytes >= limit else { return nil }
        return .tooLarge(actual: bytes, limit: limit)
    }

    // MARK: - Pretty print / minify

    static func prettyPrint(_ input: String, limit: Int = maxInputBytes) -> Result<String, Failure> {
        process(input, options: [.prettyPrinted, .sortedKeys], limit: limit)
    }

    static func minify(_ input: String, limit: Int = maxInputBytes) -> Result<String, Failure> {
        process(input, options: [], limit: limit)
    }

    private static func process(_ input: String,
                                options: JSONSerialization.WritingOptions,
                                limit: Int) -> Result<String, Failure> {
        if let sizeFailure = checkSize(input, limit: limit) {
            return .failure(sizeFailure)
        }
        let (object, error) = tryParseJSON(input)
        if let error = error {
            return .failure(.invalid(error))
        }
        guard let object = object else {
            return .failure(.invalid(L(.invalidJSON)))
        }
        do {
            return .success(try serialize(object, options: options))
        } catch {
            return .failure(.invalid("\(L(.invalidJSON)): \(error.localizedDescription)"))
        }
    }

    // MARK: - Query (JSONPath viewer)

    static func query(_ input: String, path: String, limit: Int = maxInputBytes) -> Result<[JSON], Failure> {
        if let sizeFailure = checkSize(input, limit: limit) {
            return .failure(sizeFailure)
        }
        let (object, error) = tryParseJSON(input)
        if let error = error {
            return .failure(.invalid(error))
        }
        guard let object = object else {
            return .failure(.invalid(L(.invalidJSON)))
        }
        do {
            return .success(try JSONPathEngine().evaluate(json: object, path: path))
        } catch {
            return .failure(.invalid(error.localizedDescription))
        }
    }

    /// Serializes query results: a single result is printed as itself,
    /// multiple results as an array. Top-level scalars (fragments) are handled.
    static func formatQueryResults(_ results: [JSON]) throws -> String {
        guard !results.isEmpty else { return "" }
        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
        if results.count == 1 {
            return try serialize(results[0].value, options: options)
        }
        return try serialize(results.map { $0.value }, options: options)
    }

    // MARK: - Serialization (fragment safe)

    static func serialize(_ value: Any,
                          options: JSONSerialization.WritingOptions = []) throws -> String {
        if JSONSerialization.isValidJSONObject(value) {
            let data = try JSONSerialization.data(withJSONObject: value, options: options)
            guard let text = String(data: data, encoding: .utf8) else {
                throw SerializationError(message: "Failed to encode JSON as UTF-8")
            }
            return text
        }
        // Top-level fragment (number/string/bool/null): serialize wrapped in an
        // array, then unwrap. JSONSerialization refuses to write fragments.
        let data = try JSONSerialization.data(withJSONObject: [value], options: options)
        guard var wrapped = String(data: data, encoding: .utf8),
              wrapped.hasPrefix("["), wrapped.hasSuffix("]") else {
            throw SerializationError(message: "Failed to encode JSON fragment")
        }
        wrapped.removeFirst()
        wrapped.removeLast()
        return wrapped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Display preview

    static func preview(_ text: String, limit: Int = defaultDisplayLimit) -> Preview {
        let total = text.count
        guard total > limit else {
            return Preview(display: text, truncated: false, totalCharacters: total)
        }
        let cut = text.index(text.startIndex, offsetBy: limit)
        return Preview(display: String(text[..<cut]), truncated: true, totalCharacters: total)
    }
}
