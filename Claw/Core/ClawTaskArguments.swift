import Foundation

enum ClawTaskArgumentIssue: Equatable, Sendable {
    case missingInput, invalidShape, inputTooLong, unsafePath, invalidURL, unsupportedAction

    var message: String {
        switch self {
        case .missingInput: "请填写此动作的必需执行参数。"
        case .invalidShape: "参数不符合固定安全策略，请重新填写。"
        case .inputTooLong: "参数超过 UTF-8 长度限制，请缩短后重试。"
        case .unsafePath: "路径必须是 workspace 内的相对文件路径。"
        case .invalidURL: "请输入不含账号密码的完整 http 或 https 链接。"
        case .unsupportedAction: "此步骤没有可用的 Gateway 执行器，不能真实发送。"
        }
    }
}

enum ClawTaskArguments {
    static let extractionSchema = "title:string,source:string,summary:string,confidence:number"
    static let extractionSources = "browserTrace,accessibilityTree,commandOutput,fileDiff,screenObservation"
    static let searchTemplate = "https://www.google.com/search?q={query}"
    static let remoteKinds: Set<ClawMobileActionKind> = [
        .observeScreen, .controlBrowser, .manageFiles, .runShellCommand, .extractData,
        .operateDesktopApp, .runAgentLoop, .composeMessage, .composeEmail
    ]

    static func isEditable(_ kind: ClawMobileActionKind) -> Bool {
        remoteKinds.contains(kind) && kind != .observeScreen && kind != .runAgentLoop
    }

    static func issue(in task: ClawMobileTask) -> ClawTaskArgumentIssue? {
        guard !task.actions.isEmpty else { return .unsupportedAction }
        return task.actions.lazy.compactMap { issue(in: $0) }.first
    }

    static func issue(in action: ClawMobileAction) -> ClawTaskArgumentIssue? {
        let args = action.toolArguments
        guard remoteKinds.contains(action.kind) else { return .unsupportedAction }
        guard args.values.allSatisfy({ $0.utf8.count <= 4_096 && !$0.contains("\0") }) else { return .inputTooLong }
        let keys: Set<String>
        switch action.kind {
        case .observeScreen:
            keys = ["observationGoal", "includeScreenshot", "includeAccessibilityTree", "includeWindowTitles", "maxCandidateControls", "redaction"]
            guard nonempty(args["observationGoal"]) else { return .missingInput }
            guard ["includeScreenshot", "includeAccessibilityTree", "includeWindowTitles"].allSatisfy({ args[$0] == "true" || args[$0] == "false" }),
                  (1...50).contains(Int(args["maxCandidateControls"] ?? "") ?? 0),
                  args["redaction"] == "maskSensitiveText" else { return .invalidShape }
        case .controlBrowser:
            let hasURL = nonempty(args["openURL"])
            let hasSearch = nonempty(args["searchQuery"])
            guard nonempty(args["browserGoal"]), nonempty(args["browserApp"]), hasURL || hasSearch else { return .missingInput }
            guard hasURL != hasSearch, args["captureTrace"] == "true", args["openInBrowser"] == "true" else { return .invalidShape }
            if hasURL {
                keys = ["browserGoal", "browserApp", "captureTrace", "openInBrowser", "openURL"]
                guard isHTTPURL(args["openURL"] ?? "") else { return .invalidURL }
            } else {
                keys = ["browserGoal", "browserApp", "captureTrace", "openInBrowser", "searchQuery", "searchURLTemplate"]
                guard args["searchURLTemplate"] == searchTemplate else { return .invalidShape }
            }
        case .manageFiles:
            keys = ["operation", "workspaceOnly", "writePath", "writeText"]
            guard nonempty(args["writePath"]), nonempty(args["writeText"]) else { return .missingInput }
            guard args["operation"] == "writeText", args["workspaceOnly"] == "true" else { return .invalidShape }
            guard isWorkspacePath(args["writePath"] ?? "") else { return .unsafePath }
        case .runShellCommand:
            keys = ["shellCommand", "cwdPolicy"]
            guard nonempty(args["shellCommand"]) else { return .missingInput }
            guard args["cwdPolicy"] == "workspaceOnly" else { return .invalidShape }
        case .operateDesktopApp:
            keys = ["targetApp", "automationMode", "inputMode", "draftText", "keySequence", "finalSubmitRequiresApproval", "captureBeforeAfter"]
            guard nonempty(args["targetApp"]), nonempty(args["draftText"]) || nonempty(args["keySequence"]) else { return .missingInput }
            guard args["automationMode"] == "accessibility", args["inputMode"] == "typeOrPaste",
                  args["finalSubmitRequiresApproval"] == "true", args["captureBeforeAfter"] == "true" else { return .invalidShape }
        case .extractData:
            keys = ["extractionGoal", "outputPath", "schema", "sourcePriority", "validateCompleteness"]
            guard nonempty(args["extractionGoal"]), nonempty(args["outputPath"]) else { return .missingInput }
            guard (args["extractionGoal"]?.utf8.count ?? 0) <= 500,
                  (args["outputPath"]?.utf8.count ?? 0) <= 500 else { return .inputTooLong }
            guard isWorkspacePath(args["outputPath"] ?? "") else { return .unsafePath }
            guard args["schema"] == extractionSchema, args["sourcePriority"] == extractionSources,
                  args["validateCompleteness"] == "true" else { return .invalidShape }
        case .composeMessage, .composeEmail:
            keys = ["recipientOrChannel", "deliverySurface", "draftText", "finalSubmitRequiresApproval"]
            guard nonempty(args["recipientOrChannel"]), nonempty(args["draftText"]) else { return .missingInput }
            guard args["deliverySurface"] == "messageDraft", args["finalSubmitRequiresApproval"] == "true" else { return .invalidShape }
        case .runAgentLoop:
            keys = ["objective", "loopMode", "maxIterations", "inputSources", "allowedNextActions", "approvalRequiredFor", "stopBeforeDestructiveAction", "writeTrace"]
            guard nonempty(args["objective"]) else { return .missingInput }
            guard args["loopMode"] == "observe-plan-act-verify", (1...8).contains(Int(args["maxIterations"] ?? "") ?? 0),
                  args["stopBeforeDestructiveAction"] == "true", args["writeTrace"] == "true" else { return .invalidShape }
            let inputs: Set<String> = ["screenObservation", "accessibilityTree", "browserTrace", "fileDiff", "commandOutput", "messageDraft"]
            let next: Set<String> = ["observeScreen", "controlBrowser", "manageFiles", "extractData", "operateDesktopApp", "composeMessage"]
            let approvals = next.union(["runShellCommand", "operateDesktopAppFinalSubmit", "externalNetwork", "destructiveFileChange"])
            guard !csv(args["inputSources"]).isEmpty, csv(args["inputSources"]).isSubset(of: inputs),
                  !csv(args["allowedNextActions"]).isEmpty, csv(args["allowedNextActions"]).isSubset(of: next),
                  csv(args["approvalRequiredFor"]).isSubset(of: approvals) else { return .invalidShape }
        default:
            return .unsupportedAction
        }
        return Set(args.keys) == keys ? nil : .invalidShape
    }

    static func isWorkspacePath(_ path: String) -> Bool {
        guard !path.isEmpty, path == path.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.hasPrefix("/"), !path.hasPrefix("~"), !path.contains("\\"), !path.contains(":"),
              !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return false }
        return path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    static func isHTTPURL(_ raw: String) -> Bool {
        guard raw == raw.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URLComponents(string: raw), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme), let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil,
              !raw.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return false }
        return true
    }

    private static func nonempty(_ text: String?) -> Bool {
        text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private static func csv(_ value: String?) -> Set<String> {
        Set((value ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
    }
}

struct ClawTaskArgumentEditorContext: Identifiable, Equatable, Sendable {
    let task: ClawMobileTask
    let action: ClawMobileAction
    var id: UUID { action.id }
}

/// Transient form values; only an explicit typed Apply can change a task.
struct ClawTaskArgumentInput: Equatable, Sendable {
    enum BrowserMode: String, CaseIterable, Identifiable, Sendable {
        case search, url
        var id: Self { self }
        var title: String { self == .search ? "搜索" : "打开链接" }
    }

    var browserMode: BrowserMode = .search
    var browserApp = "Safari"
    var browserGoal = ""
    var browserTarget = ""
    var filePath = ""
    var fileText = ""
    var shellCommand = ""
    var desktopApp = ""
    var desktopText = ""
    var desktopKeys = ""
    var extractionGoal = ""
    var extractionPath = ""
    var recipient = ""
    var messageBody = ""

    init(action: ClawMobileAction) {
        let args = action.toolArguments
        browserMode = args["openURL"] == nil ? .search : .url
        browserApp = args["browserApp"] ?? "Safari"
        browserGoal = args["browserGoal"] ?? ""
        browserTarget = args["openURL"] ?? args["searchQuery"] ?? ""
        filePath = args["writePath"] ?? ""
        fileText = args["writeText"] ?? ""
        shellCommand = args["shellCommand"] ?? ""
        desktopApp = args["targetApp"] ?? ""
        desktopText = args["draftText"] ?? ""
        desktopKeys = args["keySequence"] ?? ""
        extractionGoal = args["extractionGoal"] ?? ""
        extractionPath = args["outputPath"] ?? ""
        recipient = args["recipientOrChannel"] ?? ""
        messageBody = args["draftText"] ?? ""
    }

    func arguments(for kind: ClawMobileActionKind) -> [String: String] {
        switch kind {
        case .controlBrowser:
            var args = ["browserApp": browserApp, "browserGoal": browserGoal, "openInBrowser": "true", "captureTrace": "true"]
            if browserMode == .url {
                args["openURL"] = browserTarget
            } else {
                args["searchQuery"] = browserTarget
                args["searchURLTemplate"] = ClawTaskArguments.searchTemplate
            }
            return args
        case .manageFiles:
            return ["operation": "writeText", "workspaceOnly": "true", "writePath": filePath, "writeText": fileText]
        case .runShellCommand:
            return ["shellCommand": shellCommand, "cwdPolicy": "workspaceOnly"]
        case .operateDesktopApp:
            return ["targetApp": desktopApp, "automationMode": "accessibility", "inputMode": "typeOrPaste", "draftText": desktopText, "keySequence": desktopKeys, "finalSubmitRequiresApproval": "true", "captureBeforeAfter": "true"]
        case .extractData:
            return ["extractionGoal": extractionGoal, "outputPath": extractionPath, "schema": ClawTaskArguments.extractionSchema, "sourcePriority": ClawTaskArguments.extractionSources, "validateCompleteness": "true"]
        case .composeMessage, .composeEmail:
            return ["recipientOrChannel": recipient, "deliverySurface": "messageDraft", "draftText": messageBody, "finalSubmitRequiresApproval": "true"]
        default:
            return [:]
        }
    }
}
