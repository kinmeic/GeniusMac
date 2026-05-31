import SwiftUI
import AppKit
import Combine

struct MainView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            controlRow
            actionRow
            bottomStatusBar
        }
        .padding(.top, 10)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .frame(minWidth: 432, minHeight: 176)
        .background(Color(nsColor: .windowBackgroundColor))
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

    private var header: some View {
        EmptyView()
    }

    private var controlRow: some View {
        HStack(spacing: 10) {
            Picker("目标进程", selection: $viewModel.selectedProcessID) {
                Text("请选择目标进程").tag(nil as Int?)
                ForEach(viewModel.processes) { process in
                    Text(process.displayName).tag(Optional(process.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.large)
            .frame(minWidth: 208, maxWidth: .infinity, alignment: .leading)
            .disabled(viewModel.isMonitoring)

            Button {
                viewModel.refreshProcesses()
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(viewModel.isMonitoring)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.startMonitoring()
            } label: {
                Label("开始监视", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.selectedProcessID == nil || viewModel.isMonitoring)

            Button {
                viewModel.stopMonitoring()
            } label: {
                Label("停止监视", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!viewModel.isMonitoring)

            Button {
                openWindow(id: "logs")
            } label: {
                Label("日志", systemImage: "doc.text")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                openWindow(id: "settings")
            } label: {
                Label("设置", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(viewModel.isMonitoring)
        }
    }

    private var bottomStatusBar: some View {
        HStack(spacing: 8) {
            compactStatusItem(title: "状态", value: viewModel.statusText, tint: statusColor)
            compactStatusItem(title: "权限", value: viewModel.permissionSummary, tint: viewModel.permissionsHealthy ? .green : .orange)
            compactStatusItem(title: "窗口", value: viewModel.isTargetForeground ? "前台" : "后台", tint: viewModel.isTargetForeground ? .green : .orange)
            compactStatusItem(title: "监视频率", value: viewModel.monitorFrequencyText, tint: .secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.05))
        )
    }

    private var statusColor: Color {
        if viewModel.statusText.contains("错误") || viewModel.statusText.contains("退出") {
            return .red
        } else if viewModel.statusText.contains("运行中") || viewModel.statusText.contains("监视中") {
            return .green
        } else {
            return .primary
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
