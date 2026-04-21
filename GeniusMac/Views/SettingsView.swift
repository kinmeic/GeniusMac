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
                                metricPill(title: "示例", value: "R -> keyCode")
                                Spacer()
                            }

                            VStack(spacing: 0) {
                                HStack {
                                    Text("颜色值 (R)")
                                        .frame(width: 120, alignment: .leading)
                                    Text("按键码")
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
                                            Text(keyMappings[index].keyCode)
                                                .frame(width: 120, alignment: .leading)
                                                .font(.system(.body, design: .rounded))
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

                            HStack(spacing: 10) {
                                TextField("颜色值", text: $newColor)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 130)
                                TextField("按键码", text: $newKeyCode)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 130)
                                Button("添加映射") {
                                    addKeyMapping()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(newColor.isEmpty || newKeyCode.isEmpty)
                                Spacer()
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
