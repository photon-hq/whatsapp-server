import Foundation

package struct AuthContext: Sendable, Hashable {

    package let subject: String
    package let projectId: String?
    package let deviceUserId: String
    package let tokenId: String
    package let expiresAt: Date

    package init(
        subject: String,
        projectId: String?,
        deviceUserId: String,
        tokenId: String,
        expiresAt: Date
    ) {
        self.subject = subject
        self.projectId = projectId
        self.deviceUserId = deviceUserId
        self.tokenId = tokenId
        self.expiresAt = expiresAt
    }

    package init(
        projectId: String,
        deviceUserId: String,
        tokenId: String,
        expiresAt: Date
    ) {
        self.init(
            subject: projectId,
            projectId: projectId,
            deviceUserId: deviceUserId,
            tokenId: tokenId,
            expiresAt: expiresAt
        )
    }
}
