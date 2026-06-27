import SwiftUI

struct CronTool: Tool {
    let id = "cronParser"
    let name = "Cron Parser"
    let icon = "clock"
    let category: ToolCategory = .encoding
    
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
    
    private func parse() {
        errorMessage = nil
        parsedFields = []
        nextRuns = []
        humanReadable = ""
        
        let parts = cronExpression.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
        
        guard parts.count == 5 else {
            errorMessage = "Cron expression must have 5 fields"
            return
        }
        
        let names: [String]
        switch lang.language {
        case .zh: names = ["分钟", "小时", "日", "月", "星期"]
        case .ja: names = ["分", "時", "日", "月", "曜日"]
        case .ko: names = ["분", "시", "일", "월", "요일"]
        case .en: names = ["Minute", "Hour", "Day", "Month", "Weekday"]
        }
        
        let ranges: [(Int, Int)] = [(0, 59), (0, 23), (1, 31), (1, 12), (0, 7)]
        
        for (i, part) in parts.enumerated() {
            let desc = describeField(part, range: ranges[i])
            parsedFields.append(CronField(name: names[i], value: part, description: desc))
        }
        
        humanReadable = buildDescription(parts)
        nextRuns = calculateNextRuns(parts, count: 10)
    }
    
    private func describeField(_ field: String, range: (Int, Int)) -> String {
        if field == "*" { return "Every \(range.1 == 59 ? "minute" : range.1 == 23 ? "hour" : range.1 == 31 ? "day" : range.1 == 12 ? "month" : "weekday")" }
        if field.contains("/") {
            let parts = field.components(separatedBy: "/")
            if parts.count == 2, let step = Int(parts[1]) {
                return "Every \(step) \(range.1 == 59 ? "minutes" : range.1 == 23 ? "hours" : range.1 == 31 ? "days" : range.1 == 12 ? "months" : "weekdays")"
            }
        }
        if field.contains("-") {
            let parts = field.components(separatedBy: "-")
            if parts.count == 2 { return "From \(parts[0]) to \(parts[1])" }
        }
        if field.contains(",") {
            return "At \(field.replacingOccurrences(of: ",", with: ", "))"
        }
        return "At \(field)"
    }
    
    private func buildDescription(_ parts: [String]) -> String {
        let mins = describeField(parts[0], range: (0, 59))
        let hours = describeField(parts[1], range: (0, 23))
        let days = describeField(parts[2], range: (1, 31))
        let months = describeField(parts[3], range: (1, 12))
        let weekdays = describeField(parts[4], range: (0, 7))
        
        var desc = "Runs \(mins.lowercased())"
        if parts[1] != "*" { desc += " past \(hours.lowercased())" }
        if parts[2] != "*" { desc += " on \(days.lowercased())" }
        if parts[3] != "*" { desc += " in \(months.lowercased())" }
        if parts[4] != "*" { desc += " on \(weekdays.lowercased())" }
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
        
        return matchField(parts[0], value: comps.minute ?? 0, min: 0, max: 59) &&
               matchField(parts[1], value: comps.hour ?? 0, min: 0, max: 23) &&
               matchField(parts[2], value: comps.day ?? 1, min: 1, max: 31) &&
               matchField(parts[3], value: comps.month ?? 1, min: 1, max: 12) &&
               matchField(parts[4], value: (comps.weekday ?? 1) % 7, min: 0, max: 7)
    }
    
    private func matchField(_ field: String, value: Int, min: Int, max: Int) -> Bool {
        if field == "*" { return true }
        if field.hasPrefix("*/") {
            if let step = Int(String(field.dropFirst(2))) {
                return value % step == 0
            }
        }
        if field.contains("/") {
            let parts = field.components(separatedBy: "/")
            if parts.count == 2, let step = Int(parts[1]) {
                if parts[0] == "*" {
                    return value % step == 0
                }
                let rangeParts = parts[0].components(separatedBy: "-")
                if rangeParts.count == 2, let low = Int(rangeParts[0]), let high = Int(rangeParts[1]) {
                    return value >= low && value <= high && (value - low) % step == 0
                }
            }
        }
        if field.contains("-") {
            let parts = field.components(separatedBy: "-")
            if parts.count == 2, let low = Int(parts[0]), let high = Int(parts[1]) {
                return value >= low && value <= high
            }
        }
        if field.contains(",") {
            let values = field.components(separatedBy: ",").compactMap { Int($0) }
            return values.contains(value)
        }
        if let v = Int(field) {
            return value == v
        }
        return false
    }
}
