import SwiftUI
import AITerminalCore

/// 连接排序方式
enum ConnSortMode: String, CaseIterable {
    case recent, name, manual
    var label: String {
        switch self {
        case .recent: return "最近使用"
        case .name: return "名称"
        case .manual: return "添加顺序"
        }
    }
    var icon: String {
        switch self {
        case .recent: return "clock"
        case .name: return "textformat"
        case .manual: return "list.number"
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var model: AppModel
    @State private var search = ""
    @State private var collapsedGroups: Set<String> = []   // 折叠的分组（对齐 android A-GroupFold）
    @AppStorage("conn_sort_mode") private var sortModeRaw = ConnSortMode.recent.rawValue

    private var sortMode: ConnSortMode { ConnSortMode(rawValue: sortModeRaw) ?? .recent }

    private var filtered: [Connection] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return model.connections }
        return model.connections.filter {
            $0.name.lowercased().contains(q)
            || $0.host.lowercased().contains(q)
            || $0.username.lowercased().contains(q)
            || $0.groupName.lowercased().contains(q)
            || $0.noteText.lowercased().contains(q)
        }
    }

    /// 未分组的连接（按当前排序方式）
    private var ungrouped: [Connection] {
        sorted(filtered.filter { $0.groupName.isEmpty })
    }

    /// 各分组（按组名排序，组内按当前排序方式）
    private var groups: [(name: String, conns: [Connection])] {
        let dict = Dictionary(grouping: filtered.filter { !$0.groupName.isEmpty }) { $0.groupName }
        return dict.keys.sorted().map { (name: $0, conns: sorted(dict[$0] ?? [])) }
    }

    /// 按当前 sortMode 排序
    private func sorted(_ conns: [Connection]) -> [Connection] {
        switch sortMode {
        case .recent: return Self.sortedByRecent(conns)
        case .name: return conns.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .manual: return conns   // 保持原顺序（model.connections 顺序）
        }
    }

    /// 排序：用过的按 lastUsedAt 倒序在前，没用过的保持原顺序在后（稳定）
    static func sortedByRecent(_ conns: [Connection]) -> [Connection] {
        conns.enumerated().sorted { (a, b) -> Bool in
            switch (a.element.lastUsedAt, b.element.lastUsedAt) {
            case let (l?, r?): return l > r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.offset < b.offset
            }
        }.map { $0.element }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            List {
                #if os(macOS)
                Section("本地") {
                    Button {
                        model.openLocalSession()
                    } label: {
                        Label("新建本地终端", systemImage: "laptopcomputer")
                    }
                    .buttonStyle(.plain)
                }
                #endif

                Section {
                    if model.connections.isEmpty {
                        Text("暂无保存的连接")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    } else if filtered.isEmpty {
                        Text("无匹配「\(search)」的连接")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        ForEach(ungrouped) { conn in
                            ConnectionRow(connection: conn)
                        }
                    }
                } header: {
                    HStack {
                        Text("SSH 连接")
                        // 始终显示连接数：搜索时为命中数、否则为总数
                        if !model.connections.isEmpty {
                            Text("(\(search.isEmpty ? model.connections.count : filtered.count))")
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        if !model.connections.isEmpty {
                            Menu {
                                ForEach(ConnSortMode.allCases, id: \.self) { mode in
                                    Button {
                                        sortModeRaw = mode.rawValue
                                    } label: {
                                        Label(mode.label, systemImage: sortMode == mode ? "checkmark" : mode.icon)
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.textSecondary)
                            .help("排序方式")
                            Button {
                                model.checkAllReachability()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.textSecondary)
                            .help("刷新全部可达性")
                        }
                        Button {
                            model.editingConnection = Connection()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.accent)
                    }
                }

                // 分组（标题可点折叠/展开，对齐 android A-GroupFold）
                ForEach(groups, id: \.name) { grp in
                    Section {
                        if !collapsedGroups.contains(grp.name) {
                            ForEach(grp.conns) { conn in
                                ConnectionRow(connection: conn)
                            }
                        }
                    } header: {
                        Button {
                            if collapsedGroups.contains(grp.name) { collapsedGroups.remove(grp.name) }
                            else { collapsedGroups.insert(grp.name) }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: collapsedGroups.contains(grp.name) ? "chevron.right" : "chevron.down")
                                    .font(.system(size: 9))
                                Label("\(grp.name) (\(grp.conns.count))", systemImage: "folder")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .glassPanel(Theme.surface, opacity: 0.55)
        .navigationTitle("Termind")
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            TextField("搜索连接", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

private struct ConnectionRow: View {
    @EnvironmentObject var model: AppModel
    let connection: Connection
    @State private var showDeleteConfirm = false

    /// 可达性指示：探测中转圈、可达绿 wifi、不可达红 wifi.slash、未知不显示
    @ViewBuilder private var reachabilityIndicator: some View {
        switch model.reachability[connection.id] {
        case .checking:
            ProgressView().controlSize(.mini)
        case .reachable:
            Image(systemName: "wifi").font(.system(size: 11)).foregroundStyle(Theme.success)
        case .unreachable:
            Image(systemName: "wifi.slash").font(.system(size: 11)).foregroundStyle(Theme.danger)
        case nil:
            EmptyView()
        }
    }

    /// 相对时间短描述（共用 RelativeTime）
    static func relativeTime(_ date: Date) -> String { RelativeTime.string(date) }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor(model.status(for: connection)))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(connection.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                if !connection.noteText.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "note.text").font(.system(size: 9))
                        Text(connection.noteText).lineLimit(1)
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary.opacity(0.85))
                }
                if let used = connection.lastUsedAt {
                    Text("上次使用 · \(Self.relativeTime(used))")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            Spacer()
            reachabilityIndicator
        }
        .contentShape(Rectangle())
        .help(connection.noteText)
        .onTapGesture {
            model.openSession(for: connection)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("删除", systemImage: "trash")
            }
            Button {
                model.editingConnection = connection
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(Theme.surfaceLight)
        }
        .confirmationDialog("删除连接「\(connection.title)」？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) { model.deleteConnection(connection) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将移除此连接配置（不影响远程主机）。")
        }
        .contextMenu {
            let st = model.status(for: connection)
            if st == .connected || st == .connecting {
                Button {
                    model.activeSessionID = model.sessions.first { $0.connection?.id == connection.id }?.id ?? model.activeSessionID
                } label: {
                    Label("切到此会话", systemImage: "arrow.right.circle")
                }
                Button(role: .destructive) {
                    model.disconnectSession(for: connection)
                } label: {
                    Label("断开", systemImage: "stop.fill")
                }
            } else {
                Button {
                    model.openSession(for: connection)
                } label: {
                    Label("连接", systemImage: "play.fill")
                }
            }
            Button {
                model.editingConnection = connection
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button {
                model.cloneConnection(connection)
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
            Button {
                model.notebookConnection = connection
            } label: {
                Label("知识卡片", systemImage: "book.closed")
            }
            Button {
                model.checkReachability(connection)
            } label: {
                Label("测试可达性", systemImage: "wifi")
            }
            Button {
                model.qrConnection = connection
            } label: {
                Label("分享二维码", systemImage: "qrcode")
            }
            Button {
                model.copyConnectionConfig(connection)
            } label: {
                Label("复制配置", systemImage: "doc.on.clipboard")
            }
            Divider()
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}
