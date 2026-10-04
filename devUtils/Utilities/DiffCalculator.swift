import Foundation

enum DiffType {
    case added
    case removed
    case unchanged
}

struct DiffLine: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let text: String
    let type: DiffType
}

/// Line-based diff used by TextDifferTool.
///
/// Implementation notes:
/// - Common prefix/suffix are trimmed first, which makes the typical
///   "append a few lines" diff O(n) instead of O(m·n).
/// - The middle section uses a full LCS DP table for correct backtracking.
///   (The previous implementation kept only the last DP row and backtracked
///   against it, which produced wrong results for most inputs.)
/// - Above `maxCells` cells the middle falls back to a bounded block replace
///   so huge inputs cannot freeze the UI for minutes.
enum DiffCalculator {

    /// Max LCS table cells (4M cells ≈ 32 MB of Int64 rows).
    static let maxCells = 4_000_000

    static func compute(left: String, right: String,
                        ignoreCase: Bool = false,
                        ignoreWhitespace: Bool = false) -> [DiffLine] {
        let leftLines = left.isEmpty ? [] : left.components(separatedBy: "\n")
        let rightLines = right.isEmpty ? [] : right.components(separatedBy: "\n")

        let process: (String) -> String = { s in
            var result = s
            if ignoreCase { result = result.lowercased() }
            if ignoreWhitespace {
                result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            }
            return result
        }
        let leftProc = leftLines.map(process)
        let rightProc = rightLines.map(process)

        var prefix = 0
        while prefix < leftProc.count && prefix < rightProc.count,
              leftProc[prefix] == rightProc[prefix] {
            prefix += 1
        }
        var suffix = 0
        while suffix < leftProc.count - prefix && suffix < rightProc.count - prefix,
              leftProc[leftProc.count - 1 - suffix] == rightProc[rightProc.count - 1 - suffix] {
            suffix += 1
        }

        var ops: [(String, DiffType)] = []
        for i in 0..<prefix {
            ops.append((leftLines[i], .unchanged))
        }

        let lFrom = prefix, lTo = leftLines.count - suffix
        let rFrom = prefix, rTo = rightLines.count - suffix
        let m = lTo - lFrom, n = rTo - rFrom

        if m > 0 && n > 0 && m * n > maxCells {
            for i in lFrom..<lTo { ops.append((leftLines[i], .removed)) }
            for i in rFrom..<rTo { ops.append((rightLines[i], .added)) }
        } else {
            ops.append(contentsOf: middleDiff(leftProc: leftProc, rightProc: rightProc,
                                              leftLines: leftLines, rightLines: rightLines,
                                              lFrom: lFrom, lTo: lTo,
                                              rFrom: rFrom, rTo: rTo))
        }

        for i in 0..<suffix {
            ops.append((leftLines[leftLines.count - suffix + i], .unchanged))
        }

        return ops.enumerated().map { index, op in
            DiffLine(lineNumber: index + 1, text: op.0, type: op.1)
        }
    }

    private static func middleDiff(leftProc: [String], rightProc: [String],
                                   leftLines: [String], rightLines: [String],
                                   lFrom: Int, lTo: Int,
                                   rFrom: Int, rTo: Int) -> [(String, DiffType)] {
        let m = lTo - lFrom
        let n = rTo - rFrom
        guard m > 0, n > 0 else {
            var ops: [(String, DiffType)] = []
            for i in lFrom..<lTo { ops.append((leftLines[i], .removed)) }
            for i in rFrom..<rTo { ops.append((rightLines[i], .added)) }
            return ops
        }

        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                if leftProc[lFrom + i - 1] == rightProc[rFrom + j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        // Backtrack from (m, n). Appends happen in reverse chronological
        // order; on ties prefer the "added" branch first so the reversed
        // result lists removals before additions (natural reading order).
        var reversed: [(String, DiffType)] = []
        var i = m, j = n
        while i > 0 || j > 0 {
            if i > 0 && j > 0,
               leftProc[lFrom + i - 1] == rightProc[rFrom + j - 1] {
                reversed.append((leftLines[lFrom + i - 1], .unchanged))
                i -= 1
                j -= 1
            } else if i > 0 && (j == 0 || dp[i - 1][j] > dp[i][j - 1]) {
                reversed.append((leftLines[lFrom + i - 1], .removed))
                i -= 1
            } else {
                reversed.append((rightLines[rFrom + j - 1], .added))
                j -= 1
            }
        }
        return reversed.reversed()
    }
}
