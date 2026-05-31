import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var captureXText: String = ""
    @State private var captureYText: String = ""
    @State private var intervalText: String = ""
    @State private var backgroundIntervalText: String = ""
    @State private var filterGText: String = ""
    @State private var filterBText: String = ""
    @State private var keyMappings: [(color: String, keyCode: String)] = []

    @State private var newColor: String = ""
    @State private var newKeyCode: String = ""
    @State private var capturingKeyCodeID: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    settingsCard(title: "捕获设置", systemImage: "scope") {
                        VStack(alignment: .leading, spacing: 12) {
                            settingsField("坐标 X", text: $captureXText, prompt: "1")
                            settingsField("坐标 Y", text: $captureYText, prompt: "1")
                            settingsField("前台采样间隔", text: $intervalText, prompt: "100", suffix: "ms")
                            settingsField("后台采样间隔", text: $backgroundIntervalText, prompt: "500", suffix: "ms")
                        }
                    }

                    settingsCard(title: "过滤条件", systemImage: "line.3.horizontal.decrease.circle") {
                        VStack(alignment: .leading, spacing: 12) {
                            settingsField("绿色 G", text: $filterGText, prompt: "0")
                            settingsField("蓝色 B", text: $filterBText, prompt: "0")
                        }
                    }

                    settingsCard(title: "按键映射", systemImage: "keyboard") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                metricPill(title: "映射数量", value: "\(keyMappings.count)")
                                metricPill(title: "示例", value: "R -> CGKeyCode")
                                Spacer()
                            }

                            VStack(spacing: 0) {
                                HStack {
                                    Text("颜色值 (R)")
                                        .frame(width: 120, alignment: .leading)
                                    Text("虚拟键码")
                                        .frame(width: 120, alignment: .leading)
                                    Spacer()
                                    Text("操作")
                                        .frame(width: 70, alignment: .trailing)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)

                                Divider()

                                if keyMappings.isEmpty {
                                    Text("还没有按键映射。添加一条颜色值到键码的对应关系后，命中时才会触发按键。")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(14)
                                } else {
                                    ForEach(keyMappings.indices, id: \.self) { index in
                                        HStack {
                                            Text(keyMappings[index].color)
                                                .frame(width: 120, alignment: .leading)
                                                .font(.system(.body, design: .rounded))
                                            KeyCodeCaptureField(
                                                text: bindingForKeyCode(at: index),
                                                isFocused: bindingForKeyCapture(id: "mapping-\(keyMappings[index].color)")
                                            )
                                            .frame(width: 120, height: 24)
                                            Spacer()
                                            Button("删除") {
                                                keyMappings.remove(at: index)
                                            }
                                            .buttonStyle(.borderless)
                                            .foregroundStyle(.red)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)

                                        if index != keyMappings.indices.last {
                                            Divider()
                                        }
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.black.opacity(0.04))
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    TextField("颜色值", text: $newColor)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 130)
                                    KeyCodeCaptureField(
                                        text: $newKeyCode,
                                        isFocused: bindingForKeyCapture(id: "new")
                                    )
                                    .frame(width: 130, height: 24)
                                    Button("添加映射") {
                                        addKeyMapping()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(newColor.isEmpty || newKeyCode.isEmpty)
                                    Spacer()
                                }

                                Text("这里使用 macOS 虚拟键码 CGKeyCode，不是 ASCII；例如 Enter = 36，Space = 49。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Button("关闭") {
                    dismiss()
                }

                Spacer()

                Button("保存") {
                    saveConfig()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 620, minHeight: 560)
        .onAppear {
            loadFromConfig()
        }
    }

    private func loadFromConfig() {
        captureXText = String(viewModel.config.captureX)
        captureYText = String(viewModel.config.captureY)
        intervalText = String(viewModel.config.interval)
        backgroundIntervalText = String(viewModel.config.backgroundInterval)
        filterGText = String(viewModel.config.filterG)
        filterBText = String(viewModel.config.filterB)

        keyMappings = viewModel.config.keyMappings
            .sorted { Int($0.key) ?? 0 < Int($1.key) ?? 0 }
            .map { (color: $0.key, keyCode: String($0.value)) }
    }

    private func saveConfig() {
        var newConfig = viewModel.config
        newConfig.captureX = Int(captureXText) ?? 1
        newConfig.captureY = Int(captureYText) ?? 1
        newConfig.interval = Int(intervalText) ?? 100
        newConfig.backgroundInterval = Int(backgroundIntervalText) ?? 500
        newConfig.filterG = Int(filterGText) ?? 0
        newConfig.filterB = Int(filterBText) ?? 0

        var mappings: [String: Int] = [:]
        for item in keyMappings {
            if let keyCode = Int(item.keyCode) {
                mappings[item.color] = keyCode
            }
        }
        newConfig.keyMappings = mappings

        viewModel.config = newConfig
        viewModel.saveConfig()
    }

    private func addKeyMapping() {
        guard !newColor.isEmpty, !newKeyCode.isEmpty else { return }
        keyMappings.append((color: newColor, keyCode: newKeyCode))
        keyMappings.sort {
            (Int($0.color) ?? 0) < (Int($1.color) ?? 0)
        }
        newColor = ""
        newKeyCode = ""
        capturingKeyCodeID = nil
    }

    private func bindingForKeyCode(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard keyMappings.indices.contains(index) else { return "" }
                return keyMappings[index].keyCode
            },
            set: { newValue in
                guard keyMappings.indices.contains(index) else { return }
                keyMappings[index].keyCode = newValue
            }
        )
    }

    private func bindingForKeyCapture(id: String) -> Binding<Bool> {
        Binding(
            get: { capturingKeyCodeID == id },
            set: { isFocused in
                capturingKeyCodeID = isFocused ? id : (capturingKeyCodeID == id ? nil : capturingKeyCodeID)
            }
        )
    }

    private func settingsCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private func settingsField(
        _ title: String,
        text: Binding<String>,
        prompt: String,
        suffix: String? = nil
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: 88, alignment: .leading)
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
            if let suffix {
                Text(suffix)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .rounded, weight: .medium))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.05))
        )
    }
}

private struct KeyCodeCaptureField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    func makeNSView(context: Context) -> CapturingKeyCodeView {
        let view = CapturingKeyCodeView()
        view.onFocusChange = { focused in
            isFocused = focused
        }
        view.onKeyDown = { keyCode in
            text = String(keyCode)
            isFocused = false
        }
        return view
    }

    func updateNSView(_ nsView: CapturingKeyCodeView, context: Context) {
        nsView.text = text
        nsView.isCapturing = isFocused
    }

    final class CapturingKeyCodeView: NSView {
        var onKeyDown: ((UInt16) -> Void)?
        var onFocusChange: ((Bool) -> Void)?

        var text: String = "" {
            didSet { updateLabel() }
        }

        var isCapturing: Bool = false {
            didSet { updateAppearance() }
        }

        private let label = NSTextField(labelWithString: "按一下按键")

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true

            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingTail
            label.textColor = .placeholderTextColor
            addSubview(label)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                label.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])

            updateAppearance()
        }

        required init?(coder: NSCoder) {
            nil
        }

        override var acceptsFirstResponder: Bool {
            true
        }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
        }

        override func becomeFirstResponder() -> Bool {
            isCapturing = true
            onFocusChange?(true)
            return true
        }

        override func resignFirstResponder() -> Bool {
            isCapturing = false
            onFocusChange?(false)
            return true
        }

        override func keyDown(with event: NSEvent) {
            guard event.keyCode != 53 else {
                window?.makeFirstResponder(nil)
                return
            }

            let keyCode = event.keyCode
            text = String(keyCode)
            onKeyDown?(keyCode)
            window?.makeFirstResponder(nil)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateAppearance()
        }

        private func updateLabel() {
            if text.isEmpty {
                label.stringValue = isCapturing ? "请按键..." : "按一下按键"
                label.textColor = .placeholderTextColor
            } else {
                label.stringValue = text
                label.textColor = .labelColor
            }
        }

        private func updateAppearance() {
            layer?.cornerRadius = 6
            layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
            layer?.borderWidth = isCapturing ? 2 : 1
            layer?.borderColor = (isCapturing ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
            updateLabel()
        }
    }
}
