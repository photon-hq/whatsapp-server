import NIOCore

enum StreamDisconnectNormalizer {

    static func normalize(_ error: Error) -> Error {
        if error is CancellationError {
            return CancellationError()
        }

        if let channelError = error as? ChannelError {
            switch channelError {
            case .ioOnClosedChannel, .alreadyClosed, .outputClosed:
                return CancellationError()

            default:
                break
            }
        }

        return error
    }

}
