import SwiftUI
import UniformTypeIdentifiers
import AITerminalCore

/// 一个可导出的二进制文档，用于把下载内容交给系统保存面板
struct DataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// SFTP 文件浏览器：列目录 / 进入目录 / 下载 / 上传（复用当前 SSH 连接）。
struct FileBrowserView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: TerminalSessionVM

    @State private var path = "/"
    @State private var entries: [SFTPEntry] = []
    @State private var loading = false
    @State private var error: String?
    @State private var busy: String?

    @State private var exportDoc: DataDocument?
    @State private var exportName = "file"
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var dropTargeted = false
    // SFTP 增删改（对齐 android）
    @State private var showMkdir = false
    @State private var mkdirName = ""
    @State private var renameTarget: SFTPEntry?
    @State private var renameText = ""
    @State private var deleteTarget: SFTPEntry?
    @State private var showGoto = false       // 路径直接跳转
    @State private var gotoText = ""
    @State private var sortMode = 0           // 0=名称 1=大小 2=时间

    /// 文件夹优先，组内按选定方式排序
    private var sortedEntries: [SFTPEntry] {
        let cmp: (SFTPEntry, SFTPEntry) -> Bool
        switch sortMode {
        case 1: cmp = { $0.size > $1.size }
        case 2: cmp = { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
        default: cmp = { $0.name.lowercased() < $1.name.lowercased() }
        }
        return entries.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return cmp(a, b)
        }
    }

    /// 修改时间标签：今年显 MM-dd HH:mm，往年显 yyyy-MM-dd
    static func timeLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) ? "MM-dd HH:mm" : "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pathBar
                Divider().overlay(Theme.surfaceLight)
                content
            }
            .background(Theme.background)
            .overlay {
                if dropTargeted {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 3, dash: [8]))
                        Label("松开上传到当前目录", systemImage: "arrow.down.doc")
                            .font(.headline)
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Theme.surface)
                            .clipShape(Capsule())
                    }
                    .padding(6)
                    .allowsHitTesting(false)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
                handleDrop(providers)
            }
            .navigationTitle("SFTP 文件")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("排序", selection: $sortMode) {
                            Text("名称").tag(0); Text("大小").tag(1); Text("时间").tag(2)
                        }
                    } label: {
                        Label("排序", systemImage: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        mkdirName = ""; showMkdir = true
                    } label: {
                        Label("新建文件夹", systemImage: "folder.badge.plus")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("上传", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .alert("跳转到路径", isPresented: $showGoto) {
                TextField("如 /var/log", text: $gotoText)
                Button("取消", role: .cancel) {}
                Button("跳转") { let t = gotoText.trimmingCharacters(in: .whitespaces); if !t.isEmpty { Task { await load(t) } } }
            }
            .alert("新建文件夹", isPresented: $showMkdir) {
                TextField("文件夹名", text: $mkdirName)
                Button("取消", role: .cancel) {}
                Button("创建") { Task { await makeDirectory(mkdirName) } }
            }
            .alert("重命名", isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })) {
                TextField("新名称", text: $renameText)
                Button("取消", role: .cancel) { renameTarget = nil }
                Button("确定") { if let t = renameTarget { Task { await rename(t, to: renameText) } } }
            }
            .alert("删除 \(deleteTarget?.name ?? "")？", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })) {
                Button("取消", role: .cancel) { deleteTarget = nil }
                Button("删除", role: .destructive) { if let t = deleteTarget { Task { await remove(t) } } }
            } message: {
                Text(deleteTarget?.isDirectory == true ? "仅空文件夹可删除，此操作不可撤销。" : "此操作不可撤销。")
            }
            .task { await loadInitial() }
            .fileExporter(isPresented: $showExporter, document: exportDoc, contentType: .data, defaultFilename: exportName) { _ in }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                handleUpload(result)
            }
        }
        .frame(minWidth: 460, minHeight: 540)
    }

    private var pathBar: some View {
        HStack(spacing: 8) {
            Button {
                Task { await navigateUp() }
            } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.plain)
            .disabled(path == "/" || loading)

            Button {
                gotoText = path; showGoto = true
            } label: {
                HStack(spacing: 4) {
                    Text(path)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Image(systemName: "pencil").font(.system(size: 10)).foregroundStyle(Theme.accent)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            if loading || busy != nil {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.surface)
    }

    @ViewBuilder
    private var content: some View {
        if let error {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.warning)
                Text(error).font(.footnote).foregroundStyle(Theme.textSecondary)
                Button("重试") { Task { await load(path) } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if let busy {
                    Text(busy).font(.footnote).foregroundStyle(Theme.accent)
                }
                ForEach(sortedEntries) { entry in
                    row(entry)
                }
                if entries.isEmpty && !loading {
                    Text("空目录").font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
        }
    }

    private func row(_ entry: SFTPEntry) -> some View {
        Button {
            if entry.isDirectory {
                Task { await load(entry.path) }
            } else {
                Task { await download(entry) }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                    .foregroundStyle(entry.isDirectory ? Theme.accent : Theme.textSecondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.name)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if let t = entry.modifiedAt {
                        Text(Self.timeLabel(t)).font(.system(size: 10)).foregroundStyle(Theme.textSecondary.opacity(0.7))
                    }
                }
                Spacer()
                if entry.isDirectory {
                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                } else {
                    Text(formatBytes(entry.size)).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                    Image(systemName: "arrow.down.circle").foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { renameText = entry.name; renameTarget = entry } label: { Label("重命名", systemImage: "pencil") }
            Button(role: .destructive) { deleteTarget = entry } label: { Label("删除", systemImage: "trash") }
        }
    }

    // MARK: - 操作

    private func makeDirectory(_ name: String) async {
        let n = name.trimmingCharacters(in: .whitespaces); guard !n.isEmpty else { return }
        let target = (path == "/" ? "/" : path + "/") + n
        busy = "新建中…"; defer { busy = nil }
        do { try await session.sftpMakeDirectory(target); await load(path) }
        catch let e { self.error = (e as? SSHFriendlyError)?.message ?? "\(e)" }
    }

    private func remove(_ entry: SFTPEntry) async {
        busy = "删除中…"; defer { busy = nil }
        do { try await session.sftpRemove(entry.path, isDirectory: entry.isDirectory); deleteTarget = nil; await load(path) }
        catch let e { self.error = (e as? SSHFriendlyError)?.message ?? "\(e)" }
    }

    private func rename(_ entry: SFTPEntry, to newName: String) async {
        let n = newName.trimmingCharacters(in: .whitespaces); guard !n.isEmpty, n != entry.name else { renameTarget = nil; return }
        let dir = (entry.path as NSString).deletingLastPathComponent
        let target = (dir.isEmpty ? "" : dir) + "/" + n
        busy = "重命名中…"; defer { busy = nil }
        do { try await session.sftpRename(entry.path, to: target); renameTarget = nil; await load(path) }
        catch let e { self.error = (e as? SSHFriendlyError)?.message ?? "\(e)" }
    }

    private func loadInitial() async {
        let home = await session.sftpHome()
        await load(home)
    }

    private func load(_ p: String) async {
        loading = true
        error = nil
        do {
            let list = try await session.sftpList(p)
            entries = list
            path = p
        } catch {
            self.error = (error as? SSHFriendlyError)?.message ?? error.localizedDescription
        }
        loading = false
    }

    private func navigateUp() async {
        let parent = (path as NSString).deletingLastPathComponent
        await load(parent.isEmpty ? "/" : parent)
    }

    private func download(_ entry: SFTPEntry) async {
        busy = "下载 \(entry.name)…"
        defer { busy = nil }
        do {
            let data = try await session.sftpDownload(entry.path)
            exportDoc = DataDocument(data: data)
            exportName = entry.name
            showExporter = true
        } catch {
            self.error = (error as? SSHFriendlyError)?.message ?? error.localizedDescription
        }
    }

    private func handleUpload(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        Task { await uploadFile(url) }
    }

    /// 上传单个本地文件到当前远端目录
    private func uploadFile(_ url: URL) async {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let dest = path.hasSuffix("/") ? path + url.lastPathComponent : path + "/" + url.lastPathComponent
        busy = "上传 \(url.lastPathComponent)…"
        defer { busy = nil }
        do {
            let data = try Data(contentsOf: url)
            try await session.sftpUpload(data, to: dest)
            await load(path)
        } catch {
            self.error = (error as? SSHFriendlyError)?.message ?? error.localizedDescription
        }
    }

    /// 处理拖入的文件：逐个解析 URL 并依次上传
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        Task { @MainActor in
            for provider in providers {
                if let url = await loadDroppedURL(provider) {
                    await uploadFile(url)
                }
            }
        }
        return true
    }

    private func loadDroppedURL(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { cont in
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                if let data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    cont.resume(returning: url)
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }
}
