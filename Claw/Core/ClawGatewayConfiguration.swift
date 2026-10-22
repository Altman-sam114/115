import Foundation

enum ClawGatewayConfigurationError: Error, Equatable, Sendable {
    case invalidEndpoint
    case invalidToken
    case invalidRecord

    var message: String {
        switch self {
        case .invalidEndpoint:
            return "地址需为 WSS 或本机 loopback WS，不能含账号、查询参数或 fragment。"
        case .invalidToken:
            return "Token 需为 1–4096 字节的可见 ASCII，不能含空格或控制字符。"
        case .invalidRecord:
            return "已保存连接无法读取；未应用记录内容，也不会自动连接。"
        }
    }
}

// This pair is secret-bearing and deliberately not part of any Codable task or checkpoint.
struct ClawGatewayConfiguration: Equatable, Sendable {
    let endpoint: String
    let token: String

    init(endpoint: String, token: String) throws {
        guard let endpoint = Self.validatedEndpoint(endpoint) else {
            throw ClawGatewayConfigurationError.invalidEndpoint
        }
        guard Self.isValidToken(token) else { throw ClawGatewayConfigurationError.invalidToken }
        self.endpoint = endpoint
        self.token = token
    }

    static func validatedEndpoint(_ raw: String) -> String? {
        guard !raw.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else { return nil }
        let endpoint = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...2_048).contains(endpoint.utf8.count),
              endpoint.unicodeScalars.allSatisfy({ (33...126).contains($0.value) && $0.value != 92 }),
              let components = URLComponents(string: endpoint),
              let scheme = components.scheme, scheme == "ws" || scheme == "wss",
              let host = components.host, !host.isEmpty,
              components.percentEncodedHost == host,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.port.map({ (1...65_535).contains($0) }) ?? true,
              components.url?.absoluteString == endpoint else { return nil }
        guard scheme == "wss" || ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host.lowercased()) else {
            return nil
        }
        return endpoint
    }

    static func isValidToken(_ token: String) -> Bool {
        (1...4_096).contains(token.utf8.count) && token.unicodeScalars.allSatisfy { (33...126).contains($0.value) }
    }

    static func isValidAuthorizationHeader(_ header: String?) -> Bool {
        guard let header, header.hasPrefix("Bearer ") else { return false }
        return isValidToken(String(header.dropFirst(7)))
    }

    func encodedSecretRecord() throws -> Data {
        try JSONSerialization.data(withJSONObject: ["version": "claw.gateway.connection.v1", "endpoint": endpoint, "token": token],
                                   options: [.sortedKeys, .withoutEscapingSlashes])
    }

    static func decodeSecretRecord(_ data: Data) throws -> Self {
        do {
            let object = try ClawPlanningJSON.object(data, maxBytes: 16_384)
            guard Set(object.keys) == ["version", "endpoint", "token"],
                  object["version"] as? String == "claw.gateway.connection.v1",
                  let endpoint = object["endpoint"] as? String, let token = object["token"] as? String else {
                throw ClawGatewayConfigurationError.invalidRecord
            }
            return try Self(endpoint: endpoint, token: token)
        } catch {
            throw ClawGatewayConfigurationError.invalidRecord
        }
    }
}

enum ClawGatewayConfigurationLoadResult: Equatable, Sendable {
    case none
    case loaded(ClawGatewayConfiguration)
    case invalid
    case unavailable
}

enum ClawGatewayConfigurationWriteResult: Equatable, Sendable {
    case saved
    case failed
    case unavailable
}

enum ClawGatewayConfigurationClearResult: Equatable, Sendable {
    case cleared
    case failed
    case unavailable
}

protocol ClawGatewayConfigurationStore: Sendable {
    func load() -> ClawGatewayConfigurationLoadResult
    func save(_ configuration: ClawGatewayConfiguration) -> ClawGatewayConfigurationWriteResult
    func clear() -> ClawGatewayConfigurationClearResult
}

struct ClawNoopGatewayConfigurationStore: ClawGatewayConfigurationStore {
    func load() -> ClawGatewayConfigurationLoadResult { .none }
    func save(_ configuration: ClawGatewayConfiguration) -> ClawGatewayConfigurationWriteResult { .unavailable }
    func clear() -> ClawGatewayConfigurationClearResult { .cleared }
}

enum ClawGatewayConfigurationState: Equatable, Sendable {
    case notSaved
    case volatile
    case restored
    case saved
    case invalidInput(ClawGatewayConfigurationError)
    case invalidRecord
    case unavailable
    case saveFailed
    case clearFailed
    case cleared

    var message: String {
        switch self {
        case .notSaved: return "尚未保存网关连接。"
        case .volatile: return "当前配置仅在内存中，尚未保存到 Keychain。"
        case .restored: return "已从本机 Keychain 读取连接；未自动联网或恢复任务。"
        case .saved: return "地址与 Token 已作为一条记录保存到本机 Keychain；未自动连接。"
        case .invalidInput(let error): return error.message
        case .invalidRecord: return ClawGatewayConfigurationError.invalidRecord.message
        case .unavailable: return "本机 Keychain 暂不可用；解锁后可显式重新读取或保存，不会写明文备用文件。"
        case .saveFailed: return "保存失败，原已应用连接保持不变；草稿未成为已保存配置。"
        case .clearFailed: return "清除失败，原连接仍保留；未宣称凭据已删除。"
        case .cleared: return "已清除本机连接与运行时凭据；远端 Token 未撤销，已发任务不会被撤销。"
        }
    }
}
