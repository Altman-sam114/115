#!/usr/bin/env node
import { spawn } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import net from "node:net";

const port = Number(process.env.CLAW_GATEWAY_SMOKE_PORT || 18879);
const token = "smoke-token";
const host = "127.0.0.1";

const server = spawn(
  process.execPath,
  ["Tools/claw-gateway-server.mjs", "--once"],
  {
    env: {
      ...process.env,
      ...gatewayPolicyDefaults(),
      CLAW_GATEWAY_HOST: host,
      CLAW_GATEWAY_PORT: String(port),
      CLAW_GATEWAY_TOKEN: token,
    },
    stdio: ["ignore", "pipe", "pipe"],
  },
);

let serverOutput = "";
server.stdout.on("data", (chunk) => {
  serverOutput += chunk.toString("utf8");
});
server.stderr.on("data", (chunk) => {
  serverOutput += chunk.toString("utf8");
});

await waitFor(() => serverOutput.includes("Claw Gateway listening"), 3000);

const envelope = makeEnvelope(token);
const events = await connectAndCollectEvents({
  host,
  port,
  token,
  envelope,
});

server.kill();

expect(events.some((event) => event.kind === "gatewayConnected"), "missing gatewayConnected event");
expect(events.some((event) => event.kind === "actionCompleted"), "missing actionCompleted event");
expect(events.some((event) => event.kind === "actionFailed"), "missing shell policy failure event");
expect(events.some((event) => event.kind === "sessionCompleted"), "missing sessionCompleted event");
expect(events.some((event) => event.artifacts?.some((artifact) => artifact.kind === "browserTrace")), "missing browserTrace artifact");
expect(events.some((event) => event.artifacts?.some((artifact) => artifact.kind === "fileDiff")), "missing fileDiff artifact");
expect(events.some((event) => event.artifacts?.some((artifact) => artifact.kind === "commandOutput")), "missing commandOutput artifact");
expect(events.some((event) => event.artifacts?.some((artifact) => artifact.kind === "agentTrace")), "missing agentTrace artifact");
expect(events.some((event) => event.artifacts?.some((artifact) => artifact.kind === "messageDraft")), "missing messageDraft artifact");

for (const artifact of events.flatMap((event) => event.artifacts || [])) {
  if (artifact.reference?.startsWith("file://")) {
    await fs.access(new URL(artifact.reference));
  }
}

const fileDiffArtifact = findArtifactByTitle(events, "fileDiff", "file-diff-2");
assertFileChangeSafetyMetadata(fileDiffArtifact?.metadata, {
  mode: "workspace-write",
  actionKind: "manageFiles",
  workspacePolicy: "session-workspace-only",
  workspaceScoped: true,
  pathEscapeBlocked: false,
  writeAttempted: true,
  writeSucceeded: true,
  createdFileCount: 1,
  modifiedFileCount: 0,
  deletedFileCount: 0,
  requestedPathPresent: true,
  writeTextPresent: true,
  rawPathOmitted: true,
  contentOmitted: true,
  diffOmitted: true,
  resultStatus: "succeeded",
  safetyFlags: ["metadata-only", "tool-arguments-omitted", "raw-path-omitted", "workspace-path-omitted", "file-content-omitted", "diff-content-omitted", "artifact-payload-not-read", "session-workspace-only"],
}, "websocket file change");
const pathEscapeArtifact = findArtifactByTitle(events, "auditLog", "file-change-blocked-3");
assertFileChangeSafetyMetadata(pathEscapeArtifact?.metadata, {
  mode: "workspace-path-blocked",
  actionKind: "manageFiles",
  workspacePolicy: "session-workspace-only",
  workspaceScoped: false,
  pathEscapeBlocked: true,
  writeAttempted: false,
  writeSucceeded: false,
  createdFileCount: 0,
  modifiedFileCount: 0,
  deletedFileCount: 0,
  requestedPathPresent: true,
  writeTextPresent: true,
  rawPathOmitted: true,
  contentOmitted: true,
  diffOmitted: true,
  resultStatus: "failed",
  safetyFlags: ["metadata-only", "tool-arguments-omitted", "raw-path-omitted", "workspace-path-omitted", "file-content-omitted", "diff-content-omitted", "artifact-payload-not-read", "session-workspace-only", "path-escape-blocked", "no-file-written"],
}, "websocket path escape file change");
const writeFailureArtifact = findArtifactByTitle(events, "auditLog", "file-change-failed-5");
assertFileChangeSafetyMetadata(writeFailureArtifact?.metadata, {
  mode: "workspace-write-failed",
  actionKind: "manageFiles",
  workspacePolicy: "session-workspace-only",
  workspaceScoped: true,
  pathEscapeBlocked: false,
  writeAttempted: true,
  writeSucceeded: false,
  createdFileCount: 0,
  modifiedFileCount: 0,
  deletedFileCount: 0,
  requestedPathPresent: true,
  writeTextPresent: true,
  rawPathOmitted: true,
  contentOmitted: true,
  diffOmitted: true,
  resultStatus: "failed",
  safetyFlags: ["metadata-only", "tool-arguments-omitted", "raw-path-omitted", "workspace-path-omitted", "file-content-omitted", "diff-content-omitted", "artifact-payload-not-read", "session-workspace-only", "write-failed"],
}, "websocket write failure file change");

const capabilitySnapshot = await assertCapabilitySnapshot(events, {
  allowedActionKinds: envelope.gateway.allowedActionKinds,
  capabilities: {
    workspace: "workspace-only",
    shell: "dry-run",
    browserNetwork: "disabled",
    browserControl: "dry-run",
    screenCapture: "dry-run",
    windowMetadata: "dry-run",
    accessibilityTree: "dry-run",
    desktopControl: "dry-run",
  },
});
expect(capabilitySnapshot.envelope.allowedActionKinds.includes("controlBrowser"), "websocket snapshot missing controlBrowser allowlist");
expect(!capabilitySnapshot.envelope.allowedActionKinds.includes("observeScreen"), "websocket snapshot should match envelope allowlist exactly");
const shellPolicyArtifact = findArtifactByTitle(events, "commandOutput", "shell-policy-");
assertShellCommandSafetyMetadata(shellPolicyArtifact?.metadata, {
  mode: "shell-policy-blocked",
  actionKind: "runShellCommand",
  shellPolicy: "dry-run",
  structuredCommandPresent: true,
  commandParsed: true,
  allowlistConfigured: false,
  allowlistMatched: false,
  executionAttempted: false,
  executed: false,
  timedOut: false,
  exitCodePresent: false,
  exitCodeZero: false,
  stdoutPresent: false,
  stderrPresent: false,
  resultStatus: "failed",
  safetyFlags: ["metadata-only", "structured-arguments-only", "tool-arguments-omitted", "command-omitted", "stdout-omitted", "stderr-omitted", "cwd-omitted", "shell-allowlist-enforced", "dry-run-only", "no-command-executed", "artifact-payload-not-read"],
}, "websocket shell policy");

const browserTraces = await readArtifacts(events, "browserTrace");
const pageTrace = browserTraces.find((trace) => trace.mode === "local-html");
expect(pageTrace?.title === "Gateway Smoke Page", "missing websocket browser title extraction");
expect(pageTrace?.tables?.some((table) => table.rows?.some((row) => row.includes("Gateway"))), "missing websocket browser table extraction");
expect(pageTrace?.forms?.some((form) => form.fields?.some((field) => field.name === "query")), "missing websocket browser form extraction");
const pageTraceArtifact = findArtifactByTitle(events, "browserTrace", "browser-trace-1");
assertBrowserControlReviewMetadata(pageTraceArtifact?.metadata, {
  mode: "browser-control-not-requested",
  browserControlPolicy: "not-requested",
  browserControlRequested: false,
  openInBrowser: false,
  targetURLPresent: false,
  searchQueryPresent: false,
  localHTMLInput: true,
  networkFetchAttempted: false,
  networkBlocked: false,
  appAllowlistEnforced: false,
  hostAllowlistEnforced: false,
  executed: false,
  timedOut: false,
  resultStatus: "skipped",
  safetyFlags: ["metadata-only", "tool-arguments-omitted", "url-omitted", "search-query-omitted", "page-content-omitted", "form-fields-omitted", "candidate-labels-omitted", "artifact-payload-not-read"],
}, "websocket browser trace");
const pageControlArtifact = findArtifactByTitle(events, "screenshot", "browser-control-1");
assertBrowserControlReviewMetadata(pageControlArtifact?.metadata, {
  mode: "browser-control-not-requested",
  browserControlPolicy: "not-requested",
  browserControlRequested: false,
  openInBrowser: false,
  targetURLPresent: false,
  searchQueryPresent: false,
  localHTMLInput: true,
  networkFetchAttempted: false,
  networkBlocked: false,
  appAllowlistEnforced: false,
  hostAllowlistEnforced: false,
  executed: false,
  timedOut: false,
  resultStatus: "skipped",
  safetyFlags: ["metadata-only", "tool-arguments-omitted", "url-omitted", "search-query-omitted", "page-content-omitted", "form-fields-omitted", "candidate-labels-omitted", "artifact-payload-not-read"],
}, "websocket browser control");
const extractedTrace = browserTraces.find((trace) => trace.mode === "artifact-grounded-extraction");
expect(Boolean(extractedTrace), "missing websocket artifact-grounded extraction");
expect(extractedTrace?.sourceArtifacts?.browserTraceCount >= 1, "websocket extraction did not consume browser trace");
expect(extractedTrace?.sourceArtifacts?.fileDiffCount >= 1, "websocket extraction did not consume file diff");
expect(extractedTrace?.sourceArtifacts?.commandOutputCount >= 1, "websocket extraction did not consume command output");
expect(extractedTrace?.rows?.some((row) => row.title === "Gateway Smoke Page"), "websocket extraction missing page row");
const extractionArtifact = findArtifactByTitle(events, "browserTrace", "extracted-data-");
assertExtractionCompletenessMetadata(extractionArtifact?.metadata, extractedTrace, "websocket extraction");
const agentTraces = await readArtifacts(events, "agentTrace");
const agentTrace = agentTraces.find((trace) => trace.mode === "agent-loop-trace");
expect(Boolean(agentTrace), "missing websocket agent loop trace");
const agentTraceArtifact = findArtifact(events, "agentTrace");
assertAgentTraceMetadata(agentTraceArtifact?.metadata, agentTrace, "websocket agent loop");
expect(agentTrace?.sourceArtifacts?.browserTraceCount >= 1, "websocket agent loop did not consume browser trace");
expect(agentTrace?.sourceArtifacts?.fileDiffCount >= 1, "websocket agent loop did not consume file diff");
expect(agentTrace?.sourceArtifacts?.commandOutputCount >= 1, "websocket agent loop did not consume command output");
expect(agentTrace?.nextActions?.some((action) => action.kind === "composeMessage"), "websocket agent loop should propose a delivery draft");
expect(typeof agentTrace?.readiness?.score === "number", "websocket agent loop readiness score should be numeric");
expect(agentTrace?.readiness?.satisfiedSignals?.includes("browserTrace"), "websocket agent loop should satisfy browser trace signal");
expect(agentTrace?.readiness?.satisfiedSignals?.includes("fileDiff"), "websocket agent loop should satisfy file diff signal");
expect(agentTrace?.readiness?.satisfiedSignals?.includes("commandOutput"), "websocket agent loop should satisfy command output signal");
expect(agentTrace?.readiness?.missingSignals?.includes("messageDraft"), "websocket agent loop should flag missing draft signal");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "browserTrace" && item.status === "satisfied"), "websocket agent loop checklist missing browser trace");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "fileDiff" && item.status === "satisfied"), "websocket agent loop checklist missing file diff");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "commandOutput" && item.status === "satisfied"), "websocket agent loop checklist missing command output");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "messageDraft" && item.status === "missing"), "websocket agent loop checklist missing draft gap");
expect(agentTrace?.nextActions?.some((action) => action.kind === agentTrace?.selectedNextAction?.kind), "websocket selected action should come from nextActions");
expect(agentTrace?.riskTags?.includes("approval-required"), "websocket agent loop should tag approval-gated actions");
expect(agentTrace?.riskTags?.includes("final-submit-gate") || agentTrace?.stopReason === "final-submit", "websocket agent loop should stop before final delivery");
expect(typeof agentTrace?.handoffSummary === "string" && agentTrace.handoffSummary.includes(agentTrace.selectedNextAction.kind), "websocket agent loop handoff summary should name selected action");
const messageDraftArtifact = findArtifactByTitle(events, "messageDraft", "message-draft-");
assertDeliverySafetyMetadata(messageDraftArtifact?.metadata, {
  mode: "message-draft-pending-approval",
  actionKind: "composeMessage",
  targetKind: "message",
  finalSubmitRequiresApproval: true,
  userApprovalRequired: true,
  draftBodyOmitted: true,
  pasteTextOmitted: false,
  submitBlocked: true,
  allowedKeyCount: 0,
  blockedKeyCount: 0,
  blockedSubmitKeyCount: 0,
  safetyFlags: ["metadata-only", "final-submit-gated", "user-approval-required", "tool-arguments-omitted", "artifact-payload-not-read", "draft-body-omitted"],
}, "websocket message draft delivery safety");

const replayPort = port + 1;
const replayServer = spawn(
  process.execPath,
  ["Tools/claw-gateway-server.mjs"],
  {
    env: {
      ...process.env,
      ...gatewayPolicyDefaults(),
      CLAW_GATEWAY_HOST: host,
      CLAW_GATEWAY_PORT: String(replayPort),
      CLAW_GATEWAY_TOKEN: token,
      CLAW_WORKSPACE: ".build/claw-gateway-websocket-replay",
    },
    stdio: ["ignore", "pipe", "pipe"],
  },
);

let replayServerOutput = "";
replayServer.stdout.on("data", (chunk) => {
  replayServerOutput += chunk.toString("utf8");
});
replayServer.stderr.on("data", (chunk) => {
  replayServerOutput += chunk.toString("utf8");
});

await waitFor(
  () => replayServerOutput.includes("Claw Gateway listening"),
  3000,
  () => replayServerOutput,
);

const replayEnvelope = makeEnvelope(token, replayPort);
let firstReplayEvents = [];
let replayGuardEvents = [];
try {
  firstReplayEvents = await connectAndCollectEvents({
    host,
    port: replayPort,
    token,
    envelope: replayEnvelope,
  });
  replayGuardEvents = await connectAndCollectEvents({
    host,
    port: replayPort,
    token,
    envelope: replayEnvelope,
  });
} finally {
  replayServer.kill();
}

expect(firstReplayEvents.some((event) => hasArtifact(event, "browserTrace")), "websocket replay first session should still run browser trace");
expect(firstReplayEvents.some((event) => event.kind === "actionStarted"), "websocket replay first session missing actionStarted");
expect(replayGuardEvents[0]?.sessionID !== firstReplayEvents[0]?.sessionID, "websocket replay guard should use a replay session");
await assertTaskReplayGuard(replayGuardEvents, replayEnvelope, token, "websocket replay guard");

console.log(`Claw Gateway smoke passed (${events.length + firstReplayEvents.length + replayGuardEvents.length} events)`);

function makeEnvelope(rawToken, endpointPort = port) {
  const taskID = crypto.randomUUID();
  return {
    schemaVersion: "claw.computer.control.v1",
    sourceApp: "Claw Controller",
    gateway: {
      endpoint: `ws://${host}:${endpointPort}`,
      deviceName: "smoke",
      securityMode: "mutualApproval",
      tokenFingerprint: tokenFingerprint(rawToken),
      allowedActionKinds: ["controlBrowser", "manageFiles", "runShellCommand", "extractData", "runAgentLoop", "composeMessage"],
      requiresApprovalForSensitiveData: true,
      auditEnabled: true,
    },
    task: {
      id: taskID,
      command: "open browser and collect data",
      summary: "smoke",
      sourceDevice: "smoke",
      destinationGateway: `ws://${host}:${endpointPort}`,
      actions: [
        {
          id: crypto.randomUUID(),
          kind: "controlBrowser",
          title: "Control browser",
          target: "Desktop Browser",
          instruction: "Open a page and extract structured data",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            browserGoal: "collect smoke data",
            captureTrace: "true",
            html: [
              "<html><head><title>Gateway Smoke Page</title></head><body>",
              "<h1>Gateway Heading</h1>",
              "<main>Browser trace is available to extraction.</main>",
              "<table><tr><th>Tool</th><th>Status</th></tr><tr><td>Gateway</td><td>Ready</td></tr></table>",
              "<form action=\"/search\"><input name=\"query\" placeholder=\"Search\"></form>",
              "</body></html>",
            ].join(""),
          },
        },
        {
          id: crypto.randomUUID(),
          kind: "manageFiles",
          title: "Manage workspace files",
          target: "Desktop Filesystem",
          instruction: "Create a dry-run file diff in the workspace",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            workspaceOnly: "true",
            writePath: "smoke/result.txt",
            writeText: "websocket workspace write verified",
          },
        },
        {
          id: crypto.randomUUID(),
          kind: "manageFiles",
          title: "Block path escape",
          target: "Desktop Filesystem",
          instruction: "Reject file writes outside the session workspace",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            workspaceOnly: "true",
            writePath: "../escape.txt",
            writeText: "websocket escape write",
          },
        },
        {
          id: crypto.randomUUID(),
          kind: "manageFiles",
          title: "Prepare blocked parent",
          target: "Desktop Filesystem",
          instruction: "Create a workspace file that will block a nested write",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            workspaceOnly: "true",
            writePath: "blocked-parent",
            writeText: "not a directory",
          },
        },
        {
          id: crypto.randomUUID(),
          kind: "manageFiles",
          title: "Trigger write failure",
          target: "Desktop Filesystem",
          instruction: "Attempt a nested write through an existing file",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            workspaceOnly: "true",
            writePath: "blocked-parent/result.txt",
            writeText: "should not be written",
          },
        },
        {
          id: crypto.randomUUID(),
          kind: "runShellCommand",
          title: "Run shell dry-run",
          target: "Desktop Shell",
          instruction: "Run a structured command only if policy allows it",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            shellCommand: "pwd",
            cwdPolicy: "workspaceOnly",
          },
        },
        {
          id: crypto.randomUUID(),
          kind: "extractData",
          title: "Extract structured result",
          target: "Desktop Data",
          instruction: "Extract data from browser and workspace artifacts",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            extractionGoal: "collect websocket smoke rows",
            sourcePriority: "browserTrace,fileDiff,commandOutput",
            outputPath: "smoke/extracted.json",
            validateCompleteness: "true",
          },
        },
        {
          id: crypto.randomUUID(),
          kind: "runAgentLoop",
          title: "Run agent loop",
          target: "Desktop Agent Loop",
          instruction: "Review websocket smoke artifacts and decide the next safe action",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            objective: "finish websocket smoke task with artifact-backed decisions",
            loopMode: "observe-plan-act-verify",
            maxIterations: "3",
            inputSources: "browserTrace,fileDiff,commandOutput,messageDraft",
            allowedNextActions: "controlBrowser,manageFiles,extractData,composeMessage",
            approvalRequiredFor: "externalNetwork,destructiveFileChange",
            stopBeforeDestructiveAction: "true",
            writeTrace: "true",
          },
        },
        {
          id: crypto.randomUUID(),
          kind: "composeMessage",
          title: "Draft websocket follow-up",
          target: "Slack",
          instruction: "Create a delivery draft and wait for confirmation",
          approval: "gatewayApproval",
          sourceSurface: "composeController",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            channel: "Slack",
            recipient: "reviewer",
            body: "Gateway smoke summary ready for Slack approval.",
          },
        },
      ],
      status: "sent",
      riskScore: 36,
      createdAt: isoNow(),
    },
    approvalSummary: "smoke",
    auditRequired: true,
  };
}

async function readArtifacts(events, kind) {
  const artifacts = events
    .flatMap((event) => event.artifacts || [])
    .filter((artifact) => artifact.kind === kind && artifact.reference?.startsWith("file://"));
  const parsed = [];
  for (const artifact of artifacts) {
    parsed.push(JSON.parse(await fs.readFile(new URL(artifact.reference), "utf8")));
  }
  return parsed;
}

function findArtifact(events, kind) {
  return events
    .flatMap((event) => event.artifacts || [])
    .find((artifact) => artifact.kind === kind);
}

function findArtifactByTitle(events, kind, titlePrefix) {
  return events
    .flatMap((event) => event.artifacts || [])
    .find((artifact) => artifact.kind === kind && artifact.title?.startsWith(titlePrefix));
}

function hasArtifact(event, kind) {
  return event.artifacts?.some((artifact) => artifact.kind === kind);
}

async function assertTaskReplayGuard(events, replayEnvelope, rawToken, label) {
  expect(Array.isArray(events) && events.length > 0, `${label} missing events`);
  const allowedEventKinds = new Set(["gatewayConnected", "artifactStored", "actionSkipped", "sessionCompleted"]);
  expect(events.every((event) => allowedEventKinds.has(event.kind)), `${label} emitted unexpected event kind`);
  expect(!events.some((event) => event.kind === "actionStarted"), `${label} should not start actions`);
  const skippedEvents = events.filter((event) => event.kind === "actionSkipped");
  expect(skippedEvents.length === replayEnvelope.task.actions.length, `${label} actionSkipped count mismatch`);
  for (const skipped of skippedEvents) {
    const action = replayEnvelope.task.actions.find((candidate) => candidate.id === skipped.actionID);
    expect(Boolean(action), `${label} actionSkipped should keep action id`);
    expect(skipped.actionKind === action.kind, `${label} actionSkipped should keep action kind`);
    expect(skipped.actionTitle === action.title, `${label} actionSkipped should keep action title`);
    expect(skipped.resultStatus === "skipped", `${label} actionSkipped should be skipped`);
    expect(skipped.isRetryable === false, `${label} actionSkipped should not be retryable`);
  }
  const businessKinds = new Set([
    "accessibilityTree",
    "agentTrace",
    "browserTrace",
    "commandOutput",
    "fileDiff",
    "messageDraft",
    "screenshot",
  ]);
  const artifacts = events.flatMap((event) => event.artifacts || []);
  expect(!artifacts.some((artifact) => businessKinds.has(artifact.kind)), `${label} wrote business artifact`);
  const replayArtifact = artifacts.find(isTaskReplayGuardArtifact);
  expect(Boolean(replayArtifact), `${label} missing replay audit artifact`);
  expect(replayArtifact.isRedacted === true, `${label} replay audit should be redacted`);
  const audit = JSON.parse(await fs.readFile(new URL(replayArtifact.reference), "utf8"));
  assertTaskReplayGuardMetadata(replayArtifact.metadata, audit, label);
  expect(audit.mode === "gateway-task-replay-guard", `${label} audit mode mismatch`);
  expect(audit.decision === "skip-duplicate-task", `${label} audit decision mismatch`);
  expect(audit.task?.id === replayEnvelope.task.id, `${label} task id mismatch`);
  expect(audit.task?.actionCount === replayEnvelope.task.actions.length, `${label} action count mismatch`);
  expect(audit.replay?.count === 1, `${label} replay count mismatch`);
  expect(audit.safety?.businessArtifacts === "not-written", `${label} should not write business artifacts`);
  expect(audit.safety?.handlerExecution === "blocked", `${label} should block handler execution`);
  const serialized = JSON.stringify({ audit, metadata: replayArtifact.metadata });
  for (const forbidden of [
    rawToken,
    "Authorization",
    "Bearer",
    "toolArguments",
    "shellCommand",
    "Open a page and extract structured data",
    "Gateway Smoke Page",
    "websocket workspace write verified",
    "/sessions/",
  ]) {
    expect(!serialized.includes(forbidden), `${label} leaked ${forbidden}`);
  }
}

function isTaskReplayGuardArtifact(artifact) {
  return artifact.kind === "auditLog" && artifact.title === "task-replay-guard.json" && artifact.reference?.startsWith("file://");
}

function assertTaskReplayGuardMetadata(metadata, audit, label) {
  expect(metadata && typeof metadata === "object", `${label} missing metadata`);
  const allowedKeys = [
    "actionCount",
    "actionKinds",
    "decision",
    "digestMatchesFirst",
    "firstSessionID",
    "originalStatus",
    "replayCount",
    "replayDigest",
    "replayGuard",
    "safetyFlags",
    "taskID",
  ];
  expect(
    Object.keys(metadata).sort().join(",") === allowedKeys.join(","),
    `${label} metadata includes unexpected keys`,
  );
  for (const [key, value] of Object.entries(metadata)) {
    expect(typeof value === "string", `${label} metadata ${key} should be a string`);
  }
  expect(metadata.replayGuard === "taskReplayGuard", `${label} replayGuard metadata mismatch`);
  expect(metadata.decision === audit.decision, `${label} decision metadata mismatch`);
  expect(metadata.taskID === audit.task.id, `${label} task metadata mismatch`);
  expect(metadata.replayDigest === audit.task.replayDigest, `${label} digest metadata mismatch`);
  expect(metadata.digestMatchesFirst === String(audit.task.digestMatchesFirst), `${label} digest match metadata mismatch`);
  expect(metadata.firstSessionID === audit.sessions.firstSessionID, `${label} first session metadata mismatch`);
  expect(metadata.originalStatus === audit.firstRun.status, `${label} status metadata mismatch`);
  expect(metadata.replayCount === String(audit.replay.count), `${label} replay count metadata mismatch`);
  expect(metadata.actionCount === String(audit.task.actionCount), `${label} action count metadata mismatch`);
  expect(metadata.actionKinds === audit.task.actionKinds.join(","), `${label} action kinds metadata mismatch`);
  expect(
    metadata.safetyFlags === "process-local,actions-skipped,business-artifacts-not-written,credentials-omitted,structured-arguments-omitted",
    `${label} safety flags metadata mismatch`,
  );
}

async function assertCapabilitySnapshot(events, expected = {}) {
  const snapshotEventIndex = events.findIndex((event) =>
    event.kind === "artifactStored" && event.artifacts?.some(isCapabilitySnapshotArtifact)
  );
  const connectedIndex = events.findIndex((event) => event.kind === "gatewayConnected");
  const firstActionIndex = events.findIndex((event) => event.kind === "actionStarted");
  expect(connectedIndex >= 0, "websocket capability snapshot order check missing gatewayConnected");
  expect(snapshotEventIndex > connectedIndex, "websocket capability snapshot must follow gatewayConnected");
  expect(firstActionIndex > snapshotEventIndex, "websocket capability snapshot must precede first actionStarted");
  const snapshotArtifact = events[snapshotEventIndex].artifacts.find(isCapabilitySnapshotArtifact);
  expect(snapshotArtifact.isRedacted === true, "websocket capability snapshot artifact should be redacted");
  const snapshot = JSON.parse(await fs.readFile(new URL(snapshotArtifact.reference), "utf8"));
  assertCapabilitySnapshotMetadata(snapshotArtifact.metadata, snapshot, "websocket capability snapshot");
  expect(snapshot.mode === "gateway-capability-snapshot", "websocket capability snapshot mode mismatch");
  expect(!JSON.stringify(snapshot).includes(token), "websocket capability snapshot leaked raw token");
  expect(snapshot.token.configured === true, "websocket capability snapshot token should be configured");
  expect(snapshot.token.fingerprint === tokenFingerprint(token), "websocket capability snapshot token fingerprint mismatch");
  expect(snapshot.envelope.tokenFingerprint === tokenFingerprint(token), "websocket capability snapshot envelope fingerprint mismatch");
  expect(
    snapshot.envelope.allowedActionKinds.join(",") === [...expected.allowedActionKinds].sort().join(","),
    "websocket capability snapshot allowedActionKinds mismatch",
  );
  expect(snapshot.envelope.actionCount === envelope.task.actions.length, "websocket capability snapshot action count mismatch");
  expect(snapshot.gateway.platform === process.platform, "websocket capability snapshot platform mismatch");
  expect(snapshot.gateway.sessionWorkspace.startsWith(`${snapshot.gateway.workspaceRoot}/sessions/`), "websocket capability snapshot workspace is not session-scoped");
  expect(snapshot.policies.workspace.sessionWorkspace === snapshot.gateway.sessionWorkspace, "websocket capability snapshot workspace policy mismatch");
  expect(snapshot.safety.rawToken === "omitted", "websocket capability snapshot should omit raw token");
  expect(snapshot.safety.toolArguments === "omitted", "websocket capability snapshot should omit toolArguments");
  for (const [capability, state] of Object.entries(expected.capabilities || {})) {
    expect(snapshot.capabilities?.[capability]?.state === state, `websocket capability snapshot ${capability} state mismatch`);
  }
  return snapshot;
}

function isCapabilitySnapshotArtifact(artifact) {
  return artifact.kind === "auditLog" && artifact.title === "gateway-capability-snapshot.json" && artifact.reference?.startsWith("file://");
}

function assertCapabilitySnapshotMetadata(metadata, snapshot, label) {
  expect(metadata && typeof metadata === "object", `${label} missing metadata`);
  const allowedKeys = [
    "accessibilityTreeState",
    "allowedActionKinds",
    "browserControlState",
    "browserNetworkState",
    "desktopControlState",
    "platform",
    "safetyFlags",
    "screenCaptureState",
    "shellState",
    "snapshotKind",
    "tokenConfigured",
    "tokenFingerprint",
    "tokenRequired",
    "windowMetadataState",
    "workspaceState",
  ];
  expect(
    Object.keys(metadata).sort().join(",") === allowedKeys.join(","),
    `${label} metadata includes unexpected keys`,
  );
  expect(metadata.snapshotKind === "gatewayCapability", `${label} metadata kind mismatch`);
  expect(metadata.tokenConfigured === String(snapshot.token.configured), `${label} tokenConfigured mismatch`);
  expect(metadata.tokenRequired === String(snapshot.token.required), `${label} tokenRequired mismatch`);
  expect(metadata.tokenFingerprint === snapshot.token.fingerprint, `${label} tokenFingerprint mismatch`);
  expect(metadata.allowedActionKinds === snapshot.envelope.allowedActionKinds.join(","), `${label} allowedActionKinds mismatch`);
  expect(metadata.workspaceState === snapshot.capabilities.workspace.state, `${label} workspace state mismatch`);
  expect(metadata.shellState === snapshot.capabilities.shell.state, `${label} shell state mismatch`);
  expect(metadata.browserControlState === snapshot.capabilities.browserControl.state, `${label} browser control state mismatch`);
  expect(metadata.browserNetworkState === snapshot.capabilities.browserNetwork.state, `${label} browser network state mismatch`);
  expect(metadata.screenCaptureState === snapshot.capabilities.screenCapture.state, `${label} screen capture state mismatch`);
  expect(metadata.windowMetadataState === snapshot.capabilities.windowMetadata.state, `${label} window metadata state mismatch`);
  expect(metadata.accessibilityTreeState === snapshot.capabilities.accessibilityTree.state, `${label} accessibility tree state mismatch`);
  expect(metadata.desktopControlState === snapshot.capabilities.desktopControl.state, `${label} desktop control state mismatch`);
  expect(metadata.platform === snapshot.gateway.platform, `${label} platform mismatch`);
  expect(metadata.safetyFlags === "allowlists-enforced,workspace-only,raw-token-omitted,final-submit-gated", `${label} safety flags mismatch`);
  const serialized = JSON.stringify(metadata);
  for (const forbidden of [token, "Authorization", "toolArguments", "instruction", "commandOutput", "browserPageContent", "screenshotContent", "draftContent", "workspaceRoot", "sessionWorkspace"]) {
    expect(!serialized.includes(forbidden), `${label} metadata leaked ${forbidden}`);
  }
}

function assertAgentTraceMetadata(metadata, trace, label) {
  expect(metadata && typeof metadata === "object", `${label} missing agentTrace metadata`);
  const allowedKeys = [
    "handoffSummary",
    "missingSignals",
    "readinessCanContinue",
    "readinessScore",
    "riskTags",
    "satisfiedSignals",
    "selectedNextActionKind",
    "selectedNextActionRequiresApproval",
    "stopReason",
  ];
  expect(
    Object.keys(metadata).sort().join(",") === allowedKeys.join(","),
    `${label} agentTrace metadata includes unexpected keys`,
  );
  expect(metadata.readinessScore === String(trace.readiness.score), `${label} readiness score metadata mismatch`);
  expect(metadata.readinessCanContinue === String(trace.readiness.canContinue), `${label} readiness continuation metadata mismatch`);
  expect(metadata.satisfiedSignals === trace.readiness.satisfiedSignals.join(","), `${label} satisfied signals metadata mismatch`);
  expect(metadata.missingSignals === trace.readiness.missingSignals.join(","), `${label} missing signals metadata mismatch`);
  expect(metadata.selectedNextActionKind === trace.selectedNextAction.kind, `${label} selected action metadata mismatch`);
  expect(metadata.selectedNextActionRequiresApproval === String(trace.selectedNextAction.requiresApproval), `${label} selected approval metadata mismatch`);
  expect(metadata.riskTags === trace.riskTags.join(","), `${label} risk tags metadata mismatch`);
  expect(metadata.stopReason === trace.stopReason, `${label} stop reason metadata mismatch`);
  expect(metadata.handoffSummary === trace.handoffSummary, `${label} handoff summary metadata mismatch`);
}

function assertExtractionCompletenessMetadata(metadata, extraction, label) {
  expect(metadata && typeof metadata === "object", `${label} missing extraction metadata`);
  const allowedKeys = [
    "accessibilityTreeCount",
    "browserTraceCount",
    "commandOutputCount",
    "completenessStatus",
    "extractionReview",
    "fileDiffCount",
    "messageDraftCount",
    "mode",
    "rowCount",
    "safetyFlags",
    "screenObservationCount",
    "sourceArtifactKinds",
    "validateCompleteness",
  ];
  expect(
    Object.keys(metadata).sort().join(",") === allowedKeys.join(","),
    `${label} extraction metadata includes unexpected keys`,
  );
  expect(metadata.extractionReview === "artifactGrounded", `${label} extraction review metadata mismatch`);
  expect(metadata.mode === extraction.mode, `${label} mode metadata mismatch`);
  expect(metadata.validateCompleteness === String(extraction.validateCompleteness), `${label} completeness validation metadata mismatch`);
  expect(Number(metadata.rowCount) === extraction.rows.length, `${label} row count metadata mismatch`);
  expect(metadata.completenessStatus === "complete", `${label} completeness status mismatch`);
  expect(Number(metadata.browserTraceCount) === extraction.sourceArtifacts.browserTraceCount, `${label} browser trace count metadata mismatch`);
  expect(Number(metadata.fileDiffCount) === extraction.sourceArtifacts.fileDiffCount, `${label} file diff count metadata mismatch`);
  expect(Number(metadata.commandOutputCount) === extraction.sourceArtifacts.commandOutputCount, `${label} command output count metadata mismatch`);
  expect(metadata.sourceArtifactKinds.includes("browserTrace"), `${label} missing browserTrace source kind`);
  expect(metadata.sourceArtifactKinds.includes("fileDiff"), `${label} missing fileDiff source kind`);
  expect(metadata.sourceArtifactKinds.includes("commandOutput"), `${label} missing commandOutput source kind`);
  expect(metadata.safetyFlags.includes("row-content-omitted"), `${label} missing row omission safety flag`);
  const serialized = JSON.stringify(metadata);
  for (const forbidden of [token, "Authorization", "Bearer", "toolArguments", "sourcePriority", "Gateway Smoke Page", "https://", "file://", "/sessions/"]) {
    expect(!serialized.includes(forbidden), `${label} metadata leaked ${forbidden}`);
  }
}

function assertBrowserControlReviewMetadata(metadata, expected, label) {
  expect(metadata && typeof metadata === "object", `${label} missing browser control metadata`);
  const allowedKeys = [
    "actionKind",
    "appAllowlistEnforced",
    "browserControlPolicy",
    "browserControlRequested",
    "browserReview",
    "executed",
    "hostAllowlistEnforced",
    "localHTMLInput",
    "mode",
    "networkBlocked",
    "networkFetchAttempted",
    "openInBrowser",
    "resultStatus",
    "safetyFlags",
    "searchQueryPresent",
    "targetURLPresent",
    "timedOut",
  ];
  expect(
    Object.keys(metadata).sort().join(",") === allowedKeys.join(","),
    `${label} browser control metadata includes unexpected keys`,
  );
  expect(metadata.browserReview === "controlPlan", `${label} browser review metadata mismatch`);
  expect(metadata.mode === expected.mode, `${label} mode metadata mismatch`);
  expect(metadata.actionKind === "controlBrowser", `${label} action kind metadata mismatch`);
  expect(metadata.browserControlPolicy === expected.browserControlPolicy, `${label} browser policy metadata mismatch`);
  expect(metadata.browserControlRequested === String(expected.browserControlRequested), `${label} request metadata mismatch`);
  expect(metadata.openInBrowser === String(expected.openInBrowser), `${label} openInBrowser metadata mismatch`);
  expect(metadata.targetURLPresent === String(expected.targetURLPresent), `${label} URL presence metadata mismatch`);
  expect(metadata.searchQueryPresent === String(expected.searchQueryPresent), `${label} search presence metadata mismatch`);
  expect(metadata.localHTMLInput === String(expected.localHTMLInput), `${label} HTML input metadata mismatch`);
  expect(metadata.networkFetchAttempted === String(expected.networkFetchAttempted), `${label} network fetch metadata mismatch`);
  expect(metadata.networkBlocked === String(expected.networkBlocked), `${label} network block metadata mismatch`);
  expect(metadata.appAllowlistEnforced === String(expected.appAllowlistEnforced), `${label} app allowlist metadata mismatch`);
  expect(metadata.hostAllowlistEnforced === String(expected.hostAllowlistEnforced), `${label} host allowlist metadata mismatch`);
  expect(metadata.executed === String(expected.executed), `${label} executed metadata mismatch`);
  expect(metadata.timedOut === String(expected.timedOut), `${label} timeout metadata mismatch`);
  expect(metadata.resultStatus === expected.resultStatus, `${label} result status metadata mismatch`);
  for (const flag of expected.safetyFlags) {
    expect(metadata.safetyFlags.includes(flag), `${label} missing safety flag ${flag}`);
  }
  const serialized = JSON.stringify(metadata);
  for (const forbidden of [
    token,
    "Authorization",
    "Bearer",
    "toolArguments",
    "Gateway Smoke Page",
    "Browser trace is available",
    "https://",
    "file://",
    "/sessions/",
    "stdout",
    "stderr",
  ]) {
    expect(!serialized.includes(forbidden), `${label} metadata leaked ${forbidden}`);
  }
}

function assertFileChangeSafetyMetadata(metadata, expected, label) {
  expect(metadata && typeof metadata === "object", `${label} missing file change metadata`);
  const allowedKeys = [
    "actionKind",
    "contentOmitted",
    "createdFileCount",
    "deletedFileCount",
    "diffOmitted",
    "fileChangeReview",
    "mode",
    "modifiedFileCount",
    "pathEscapeBlocked",
    "rawPathOmitted",
    "requestedPathPresent",
    "resultStatus",
    "safetyFlags",
    "workspacePolicy",
    "workspaceScoped",
    "writeAttempted",
    "writeSucceeded",
    "writeTextPresent",
  ].sort();
  expect(
    Object.keys(metadata).sort().join(",") === allowedKeys.join(","),
    `${label} file change metadata includes unexpected keys`,
  );
  expect(metadata.fileChangeReview === "workspaceWrite", `${label} file change review metadata mismatch`);
  expect(metadata.mode === expected.mode, `${label} mode metadata mismatch`);
  expect(metadata.actionKind === expected.actionKind, `${label} action kind metadata mismatch`);
  expect(metadata.workspacePolicy === expected.workspacePolicy, `${label} workspace policy metadata mismatch`);
  expect(metadata.workspaceScoped === String(expected.workspaceScoped), `${label} workspace scope metadata mismatch`);
  expect(metadata.pathEscapeBlocked === String(expected.pathEscapeBlocked), `${label} path escape metadata mismatch`);
  expect(metadata.writeAttempted === String(expected.writeAttempted), `${label} write attempt metadata mismatch`);
  expect(metadata.writeSucceeded === String(expected.writeSucceeded), `${label} write success metadata mismatch`);
  expect(Number(metadata.createdFileCount) === expected.createdFileCount, `${label} created count metadata mismatch`);
  expect(Number(metadata.modifiedFileCount) === expected.modifiedFileCount, `${label} modified count metadata mismatch`);
  expect(Number(metadata.deletedFileCount) === expected.deletedFileCount, `${label} deleted count metadata mismatch`);
  expect(metadata.requestedPathPresent === String(expected.requestedPathPresent), `${label} requested path presence metadata mismatch`);
  expect(metadata.writeTextPresent === String(expected.writeTextPresent), `${label} write text presence metadata mismatch`);
  expect(metadata.rawPathOmitted === String(expected.rawPathOmitted), `${label} raw path omission metadata mismatch`);
  expect(metadata.contentOmitted === String(expected.contentOmitted), `${label} content omission metadata mismatch`);
  expect(metadata.diffOmitted === String(expected.diffOmitted), `${label} diff omission metadata mismatch`);
  expect(metadata.resultStatus === expected.resultStatus, `${label} result status metadata mismatch`);
  for (const flag of expected.safetyFlags) {
    expect(metadata.safetyFlags.includes(flag), `${label} missing safety flag ${flag}`);
  }
  const serialized = JSON.stringify(metadata);
  for (const forbidden of [
    token,
    "Authorization",
    "Bearer",
    "toolArguments",
    "writePath",
    "\"requestedPath\"",
    "websocket workspace write verified",
	    "smoke/result.txt",
	    "../escape.txt",
	    "websocket escape write",
	    "blocked-parent",
	    "should not be written",
	    "not a directory",
	    "patch",
    "@@",
    "diffHunk",
    "https://",
    "file://",
    "/sessions/",
    "stdout",
    "stderr",
  ]) {
    expect(!serialized.includes(forbidden), `${label} metadata leaked ${forbidden}`);
  }
}

function assertShellCommandSafetyMetadata(metadata, expected, label) {
  expect(metadata && typeof metadata === "object", `${label} missing shell safety metadata`);
  const allowedKeys = [
    "actionKind",
    "allowlistConfigured",
    "allowlistMatched",
    "commandOmitted",
    "commandParsed",
    "cwdOmitted",
    "executed",
    "executionAttempted",
    "exitCodePresent",
    "exitCodeZero",
    "mode",
    "resultStatus",
    "safetyFlags",
    "shellPolicy",
    "shellReview",
    "stderrOmitted",
    "stderrPresent",
    "stdoutOmitted",
    "stdoutPresent",
    "structuredCommandPresent",
    "timedOut",
  ].sort();
  expect(
    Object.keys(metadata).sort().join(",") === allowedKeys.join(","),
    `${label} shell safety metadata includes unexpected keys`,
  );
  expect(metadata.shellReview === "commandSafety", `${label} shell review metadata mismatch`);
  expect(metadata.mode === expected.mode, `${label} mode metadata mismatch`);
  expect(metadata.actionKind === expected.actionKind, `${label} action kind metadata mismatch`);
  expect(metadata.shellPolicy === expected.shellPolicy, `${label} shell policy metadata mismatch`);
  expect(metadata.structuredCommandPresent === String(expected.structuredCommandPresent), `${label} structured command metadata mismatch`);
  expect(metadata.commandParsed === String(expected.commandParsed), `${label} command parsed metadata mismatch`);
  expect(metadata.allowlistConfigured === String(expected.allowlistConfigured), `${label} allowlist configured metadata mismatch`);
  expect(metadata.allowlistMatched === String(expected.allowlistMatched), `${label} allowlist matched metadata mismatch`);
  expect(metadata.executionAttempted === String(expected.executionAttempted), `${label} execution attempt metadata mismatch`);
  expect(metadata.executed === String(expected.executed), `${label} executed metadata mismatch`);
  expect(metadata.timedOut === String(expected.timedOut), `${label} timeout metadata mismatch`);
  expect(metadata.exitCodePresent === String(expected.exitCodePresent), `${label} exit code presence metadata mismatch`);
  expect(metadata.exitCodeZero === String(expected.exitCodeZero), `${label} exit zero metadata mismatch`);
  expect(metadata.stdoutPresent === String(expected.stdoutPresent), `${label} stdout presence metadata mismatch`);
  expect(metadata.stderrPresent === String(expected.stderrPresent), `${label} stderr presence metadata mismatch`);
  expect(metadata.commandOmitted === "true", `${label} command omission metadata mismatch`);
  expect(metadata.stdoutOmitted === "true", `${label} stdout omission metadata mismatch`);
  expect(metadata.stderrOmitted === "true", `${label} stderr omission metadata mismatch`);
  expect(metadata.cwdOmitted === "true", `${label} cwd omission metadata mismatch`);
  expect(metadata.resultStatus === expected.resultStatus, `${label} result status metadata mismatch`);
  for (const flag of expected.safetyFlags) {
    expect(metadata.safetyFlags.includes(flag), `${label} missing safety flag ${flag}`);
  }
  const serialized = JSON.stringify(metadata);
  for (const forbidden of [
    token,
    "Authorization",
    "Bearer",
    "toolArguments",
    "shellCommand",
    "pwd",
    "Command:",
    "Allowlist:",
    "Run a structured command only if policy allows it",
    "https://",
    "file://",
    "/sessions/",
    ".build/claw-gateway-workspace",
  ]) {
    expect(!serialized.includes(forbidden), `${label} metadata leaked ${forbidden}`);
  }
}

function assertDeliverySafetyMetadata(metadata, expected, label) {
  expect(metadata && typeof metadata === "object", `${label} missing delivery metadata`);
  const allowedKeys = [
    "actionKind",
    "allowedKeyCount",
    "blockedKeyCount",
    "blockedSubmitKeyCount",
    "deliveryReview",
    "draftBodyOmitted",
    "finalSubmitRequiresApproval",
    "mode",
    "pasteTextOmitted",
    "safetyFlags",
    "submitBlocked",
    "targetKind",
    "userApprovalRequired",
  ];
  expect(
    Object.keys(metadata).sort().join(",") === allowedKeys.join(","),
    `${label} delivery metadata includes unexpected keys`,
  );
  expect(metadata.deliveryReview === "finalSubmitGate", `${label} delivery review metadata mismatch`);
  expect(metadata.mode === expected.mode, `${label} mode metadata mismatch`);
  expect(metadata.actionKind === expected.actionKind, `${label} action kind metadata mismatch`);
  expect(metadata.targetKind === expected.targetKind, `${label} target kind metadata mismatch`);
  expect(metadata.finalSubmitRequiresApproval === String(expected.finalSubmitRequiresApproval), `${label} final submit metadata mismatch`);
  expect(metadata.userApprovalRequired === String(expected.userApprovalRequired), `${label} approval metadata mismatch`);
  expect(metadata.draftBodyOmitted === String(expected.draftBodyOmitted), `${label} draft omission metadata mismatch`);
  expect(metadata.pasteTextOmitted === String(expected.pasteTextOmitted), `${label} paste omission metadata mismatch`);
  expect(metadata.submitBlocked === String(expected.submitBlocked), `${label} submit blocked metadata mismatch`);
  expect(Number(metadata.allowedKeyCount) === expected.allowedKeyCount, `${label} allowed key count mismatch`);
  expect(Number(metadata.blockedKeyCount) === expected.blockedKeyCount, `${label} blocked key count mismatch`);
  expect(Number(metadata.blockedSubmitKeyCount) === expected.blockedSubmitKeyCount, `${label} blocked submit key count mismatch`);
  for (const flag of expected.safetyFlags) {
    expect(metadata.safetyFlags.includes(flag), `${label} missing safety flag ${flag}`);
  }
  const serialized = JSON.stringify(metadata);
  for (const forbidden of [
    token,
    "Authorization",
    "Bearer",
    "toolArguments",
    "draftText",
    "pasteTextPreview",
    "keySequence",
    "Gateway smoke summary ready",
    "https://",
    "file://",
    "/sessions/",
  ]) {
    expect(!serialized.includes(forbidden), `${label} metadata leaked ${forbidden}`);
  }
}

function connectAndCollectEvents({ host, port, token, envelope }) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host, port });
    const key = crypto.randomBytes(16).toString("base64");
    let handshake = "";
    let buffer = Buffer.alloc(0);
    const events = [];

    socket.on("connect", () => {
      socket.write(
        [
          "GET / HTTP/1.1",
          `Host: ${host}:${port}`,
          "Upgrade: websocket",
          "Connection: Upgrade",
          `Sec-WebSocket-Key: ${key}`,
          "Sec-WebSocket-Version: 13",
          "X-Claw-Schema: claw.computer.control.v1",
          `Authorization: Bearer ${token}`,
          "",
          "",
        ].join("\r\n"),
      );
    });

    socket.on("data", (chunk) => {
      if (!handshake.includes("\r\n\r\n")) {
        handshake += chunk.toString("latin1");
        const split = handshake.indexOf("\r\n\r\n");
        if (split === -1) {
          return;
        }
        const head = handshake.slice(0, split);
        if (!head.includes("101 Switching Protocols")) {
          reject(new Error(`upgrade failed: ${head}`));
          socket.destroy();
          return;
        }
        const remainder = Buffer.from(handshake.slice(split + 4), "latin1");
        socket.write(encodeClientFrame(JSON.stringify(envelope)));
        if (remainder.length > 0) {
          consume(remainder);
        }
        return;
      }
      consume(chunk);
    });

    socket.on("error", reject);
    socket.on("close", () => resolve(events));

    function consume(chunk) {
      buffer = Buffer.concat([buffer, chunk]);
      while (buffer.length >= 2) {
        const frame = parseServerFrame(buffer);
        if (!frame) {
          return;
        }
        buffer = buffer.subarray(frame.consumed);
        if (frame.opcode === 0x8) {
          socket.end();
          return;
        }
        if (frame.opcode === 0x1) {
          events.push(JSON.parse(frame.payload.toString("utf8")));
        }
      }
    }
  });
}

function encodeClientFrame(text) {
  const payload = Buffer.from(text, "utf8");
  const mask = crypto.randomBytes(4);
  const length = payload.length;
  let header;
  if (length < 126) {
    header = Buffer.from([0x81, 0x80 | length]);
  } else if (length < 65536) {
    header = Buffer.alloc(4);
    header[0] = 0x81;
    header[1] = 0x80 | 126;
    header.writeUInt16BE(length, 2);
  } else {
    throw new Error("payload too large for smoke");
  }
  const masked = Buffer.from(payload.map((byte, index) => byte ^ mask[index % 4]));
  return Buffer.concat([header, mask, masked]);
}

function parseServerFrame(buffer) {
  const opcode = buffer[0] & 0x0f;
  let length = buffer[1] & 0x7f;
  let offset = 2;
  if (length === 126) {
    if (buffer.length < 4) {
      return null;
    }
    length = buffer.readUInt16BE(2);
    offset = 4;
  } else if (length === 127) {
    throw new Error("large frames unsupported in smoke");
  }
  if (buffer.length < offset + length) {
    return null;
  }
  return {
    opcode,
    payload: buffer.subarray(offset, offset + length),
    consumed: offset + length,
  };
}

function tokenFingerprint(value) {
  return `sha256:${crypto.createHash("sha256").update(value.trim()).digest("hex").slice(0, 12)}`;
}

function gatewayPolicyDefaults() {
  return {
    CLAW_GATEWAY_TOKEN: "",
    CLAW_REQUIRE_TOKEN: "0",
    CLAW_WORKSPACE: "",
    CLAW_ALLOW_SHELL: "0",
    CLAW_SHELL_ALLOWLIST: "",
    CLAW_ALLOW_BROWSER_NETWORK: "0",
    CLAW_BROWSER_HOST_ALLOWLIST: "",
    CLAW_ALLOW_BROWSER_CONTROL: "0",
    CLAW_BROWSER_APP_ALLOWLIST: "",
    CLAW_ALLOW_SCREEN_CAPTURE: "0",
    CLAW_ALLOW_WINDOW_METADATA: "0",
    CLAW_ALLOW_ACCESSIBILITY_OBSERVE: "0",
    CLAW_ALLOW_DESKTOP_CONTROL: "0",
    CLAW_DESKTOP_APP_ALLOWLIST: "",
    CLAW_DESKTOP_KEY_ALLOWLIST: "",
  };
}

function isoNow() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

function expect(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function waitFor(predicate, timeoutMs, outputText = () => serverOutput) {
  const started = Date.now();
  while (!predicate()) {
    if (Date.now() - started > timeoutMs) {
      throw new Error(`timeout waiting for gateway. Output:\n${outputText()}`);
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
}
