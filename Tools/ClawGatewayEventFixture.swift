import Foundation

@main
enum ClawGatewayEventFixture {
    private static let gatewayHandlerSupportedKinds: Set<String> = [
        "runAgentLoop",
        "observeScreen",
        "controlBrowser",
        "manageFiles",
        "runShellCommand",
        "extractData",
        "operateDesktopApp",
        "composeMessage",
        "composeEmail"
    ]

    static func main() throws {
        if CommandLine.arguments.contains("--help") {
            print("""
            usage: claw-gateway-event-fixture [envelope.json]

            Reads a claw.computer.control.v1 envelope from a file or stdin and prints
            newline-delimited ClawGatewayEvent JSON. This is a desktop Gateway contract
            fixture, not a real computer-control runtime.
            """)
            return
        }
        if CommandLine.arguments.contains("--self-test") {
            try runSelfTest()
            print("Claw Gateway event fixture self-test passed")
            return
        }

        let input = try readInput()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(ClawMobileEnvelope.self, from: input)
        guard envelope.schemaVersion == "claw.computer.control.v1" else {
            throw FixtureError.unsupportedSchema(envelope.schemaVersion)
        }

        let sessionID = UUID()
        let events = makeEvents(for: envelope, sessionID: sessionID)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        for event in events {
            let data = try encoder.encode(event)
            guard let line = String(data: data, encoding: .utf8) else {
                throw FixtureError.encodingFailed
            }
            print(line)
        }
    }

    private static func readInput() throws -> Data {
        let args = CommandLine.arguments.dropFirst().filter { $0 != "--help" }
        if let path = args.first {
            return try Data(contentsOf: URL(fileURLWithPath: path))
        }

        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard data.isEmpty == false else {
            throw FixtureError.missingInput
        }
        return data
    }

    private static func runSelfTest() throws {
        let unsupportedAction = ClawMobileAction(
            kind: .openExternalURL,
            title: "Unsupported fixture action",
            target: "omitted",
            instruction: "omitted",
            approval: .gatewayApproval,
            sourceSurface: .clawGateway,
            handlesSensitiveData: true,
            inputPreview: "omitted"
        )
        let skippedAction = ClawMobileAction(
            kind: .observeScreen,
            title: "Policy-skipped fixture action",
            target: "omitted",
            instruction: "omitted",
            approval: .automatic,
            sourceSurface: .clawGateway,
            handlesSensitiveData: true,
            inputPreview: "omitted"
        )
        let approvalOverrideAction = ClawMobileAction(
            kind: .runAgentLoop,
            title: "Approval override fixture action",
            target: "omitted",
            instruction: "omitted",
            approval: .gatewayApproval,
            sourceSurface: .clawGateway,
            handlesSensitiveData: false,
            inputPreview: "omitted",
            toolArguments: [
                "allowedNextActions": "extractData",
                "approvalRequiredFor": "extractData"
            ]
        )
        let noActionOverrideAction = ClawMobileAction(
            kind: .runAgentLoop,
            title: "No-action fixture action",
            target: "omitted",
            instruction: "omitted",
            approval: .gatewayApproval,
            sourceSurface: .clawGateway,
            handlesSensitiveData: false,
            inputPreview: "omitted",
            toolArguments: [
                "allowedNextActions": "observeScreen",
                "approvalRequiredFor": "none"
            ]
        )
        let envelope = ClawMobileEnvelope(
            schemaVersion: "claw.computer.control.v1",
            sourceApp: "Claw Controller",
            task: ClawMobileTask(
                command: "fixture self-test",
                summary: "fixture self-test",
                sourceDevice: "CI",
                destinationGateway: "fixture",
                actions: [unsupportedAction, skippedAction],
                status: .sent,
                riskScore: 10
            ),
            gateway: ClawGatewayProfile(
                endpoint: "fixture://gateway",
                deviceName: "fixture",
                securityMode: .mutualApproval,
                tokenFingerprint: "unset",
                allowedActionKinds: [.openExternalURL],
                requiresApprovalForSensitiveData: true,
                auditEnabled: true
            ),
            approvalSummary: "fixture",
            auditRequired: true
        )
        let events = makeEvents(for: envelope, sessionID: UUID())
        let failed = events.first {
            $0.actionID == unsupportedAction.id &&
            $0.kind == .actionFailed &&
            $0.resultStatus == .failed &&
            $0.isRetryable == false
        }
        let audit = events
            .filter { $0.actionID == unsupportedAction.id && $0.kind == .artifactStored }
            .flatMap(\.artifacts)
            .first { artifact in
                artifact.kind == .auditLog &&
                artifact.isRedacted &&
                artifact.metadata?["handlerSupported"] == "false"
            }
        let skipped = events.first {
            $0.actionID == skippedAction.id &&
            $0.kind == .actionSkipped &&
            $0.resultStatus == .skipped
        }
        let skippedArtifacts = events
            .filter { $0.actionID == skippedAction.id && $0.kind == .artifactStored }
            .flatMap(\.artifacts)
        let blockedDecision = agentTraceMetadata(
            for: unsupportedAction,
            allowedActionKinds: [.runAgentLoop]
        )
        let desktopDecision = agentTraceMetadata(
            for: unsupportedAction,
            allowedActionKinds: [.runAgentLoop, .operateDesktopApp]
        )
        let approvalOverrideDecision = agentTraceMetadata(
            for: approvalOverrideAction,
            allowedActionKinds: [.runAgentLoop, .extractData]
        )
        let noActionOverrideDecision = agentTraceMetadata(
            for: noActionOverrideAction,
            allowedActionKinds: [.runAgentLoop, .observeScreen]
        )
        guard
            failed != nil,
            audit != nil,
            skipped != nil,
            skippedArtifacts.count == 1,
            skippedArtifacts.first?.kind == .auditLog,
            skippedArtifacts.first?.isRedacted == true,
            blockedDecision["selectedActionDecisionPolicy"] == "evidence-first-safe-v1",
            blockedDecision["selectedActionDecisionReason"] == "policy-blocked",
            blockedDecision["selectedActionCandidateCount"] == "1",
            blockedDecision["selectedActionCandidateOrdinal"] == "1",
            blockedDecision["selectedActionFromCandidates"] == "true",
            blockedDecision["selectedActionDecisionConsistent"] == "true",
            desktopDecision["selectedNextActionKind"] == "operateDesktopApp",
            desktopDecision["selectedActionDecisionReason"] == "approval-required-fallback",
            desktopDecision["riskTags"]?.contains("desktop-control-gate") == true,
            desktopDecision["riskTags"]?.contains("final-submit-gate") == true,
            desktopDecision["stopReason"] == "final-submit",
            desktopDecision["handoffStatus"] == "final-submit-review",
            approvalOverrideDecision["selectedNextActionKind"] == "extractData",
            approvalOverrideDecision["selectedNextActionRequiresApproval"] == "true",
            approvalOverrideDecision["selectedActionDecisionReason"] == "approval-required-fallback",
            approvalOverrideDecision["stopReason"] == "approval-required",
            approvalOverrideDecision["handoffStatus"] == "waiting-for-approval",
            noActionOverrideDecision["selectedNextActionKind"] == "none",
            noActionOverrideDecision["selectedNextActionRequiresApproval"] == "false",
            noActionOverrideDecision["selectedActionDecisionReason"] == "no-action-needed",
            noActionOverrideDecision["stopReason"] == "complete",
            noActionOverrideDecision["handoffStatus"] == "complete"
        else {
            throw FixtureError.selfTestFailed
        }
    }

    private static func makeEvents(
        for envelope: ClawMobileEnvelope,
        sessionID: UUID
    ) -> [ClawGatewayEvent] {
        let task = envelope.task
        var sequence = 0
        var events: [ClawGatewayEvent] = [
            ClawGatewayEvent(
                sessionID: sessionID,
                taskID: task.id,
                sequence: sequence,
                kind: .sessionPrepared,
                summary: "fixture session prepared for \(task.actions.count) actions"
            )
        ]
        sequence += 1
        events.append(
            ClawGatewayEvent(
                sessionID: sessionID,
                taskID: task.id,
                sequence: sequence,
                kind: .gatewayConnected,
                summary: "fixture gateway accepted envelope from \(envelope.sourceApp)"
            )
        )
        sequence += 1

        for (index, action) in task.actions.enumerated() {
            events.append(
                ClawGatewayEvent(
                    sessionID: sessionID,
                    taskID: task.id,
                    sequence: sequence,
                    kind: .actionStarted,
                    actionID: action.id,
                    actionKind: action.kind,
                    actionTitle: action.title,
                    resultStatus: .running,
                    summary: "fixture started \(action.kind.rawValue)"
                )
            )
            sequence += 1

            let status = resultStatus(
                for: action,
                allowedActionKinds: envelope.gateway.allowedActionKinds
            )
            let artifacts = artifacts(
                for: action,
                index: index,
                allowedActionKinds: envelope.gateway.allowedActionKinds,
                status: status
            )
            if artifacts.isEmpty == false {
                events.append(
                    ClawGatewayEvent(
                        sessionID: sessionID,
                        taskID: task.id,
                        sequence: sequence,
                        kind: .artifactStored,
                        actionID: action.id,
                        actionKind: action.kind,
                        actionTitle: action.title,
                        resultStatus: .running,
                        summary: "fixture stored \(artifacts.count) artifact references",
                        artifacts: artifacts
                    )
                )
                sequence += 1
            }

            events.append(
                ClawGatewayEvent(
                    sessionID: sessionID,
                    taskID: task.id,
                    sequence: sequence,
                    kind: eventKind(for: status),
                    actionID: action.id,
                    actionKind: action.kind,
                    actionTitle: action.title,
                    resultStatus: status,
                    summary: summary(for: action, status: status),
                    isRetryable: action.kind == .runShellCommand && status == .failed
                )
            )
            sequence += 1
        }

        events.append(
            ClawGatewayEvent(
                sessionID: sessionID,
                taskID: task.id,
                sequence: sequence,
                kind: .sessionCompleted,
                summary: "fixture session completed"
            )
        )

        return events
    }

    private static func resultStatus(
        for action: ClawMobileAction,
        allowedActionKinds: [ClawMobileActionKind]
    ) -> ClawGatewayActionResultStatus {
        if action.approval == .blocked || allowedActionKinds.contains(action.kind) == false {
            return .skipped
        }

        guard gatewayHandlerSupportedKinds.contains(action.kind.rawValue) else {
            return .failed
        }

        switch action.kind {
        case .runShellCommand:
            return .failed
        case .operateDesktopApp, .composeMessage, .composeEmail:
            return .waitingForApproval
        case .runAgentLoop, .observeScreen, .controlBrowser, .manageFiles, .extractData:
            return .succeeded
        case .analyzeLocalContext, .requestPermission, .readContacts, .createReminder, .scheduleNotification, .openExternalURL, .runShortcut, .speechCapture, .backgroundRefresh, .desktopHandoff, .auditLog, .blockedUnsupported:
            return .failed
        }
    }

    private static func eventKind(for status: ClawGatewayActionResultStatus) -> ClawGatewayEventKind {
        switch status {
        case .pending, .running:
            return .actionStarted
        case .succeeded:
            return .actionCompleted
        case .failed:
            return .actionFailed
        case .skipped:
            return .actionSkipped
        case .waitingForApproval:
            return .approvalRequested
        }
    }

    private static func artifacts(
        for action: ClawMobileAction,
        index: Int,
        allowedActionKinds: [ClawMobileActionKind],
        status: ClawGatewayActionResultStatus
    ) -> [ClawGatewayArtifact] {
        let suffix = index + 1
        if status == .skipped {
            return [
                artifact(
                    .auditLog,
                    "fixture-policy-skip-\(suffix).json",
                    redacted: true,
                    metadata: policySkippedMetadata(for: action)
                )
            ]
        }
        if status == .failed && gatewayHandlerSupportedKinds.contains(action.kind.rawValue) == false {
            return [
                artifact(
                    .auditLog,
                    "fixture-unsupported-action-\(suffix).json",
                    redacted: true,
                    metadata: unsupportedActionMetadata(for: action)
                )
            ]
        }

        switch action.kind {
        case .runAgentLoop:
            return [artifact(.agentTrace, "fixture-agent-loop-\(suffix).json", redacted: true, metadata: agentTraceMetadata(for: action, allowedActionKinds: allowedActionKinds))]
        case .observeScreen:
            return [
                artifact(.screenshot, "fixture-screen-\(suffix).png", redacted: true),
                artifact(.accessibilityTree, "fixture-ax-\(suffix).json", redacted: true)
            ]
        case .controlBrowser:
            return [
                artifact(.browserTrace, "fixture-browser-\(suffix).json", redacted: false, metadata: browserControlReviewMetadata()),
                artifact(.screenshot, "fixture-browser-\(suffix).png", redacted: true, metadata: browserControlReviewMetadata())
            ]
        case .manageFiles:
            return [artifact(.fileDiff, "fixture-file-diff-\(suffix).json", redacted: false, metadata: fileChangeReviewMetadata())]
        case .runShellCommand:
            return [artifact(.commandOutput, "fixture-shell-\(suffix).log", redacted: true, metadata: shellCommandSafetyMetadata())]
        case .operateDesktopApp:
            return [artifact(.screenshot, "fixture-app-\(suffix).png", redacted: true)]
        case .composeMessage, .composeEmail:
            return [artifact(.messageDraft, "fixture-draft-\(suffix).txt", redacted: true)]
        case .analyzeLocalContext, .requestPermission, .extractData, .readContacts, .createReminder, .scheduleNotification, .openExternalURL, .runShortcut, .speechCapture, .backgroundRefresh, .desktopHandoff, .auditLog, .blockedUnsupported:
            return [artifact(.auditLog, "fixture-audit-\(suffix).json", redacted: action.handlesSensitiveData)]
        }
    }

    private static func unsupportedActionMetadata(
        for action: ClawMobileAction
    ) -> [String: String] {
        [
            "mode": "gateway-unsupported-action",
            "actionID": action.id.uuidString,
            "actionKind": action.kind.rawValue,
            "policyDiagnostic": "unsupported-action-handler",
            "schemaActionKnown": "true",
            "envelopeAllowed": "true",
            "handlerSupported": "false",
            "handlerExecution": "blocked",
            "handlerExecutionAttempted": "false",
            "businessSideEffectsAttempted": "false",
            "resultStatus": "failed",
            "retryable": "false",
            "safetyFlags": "metadata-only,action-bound,handler-not-invoked,business-artifacts-not-written,tool-arguments-omitted,instruction-omitted,input-preview-omitted,target-omitted"
        ]
    }

    private static func policySkippedMetadata(
        for action: ClawMobileAction
    ) -> [String: String] {
        [
            "mode": "gateway-policy-skip",
            "actionID": action.id.uuidString,
            "actionKind": action.kind.rawValue,
            "policyDiagnostic": "approval-or-envelope-blocked",
            "handlerExecutionAttempted": "false",
            "businessSideEffectsAttempted": "false",
            "resultStatus": "skipped",
            "retryable": "false",
            "safetyFlags": "metadata-only,action-bound,handler-not-invoked,business-artifacts-not-written,tool-arguments-omitted"
        ]
    }

    private static func agentTraceMetadata(
        for action: ClawMobileAction,
        allowedActionKinds: [ClawMobileActionKind]
    ) -> [String: String] {
        let supported: Set<String> = ["observeScreen", "controlBrowser", "manageFiles", "extractData", "operateDesktopApp", "composeMessage"]
        let defaultNextActions = "observeScreen,controlBrowser,manageFiles,extractData,operateDesktopApp,composeMessage"
        let requested = (action.toolArguments["allowedNextActions"] ?? defaultNextActions)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .reduce(into: [String]()) { values, value in
                if values.contains(value) == false { values.append(value) }
            }
        let envelopeAllowed = Set(allowedActionKinds.map(\.rawValue))
        let effective = requested.filter { supported.contains($0) && envelopeAllowed.contains($0) }
        let blocked = requested.count - effective.count
        let policyBlocked = effective.isEmpty
        let candidates = ["extractData", "composeMessage", "operateDesktopApp"].filter { effective.contains($0) }
        let selected = candidates.first ?? "none"
        let approvalRequiredFor = Set((action.toolArguments["approvalRequiredFor"] ?? "runShellCommand,operateDesktopAppFinalSubmit,externalNetwork,destructiveFileChange")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        let selectedRequiresApproval = selected != "none" &&
            (selected != "extractData" || approvalRequiredFor.contains(selected))
        let selectedNeedsFinalSubmit = selected == "composeMessage" ||
            (selected == "operateDesktopApp" && approvalRequiredFor.contains("operateDesktopAppFinalSubmit"))
        let selectedOrdinal = selected == "none" ? 1 : ((candidates.firstIndex(of: selected) ?? 0) + 1)
        let decisionReason = policyBlocked
            ? "policy-blocked"
            : (selected == "none"
                ? "no-action-needed"
                : (selectedRequiresApproval ? "approval-required-fallback" : "safe-without-approval"))
        let stopReason = policyBlocked
            ? "policy-blocked"
            : (selected == "none"
                ? "complete"
                : (selectedNeedsFinalSubmit
                    ? "final-submit"
                    : (selectedRequiresApproval ? "approval-required" : "none")))
        let handoffStatus = policyBlocked
            ? "blocked"
            : (stopReason == "complete"
                ? "complete"
                : (stopReason == "final-submit"
                    ? "final-submit-review"
                    : (selectedRequiresApproval ? "waiting-for-approval" : "ready-to-continue")))
        var riskTags = ["degraded-screen-observation", "degraded-accessibility-tree", "missing-message-draft"]
        if policyBlocked {
            riskTags.insert("next-action-policy-blocked", at: 0)
        } else if selectedRequiresApproval {
            riskTags.append("approval-required")
            if selected == "operateDesktopApp" {
                riskTags.append("desktop-control-gate")
            }
            if selectedNeedsFinalSubmit {
                riskTags.append("final-submit-gate")
            }
        }
        return [
            "readinessScore": "50",
            "readinessCanContinue": "true",
            "satisfiedSignals": "browserTrace,fileDiff,commandOutput",
            "degradedSignals": "screenObservation,accessibilityTree",
            "missingSignals": "messageDraft",
            "selectedNextActionKind": selected,
            "selectedNextActionRequiresApproval": String(selectedRequiresApproval),
            "nextActionPolicy": "envelope-intersection",
            "nextActionPolicyDiagnostic": policyBlocked ? "policy-blocked" : "allowed",
            "requestedNextActionCount": String(requested.count),
            "effectiveNextActionCount": String(effective.count),
            "blockedNextActionCount": String(blocked),
            "selectedNextActionAllowedByEnvelope": "true",
            "selectedActionDecisionPolicy": "evidence-first-safe-v1",
            "selectedActionDecisionReason": decisionReason,
            "selectedActionCandidateCount": String(max(candidates.count, 1)),
            "selectedActionCandidateOrdinal": String(selectedOrdinal),
            "selectedActionFromCandidates": "true",
            "selectedActionDecisionConsistent": "true",
            "riskTags": riskTags.joined(separator: ","),
            "stopReason": stopReason,
            "handoffStatus": handoffStatus,
            "handoffSummary": "Evidence score 50/100. Selected next action: \(selected)."
        ]
    }

    private static func artifact(
        _ kind: ClawGatewayArtifactKind,
        _ title: String,
        redacted: Bool,
        metadata: [String: String]? = nil
    ) -> ClawGatewayArtifact {
        ClawGatewayArtifact(
            kind: kind,
            title: title,
            reference: "\(kind.rawValue)://fixture/\(title)",
            isRedacted: redacted,
            metadata: metadata
        )
    }

    private static func browserControlReviewMetadata() -> [String: String] {
        [
            "browserReview": "controlPlan",
            "mode": "browser-control-dry-run",
            "actionKind": ClawMobileActionKind.controlBrowser.rawValue,
            "browserControlPolicy": "dry-run",
            "policyDiagnostic": "dry-run",
            "retryableReason": "enable-browser-control",
            "browserControlRequested": "true",
            "openInBrowser": "true",
            "openAttempted": "false",
            "targetURLPresent": "true",
            "searchQueryPresent": "true",
            "localHTMLInput": "false",
            "networkFetchAttempted": "false",
            "networkFetchSucceeded": "false",
            "networkBlocked": "false",
            "networkPolicyDiagnostic": "not-requested",
            "redirectPolicyChecked": "false",
            "redirectCount": "0",
            "redirectBlocked": "false",
            "redirectLimitExceeded": "false",
            "appAllowlistEnforced": "false",
            "hostAllowlistEnforced": "false",
            "appPolicyChecked": "false",
            "hostPolicyChecked": "false",
            "executed": "false",
            "timedOut": "false",
            "resultStatus": "succeeded",
            "safetyFlags": "metadata-only,tool-arguments-omitted,url-omitted,search-query-omitted,page-content-omitted,form-fields-omitted,candidate-labels-omitted,artifact-payload-not-read"
        ]
    }

    private static func fileChangeReviewMetadata() -> [String: String] {
        [
            "fileChangeReview": "workspaceWrite",
            "mode": "workspace-write",
            "actionKind": ClawMobileActionKind.manageFiles.rawValue,
            "workspacePolicy": "session-workspace-only",
            "workspaceScoped": "true",
            "pathEscapeBlocked": "false",
            "writeAttempted": "true",
            "writeSucceeded": "true",
            "createdFileCount": "1",
            "modifiedFileCount": "0",
            "deletedFileCount": "0",
            "requestedPathPresent": "true",
            "writeTextPresent": "true",
            "rawPathOmitted": "true",
            "contentOmitted": "true",
            "diffOmitted": "true",
            "resultStatus": "succeeded",
            "safetyFlags": "metadata-only,tool-arguments-omitted,raw-path-omitted,workspace-path-omitted,file-content-omitted,diff-content-omitted,artifact-payload-not-read,session-workspace-only"
        ]
    }

    private static func shellCommandSafetyMetadata() -> [String: String] {
        [
            "shellReview": "commandSafety",
            "mode": "shell-policy-blocked",
            "actionKind": ClawMobileActionKind.runShellCommand.rawValue,
            "shellPolicy": "dry-run",
            "structuredCommandPresent": "true",
            "commandParsed": "true",
            "allowlistConfigured": "false",
            "allowlistMatched": "false",
            "executionAttempted": "false",
            "executed": "false",
            "timedOut": "false",
            "exitCodePresent": "false",
            "exitCodeZero": "false",
            "stdoutPresent": "false",
            "stderrPresent": "false",
            "commandOmitted": "true",
            "stdoutOmitted": "true",
            "stderrOmitted": "true",
            "cwdOmitted": "true",
            "resultStatus": "failed",
            "safetyFlags": "metadata-only,structured-arguments-only,tool-arguments-omitted,command-omitted,stdout-omitted,stderr-omitted,cwd-omitted,shell-allowlist-enforced,dry-run-only,no-command-executed,artifact-payload-not-read"
        ]
    }

    private static func summary(
        for action: ClawMobileAction,
        status: ClawGatewayActionResultStatus
    ) -> String {
        switch status {
        case .succeeded:
            return "fixture completed \(action.title)"
        case .failed:
            if gatewayHandlerSupportedKinds.contains(action.kind.rawValue) == false {
                return "fixture blocked unsupported action handler"
            }
            return "fixture paused \(action.title); command policy needs a narrower allowlist"
        case .waitingForApproval:
            return "fixture reached confirmation point for \(action.title)"
        case .skipped:
            return "fixture skipped \(action.title)"
        case .pending, .running:
            return "fixture is processing \(action.title)"
        }
    }
}

enum FixtureError: Error, CustomStringConvertible {
    case missingInput
    case unsupportedSchema(String)
    case encodingFailed
    case selfTestFailed

    var description: String {
        switch self {
        case .missingInput:
            return "missing envelope input"
        case .unsupportedSchema(let schema):
            return "unsupported schema: \(schema)"
        case .encodingFailed:
            return "failed to encode event line"
        case .selfTestFailed:
            return "fixture unsupported-action contract failed"
        }
    }
}
