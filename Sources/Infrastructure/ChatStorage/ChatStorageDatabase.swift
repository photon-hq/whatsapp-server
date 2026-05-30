import Domain
import Foundation
import GRDB
import Logging

package actor ChatStorageDatabase {

    private let dbPool: DatabasePool
    private let logger: Logger

    package init(path: String) throws {
        var config = Configuration()
        config.readonly = true
        config.label = "ChatStorage.sqlite"
        config.busyMode = .timeout(5)

        self.dbPool = try DatabasePool(path: path, configuration: config)
        self.logger = Logger(label: "ChatStorageDatabase")

        logger.info("Opened ChatStorage.sqlite at \(path)")
    }

    func read<T: Sendable>(
        _ block: @Sendable (Database) throws -> T
    ) async throws -> T {
        do {
            return try await dbPool.read(block)
        } catch {
            throw DomainError(.internalError, "ChatStorage.sqlite read failed")
                .with("detail", String(describing: error))
        }
    }

}
