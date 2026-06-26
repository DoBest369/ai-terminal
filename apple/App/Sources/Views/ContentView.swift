import SwiftUI
import UniformTypeIdentifiers
import AITerminalCore

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var showAIPanel = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            mainArea
        }
        .sheet(isPresented: $model.showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $model.showSnippets) {
            SnippetsView()
        }
        .sheet(isPresented: $model.showFileBrowser) {
            if let session = model.activeSession, session.supportsSFTP {
                FileBrowserView(session: session)
            }
        }
        .sheet(isPresented: $model.showPortForward) {
            if let session = model.activeSession, session.supportsSFTP {
                PortForwardView(session: session)
            }
        }
        .sheet(isPresented: $model.showInspect) {
            InspectView()
        }
        .sheet(isPresented: $model.showBatch) {
            BatchView()
        }
        .sheet(item: $model.notebookConnection) { conn in
            NotebookView(connection: conn)
        }
        .sheet(item: $model.qrConnection) { conn in
            ConnectionQRView(connection: conn)
        }
        .sheet(item: $model.editingConnection) { conn in
            ConnectionEditView(connection: conn)
        }
        .tint(Theme.accent)
        .overlay(alignment: .top) {
            if let toast = model.toast {
                ToastView(text: toast)
                    .onAppear {
                        Task {
                            try? await Task.sleep(nanoseconds: 2_500_000_000)
                            model.toast = nil
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var mainArea: some View {
        if let session = model.activeSession {
            VStack(spacing: 0) {
                SessionTabsBar()
                StatusBarView(session: session)
                Divider().overlay(Theme.surfaceLight)
                if model.searchActive {
                    TerminalSearchBar(session: session, active: $model.searchActive)
                }
                if model.splitEnabled, let secondary = model.secondarySession {
                    SplitTerminals(primary: session, secondary: secondary)
                } else if showAIPanel {
                    HSplitTerminalAndAI(session: session)
                } else {
                    TerminalPane(session: session)
                        .id(session.id)
                }
                #if os(iOS)
                if !session.isLocal && !model.splitEnabled {
                    TerminalKeyBar(session: session)
                }
                #endif
            }
            .background(Theme.background)
            .toolbar { toolbarContent }
        } else {
            EmptyStateView()
                .toolbar { toolbarContent }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Button { model.zoomIn() } label: { Label("放大", systemImage: "plus.magnifyingglass") }
                Button { model.zoomOut() } label: { Label("缩小", systemImage: "minus.magnifyingglass") }
                Button { model.resetZoom() } label: { Label("重置字号", systemImage: "arrow.counterclockwise") }
                Text("当前字号 \(Int(model.terminalFontSize))")
            } label: {
                Label("字号", systemImage: "textformat.size")
            }
            if model.activeSession != nil {
                Button {
                    model.searchActive.toggle()
                } label: {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                Button {
                    model.activeSession?.clearScreen()
                } label: {
                    Label("清屏", systemImage: "clear")
                }
            }
            if let s = model.activeSession, !s.isLocal,
               s.status == .connected || s.status == .connecting {
                Button {
                    model.disconnectActiveSession()
                } label: {
                    Label("断开", systemImage: "bolt.slash")
                }
            } else if let s = model.activeSession, !s.isLocal,
                      s.status == .disconnected || s.status == .error {
                Button {
                    model.activeSession?.reconnect()
                } label: {
                    Label("重连", systemImage: "bolt.fill")
                }
            }
            if model.sessions.count >= 2 {
                Button {
                    model.toggleSplit()
                } label: {
                    Label("分屏", systemImage: model.splitEnabled ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                }
            }
            if model.activeSession?.supportsSFTP == true {
                Button {
                    model.showFileBrowser = true
                } label: {
                    Label("文件", systemImage: "folder")
                }
                Button {
                    model.showPortForward = true
                } label: {
                    Label("端口转发", systemImage: "arrow.left.arrow.right")
                }
            }
            if let session = model.activeSession, !session.isLocal {
                RecordButton(session: session)
            }
            Button {
                model.showSnippets = true
            } label: {
                Label("快捷命令", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Button {
                model.inspectionResults = []
                model.showInspect = true
            } label: {
                Label("批量巡检", systemImage: "stethoscope")
            }
            Button {
                model.batchResults = []
                model.showBatch = true
            } label: {
                Label("批量群发", systemImage: "square.stack.3d.up")
            }
            Button {
                withAnimation { showAIPanel.toggle() }
            } label: {
                Label("AI 助手", systemImage: showAIPanel ? "sparkles.rectangle.stack.fill" : "sparkles")
            }
            Button {
                model.showSettings = true
            } label: {
                Label("设置", systemImage: "gearshape")
            }
        }
    }
}

/// 终端输出录制按钮：开始/停止录制，停止时导出为 .txt。仅 SSH 会话。
private struct RecordButton: View {
    @ObservedObject var session: TerminalSessionVM
    @State private var doc: TextFileDocument?
    @State private var showExporter = false

    var body: some View {
        Button {
            if session.isRecording {
                session.stopRecording()
                doc = TextFileDocument(text: session.recordedText())
                showExporter = true
            } else {
                session.startRecording()
            }
        } label: {
            Label(session.isRecording ? "停止录制" : "录制",
                  systemImage: session.isRecording ? "stop.circle.fill" : "record.circle")
        }
        .tint(session.isRecording ? Theme.danger : nil)
        .help(session.isRecording ? "停止并导出录制" : "录制终端输出")
        .fileExporter(isPresented: $showExporter, document: doc, contentType: .plainText, defaultFilename: "session-recording") { _ in }
    }
}

/// 终端分屏：两个会话并排（宽屏）/ 上下（窄屏），各带小标题。
private struct SplitTerminals: View {
    @ObservedObject var primary: TerminalSessionVM
    @ObservedObject var secondary: TerminalSessionVM
    @AppStorage("split_ratio") private var ratio: Double = 0.5
    @State private var dragStartRatio: Double?

    private let handleThickness: CGFloat = 6
    private let minRatio = 0.2, maxRatio = 0.8

    var body: some View {
        GeometryReader { geo in
            let horizontal = geo.size.width > geo.size.height
            let total = (horizontal ? geo.size.width : geo.size.height) - handleThickness
            let firstSize = max(0, total * ratio)
            if horizontal {
                HStack(spacing: 0) {
                    pane(primary).frame(width: firstSize)
                    handle(horizontal: true, total: total)
                    pane(secondary)
                }
            } else {
                VStack(spacing: 0) {
                    pane(primary).frame(height: firstSize)
                    handle(horizontal: false, total: total)
                    pane(secondary)
                }
            }
        }
    }

    /// 可拖拽分隔条：拖动调整左右/上下比例（夹在 minRatio~maxRatio），macOS 悬停变光标。
    private func handle(horizontal: Bool, total: CGFloat) -> some View {
        Rectangle()
            .fill(Theme.surfaceLight)
            .frame(width: horizontal ? handleThickness : nil,
                   height: horizontal ? nil : handleThickness)
            .overlay(
                Capsule().fill(Theme.textSecondary.opacity(0.6))
                    .frame(width: horizontal ? 2 : 26, height: horizontal ? 26 : 2)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let base = dragStartRatio ?? ratio
                        if dragStartRatio == nil { dragStartRatio = ratio }
                        let delta = horizontal ? value.translation.width : value.translation.height
                        let newRatio = base + Double(delta) / Double(max(total, 1))
                        ratio = min(maxRatio, max(minRatio, newRatio))
                    }
                    .onEnded { _ in dragStartRatio = nil }
            )
            #if os(macOS)
            .onHover { inside in
                if inside { (horizontal ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).set() }
                else { NSCursor.arrow.set() }
            }
            #endif
    }

    private func pane(_ session: TerminalSessionVM) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(statusColor(session.status)).frame(width: 6, height: 6)
                Text(session.title).font(.system(size: 11)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Theme.surface)
            TerminalPane(session: session).id(session.id)
        }
    }
}

/// 终端 + AI 并排（宽屏）/ 上下（窄屏）
private struct HSplitTerminalAndAI: View {
    @ObservedObject var session: TerminalSessionVM

    var body: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            TerminalPane(session: session).id(session.id)
            Divider().overlay(Theme.surfaceLight)
            AIAgentView()
                .frame(width: 360)
        }
        #else
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                HStack(spacing: 0) {
                    TerminalPane(session: session).id(session.id)
                    Divider().overlay(Theme.surfaceLight)
                    AIAgentView().frame(width: 320)
                }
            } else {
                VStack(spacing: 0) {
                    TerminalPane(session: session).id(session.id)
                    Divider().overlay(Theme.surfaceLight)
                    AIAgentView().frame(height: geo.size.height * 0.45)
                }
            }
        }
        #endif
    }
}

/// 顶部会话标签栏
private struct SessionTabsBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(model.sessions) { session in
                    sessionTab(session)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(Theme.surface)
    }

    private func sessionTab(_ session: TerminalSessionVM) -> some View {
        let active = session.id == model.activeSessionID
        return HStack(spacing: 6) {
            Circle()
                .fill(statusColor(session.status))
                .frame(width: 7, height: 7)
            Text(session.title)
                .font(.caption)
                .lineLimit(1)
            Button {
                model.closeSession(session)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(active ? Theme.surfaceLight : Theme.surface)
        .foregroundStyle(active ? Theme.textPrimary : Theme.textSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(active ? Theme.accent.opacity(0.5) : .clear, lineWidth: 1)
        )
        .help(session.connection?.subtitle ?? (session.isLocal ? "本地终端" : session.title))
        .onTapGesture { model.activeSessionID = session.id }
    }
}

func statusColor(_ status: SessionStatus) -> Color {
    switch status {
    case .connected: return Theme.success
    case .connecting: return Theme.warning
    case .error: return Theme.danger
    case .disconnected: return Theme.textSecondary
    }
}

private struct EmptyStateView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 56))
                .foregroundStyle(Theme.accent)
            Text("Termind")
                .font(.title.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("从左侧选择一个连接，或新建 SSH 连接")
                .foregroundStyle(Theme.textSecondary)
            Button {
                model.editingConnection = Connection()
            } label: {
                Label("新建 SSH 连接", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

private struct ToastView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.surfaceLight)
            .foregroundStyle(Theme.textPrimary)
            .clipShape(Capsule())
            .shadow(radius: 8)
            .padding(.top, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
