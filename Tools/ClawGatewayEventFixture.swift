import Foundation

@main
enum ClawGatewayEventFixture {
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

            let artifacts = artifacts(for: action, index: index)
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

            let status = resultStatus(for: action)
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

    private static func resultStatus(for action: ClawMobileAction) -> ClawGatewayActionResultStatus {
        if action.approval == .blocked {
            return .skipped
        }

        switch action.kind {
        case .runShellCommand:
            return .failed
        case .operateDesktopApp, .composeMessage, .composeEmail:
            return .waitingForApproval
        case .blockedUnsupported:
            return .skipped
        case .analyzeLocalContext, .requestPermission, .runAgentLoop, .observeScreen, .controlBrowser, .manageFiles, .extractData, .readContacts, .createReminder, .scheduleNotification, .openExternalURL, .runShortcut, .speechCapture, .backgroundRefresh, .desktopHandoff, .auditLog:
            return .succeeded
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
        index: Int
    ) -> [ClawGatewayArtifact] {
        let suffix = index + 1
        switch action.kind {
        case .runAgentLoop:
            return [artifact(.agentTrace, "fixture-agent-loop-\(suffix).json", redacted: true)]
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
            "browserControlRequested": "true",
            "openInBrowser": "true",
            "targetURLPresent": "true",
            "searchQueryPresent": "true",
            "localHTMLInput": "false",
            "networkFetchAttempted": "false",
            "networkBlocked": "false",
            "appAllowlistEnforced": "false",
            "hostAllowlistEnforced": "false",
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

    var description: String {
        switch self {
        case .missingInput:
            return "missing envelope input"
        case .unsupportedSchema(let schema):
            return "unsupported schema: \(schema)"
        case .encodingFailed:
            return "failed to encode event line"
        }
    }
}
