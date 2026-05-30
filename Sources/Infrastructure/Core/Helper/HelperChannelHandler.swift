import Domain
import Foundation
import NIOCore

final class HelperChannelHandler: ChannelInboundHandler, @unchecked Sendable {

    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    let response: EventLoopFuture<Data>

    private let requestBody: Data
    private let maxFrameBytes: Int
    private let responsePromise: EventLoopPromise<Data>
    private var inbound = ByteBuffer()
    private var completed = false

    init(
        requestBody: Data,
        maxFrameBytes: Int,
        eventLoop: any EventLoop
    ) {
        self.requestBody = requestBody
        self.maxFrameBytes = maxFrameBytes
        self.responsePromise = eventLoop.makePromise(of: Data.self)
        self.response = responsePromise.futureResult
    }

    func channelActive(context: ChannelHandlerContext) {
        var frame = context.channel.allocator.buffer(capacity: 4 + requestBody.count)
        frame.writeInteger(UInt32(requestBody.count), endianness: .big)
        frame.writeBytes(requestBody)
        context.writeAndFlush(wrapOutboundOut(frame), promise: nil)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var chunk = unwrapInboundIn(data)
        inbound.writeBuffer(&chunk)

        guard let readableBytes = inbound.getInteger(
            at: inbound.readerIndex,
            endianness: .big,
            as: UInt32.self
        ) else {
            return
        }

        let frameLength = Int(readableBytes)
        guard frameLength > 0, frameLength <= maxFrameBytes else {
            fail(
                DomainError(.internalError, "Helper response frame length is invalid")
                    .with("frame_length", frameLength)
                    .with("max_frame_bytes", maxFrameBytes)
            )
            context.close(promise: nil)
            return
        }

        guard inbound.readableBytes >= 4 + frameLength else {
            return
        }

        inbound.moveReaderIndex(forwardBy: 4)
        let bytes = inbound.readBytes(length: frameLength) ?? []
        succeed(Data(bytes))
        context.close(promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        fail(error)
        context.close(promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        fail(DomainError(.serviceUnavailable, "whatsapp-helper closed the connection"))
    }

    private func succeed(_ data: Data) {
        guard !completed else {
            return
        }

        completed = true
        responsePromise.succeed(data)
    }

    private func fail(_ error: any Error) {
        guard !completed else {
            return
        }

        completed = true
        responsePromise.fail(error)
    }

}
