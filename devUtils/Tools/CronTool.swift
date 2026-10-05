import SwiftUI

struct CronTool: Tool {
    let id = "cronParser"
    let name = "Cron Parser"
    let icon = "clock"
    let category: ToolCategory = .webDev
    
    @State private var cronExpression = ""
    @State private var parsedFields: [CronField] = []
    @State private var nextRuns: [Date] = []
    @State private var errorMessage: String?
    @State private var humanReadable = ""
    @ObservedObject private var lang = LanguageManager.shared
    
    struct CronField: Identifiable {
        let id = UUID()
        let name: String
        let value: String
        let description: String
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(spacing: 16) {
                inputSection
                if !humanReadable.isEmpty {
                    humanReadableSection
                }
                if !parsedFields.isEmpty {
                    fieldsSection
                }
                if !nextRuns.isEmpty {
                    nextRunsSection
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var header: some View {
        HStack {
            Text(L(.cronExpressionParser))
                .font(.title2.bold())
            Spacer()
            Button(L(.loadExample)) {
                cronExpression = "*/15 0 1,15 * 1-5"
                parse()
            }
            Button(L(.execute)) { parse() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.cronExpression)).font(.headline)
            HStack {
                TextField("e.g. */15 0 1,15 * 1-5", text: $cronExpression)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { parse() }
                
                Button(L(.execute)) { parse() }
                    .buttonStyle(.borderedProminent)
            }
            
            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }
    
    private var humanReadableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.description)).font(.headline)
            Text(humanReadable)
                .font(.body)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)
        }
    }
    
    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.options)).font(.headline)
            // Wrapped in a VStack so the padding/background/cornerRadius
            // below apply to the table as a whole — modifiers on a bare
            // ForEach apply per row, producing five separate cards.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(parsedFields) { field in
                    HStack {
                        Text(field.name)
                            .font(.system(.body, design: .monospaced).bold())
                            .frame(width: 100, alignment: .trailing)
                        Text(field.value)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 80, alignment: .leading)
                        Text(field.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
    }
    
    private var nextRunsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.nextRuns)).font(.headline)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(nextRuns.enumerated()), id: \.offset) { idx, date in
                        HStack {
                            Text("\(idx + 1).")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .trailing)
                            Text(date, style: .date)
                            Text(date, style: .time)
                        }
                        .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .frame(maxHeight: 200)
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
    }
    
    // MARK: - Shared cron field metadata
    private typealias FieldDesc = (singular: LocalizedString, plural: LocalizedString)

    private static let fieldDescriptors: [FieldDesc] = [
        (.cronEveryMinute, .cronEveryMinutes),
        (.cronEveryHour,   .cronEveryHours),
        (.cronEveryDay,    .cronEveryDays),
        (.cronEveryMonth,  .cronEveryMonths),
        (.cronEveryWeekday,.cronEveryWeekdays),
    ]

    private static let fieldRanges: [(Int, Int)] = [(0, 59), (0, 23), (1, 31), (1, 12), (0, 7)]

    private func parse() {
        errorMessage = nil
        parsedFields = []
        nextRuns = []
        humanReadable = ""

        let parts = Self.splitFields(cronExpression)

        guard parts.count == 5 else {
            errorMessage = L(.cronFiveFieldsRequired)
            return
        }

        let names = [
            L(.minute), L(.hour), L(.day), L(.month), L(.weekday)
        ]

        for (i, part) in parts.enumerated() {
            let desc = describeField(part, range: Self.fieldRanges[i], desc: Self.fieldDescriptors[i])
            parsedFields.append(CronField(name: names[i], value: part, description: desc))
        }

        humanReadable = buildDescription(parts)
        nextRuns = calculateNextRuns(parts, count: 10)
    }

    /// Returns a title-cased description for display in the field table.
    private func describeField(_ field: String, range: (Int, Int), desc: (singular: LocalizedString, plural: LocalizedString)) -> String {
        if field == "*" { return L(desc.singular) }
        if field.contains("/") {
            let parts = field.components(separatedBy: "/")
            if parts.count == 2, let step = Int(parts[1]) {
                if step == 1 { return L(desc.singular) }
                return L(desc.plural, step)
            }
        }
        if field.contains("-") {
            let parts = field.components(separatedBy: "-")
            if parts.count == 2 { return L(.cronFromTo, parts[0], parts[1]) }
        }
        if field.contains(",") {
            return L(.cronAt, field.replacingOccurrences(of: ",", with: ", "))
        }
        return L(.cronAt, field)
    }

    private func buildDescription(_ parts: [String]) -> String {
        // Only minimal localization for the structured sentence — full i18n of sentence
        // structure would require a format-string per language.
        let lang = lang.language

        let mins = describeField(parts[0], range: Self.fieldRanges[0], desc: Self.fieldDescriptors[0]).lowercased()
        let hours = describeField(parts[1], range: Self.fieldRanges[1], desc: Self.fieldDescriptors[1]).lowercased()
        let days = describeField(parts[2], range: Self.fieldRanges[2], desc: Self.fieldDescriptors[2]).lowercased()
        let months = describeField(parts[3], range: Self.fieldRanges[3], desc: Self.fieldDescriptors[3]).lowercased()
        let weekdays = describeField(parts[4], range: Self.fieldRanges[4], desc: Self.fieldDescriptors[4]).lowercased()

        var desc = L(.cronRuns, mins)
        if parts[1] != "*" {
            switch lang {
            case .en: desc += " past \(hours)"
            case .zh: desc += "，在 \(hours) 之后"
            case .ja: desc += "、\(hours) 過ぎ"
            case .ko: desc += ", \(hours) 지나서"
            }
        }
        if parts[2] != "*" {
            switch lang {
            case .en, .ja, .ko: desc += " on \(days)"
            case .zh: desc += "，在 \(days)"
            }
        }
        if parts[3] != "*" {
            switch lang {
            case .en: desc += " in \(months)"
            case .zh: desc += "，在 \(months)"
            case .ja: desc += "、\(months) に"
            case .ko: desc += ", \(months)에"
            }
        }
        if parts[4] != "*" {
            switch lang {
            case .en, .ja, .ko: desc += " on \(weekdays)"
            case .zh: desc += "，在 \(weekdays)"
            }
        }
        return desc
    }
    
    private func calculateNextRuns(_ parts: [String], count: Int) -> [Date] {
        let calendar = Calendar.current
        var date = Date()
        var runs: [Date] = []
        
        for _ in 0..<525960 where runs.count < count {
            guard let next = calendar.date(byAdding: Calendar.Component.minute, value: 1, to: date) else { break }
            date = next
            if matchesCron(date: date, parts: parts) {
                runs.append(date)
            }
        }
        return runs
    }
    
    private func matchesCron(date: Date, parts: [String]) -> Bool {
        let cal = Calendar.current
        let comps = cal.dateComponents([.minute, .hour, .day, .month, .weekday], from: date)
        
        return Self.matchField(parts[0], value: comps.minute ?? 0, min: 0, max: 59) &&
               Self.matchField(parts[1], value: comps.hour ?? 0, min: 0, max: 23) &&
               Self.matchField(parts[2], value: comps.day ?? 1, min: 1, max: 31) &&
               Self.matchField(parts[3], value: comps.month ?? 1, min: 1, max: 12) &&
               Self.matchField(parts[4], value: (comps.weekday ?? 1) - 1, min: 0, max: 7)
    }
    
    /// Splits a cron expression into its five fields, tolerating tabs,
    /// newlines (pasted expressions) and repeated whitespace.
    static func splitFields(_ expression: String) -> [String] {
        expression.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    /// Matches one cron field against a value.
    ///
    /// - Note: `max == 7` is the weekday field where cron allows `7` == Sunday
    ///   == `0`; both are normalized to 0 before comparing.
    static func matchField(_ field: String, value: Int, min: Int, max: Int) -> Bool {
        if field.contains(",") {
            return field.components(separatedBy: ",")
                .contains { matchSingleField($0, value: value, min: min, max: max) }
        }
        return matchSingleField(field, value: value, min: min, max: max)
    }

    private static func matchSingleField(_ field: String, value: Int, min: Int, max: Int) -> Bool {
        let trimmed = field.trimmingCharacters(in: .whitespaces)
        if trimmed == "*" { return true }

        var rangePart = trimmed
        var step = 1
        if let slash = trimmed.firstIndex(of: "/") {
            rangePart = String(trimmed[..<slash])
            // step must be a positive integer — `*/0` used to reach `value % 0`
            // and crash the app.
            guard let parsedStep = Int(trimmed[trimmed.index(after: slash)...]), parsedStep > 0 else {
                return false
            }
            step = parsedStep
        }

        let normalize: (Int) -> Int = { v in (max == 7 && v == 7) ? 0 : v }

        let low: Int
        let high: Int
        if rangePart == "*" {
            low = min
            high = max
        } else if rangePart.contains("-") {
            let bounds = rangePart.components(separatedBy: "-")
            guard bounds.count == 2, let a = Int(bounds[0]), let b = Int(bounds[1]) else {
                return false
            }
            low = normalize(a)
            high = normalize(b)
        } else if let single = Int(rangePart) {
            let target = normalize(single)
            if step > 1 {
                // e.g. `0/15` → from target to the field maximum
                low = target
                high = max
            } else {
                return value == target
            }
        } else {
            return false
        }

        let inRange: Bool
        if low <= high {
            inRange = value >= low && value <= high
        } else {
            // wrapped range (e.g. weekday `5-7` normalized to 5...0)
            inRange = value >= low || value <= high
        }
        guard inRange else { return false }

        if step > 1 {
            return ((value - low) % step + step) % step == 0
        }
        return true
    }
}
