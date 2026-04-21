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
            .frame(minWidth: 208, maxWidth: .infinity, alignment: .leading)
            .disabled(viewModel.isMonitoring)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.refreshProcesses()
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isMonitoring)

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

    private let processManager = ProcessManager()
    private let pixelMonitor = PixelMonitor()
    private let windowObserver = WindowObserver()
    private let configService = ConfigService()
    private let permissionService = PermissionService()

    private var cancellables = Set<AnyCancellable>()

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
        config = configService.load()
        refreshRuntimeState()
        pixelMonitor.delegate = self

        windowObserver.$isTargetForeground
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isTargetForeground = value
                self?.updateSamplingInterval()
            }
            .store(in: &cancellables)
    }

    func refreshProcesses() {
        processes = processManager.listVisibleProcesses()
        if let selectedProcessID,
           !processes.contains(where: { $0.id == selectedProcessID }) {
            self.selectedProcessID = nil
        }
    }

    func saveConfig() {
        configService.save(config)
        updateSamplingInterval()
    }

    func refreshRuntimeState() {
        screenRecordingGranted = permissionService.screenRecordingGranted()
        accessibilityGranted = permissionService.accessibilityGranted()
        refreshProcesses()
    }

    func startMonitoring() {
        guard let pidInt = selectedProcessID else { return }
        let pid = pid_t(pidInt)

        refreshRuntimeState()

        guard processManager.findProcess(byPID: pid) != nil else {
            statusText = "进程不存在或已退出"
            return
        }

        guard screenRecordingGranted else {
            statusText = "缺少屏幕录制权限"
            showPermissionAlert = true
            return
        }

        pixelMonitor.targetPID = pid
        pixelMonitor.x = config.captureX
        pixelMonitor.y = config.captureY
        pixelMonitor.interval = normalizedInterval(isForeground: false)

        showPermissionAlert = false
        windowObserver.targetProcessID = pid
        windowObserver.startMonitoring()

        pixelMonitor.start()
        isMonitoring = true
        statusText = "监视中..."
    }

    func stopMonitoring() {
        pixelMonitor.stop()
        windowObserver.stopMonitoring()
        isMonitoring = false
        isTargetForeground = false
        statusText = "等待中..."
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
        return max(Double(intervalMS) / 1000.0, 0.05)
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

                guard isTargetForeground else { return }

                if event.g == config.filterG && event.b == config.filterB {
                    if let keyCodeValue = config.getKeyMapping(for: event.r) {
                        KeySimulator.press(keyCode: CGKeyCode(truncatingIfNeeded: keyCodeValue))
                    }
                }

            case .noWindowHandle:
                statusText = "未找到可采样的目标窗口"
            case .processExited:
                statusText = "进程不存在或已退出"
                stopMonitoring()
            case .notResponding:
                statusText = "进程无响应..."
            case .permissionDenied:
                statusText = "缺少屏幕录制权限"
                screenRecordingGranted = false
                showPermissionAlert = true
                stopMonitoring()
            }
        }
    }
}
