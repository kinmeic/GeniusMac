import SwiftUI

struct LogView: View {
    @EnvironmentObject private var viewModel: MainViewModel

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("日志")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.clearLogs()
                } label: {
                    Label("清空", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.logs.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if viewModel.logs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("暂无日志")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.logs) { entry in
                                logRow(entry)
                                    .id(entry.id)
                                Divider()
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: viewModel.logs.last?.id) { id in
                        guard let id else { return }
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 640, minHeight: 420)
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(Self.timeFormatter.string(from: entry.timestamp))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)

            Text(entry.level.rawValue)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(levelColor(entry.level))
                .frame(width: 46, alignment: .leading)

            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }

    private func levelColor(_ level: LogEntry.Level) -> Color {
        switch level {
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
