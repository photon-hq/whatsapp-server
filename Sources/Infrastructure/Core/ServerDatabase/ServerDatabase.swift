import Domain
import Foundation
import GRDB
import Logging

package actor ServerDatabase {

    private let dbPool: DatabasePool
    private let logger: Logger

    package init(path: String) throws {
        let directory = (path as NSString).deletingLastPathComponent

        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )

        var config = Configuration()
        config.label = "server.db"
        config.busyMode = .timeout(5)

        self.dbPool = try DatabasePool(path: path, configuration: config)
        self.logger = Logger(label: "ServerDatabase")

        var migrator = DatabaseMigrator()
        ServerMigrations.registerAll(&migrator)
        try migrator.migrate(dbPool)

        logger.info("Server database initialized at \(path)")
    }

    func read<T: Sendable>(
        _ block: @Sendable (Database) throws -> T
    ) async throws -> T {
        do {
            return try await dbPool.read(block)
        } catch {
            throw DomainError(.internalError, "server.db read failed")
                .with("detail", String(describing: error))
        }
    }

    func write<T: Sendable>(
        _ block: @Sendable (Database) throws -> T
    ) async throws -> T {
        do {
            return try await dbPool.write(block)
        } catch {
            throw DomainError(.internalError, "server.db write failed")
                .with("detail", String(describing: error))
        }
    }

}
