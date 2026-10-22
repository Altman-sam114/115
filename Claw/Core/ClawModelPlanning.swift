import Foundation
import CoreFoundation

enum ClawPlanSource: Equatable, Sendable {
    case rules, configuredModel
    var title: String { self == .rules ? "规则计划预览" : "自托管模型计划 · 待人工复核" }
}

enum ClawModelPlanningError: String, Error, Equatable, Sendable {
    case configuration, invalidInput, invalidResponse, transport, timeout, capacity
    var message: String {
        switch self {
        case .configuration: "请保存有效 Gateway 地址和凭据，并在桌面配置本机 Ollama 与模型。"
        case .invalidInput: "任务文本或模型参数不符合规划合同，请检查长度和输入。"
        case .invalidResponse: "模型计划未通过安全校验；没有生成或执行电脑任务。"
        case .transport: "模型规划请求失败；不会自动重试或切换到模拟结果。"
        case .timeout: "模型规划超时；不会自动重试，远端计算可能尚未停止。"
        case .capacity: "桌面模型正在处理其他规划，请稍后显式重试。"
        }
    }
}

enum ClawModelPlanningPhase: Equatable, Sendable {
    case idle, requesting, ready, cancelled, stale, failed(ClawModelPlanningError)
    var message: String {
        switch self {
        case .idle: "模型规划只发送本次任务文本，不发送屏幕、文件或历史会话。"
        case .requesting: "正在请求桌面已配置的模型；不会执行电脑动作。"
        case .ready: "模型计划已校验。请复核步骤，再生成任务、检查参数和审批。"
        case .cancelled: "已停止本地规划等待，不自动重试；不承诺撤销已经开始的远端计算。"
        case .stale: "上下文已变化，旧模型结果已丢弃。请显式重新规划。"
        case .failed(let error): error.message
        }
    }
}

struct ClawModelPlanningUsage: Equatable, Sendable {
    let inputTokens: Int?
    let outputTokens: Int?
    var title: String {
        "本次模型用量：输入 \(inputTokens.map(String.init) ?? "未知") / 输出 \(outputTokens.map(String.init) ?? "未知") tokens；不是费用报价。"
    }
}

struct ClawModelPlanningRequest: Sendable {
    static let controlPlane = "claw.gateway.planning.v1"
    let command: String
    let nonce: String

    init(command: String, nonce: String = UUID().uuidString.lowercased()) throws {
        let command = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty, command.utf8.count <= 4_096, !command.contains("\0"),
              (8...128).contains(nonce.utf8.count), nonce.utf8.allSatisfy({
                  (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
              }) else { throw ClawModelPlanningError.invalidInput }
        self.command = command
        self.nonce = nonce
    }

    func encodedData() throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "controlPlane": Self.controlPlane, "kind": "planningRequest", "requestNonce": nonce, "command": command
        ], options: [.sortedKeys])
    }
}

struct ClawModelPlannedAction: Equatable, Sendable {
    let kind: ClawMobileActionKind
    let goal: String
    let inputs: [String: String]

    static let inputKeys: [ClawMobileActionKind: Set<String>] = [
        .observeScreen: [], .controlBrowser: ["mode", "app", "target"], .manageFiles: ["path", "text"],
        .runShellCommand: ["command"], .operateDesktopApp: ["app", "text", "keys"],
        .extractData: ["path"], .composeMessage: ["recipient", "text"], .composeEmail: ["recipient", "text"]
    ]

    func arguments() -> [String: String] {
        if kind == .observeScreen {
            return ["observationGoal": goal, "includeScreenshot": "true", "includeAccessibilityTree": "true",
                    "includeWindowTitles": "true", "maxCandidateControls": "20", "redaction": "maskSensitiveText"]
        }
        let template = ClawMobileAction(kind: kind, title: kind.title, target: "Desktop", instruction: goal,
            approval: .gatewayApproval, sourceSurface: .clawGateway, handlesSensitiveData: true, inputPreview: "omitted")
        var input = ClawTaskArgumentInput(action: template)
        input.browserMode = inputs["mode"] == "url" ? .url : .search
        input.browserApp = inputs["app"] ?? ""
        input.browserGoal = goal
        input.browserTarget = inputs["target"] ?? ""
        input.filePath = inputs["path"] ?? ""
        input.fileText = inputs["text"] ?? ""
        input.shellCommand = inputs["command"] ?? ""
        input.desktopApp = inputs["app"] ?? ""
        input.desktopText = inputs["text"] ?? ""
        input.desktopKeys = inputs["keys"] ?? ""
        input.extractionGoal = goal
        input.extractionPath = inputs["path"] ?? ""
        input.recipient = inputs["recipient"] ?? ""
        input.messageBody = inputs["text"] ?? ""
        return input.arguments(for: kind)
    }

    func step() -> PhoneAgentStep {
        PhoneAgentStep(title: kind.title, instruction: goal, target: "Desktop Gateway", surface: .clawGateway,
            runMode: .gatewayOnly, requiresUserConfirmation: true, isAllowedOnIOS: false,
            rationale: "模型仅提出结构化建议；用户复核参数并审批后才能显式发送。", modelProposal: self)
    }
}

struct ClawModelPlanProposal: Equatable, Sendable {
    let summary: String
    let actions: [ClawModelPlannedAction]

    static func parse(_ object: Any) throws -> Self {
        guard let root = object as? [String: Any], Set(root.keys) == ["summary", "actions"],
              let encoded = try? JSONSerialization.data(withJSONObject: root, options: [.withoutEscapingSlashes]), encoded.count <= 32_768,
              let summary = root["summary"] as? String, validText(summary, limit: 500, allowEmpty: false),
              let rows = root["actions"] as? [[String: Any]], (1...8).contains(rows.count) else {
            throw ClawModelPlanningError.invalidResponse
        }
        let actions = try rows.map { row -> ClawModelPlannedAction in
            guard Set(row.keys) == ["kind", "goal", "inputs"], let rawKind = row["kind"] as? String,
                  let kind = ClawMobileActionKind(rawValue: rawKind), let keys = ClawModelPlannedAction.inputKeys[kind],
                  let goal = row["goal"] as? String, validText(goal, limit: 500, allowEmpty: false),
                  let inputs = row["inputs"] as? [String: String], Set(inputs.keys) == keys,
                  inputs.values.allSatisfy({ validText($0, limit: 4_096, allowEmpty: true) }) else {
                throw ClawModelPlanningError.invalidResponse
            }
            if let path = inputs["path"], !path.isEmpty, !ClawTaskArguments.isWorkspacePath(path) {
                throw ClawModelPlanningError.invalidResponse
            }
            if kind == .extractData, (inputs["path"]?.utf8.count ?? 0) > 500 { throw ClawModelPlanningError.invalidResponse }
            if kind == .controlBrowser {
                guard inputs["mode"] == "search" || inputs["mode"] == "url" else { throw ClawModelPlanningError.invalidResponse }
                if inputs["mode"] == "url", let target = inputs["target"], !target.isEmpty, !ClawTaskArguments.isHTTPURL(target) {
                    throw ClawModelPlanningError.invalidResponse
                }
            }
            return ClawModelPlannedAction(kind: kind, goal: goal, inputs: inputs)
        }
        return Self(summary: summary, actions: actions)
    }

    func plan(command: String) -> PhoneAgentPlan {
        let review = PhoneAgentStep(title: "复核本轮证据与下一步", instruction: "仅汇总本轮证据与受控下一步，不自动执行模型建议。",
            target: "Desktop Agent Loop", surface: .clawGateway, runMode: .gatewayOnly,
            requiresUserConfirmation: true, isAllowedOnIOS: false, rationale: "客户端固定证据复核步骤，沿用已有 Gateway 安全策略。")
        return PhoneAgentPlan(command: command, summary: summary, steps: actions.map { $0.step() } + [review], source: .configuredModel)
    }

    private static func validText(_ text: String, limit: Int, allowEmpty: Bool) -> Bool {
        text.utf8.count <= limit && !text.contains("\0") && (allowEmpty || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

struct ClawModelPlanningResponse: Sendable {
    let proposal: ClawModelPlanProposal
    let usage: ClawModelPlanningUsage

    static func decode(_ data: Data, nonce: String) throws -> Self {
        let root = try ClawPlanningJSON.object(data, maxBytes: 65_536)
        if Set(root.keys) == ["controlPlane", "kind", "errorCode"],
           root["controlPlane"] as? String == ClawModelPlanningRequest.controlPlane,
           root["kind"] as? String == "planningError" {
            switch root["errorCode"] as? String {
            case "planning_not_configured", "planning_unauthorized": throw ClawModelPlanningError.configuration
            case "planning_timeout": throw ClawModelPlanningError.timeout
            case "planning_capacity": throw ClawModelPlanningError.capacity
            default: throw ClawModelPlanningError.invalidResponse
            }
        }
        guard Set(root.keys) == ["controlPlane", "kind", "requestNonce", "proposal", "usage", "effects"],
              root["controlPlane"] as? String == ClawModelPlanningRequest.controlPlane,
              root["kind"] as? String == "planningResponse", root["requestNonce"] as? String == nonce,
              let proposalObject = root["proposal"],
              let effects = root["effects"] as? [String: Any], Set(effects.keys) == ["computerActions", "taskDispatched"],
              effects.values.allSatisfy({ value in
                  guard let number = value as? NSNumber else { return false }
                  return CFGetTypeID(number) == CFBooleanGetTypeID() && !number.boolValue
              }), let usage = root["usage"] as? [String: Any], Set(usage.keys) == ["inputTokens", "outputTokens"] else {
            throw ClawModelPlanningError.invalidResponse
        }
        func count(_ key: String) throws -> Int? {
            if usage[key] is NSNull { return nil }
            guard let value = usage[key] as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
                  value.doubleValue >= 0, value.doubleValue <= 1_000_000, value.doubleValue.rounded() == value.doubleValue else {
                throw ClawModelPlanningError.invalidResponse
            }
            return value.intValue
        }
        return try Self(proposal: ClawModelPlanProposal.parse(proposalObject),
            usage: ClawModelPlanningUsage(inputTokens: count("inputTokens"), outputTokens: count("outputTokens")))
    }
}

// JSONSerialization checks grammar; this scan additionally rejects duplicate object keys.
enum ClawPlanningJSON {
    static func object(_ data: Data, maxBytes: Int) throws -> [String: Any] {
        guard data.count <= maxBytes, let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClawModelPlanningError.invalidResponse
        }
        struct Frame { var object: Bool; var expectsKey: Bool; var keys: Set<String> = [] }
        var stack: [Frame] = []
        let bytes = Array(data)
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 34 {
                let start = index
                index += 1
                while index < bytes.count {
                    if bytes[index] == 92 { index += 2; continue }
                    if bytes[index] == 34 { break }
                    index += 1
                }
                if let frame = stack.last, frame.object && frame.expectsKey {
                    let key = try JSONDecoder().decode(String.self, from: Data(bytes[start...index]))
                    guard !frame.keys.contains(key) else { throw ClawModelPlanningError.invalidResponse }
                    stack[stack.count - 1].keys.insert(key)
                    stack[stack.count - 1].expectsKey = false
                }
            } else if byte == 123 || byte == 91 {
                guard stack.count < 20 else { throw ClawModelPlanningError.invalidResponse }
                stack.append(Frame(object: byte == 123, expectsKey: byte == 123))
            } else if byte == 125 || byte == 93 {
                if !stack.isEmpty { stack.removeLast() }
            } else if byte == 44, stack.last?.object == true {
                stack[stack.count - 1].expectsKey = true
            }
            index += 1
        }
        return root
    }
}
