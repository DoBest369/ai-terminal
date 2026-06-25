import SwiftUI
import SwiftTerm
import AITerminalCore

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 根据会话类型选择本地或 SSH 终端视图。
struct TerminalContainer: View {
    @ObservedObject var session: TerminalSessionVM

    var fontSize: CGFloat = 13
    var themeID: String = "midnight"

    var body: some View {
        Group {
            if session.isLocal {
                #if os(macOS)
                LocalTerminalRepresentable(session: session, fontSize: fontSize, themeID: themeID)
                #else
                // iOS 不支持本地 shell
                UnsupportedLocalView()
                #endif
            } else {
                SSHTerminalRepresentable(session: session, fontSize: fontSize, themeID: themeID)
            }
        }
        .background(Theme.background)
    }
}

#if !os(macOS)
private struct UnsupportedLocalView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textSecondary)
            Text("iOS 不支持本地终端")
                .foregroundStyle(Theme.textPrimary)
            Text("请通过 SSH 连接远程服务器使用终端")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
#endif

// MARK: - SSH 终端

struct SSHTerminalRepresentable: PlatformViewRepresentable {
    @ObservedObject var session: TerminalSessionVM
    var fontSize: CGFloat = 13
    var themeID: String = "midnight"

    func makeCoordinator() -> SSHTerminalCoordinator {
        SSHTerminalCoordinator(session: session)
    }

    private func refresh(_ view: TerminalView) {
        TerminalTheme.applyColors(to: view)
        TerminalTheme.updateFontSize(view, size: fontSize)
    }

    #if os(macOS)
    func makeNSView(context: Context) -> TerminalView { context.coordinator.makeTerminal(fontSize: fontSize) }
    func updateNSView(_ nsView: TerminalView, context: Context) { refresh(nsView) }
    #else
    func makeUIView(context: Context) -> TerminalView { context.coordinator.makeTerminal(fontSize: fontSize) }
    func updateUIView(_ uiView: TerminalView, context: Context) { refresh(uiView) }
    #endif
}

final class SSHTerminalCoordinator: NSObject, TerminalViewDelegate {
    let session: TerminalSessionVM
    weak var terminal: TerminalView?

    init(session: TerminalSessionVM) {
        self.session = session
    }

    @MainActor
    func makeTerminal(fontSize: CGFloat = 13) -> TerminalView {
        let tv = TerminalView(frame: CGRect(x: 0, y: 0, width: 600, height: 400))
        tv.terminalDelegate = self
        TerminalTheme.apply(to: tv, fontSize: fontSize)
        self.terminal = tv
        session.terminalView = tv
        #if os(macOS)
        tv.menu = makeTerminalContextMenu(tv: tv, clearTarget: self)
        #endif

        // 显示输出回调（@MainActor）
        session.feed = { [weak tv] data in
            tv?.feed(byteArray: ArraySlice(data))
        }
        // AI 注入命令：作为输入发送到远端
        session.injectCommand = { [weak self] cmd in
            self?.session.sendInput(ArraySlice(Array(cmd.utf8)))
        }

        let term = tv.getTerminal()
        session.startSSH(cols: term.cols, rows: term.rows)
        return tv
    }

    // MARK: TerminalViewDelegate（SwiftTerm 在主线程回调）
    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        MainActor.assumeIsolated { session.sendInput(data) }
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        MainActor.assumeIsolated { session.resize(cols: newCols, rows: newRows) }
    }

    func setTerminalTitle(source: TerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func scrolled(source: TerminalView, position: Double) {}
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    func clipboardCopy(source: TerminalView, content: Data) {
        #if os(macOS)
        if let text = String(data: content, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        #else
        if let text = String(data: content, encoding: .utf8) {
            UIPasteboard.general.string = text
        }
        #endif
    }
    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        #if os(macOS)
        if let url = URL(string: link) { NSWorkspace.shared.open(url) }
        #else
        if let url = URL(string: link) { UIApplication.shared.open(url) }
        #endif
    }

    #if os(macOS)
    /// 右键菜单「清屏」：向远端 shell 发 Ctrl-L
    @objc func terminalClearScreen() {
        MainActor.assumeIsolated { terminal?.send(txt: "\u{0c}") }
    }
    #endif
}

// MARK: - 本地终端（仅 macOS）

#if os(macOS)
struct LocalTerminalRepresentable: NSViewRepresentable {
    @ObservedObject var session: TerminalSessionVM
    var fontSize: CGFloat = 13
    var themeID: String = "midnight"

    func makeCoordinator() -> LocalTerminalCoordinator {
        LocalTerminalCoordinator(session: session)
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        context.coordinator.makeTerminal(fontSize: fontSize)
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        TerminalTheme.applyColors(to: nsView)
        TerminalTheme.updateFontSize(nsView, size: fontSize)
    }
}

final class LocalTerminalCoordinator: NSObject, LocalProcessTerminalViewDelegate {
    let session: TerminalSessionVM
    weak var terminal: LocalProcessTerminalView?

    init(session: TerminalSessionVM) {
        self.session = session
    }

    @MainActor
    func makeTerminal(fontSize: CGFloat = 13) -> LocalProcessTerminalView {
        let tv = LocalProcessTerminalView(frame: CGRect(x: 0, y: 0, width: 600, height: 400))
        tv.processDelegate = self
        // URL 点击：LocalProcessTerminalView 自任 terminalDelegate，requestOpenLink 走 SwiftTerm
        // 协议扩展默认实现（NSWorkspace.shared.open），故本地终端点链接已可打开，无需额外接线。
        TerminalTheme.apply(to: tv, fontSize: fontSize)
        self.terminal = tv
        session.terminalView = tv
        tv.menu = makeTerminalContextMenu(tv: tv, clearTarget: self)

        // AI 注入：写入子进程 stdin
        session.injectCommand = { [weak tv] cmd in
            tv?.send(data: ArraySlice(Array(cmd.utf8)))
        }
        session.feed = { [weak tv] data in
            tv?.feed(byteArray: ArraySlice(data))
        }

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        env.append("LANG=en_US.UTF-8")
        tv.startProcess(executable: shell, args: [], environment: env)
        return tv
    }

    // MARK: LocalProcessTerminalViewDelegate
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor in
            self.session.status = .disconnected
            self.session.statusMessage = "进程已退出 (\(exitCode ?? 0))"
        }
    }

    /// 右键菜单「清屏」：向 shell 发 Ctrl-L
    @objc func terminalClearScreen() {
        MainActor.assumeIsolated { terminal?.send(txt: "\u{0c}") }
    }
}

/// 终端右键菜单：复制 / 粘贴 / 全选 走 SwiftTerm 的 copy:/paste:/selectAll:（响应链，target=终端视图）；
/// 清屏 target 给 coordinator。
@MainActor
func makeTerminalContextMenu(tv: TerminalView, clearTarget: AnyObject) -> NSMenu {
    let menu = NSMenu()
    func add(_ title: String, _ selector: Selector, _ target: AnyObject, _ key: String) {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = target
        menu.addItem(item)
    }
    add("复制", Selector(("copy:")), tv, "c")
    add("粘贴", Selector(("paste:")), tv, "v")
    add("全选", Selector(("selectAll:")), tv, "a")
    menu.addItem(.separator())
    add("清屏", Selector(("terminalClearScreen")), clearTarget, "k")
    return menu
}
#endif
