import SwiftUI
import UniformTypeIdentifiers
import AITerminalCore

struct ConnectionEditView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Connection
    @State private var portText: String
    @State private var showPassword = false
    @State private var showKeyImporter = false

    // 内联连接测试（TCP 可达性）
    enum TestResult { case idle, testing, reachable, unreachable }
    @State private var testResult: TestResult = .idle

    init(connection: Connection) {
        _draft = State(initialValue: connection)
        _portText = State(initialValue: String(connection.port))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("名称（可选）", text: $draft.name)
                    TextField("分组（可选）", text: Binding(
                        get: { draft.group ?? "" },
                        set: { draft.group = $0.isEmpty ? nil : $0 }
                    ))
                    TextField("主机地址", text: $draft.host)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .onChange(of: draft.host) { _, _ in testResult = .idle }
                    TextField("端口", text: $portText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .onChange(of: portText) { _, _ in testResult = .idle }
                    TextField("用户名", text: $draft.username)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    HStack {
                        Button {
                            testConnection()
                        } label: {
                            Label("测试连接", systemImage: "dot.radiowaves.left.and.right")
                        }
                        .disabled(draft.host.trimmingCharacters(in: .whitespaces).isEmpty || testResult == .testing)
                        Spacer()
                        testResultLabel
                    }
                }

                Section("认证方式") {
                    Picker("方式", selection: $draft.authType) {
                        ForEach(AuthType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if draft.authType == .password {
                        HStack {
                            if showPassword {
                                TextField("密码", text: $draft.password)
                            } else {
                                SecureField("密码", text: $draft.password)
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.plain)
                        }
                        Toggle("保存密码", isOn: $draft.savePassword)
                    } else {
                        privateKeySection
                    }
                }

                Section {
                    TextField("跳板主机（留空=不用）", text: Binding(
                        get: { draft.jumpHost ?? "" },
                        set: { draft.jumpHost = $0.isEmpty ? nil : $0 }
                    ))
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    if draft.hasJump || !(draft.jumpHost ?? "").isEmpty {
                        TextField("跳板端口", text: Binding(
                            get: { draft.jumpPort.map(String.init) ?? "22" },
                            set: { draft.jumpPort = Int($0) }
                        ))
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        TextField("跳板用户名", text: Binding(
                            get: { draft.jumpUsername ?? "" },
                            set: { draft.jumpUsername = $0.isEmpty ? nil : $0 }
                        ))
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        SecureField("跳板密码", text: Binding(
                            get: { draft.jumpPassword ?? "" },
                            set: { draft.jumpPassword = $0.isEmpty ? nil : $0 }
                        ))
                    }
                } header: {
                    Text("跳板机 / Bastion（可选）")
                } footer: {
                    Text("配置后先连跳板机再经它连到目标主机（跳板用密码认证）。")
                }

                Section {
                    TextField("如 cd /var/www\nsource venv/bin/activate", text: Binding(
                        get: { draft.startupCommands ?? "" },
                        set: { draft.startupCommands = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(2...6)
                    .autocorrectionDisabled()
                    .font(.system(size: 13, design: .monospaced))
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                } header: {
                    Text("启动命令（可选）")
                } footer: {
                    Text("每行一条，SSH 连接就绪后自动依次执行。")
                }

                Section {
                    TextField("终端字号（留空用全局）", text: Binding(
                        get: { draft.fontSizeOverride.map { String(Int($0)) } ?? "" },
                        set: { draft.fontSizeOverride = clampedFontSize($0) }
                    ))
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                } header: {
                    Text("终端字号（可选）")
                } footer: {
                    Text("仅对该连接生效，范围 8–32；留空则使用全局字号。")
                }

                Section("备注（可选）") {
                    TextField("如：数据库主库 / 需先连 VPN", text: Binding(
                        get: { draft.note ?? "" },
                        set: { draft.note = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(2...4)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                }
            }
            .formStyle(.grouped)
            .navigationTitle(draft.host.isEmpty ? "新建连接" : "编辑连接")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
            .fileImporter(isPresented: $showKeyImporter,
                          allowedContentTypes: [.data, .text, .item],
                          allowsMultipleSelection: false) { result in
                handleKeyImport(result)
            }
        }
        .frame(minWidth: 420, minHeight: 480)
    }

    @ViewBuilder
    private var privateKeySection: some View {
        #if os(macOS)
        HStack {
            Text(draft.privateKeyPath.isEmpty ? "未选择私钥文件" : draft.privateKeyPath)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button("选择文件…") { showKeyImporter = true }
        }
        #else
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("私钥内容")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button("从文件导入") { showKeyImporter = true }
                    .font(.caption)
            }
            TextEditor(text: $draft.privateKeyText)
                .font(.system(size: 11, design: .monospaced))
                .frame(height: 120)
                .autocorrectionDisabled()
        }
        #endif

        SecureField("私钥口令（可选）", text: $draft.passphrase)
    }

    private func handleKeyImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        #if os(macOS)
        draft.privateKeyPath = url.path
        #endif
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            draft.privateKeyText = text
        }
    }

    /// 可保存：主机与用户名去空白后非空
    private var canSave: Bool {
        !draft.host.trimmingCharacters(in: .whitespaces).isEmpty
        && !draft.username.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        guard canSave else { return }
        // 存干净值，避免首尾空白（含分组/备注，防「生产 」与「生产」分裂）
        draft.host = draft.host.trimmingCharacters(in: .whitespaces)
        draft.username = draft.username.trimmingCharacters(in: .whitespaces)
        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
        let g = (draft.group ?? "").trimmingCharacters(in: .whitespaces)
        draft.group = g.isEmpty ? nil : g
        let n = (draft.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        draft.note = n.isEmpty ? nil : n
        draft.port = Int(portText) ?? 22
        model.saveConnection(draft)
        dismiss()
    }

    /// 解析终端字号输入：空/非法→nil，否则夹到 8–32
    private func clampedFontSize(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard let v = Int(t) else { return nil }
        return Double(min(32, max(8, v)))
    }

    /// 测试结果就地展示（颜色 + 文字）
    @ViewBuilder private var testResultLabel: some View {
        switch testResult {
        case .idle:
            EmptyView()
        case .testing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("测试中…").font(.caption).foregroundStyle(Theme.textSecondary)
            }
        case .reachable:
            Label("可达", systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(Theme.success)
        case .unreachable:
            Label("不可达", systemImage: "xmark.circle.fill")
                .font(.caption).foregroundStyle(Theme.danger)
        }
    }

    /// 探测当前填写的 host:port 的 TCP 可达性（不做 SSH 握手）
    private func testConnection() {
        let host = draft.host.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else { return }
        let port = Int(portText) ?? 22
        testResult = .testing
        Task {
            let ok = await ReachabilityChecker.probe(host: host, port: port)
            testResult = ok ? .reachable : .unreachable
        }
    }
}
