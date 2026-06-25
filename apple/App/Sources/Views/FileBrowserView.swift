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
                    Button {
                        showImporter = true
                    } label: {
                        Label("上传", systemImage: "square.and.arrow.up")
                    }
                }
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

            Text(path)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.head)
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
                ForEach(entries) { entry in
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
                Text(entry.name)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
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
    }

    // MARK: - 操作

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
