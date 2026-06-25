import SwiftUI
import AITerminalCore

/// 本地端口转发管理：本机端口 →（经 SSH）远端 host:port。增删 + 开关 + 状态。
struct PortForwardView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: TerminalSessionVM

    @State private var localPort = ""
    @State private var remoteHost = "127.0.0.1"
    @State private var remotePort = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if session.portForwards.isEmpty {
                        Text("暂无端口转发")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        ForEach(session.portForwards) { pf in
                            row(pf)
                        }
                    }
                } header: {
                    Text("转发规则")
                } footer: {
                    if let err = session.forwardError {
                        Text(err).foregroundStyle(Theme.danger)
                    } else {
                        Text("开启后，连接本机 127.0.0.1:本地端口 即经此 SSH 通到远端。")
                    }
                }

                Section("新建转发") {
                    HStack {
                        TextField("本地端口", text: $localPort)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Image(systemName: "arrow.right").foregroundStyle(Theme.textSecondary)
                        TextField("远端 host", text: $remoteHost)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                        Text(":").foregroundStyle(Theme.textSecondary)
                        TextField("端口", text: $remotePort)
                            .frame(maxWidth: 70)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }
                    Button {
                        addForward()
                    } label: {
                        Label("添加", systemImage: "plus.circle.fill")
                    }
                    .disabled(Int(localPort) == nil || remoteHost.isEmpty || Int(remotePort) == nil)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("端口转发")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .frame(minWidth: 460, minHeight: 480)
    }

    private func row(_ pf: PortForward) -> some View {
        let active = session.activeForwardIDs.contains(pf.id)
        return HStack(spacing: 10) {
            Circle().fill(active ? Theme.success : Theme.textSecondary).frame(width: 8, height: 8)
            Text(pf.summary)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer()
            Toggle("", isOn: Binding(
                get: { active },
                set: { _ in session.toggleForward(pf) }
            ))
            .labelsHidden()
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                session.removeForward(pf)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func addForward() {
        guard let lp = Int(localPort), let rp = Int(remotePort), !remoteHost.isEmpty else { return }
        session.addForward(localPort: lp, remoteHost: remoteHost.trimmingCharacters(in: .whitespaces), remotePort: rp)
        localPort = ""
        remotePort = ""
    }
}
