import Foundation

/// Regex execution with match/size/time limits, extracted from `RegexTool`
/// so the limits are enforced (and tested) independently of the UI.
enum RegexRunner {

    enum Status: Equatable {
        case success
        case invalidPattern
        case tooLarge
    }

    struct Match: Equatable {
        let text: String
        let range: NSRange
        let groups: [String]
    }

    struct Result {
        let status: Status
        let matches: [Match]
        let truncated: Bool
        let timedOut: Bool
    }

    static let defaultMaxMatches = 10_000
    static let defaultMaxInputBytes = 10_000_000

    /// Runs `pattern` over `input`.
    ///
    /// - Parameters:
    ///   - maxMatches: stop after this many matches (`truncated` is set).
    ///   - maxInputBytes: inputs at or above this size return `.tooLarge`.
    ///   - deadline: when present, matching stops between matches once the
    ///     date passes (`timedOut` is set). This bounds ReDoS-style patterns.
    static func run(pattern: String,
                    input: String,
                    options: NSRegularExpression.Options = [],
                    maxMatches: Int = defaultMaxMatches,
                    maxInputBytes: Int = defaultMaxInputBytes,
                    deadline: Date? = nil) -> Result {
        guard input.utf8.count < maxInputBytes else {
            return Result(status: .tooLarge, matches: [], truncated: false, timedOut: false)
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return Result(status: .invalidPattern, matches: [], truncated: false, timedOut: false)
        }

        let nsInput = input as NSString
        let fullRange = NSRange(location: 0, length: nsInput.length)
        var matches: [Match] = []
        var truncated = false
        var timedOut = false

        regex.enumerateMatches(in: input, options: [], range: fullRange) { match, _, stop in
            if let deadline = deadline, Date() > deadline {
                timedOut = true
                stop.pointee = true
                return
            }
            guard let match = match else { return }

            if matches.count >= maxMatches {
                truncated = true
                stop.pointee = true
                return
            }

            var groups: [String] = []
            if match.numberOfRanges > 1 {
                for i in 1..<match.numberOfRanges {
                    let r = match.range(at: i)
                    if r.location != NSNotFound {
                        groups.append(nsInput.substring(with: r))
                    }
                }
            }

            matches.append(Match(text: nsInput.substring(with: match.range),
                                 range: match.range,
                                 groups: groups))
        }

        return Result(status: .success, matches: matches, truncated: truncated, timedOut: timedOut)
    }
}
