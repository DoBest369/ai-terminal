import Foundation
import NIOCore

/// 一条本地端口转发：本机 localPort → （经 SSH）远端 remoteHost:remotePort
public struct PortForward: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var localPort: Int
    public var remoteHost: String
    public var remotePort: Int

    public init(id: UUID = UUID(), localPort: Int, remoteHost: String, remotePort: Int) {
        self.id = id
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
    }

    public var summary: String {
        "127.0.0.1:\(localPort) → \(remoteHost):\(remotePort)"
    }
}

/// 双向桥接两个 NIO Channel（本地 TCP ↔ SSH direct-tcpip）。
/// 一端收到的 ByteBuffer 写到另一端；任一端关闭则关闭对端。
///
/// 线程安全：两端 channel 可能在不同 eventLoop 上。对端转发/关闭都经本端
/// `channel`（Channel 是 Sendable，writeAndFlush/close 会派发到自身 eventLoop），
/// 并显式跳到本端 eventLoop，绝不跨 loop 触碰 ChannelHandlerContext。
final class GlueHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer

    private var partner: GlueHandler?
    /// 本端 channel；handlerAdded 时记录。用它跨 eventLoop 安全写/关。
    private var channel: Channel?

    static func matchedPair() -> (GlueHandler, GlueHandler) {
        let a = GlueHandler()
        let b = GlueHandler()
        a.partner = b
        b.partner = a
        return (a, b)
    }

    func handlerAdded(context: ChannelHandlerContext) {
        self.channel = context.channel
    }

    func handlerRemoved(context: ChannelHandlerContext) {
        self.channel = nil
        self.partner = nil
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        partner?.writeFromPartner(buffer)
    }

    /// 由对端 eventLoop 调用：跳到本端 eventLoop 再写。
    private func writeFromPartner(_ buffer: ByteBuffer) {
        guard let channel = channel else { return }
        if channel.eventLoop.inEventLoop {
            channel.writeAndFlush(buffer, promise: nil)
        } else {
            channel.eventLoop.execute {
                channel.writeAndFlush(buffer, promise: nil)
            }
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        partner?.closeFromPartner()
        context.fireChannelInactive()
    }

    /// 由对端 eventLoop 调用：跳到本端 eventLoop 再关。
    private func closeFromPartner() {
        guard let channel = channel else { return }
        if channel.eventLoop.inEventLoop {
            channel.close(promise: nil)
        } else {
            channel.eventLoop.execute {
                channel.close(promise: nil)
            }
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        // errorCaught 在本端 eventLoop 上，用 context 关闭即可
        context.close(promise: nil)
    }
}
