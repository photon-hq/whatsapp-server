import CryptoKit
import Domain
import Foundation

package actor Ed25519JWTVerifier: AuthVerifying {

    private let publicKeyPath: String
    private let serviceName: String
    private let deviceUserId: String

    private var cachedPublicKey: Curve25519.Signing.PublicKey?

    package init(
        publicKeyPath: String,
        serviceName: String,
        deviceUserId: String
    ) {
        self.publicKeyPath = publicKeyPath
        self.serviceName = serviceName
        self.deviceUserId = deviceUserId
    }

    package func verify(token: String) async throws -> AuthContext {
        let (headerB64, payloadB64, signatureB64) = try parseJWT(token)
        let publicKey = try getPublicKey()

        try verifySignature(
            publicKey: publicKey,
            header: headerB64,
            payload: payloadB64,
            signature: signatureB64
        )

        let claims = try decodePayload(payloadB64)
        let authIdentity = try validateClaims(claims)
        let expiresAt = try validateExpiration(claims.exp)

        return AuthContext(
            subject: authIdentity.subject,
            projectId: authIdentity.projectId,
            deviceUserId: deviceUserId,
            tokenId: authIdentity.tokenId,
            expiresAt: expiresAt
        )
    }

    private func parseJWT(_ token: String) throws -> (header: String, payload: String, signature: String) {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)

        guard parts.count == 3 else {
            throw DomainError(.unauthenticated, "Malformed JWT: expected 3 parts")
        }

        return (String(parts[0]), String(parts[1]), String(parts[2]))
    }

    private func decodePayload(_ payloadB64: String) throws -> JWTClaims {
        guard let payloadData = Self.base64URLDecode(payloadB64) else {
            throw DomainError(.unauthenticated, "JWT payload base64url decode failed")
        }

        do {
            return try JSONDecoder().decode(JWTClaims.self, from: payloadData)
        } catch {
            throw DomainError(.unauthenticated, "JWT payload JSON decode failed", context: [:])
        }
    }

    private func validateClaims(_ claims: JWTClaims) throws -> AuthIdentity {
        guard claims.iss == "codes.photon.lightauth" else {
            throw DomainError(.unauthenticated, "JWT issuer mismatch")
        }

        guard claims.aud == serviceName else {
            throw DomainError(.unauthenticated, "JWT audience mismatch")
        }

        let subject = try Self.requireIdentifierClaim(claims.sub, field: "sub")
        let tokenId = try Self.requireIdentifierClaim(claims.jti, field: "jti")

        let isSharedServiceToken = subject == AuthConstants.sharedServiceSubject

        return AuthIdentity(
            subject: subject,
            projectId: isSharedServiceToken ? nil : subject,
            tokenId: tokenId
        )
    }

    static func requireIdentifierClaim(_ value: String?, field: String) throws -> String {
        guard let value, !value.isEmpty else {
            throw DomainError(.unauthenticated, "JWT missing \(field) claim")
        }

        guard value == value.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw DomainError(.unauthenticated, "JWT invalid \(field) claim")
        }

        return value
    }

    private func validateExpiration(_ exp: Int?) throws -> Date {
        guard let exp else {
            return Date.distantFuture
        }

        let expDate = Date(timeIntervalSince1970: TimeInterval(exp))

        guard expDate > Date() else {
            throw DomainError(.tokenExpired, "JWT has expired")
        }

        return expDate
    }

    private func verifySignature(
        publicKey: Curve25519.Signing.PublicKey,
        header: String,
        payload: String,
        signature: String
    ) throws {
        guard let signatureData = Self.base64URLDecode(signature) else {
            throw DomainError(.unauthenticated, "JWT signature base64url decode failed")
        }

        let signingInput = Data("\(header).\(payload)".utf8)

        guard publicKey.isValidSignature(signatureData, for: signingInput) else {
            throw DomainError(.unauthenticated, "JWT signature verification failed")
        }
    }

    private func getPublicKey() throws -> Curve25519.Signing.PublicKey {
        if let cached = cachedPublicKey {
            return cached
        }

        let key = try loadPublicKey()
        cachedPublicKey = key
        return key
    }

    private func loadPublicKey() throws -> Curve25519.Signing.PublicKey {
        do {
            let pem = try String(contentsOfFile: publicKeyPath, encoding: .utf8)
            return try Self.parseEd25519PublicKey(pem: pem)
        } catch let error as DomainError {
            throw error
        } catch {
            throw DomainError(.internalError, "Failed to load public key")
        }
    }
}

private struct JWTClaims: Decodable {
    let iss: String
    let aud: String
    let sub: String?
    let jti: String?
    let exp: Int?
}

private struct AuthIdentity {
    let subject: String
    let projectId: String?
    let tokenId: String
}

extension Ed25519JWTVerifier {

    private static let ed25519SPKIPrefix: [UInt8] = [
        0x30, 0x2A, 0x30, 0x05, 0x06, 0x03, 0x2B, 0x65,
        0x70, 0x03, 0x21, 0x00,
    ]

    private static func parseEd25519PublicKey(pem: String) throws -> Curve25519.Signing.PublicKey {
        let stripped = pem
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let derData = Data(base64Encoded: stripped) else {
            throw DomainError(.unauthenticated, "Invalid public key base64")
        }

        guard derData.count == 44 else {
            throw DomainError(.unauthenticated, "Unexpected public key length")
        }

        guard derData.prefix(ed25519SPKIPrefix.count).elementsEqual(ed25519SPKIPrefix) else {
            throw DomainError(.unauthenticated, "Unexpected public key algorithm")
        }

        let rawKey = derData.suffix(32)
        return try Curve25519.Signing.PublicKey(rawRepresentation: rawKey)
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        return Data(base64Encoded: base64)
    }
}
