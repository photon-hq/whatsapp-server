import GRDB

enum ServerMigrations {

    static func registerAll(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_create_event_log") { db in
            try db.create(table: "event_log") { t in
                t.autoIncrementedPrimaryKey("sequence")
                t.column("recorded_at", .datetime).notNull()
                t.column("payload", .blob).notNull()
            }
        }

        migrator.registerMigration("v2_create_persistent_cursors") { db in
            try db.create(table: "persistent_cursors") { t in
                t.primaryKey("name", .text)
                t.column("value", .text).notNull()
                t.column("updated_at", .datetime).notNull()
            }
        }
    }

}
