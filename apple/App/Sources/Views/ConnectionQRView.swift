import SwiftUI
import AITerminalCore

/// 连接二维码分享：把单条连接的非敏感配置（不含密码）编码为 QR，扫码可在另一端导入。
struct ConnectionQRView: View {
    @Environment(\.dismiss) private var dismiss
    let connection: Connection

    /// 复用跨端交换格式（默认不含密码/口令）
    private var payload: String {
        let data = ConnectionPortability.export([connection], includeSecrets: false)
        return String(decoding: data, as: UTF8.self)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(connection.title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                if let qr = QRCode.image(from: payload) {
                    qr
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260, maxHeight: 260)
                        .padding(10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Text("无法生成二维码").foregroundStyle(Theme.danger)
                }
                Text("用另一台设备的相机/导入功能扫码，即可导入此连接（不含密码）。")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            }
            .padding(.top, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle("分享二维码")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 420)
    }
}
