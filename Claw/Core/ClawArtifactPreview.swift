import CoreFoundation
import Foundation

enum ClawArtifactPreviewError: Error, Equatable, Sendable {
    case unavailable, configuration, invalidResponse, transport, cancelled, timeout, stale

    var message: String {
        switch self {
        case .unavailable: return "结果不可读取：可能已过期、超限或不支持文本预览。"
        case .configuration: return "请先保存与本次执行一致的安全 Gateway 连接。"
        case .invalidResponse: return "结果响应未通过身份、格式或容量校验。"
        case .transport: return "读取失败；不会自动重试或改用模拟内容。"
        case .cancelled: return "已取消读取，本机预览内容已清除。"
        case .timeout: return "读取超时；不会自动重试。"
        case .stale: return "任务、结果或连接已变化，请重新选择当前结果。"
        }
    }
}

struct ClawArtifactPreviewSelection: Identifiable, Equatable, Sendable {
    let taskID: UUID
    let sessionID: UUID
    let artifact: ClawGatewayArtifact
    let binding: String
    var id: UUID { artifact.id }

    static func supports(_ kind: ClawGatewayArtifactKind) -> Bool {
        [.fileDiff, .commandOutput, .browserTrace, .messageDraft].contains(kind)
    }
}

struct ClawArtifactPreviewRequest: Sendable {
    static let controlPlane = "claw.gateway.artifact-preview.v1"
    let taskID: UUID
    let artifactID: UUID
    let nonce: String

    init(taskID: UUID, artifactID: UUID, nonce: String = UUID().uuidString.replacingOccurrences(of: "-", with: "")) {
        self.taskID = taskID
        self.artifactID = artifactID
        self.nonce = nonce
    }

    func encodedData() throws -> Data {
        guard (8...128).contains(nonce.utf8.count), nonce.utf8.allSatisfy({
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        }) else { throw ClawArtifactPreviewError.invalidResponse }
        return try JSONSerialization.data(withJSONObject: ["controlPlane": Self.controlPlane, "kind": "previewRequest",
            "requestNonce": nonce, "taskID": taskID.uuidString, "artifactID": artifactID.uuidString])
    }
}

struct ClawArtifactPreviewContent: Equatable, Sendable {
    let text: String
    let byteCount: Int

    static func decode(_ data: Data, request: ClawArtifactPreviewRequest, kind: ClawGatewayArtifactKind) throws -> Self {
        guard let root = try? ClawPlanningJSON.object(data, maxBytes: 262_144) else {
            throw ClawArtifactPreviewError.invalidResponse
        }
        if Set(root.keys) == ["controlPlane", "kind", "errorCode"],
           root["controlPlane"] as? String == ClawArtifactPreviewRequest.controlPlane,
           root["kind"] as? String == "previewError" {
            switch root["errorCode"] as? String {
            case "preview_not_available": throw ClawArtifactPreviewError.unavailable
            case "preview_unauthorized": throw ClawArtifactPreviewError.configuration
            default: throw ClawArtifactPreviewError.invalidResponse
            }
        }
        guard Set(root.keys) == ["controlPlane", "kind", "requestNonce", "taskID", "artifactID", "artifactKind", "mediaType", "content", "byteCount", "effects"],
              root["controlPlane"] as? String == ClawArtifactPreviewRequest.controlPlane,
              root["kind"] as? String == "previewResponse", root["requestNonce"] as? String == request.nonce,
              (root["taskID"] as? String).flatMap(UUID.init(uuidString:)) == request.taskID,
              (root["artifactID"] as? String).flatMap(UUID.init(uuidString:)) == request.artifactID,
              ClawArtifactPreviewSelection.supports(kind), root["artifactKind"] as? String == kind.rawValue,
              root["mediaType"] as? String == "text/plain; charset=utf-8",
              let text = root["content"] as? String, !text.contains("\0"), text.utf8.count <= 32_768,
              let count = root["byteCount"] as? NSNumber, CFGetTypeID(count) != CFBooleanGetTypeID(),
              count.doubleValue == Double(text.utf8.count),
              let effects = root["effects"] as? [String: Any], Set(effects.keys) == ["computerActions", "taskDispatched"],
              effects.values.allSatisfy({ value in
                  guard let number = value as? NSNumber else { return false }
                  return CFGetTypeID(number) == CFBooleanGetTypeID() && !number.boolValue
              }) else { throw ClawArtifactPreviewError.invalidResponse }
        return Self(text: text, byteCount: text.utf8.count)
    }
}

enum ClawArtifactPreviewState: Equatable, Sendable {
    case idle
    case loading(ClawArtifactPreviewSelection)
    case ready(ClawArtifactPreviewSelection, ClawArtifactPreviewContent)
    case failed(ClawArtifactPreviewSelection, ClawArtifactPreviewError)

    var selection: ClawArtifactPreviewSelection? {
        switch self {
        case .idle: return nil
        case .loading(let value), .ready(let value, _), .failed(let value, _): return value
        }
    }
}
