import SwiftUI

@main
struct AITerminalApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("新建本地终端") { model.openLocalSession() }
                    .keyboardShortcut("t", modifiers: .command)
            }
            CommandGroup(after: .textEditing) {
                Button("在终端中查找") {
                    if model.activeSession != nil { model.searchActive = true }
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("放大字号") { model.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("缩小字号") { model.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("重置字号") { model.resetZoom() }
                    .keyboardShortcut("0", modifiers: .command)
            }
        }
        #endif
    }
}
