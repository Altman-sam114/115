import Foundation
import Security

struct ClawGatewayKeychainStore: ClawGatewayConfigurationStore {
    static let productionService = "app.claw.gateway.connection.v1"
    let service: String

    init(service: String = ClawGatewayKeychainStore.productionService) {
        self.service = service
    }

    private var query: [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "connection",
            kSecAttrSynchronizable as String: false
        ]
        #if os(macOS) || targetEnvironment(macCatalyst)
        query[kSecUseDataProtectionKeychain as String] = true
        #endif
        return query
    }

    func load() -> ClawGatewayConfigurationLoadResult {
        var query = query
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return .none }
        guard status == errSecSuccess, let data = item as? Data else { return .unavailable }
        guard let configuration = try? ClawGatewayConfiguration.decodeSecretRecord(data) else { return .invalid }
        return .loaded(configuration)
    }

    func save(_ configuration: ClawGatewayConfiguration) -> ClawGatewayConfigurationWriteResult {
        guard let data = try? configuration.encodedSecretRecord() else { return .failed }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        // Never delete the old pair before publishing its replacement.
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
            if status == errSecDuplicateItem {
                status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            }
        }
        return status == errSecSuccess ? .saved : .failed
    }

    func clear() -> ClawGatewayConfigurationClearResult {
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound ? .cleared : .failed
    }
}
