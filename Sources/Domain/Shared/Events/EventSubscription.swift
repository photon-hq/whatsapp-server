package struct EventSubscription<Element: Sendable>: AsyncSequence, Sendable {

    package struct Iterator: AsyncIteratorProtocol {

        private let nextHandler: @Sendable () async throws -> Element?

        fileprivate init(
            nextHandler: @escaping @Sendable () async throws -> Element?
        ) {
            self.nextHandler = nextHandler
        }

        package mutating func next() async throws -> Element? {
            try await nextHandler()
        }
    }

    private let makeIteratorHandler: @Sendable () -> Iterator

    package init<Source: AsyncSequence & Sendable>(
        _ source: Source
    ) where Source.Element == Element {
        self.makeIteratorHandler = {
            let iteratorBox = SourceIteratorBox(source: source)

            return Iterator {
                try await iteratorBox.next()
            }
        }
    }

    fileprivate init(
        makeIteratorHandler: @escaping @Sendable () -> Iterator
    ) {
        self.makeIteratorHandler = makeIteratorHandler
    }

    package func makeAsyncIterator() -> Iterator {
        makeIteratorHandler()
    }

    package func compactMap<Mapped: Sendable>(
        _ transform: @escaping @Sendable (Element) async throws -> Mapped?
    ) -> EventSubscription<Mapped> {
        EventSubscription<Mapped>(
            makeIteratorHandler: {
                let iteratorBox = CompactMapIteratorBox(
                    upstream: makeAsyncIterator(),
                    transform: transform
                )

                return EventSubscription<Mapped>.Iterator {
                    try await iteratorBox.next()
                }
            }
        )
    }

}


private extension EventSubscription {

    final class SourceIteratorBox<Source: AsyncSequence>: @unchecked Sendable
    where Source.Element == Element {

        private var iterator: Source.AsyncIterator

        init(source: Source) {
            iterator = source.makeAsyncIterator()
        }

        func next() async throws -> Element? {
            try await iterator.next()
        }

    }


    final class CompactMapIteratorBox<Mapped: Sendable>: @unchecked Sendable {

        private var upstream: Iterator
        private let transform: @Sendable (Element) async throws -> Mapped?

        init(
            upstream: Iterator,
            transform: @escaping @Sendable (Element) async throws -> Mapped?
        ) {
            self.upstream = upstream
            self.transform = transform
        }

        func next() async throws -> Mapped? {
            while let element = try await upstream.next() {
                if let mapped = try await transform(element) {
                    return mapped
                }
            }

            return nil
        }

    }

}
