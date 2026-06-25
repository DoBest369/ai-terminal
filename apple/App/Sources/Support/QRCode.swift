import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// 把字符串生成二维码图（跨平台）。内容应为非敏感数据（连接配置 JSON，不含密码）。
enum QRCode {
    static func image(from string: String, scale: CGFloat = 10) -> Image? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        #if os(macOS)
        let ns = NSImage(cgImage: cg, size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
        return Image(nsImage: ns)
        #else
        return Image(uiImage: UIImage(cgImage: cg))
        #endif
    }
}
