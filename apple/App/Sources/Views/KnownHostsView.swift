import SwiftUI
import AITerminalCore

/// 已知主机密钥（TOFU）管理：查看 host → 指纹列表，单条删除或全部清除。
struct KnownHostsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hosts: [HostEntry] = []
    @State private var showClearAlert = false

    struct HostEntry: Identifiable {
        let id = UUID()
        let host: String
        let fingerprint: String
    }

    var body: some View {
        NavigationStack {
            Group {
                if hosts.isEmpty {
                    ContentUnavailableCompat(
                        title: "暂无已知主机",
                        systemImage: "key",
                        description: "首次连接 SSH 主机后，其指纹会记录在此用于 TOFU 校验。"
                    )
                } else {
                    List {
                        Section {
                            ForEach(hosts) { entry in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.host)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(entry.fingerprint)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        KnownHostsStore.shared.forget(entry.host)
                                        reload()
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        } footer: {
                            Text("删除某主机后，下次连接会重新记录其指纹（TOFU 首次信任）。")
                        }
                    }
                }
            }
            .navigationTitle("已知主机")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("全部清除", role: .destructive) {
                        showClearAlert = true
                    }
                    .disabled(hosts.isEmpty)
                }
            }
            .alert("清除全部已知主机？", isPresented: $showClearAlert) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    KnownHostsStore.shared.clear()
                    reload()
                }
            } message: {
                Text("清除后，所有主机下次连接都会重新信任并记录指纹。")
            }
        }
        .frame(minWidth: 460, minHeight: 420)
        .onAppear(perform: reload)
    }

    private func reload() {
        hosts = KnownHostsStore.shared.all().map { HostEntry(host: $0.host, fingerprint: $0.fingerprint) }
    }
}

/// ContentUnavailableView 的兼容封装（统一空态样式）
struct ContentUnavailableCompat: View {
    let title: String
    let systemImage: String
    let description: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(Theme.textSecondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text(description)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
