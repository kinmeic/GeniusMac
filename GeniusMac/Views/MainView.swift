import SwiftUI
import AppKit
import Combine

struct MainView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @Environment(\.openWindow) private var openWindow

    private static let logTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 0) {
            processPane
                .frame(width: 300)

            Divider()

            dashboardPane
                .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 820, minHeight: 520)
        .onAppear {
            viewModel.onAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshRuntimeState()
        }
        .alert("需要屏幕录制权限", isPresented: $viewModel.showPermissionAlert) {
            Button("打开系统设置") {
                viewModel.openScreenRecordingSettings()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("请在「系统设置 → 隐私与安全性 → 屏幕录制」中开启 GeniusMac 的权限，然后重新启动应用。")
        }
    }

    private var processPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("进程", systemImage: "macwindow")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.refreshProcesses()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
                .help("刷新进程列表")
                .disabled(viewModel.isMonitoring)
            }

            selectionSummary

            List(selection: $viewModel.selectedProcessID) {
                ForEach(viewModel.processes) { process in
                    processRow(process)
                        .tag(Optional(process.id))
                }
            }
            .listStyle(.sidebar)
            .disabled(viewModel.isMonitoring)
            .overlay {
                if viewModel.processes.isEmpty {
                    Text("暂无可见进程")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.isMonitoring ? "已锁定目标" : "当前选择")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let selectedProcess {
                Text(selectedProcess.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                Text("PID \(selectedProcess.pid)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text("未选择进程")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }

    private func processRow(_ process: RunningProcess) -> some View {
        HStack(spacing: 10) {
            Image(systemName: selectedProcess?.id == process.id ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selectedProcess?.id == process.id ? .blue : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .lineLimit(1)
                Text("PID \(process.pid)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var dashboardPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Genius")
                        .font(.title2.weight(.semibold))
                    Text(viewModel.isMonitoring ? "正在捕获" : "待命")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                statusBadge
            }

            statusGrid

            actionPanel

            recentLogsPanel
        }
        .padding(20)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isMonitoring ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
            Text(viewModel.isMonitoring ? "运行中" : "空闲")
                .font(.system(.caption, design: .rounded, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var statusGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            statusCard(title: "状态", value: viewModel.statusText, systemImage: "waveform.path.ecg", tint: statusColor)
            statusCard(title: "权限", value: viewModel.permissionSummary, systemImage: "lock.shield", tint: viewModel.permissionsHealthy ? .green : .orange)
            statusCard(title: "窗口", value: viewModel.isTargetForeground ? "前台" : "后台", systemImage: "rectangle.on.rectangle", tint: viewModel.isTargetForeground ? .green : .orange)
            statusCard(title: "监视频率", value: viewModel.monitorFrequencyText, systemImage: "timer", tint: .secondary)
        }
    }

    private func statusCard(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var actionPanel: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.startMonitoring()
            } label: {
                Label("开始捕获", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.selectedProcessID == nil || viewModel.isMonitoring)

            Button {
                viewModel.stopMonitoring()
            } label: {
                Label("停止", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!viewModel.isMonitoring)

            Button {
                openWindow(id: "settings")
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("打开设置")
            .disabled(viewModel.isMonitoring)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var recentLogsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("最近日志", systemImage: "list.bullet.rectangle")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.clearLogs()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("清空日志")
                .disabled(viewModel.logs.isEmpty)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if viewModel.logs.isEmpty {
                            Text("暂无日志")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                        } else {
                            ForEach(viewModel.logs.suffix(80)) { entry in
                                recentLogRow(entry)
                                    .id(entry.id)
                                Divider()
                            }
                        }
                    }
                }
                .onChange(of: viewModel.logs.last?.id) { id in
                    guard let id else { return }
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func recentLogRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(Self.logTimeFormatter.string(from: entry.timestamp))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)

            Text(entry.level.rawValue)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(logLevelColor(entry.level))
                .frame(width: 42, alignment: .leading)

            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }

    private var selectedProcess: RunningProcess? {
        guard let selectedProcessID = viewModel.selectedProcessID else { return nil }
        return viewModel.processes.first { $0.id == selectedProcessID }
    }

    private var statusColor: Color {
        if viewModel.statusText.contains("错误") || viewModel.statusText.contains("退出") {
            return .red
        } else if viewModel.statusText.contains("运行中") || viewModel.statusText.contains("监视中") || viewModel.statusText.contains("R:") {
            return .green
        } else {
            return .primary
        }
    }

    private func logLevelColor(_ level: LogEntry.Level) -> Color {
        switch level {
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private func compactStatusItem(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(tint)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.8))
        )
    }
}

// MARK: - ViewModel

@MainActor
final class MainViewModel: ObservableObject {
    @Published var processes: [RunningProcess] = []
    @Published var selectedProcessID: Int? = nil
    @Published var isMonitoring = false
    @Published var statusText = "等待中..."
    @Published var isTargetForeground = false
    @Published var config = Config()
    @Published var showPermissionAlert = false
    @Published var screenRecordingGranted = false
    @Published var accessibilityGranted = false
    @Published var logs: [LogEntry] = []

    private let processManager = ProcessManager()
    private let pixelMonitor = PixelMonitor()
    private let windowObserver = WindowObserver()
    private let configService = ConfigService()
    private let permissionService = PermissionService()

    private var cancellables = Set<AnyCancellable>()
    private var lastLoggedCaptureError: CaptureEvent.Error?
    private var didLogCaptureRecovery = false
    private var didInitialize = false
    private let maxLogCount = 500

    var permissionsHealthy: Bool {
        screenRecordingGranted && accessibilityGranted
    }

    var permissionSummary: String {
        switch (screenRecordingGranted, accessibilityGranted) {
        case (true, true):
            return "全部正常"
        case (false, false):
            return "录屏 / 辅助功能"
        case (false, true):
            return "缺少录屏"
        case (true, false):
            return "缺少辅助功能"
        }
    }

    var monitorFrequencyText: String {
        let activeInterval = isTargetForeground ? config.interval : config.backgroundInterval
        return "\(activeInterval) ms"
    }

    func onAppear() {
        guard !didInitialize else { return }
        didInitialize = true

        config = configService.load()
        pixelMonitor.delegate = self
        appendLog("应用已启动")
        refreshRuntimeState()

        windowObserver.$isTargetForeground
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                guard let self else { return }
                let changed = self.isTargetForeground != value
                self.isTargetForeground = value
                self.pixelMonitor.updateForegroundState(value)
                if changed {
                    self.appendLog(value ? "目标窗口进入前台" : "目标窗口离开前台")
                    self.updateSamplingInterval()
                }
            }
            .store(in: &cancellables)
    }

    func refreshProcesses() {
        refreshProcesses(shouldLog: true)
    }

    private func refreshProcesses(shouldLog: Bool) {
        processes = processManager.listVisibleProcesses()
        if let selectedProcessID,
           !processes.contains(where: { $0.id == selectedProcessID }) {
            self.selectedProcessID = nil
        }
        if shouldLog {
            appendLog("已刷新进程列表，共 \(processes.count) 个可见进程")
        }
    }

    func saveConfig() {
        configService.save(config)
        updateSamplingInterval()
    }

    func refreshRuntimeState() {
        screenRecordingGranted = permissionService.screenRecordingGranted()
        accessibilityGranted = permissionService.accessibilityGranted()
        refreshProcesses(shouldLog: false)
    }

    func startMonitoring() {
        guard let pidInt = selectedProcessID else { return }
        let pid = pid_t(pidInt)

        refreshRuntimeState()

        guard processManager.findProcess(byPID: pid) != nil else {
            statusText = "进程不存在或已退出"
            appendLog("启动监视失败：进程不存在或已退出，PID \(pid)", level: .error)
            return
        }

        guard screenRecordingGranted else {
            statusText = "缺少屏幕录制权限"
            showPermissionAlert = true
            appendLog("启动监视失败：缺少屏幕录制权限", level: .error)
            return
        }

        pixelMonitor.targetPID = pid
        pixelMonitor.x = config.captureX
        pixelMonitor.y = config.captureY
        pixelMonitor.interval = normalizedInterval(isForeground: false)
        pixelMonitor.filterG = config.filterG
        pixelMonitor.filterB = config.filterB
        pixelMonitor.keyMappings = Dictionary(
            uniqueKeysWithValues: config.keyMappings.compactMap { key, value in
                guard let color = Int(key) else { return nil }
                return (color, CGKeyCode(truncatingIfNeeded: value))
            }
        )
        pixelMonitor.updateForegroundState(false)

        showPermissionAlert = false
        windowObserver.targetProcessID = pid
        windowObserver.startMonitoring()

        pixelMonitor.start()
        isMonitoring = true
        statusText = "监视中..."
        lastLoggedCaptureError = nil
        didLogCaptureRecovery = false
        appendLog("开始监视 PID \(pid)，采样点 (\(config.captureX), \(config.captureY))")
    }

    func stopMonitoring() {
        pixelMonitor.stop()
        windowObserver.stopMonitoring()
        isMonitoring = false
        isTargetForeground = false
        statusText = "等待中..."
        appendLog("停止监视")
    }

    func clearLogs() {
        logs.removeAll()
    }

    func openScreenRecordingSettings() {
        permissionService.openScreenRecordingSettings()
    }

    func openAccessibilitySettings() {
        permissionService.openAccessibilitySettings()
    }

    private func updateSamplingInterval() {
        let newInterval = normalizedInterval(isForeground: isTargetForeground)
        pixelMonitor.updateInterval(newInterval)
    }

    private func normalizedInterval(isForeground: Bool) -> TimeInterval {
        let intervalMS = isForeground ? config.interval : config.backgroundInterval
        return max(Double(intervalMS) / 1000.0, 0.005)
    }

    private func appendLog(_ message: String, level: LogEntry.Level = .info) {
        logs.append(LogEntry(timestamp: Date(), level: level, message: message))
        if logs.count > maxLogCount {
            logs.removeFirst(logs.count - maxLogCount)
        }
    }
}

// MARK: - PixelMonitorDelegate

extension MainViewModel: PixelMonitorDelegate {
    nonisolated func pixelMonitor(_ monitor: PixelMonitor, didUpdate event: CaptureEvent) {
        Task { @MainActor in
            switch event.error {
            case .success:
                showPermissionAlert = false
                screenRecordingGranted = true
                statusText = String(format: "R:%d G:%d B:%d", event.r, event.g, event.b)
                if !didLogCaptureRecovery || lastLoggedCaptureError != nil {
                    appendLog("采样正常，当前色值 R:\(event.r) G:\(event.g) B:\(event.b)")
                    didLogCaptureRecovery = true
                    lastLoggedCaptureError = nil
                }

            case .noWindowHandle:
                statusText = "未找到可采样的目标窗口"
                logCaptureErrorIfNeeded(.noWindowHandle, message: "未找到可采样的目标窗口", level: .warning)
            case .processExited:
                statusText = "进程不存在或已退出"
                logCaptureErrorIfNeeded(.processExited, message: "目标进程不存在或已退出", level: .error)
                stopMonitoring()
            case .notResponding:
                statusText = "进程无响应..."
                logCaptureErrorIfNeeded(.notResponding, message: "目标进程无响应", level: .warning)
            case .permissionDenied:
                statusText = "缺少屏幕录制权限"
                screenRecordingGranted = false
                showPermissionAlert = true
                logCaptureErrorIfNeeded(.permissionDenied, message: "缺少屏幕录制权限", level: .error)
                stopMonitoring()
            }
        }
    }

    nonisolated func pixelMonitor(_ monitor: PixelMonitor, didTriggerKey keyCode: CGKeyCode, event: CaptureEvent) {
        Task { @MainActor in
            appendLog(
                "发送按键 \(keyName(for: keyCode)) (keyCode \(keyCode))，RGB R:\(event.r) G:\(event.g) B:\(event.b)，rgb \(event.rgb)"
            )
        }
    }

    private func logCaptureErrorIfNeeded(
        _ error: CaptureEvent.Error,
        message: String,
        level: LogEntry.Level
    ) {
        guard lastLoggedCaptureError != error else { return }
        lastLoggedCaptureError = error
        appendLog(message, level: level)
    }

    private func keyName(for keyCode: CGKeyCode) -> String {
        switch keyCode {
        case 0:
            return "A"
        case 11:
            return "B"
        case 18:
            return "1"
        case 19:
            return "2"
        case 20:
            return "3"
        case 21:
            return "4"
        case 22:
            return "6"
        case 23:
            return "5"
        case 24:
            return "="
        case 25:
            return "9"
        case 26:
            return "7"
        case 28:
            return "8"
        case 29:
            return "0"
        case 49:
            return "Space"
        case 50:
            return "`"
        case 96:
            return "F5"
        case 97:
            return "F6"
        case 98:
            return "F7"
        case 99:
            return "F3"
        case 100:
            return "F8"
        case 101:
            return "F9"
        case 103:
            return "F11"
        case 109:
            return "F10"
        case 111:
            return "F12"
        case 118:
            return "F4"
        case 120:
            return "F2"
        case 122:
            return "F1"
        default:
            return "Unknown"
        }
    }
}
