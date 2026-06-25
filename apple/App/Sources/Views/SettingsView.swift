import SwiftUI
import UniformTypeIdentifiers
import AITerminalCore

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft = AIConfig()
    @State private var showKey = false

    // 连接备份
    @State private var includeSecrets = false
    @State private var exportDoc: DataDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showKnownHosts = false

    /// 绑定到自定义主题某个颜色的 ColorPicker（Color ↔ hex）
    private func customColorPicker(_ label: String, _ keyPath: WritableKeyPath<CustomThemeColors, String>) -> some View {
        ColorPicker(label, selection: Binding(
            get: { Color(hex: model.customColors[keyPath: keyPath]) },
            set: { model.setCustomColor(keyPath, $0.toHexString()) }
        ))
        .font(.system(size: 13))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("配色主题") {
                    Picker("主题", selection: $model.themeID) {
                        ForEach(AppColorScheme.all) { scheme in
                            Text(scheme.name).tag(scheme.id)
                        }
                        Text("自定义").tag(AppColorScheme.customID)
                    }
                    .pickerStyle(.menu)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(AppColorScheme.all) { scheme in
                                ThemeThumbnail(background: scheme.background, foreground: scheme.termForeground,
                                               accent: scheme.accent, name: scheme.name,
                                               selected: scheme.id == model.themeID)
                                    .onTapGesture { model.themeID = scheme.id }
                            }
                            // 自定义主题缩略图（用当前自定义颜色）
                            ThemeThumbnail(background: model.customColors.background, foreground: model.customColors.textPrimary,
                                           accent: model.customColors.accent, name: "自定义",
                                           selected: model.themeID == AppColorScheme.customID)
                                .onTapGesture { model.themeID = AppColorScheme.customID }
                        }
                        .padding(.vertical, 4)
                    }

                    if model.themeID == AppColorScheme.customID {
                        customColorPicker("背景", \.background)
                        customColorPicker("主文字", \.textPrimary)
                        customColorPicker("强调色", \.accent)
                        customColorPicker("终端光标", \.caret)
                    }
                }

                Section("AI 服务商") {
                    Picker("Provider", selection: $draft.provider) {
                        ForEach(AIProvider.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    HStack {
                        if showKey {
                            TextField(keyPlaceholder, text: $draft.apiKey)
                        } else {
                            SecureField(keyPlaceholder, text: $draft.apiKey)
                        }
                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("\(draft.provider.displayName) API Key")
                } footer: {
                    Text("密钥仅保存在本设备。切换服务商会分别记住各自的密钥。")
                }

                Section("模型") {
                    TextField("模型名称", text: $draft.model)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    Picker("快速选择", selection: $draft.model) {
                        ForEach(draft.provider.commonModels, id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("API 地址") {
                    TextField("Base URL", text: $draft.baseURL)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    Button("恢复默认地址") {
                        draft.baseURLOverrides[draft.provider.rawValue] = ""
                    }
                    .font(.caption)
                }

                Section {
                    Menu {
                        ForEach(PromptPreset.all) { preset in
                            Button(preset.name) { model.agentSystemPrompt = preset.text }
                        }
                    } label: {
                        Label("套用预设模板", systemImage: "text.badge.checkmark")
                    }
                    TextEditor(text: $model.agentSystemPrompt)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 120)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    Button("恢复默认提示词") {
                        model.resetAgentSystemPrompt()
                    }
                    .font(.caption)
                } header: {
                    Text("AI 系统提示词")
                } footer: {
                    Text("可套用预设（默认/只读/详解/精简）或自行编辑。请保留 [EXECUTE]命令[/EXECUTE] 用法说明，否则 AI 无法在终端执行命令。")
                }

                Section {
                    Toggle("导出时包含密码（明文，谨慎）", isOn: $includeSecrets)
                    Button {
                        exportDoc = DataDocument(data: model.exportConnectionsData(includeSecrets: includeSecrets))
                        showExporter = true
                    } label: {
                        Label("导出连接…", systemImage: "square.and.arrow.up")
                    }
                    .disabled(model.connections.isEmpty)
                    Button {
                        showImporter = true
                    } label: {
                        Label("导入连接…", systemImage: "square.and.arrow.down")
                    }
                    #if os(macOS)
                    Button {
                        model.importSSHConfig()
                    } label: {
                        Label("从 ~/.ssh/config 导入", systemImage: "doc.text")
                    }
                    #endif
                } header: {
                    Text("连接备份")
                } footer: {
                    Text("跨端通用 JSON 格式（详见 docs/connection-format.md）。默认不导出密码。")
                }

                Section {
                    Button {
                        showKnownHosts = true
                    } label: {
                        Label("管理已知主机", systemImage: "key")
                    }
                } header: {
                    Text("主机密钥（TOFU）")
                } footer: {
                    Text("首次连接会记录服务器指纹，之后校验；若提示「主机密钥已变化」且确认服务器确实更换了密钥，可在此删除对应主机后重连。")
                }

                Section {
                    Text("AI Terminal v1.0.0\n原生 macOS / iOS 终端工具")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("设置")
            .fileExporter(isPresented: $showExporter, document: exportDoc, contentType: .json, defaultFilename: "ai-terminal-connections") { _ in }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    if let data = try? Data(contentsOf: url) { model.importConnections(from: data) }
                }
            }
            .sheet(isPresented: $showKnownHosts) {
                KnownHostsView()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        draft.apiKey = draft.apiKey.trimmingCharacters(in: .whitespaces)
                        draft.baseURL = draft.baseURL.trimmingCharacters(in: .whitespaces)
                        model.saveAIConfig(draft)
                        dismiss()
                    }
                }
            }
            .onAppear { draft = model.aiConfig }
        }
        .frame(minWidth: 440, minHeight: 480)
    }

    private var keyPlaceholder: String {
        draft.provider == .anthropic ? "sk-ant-…" : "sk-…"
    }
}
