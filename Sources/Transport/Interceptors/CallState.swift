import os

final class CallState: @unchecked Sendable {

    let service: String
    let operation: String

    private struct Mutable {
        var projectId: String?
        var deviceUserId: String?
        var extra: [String: String] = [:]
    }

    private let mutable: OSAllocatedUnfairLock<Mutable>

    init(service: String, operation: String) {
        self.service = service
        self.operation = operation
        self.mutable = OSAllocatedUnfairLock(initialState: Mutable())
    }

    func setAuth(
        projectId: String?,
        deviceUserId: String
    ) {
        mutable.withLock {
            $0.projectId = projectId
            $0.deviceUserId = deviceUserId
        }
    }

    func record(_ fields: [String: String]) {
        mutable.withLock {
            $0.extra.merge(fields) { _, new in new }
        }
    }

    func allFields() -> [String: String] {
        let s = mutable.withLock { $0 }

        var fields = s.extra
        fields["app_service"] = service
        fields["app_operation"] = operation

        if let v = s.deviceUserId {
            fields["device_user_id"] = v
        }
        if let v = s.projectId {
            fields["project_id"] = v
        }

        return fields
    }
}

enum CurrentCallState {
    @TaskLocal static var current: CallState?
}
