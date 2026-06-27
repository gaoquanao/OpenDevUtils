import SwiftUI

struct TimestampTool: Tool {
    let id = "timestamp"
    let name = "Timestamp"
    let icon = "calendar"
    let category: ToolCategory = .webDev
    
    @State private var inputTimestamp = ""
    @State private var inputDate = ""
    @State private var currentTimestamp = ""
    @State private var convertedDate = ""
    @State private var convertedTimestamp = ""
    @State private var timestampUnit: TimestampUnit = .seconds
    @State private var errorMessage: String?
    @ObservedObject private var lang = LanguageManager.shared
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    enum TimestampUnit: String, CaseIterable {
        case seconds
        case milliseconds
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(spacing: 16) {
                nowSection
                Divider()
                convertSection
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
        }
        .onAppear { refreshCurrent() }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var header: some View {
        HStack {
            Text(L(.unixTimestampConverter))
                .font(.title2.bold())
            Spacer()
            Button(L(.refresh)) { refreshCurrent() }
        }
        .padding(.vertical, 8)
    }
    
    private var nowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.currentTime)).font(.headline)
            HStack {
                Text(currentTimestamp)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                
                Button {
                    PasteboardHelper.writeString(currentTimestamp)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help(L(.copy))
            }
        }
    }
    
    private var convertSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L(.timestampToDate)).font(.headline)
                    Spacer()
                    Picker("", selection: $timestampUnit) {
                        Text(L(.seconds)).tag(TimestampUnit.seconds)
                        Text(L(.milliseconds)).tag(TimestampUnit.milliseconds)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                
                HStack {
                    TextField(L(.enterTimestamp), text: $inputTimestamp)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { timestampToDate() }
                    
                    Button(L(.convert)) { timestampToDate() }
                        .buttonStyle(.borderedProminent)
                }
                
                if !convertedDate.isEmpty {
                    HStack {
                        Text(convertedDate)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                        Button {
                            PasteboardHelper.writeString(convertedDate)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L(.dateToTimestamp)).font(.headline)
                
                HStack {
                    TextField(L(.enterDate), text: $inputDate)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { dateToTimestamp() }
                    
                    Button(L(.convert)) { dateToTimestamp() }
                        .buttonStyle(.borderedProminent)
                }
                
                if !convertedTimestamp.isEmpty {
                    HStack {
                        Text(convertedTimestamp)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        Button {
                            PasteboardHelper.writeString(convertedTimestamp)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                }
            }
            
            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }
    
    private func refreshCurrent() {
        let now = Date()
        let ts = Int(now.timeIntervalSince1970)
        currentTimestamp = "\(ts)  (\(dateFormatter.string(from: now)))"
    }
    
    private func timestampToDate() {
        errorMessage = nil
        guard let num = Double(inputTimestamp.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = L(.invalidJSON)
            return
        }
        
        let interval: TimeInterval
        switch timestampUnit {
        case .seconds: interval = num
        case .milliseconds: interval = num / 1000.0
        }
        
        let date = Date(timeIntervalSince1970: interval)
        convertedDate = "\(dateFormatter.string(from: date))  (\(Int(date.timeIntervalSince1970)))"
    }
    
    private func dateToTimestamp() {
        errorMessage = nil
        let trimmed = inputDate.trimmingCharacters(in: .whitespaces)
        
        guard let date = dateFormatter.date(from: trimmed) else {
            errorMessage = L(.invalidDateFormat)
            return
        }
        
        let ts = Int(date.timeIntervalSince1970)
        let tsMs = Int(date.timeIntervalSince1970 * 1000)
        convertedTimestamp = "s: \(ts)    ms: \(tsMs)"
    }
}
