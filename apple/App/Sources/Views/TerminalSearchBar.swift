import SwiftUI

/// 终端搜索栏：在回滚缓冲里查找关键字（SwiftTerm 内置搜索），支持上一个/下一个 + 匹配计数。
struct TerminalSearchBar: View {
    @ObservedObject var session: TerminalSessionVM
    @Binding var active: Bool

    @State private var term = ""
    @State private var found: Bool?
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)

            TextField("在终端中查找…", text: $term)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .focused($focused)
                .onChange(of: term) { _, _ in incremental() }
                .onSubmit { next() }
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif

            if !term.isEmpty, let found {
                Text(found ? "已定位" : "无匹配")
                    .font(.system(size: 11))
                    .foregroundStyle(found ? Theme.success : Theme.textSecondary)
            }

            Button { previous() } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.plain)
                .disabled(term.isEmpty)
            Button { next() } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.plain)
                .disabled(term.isEmpty)
            Button {
                active = false
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.surfaceLight).frame(height: 0.5) }
        .onAppear { focused = true }
    }

    /// 输入即查（增量搜索，跳到下一个匹配）
    private func incremental() {
        found = term.isEmpty ? nil : session.searchNext(term)
    }

    private func next() {
        guard !term.isEmpty else { return }
        found = session.searchNext(term)
    }

    private func previous() {
        guard !term.isEmpty else { return }
        found = session.searchPrevious(term)
    }
}
