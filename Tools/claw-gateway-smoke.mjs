#!/usr/bin/env node
import { spawn } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import http from "node:http";
import net from "node:net";
import path from "node:path";

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
expect(events.some((event) => event.artifacts?.some((artifact) => artifact.kind === "accessibilityTree")), "missing accessibilityTree artifact");
expect(events.some((event) => event.artifacts?.some((artifact) => artifact.kind === "agentTrace")), "missing agentTrace artifact");
expect(events.some((event) => event.artifacts?.some((artifact) => artifact.kind === "messageDraft")), "missing messageDraft artifact");

for (const artifact of events.flatMap((event) => event.artifacts || [])) {
  if (artifact.reference?.startsWith("file://")) {
    await fs.access(new URL(artifact.reference));
  }
}

const fileDiffArtifact = findArtifactByTitle(events, "fileDiff", "file-diff-3");
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
  filePolicyDiagnostic: "write-succeeded",
  fileRetryableReason: "none",
  policyChecked: true,
  workspacePolicyChecked: true,
  pathPolicyChecked: true,
  safetyFlags: ["metadata-only", "tool-arguments-omitted", "raw-path-omitted", "workspace-path-omitted", "file-content-omitted", "diff-content-omitted", "artifact-payload-not-read", "session-workspace-only"],
}, "websocket file change");
const pathEscapeArtifact = findArtifactByTitle(events, "auditLog", "file-change-blocked-4");
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
  filePolicyDiagnostic: "path-escape-blocked",
  fileRetryableReason: "fix-workspace-scope",
  policyChecked: true,
  workspacePolicyChecked: true,
  pathPolicyChecked: true,
  safetyFlags: ["metadata-only", "tool-arguments-omitted", "raw-path-omitted", "workspace-path-omitted", "file-content-omitted", "diff-content-omitted", "artifact-payload-not-read", "session-workspace-only", "path-escape-blocked", "no-file-written"],
}, "websocket path escape file change");
const writeFailureArtifact = findArtifactByTitle(events, "auditLog", "file-change-failed-6");
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
  filePolicyDiagnostic: "workspace-write-failed",
  fileRetryableReason: "retry-write",
  policyChecked: true,
  workspacePolicyChecked: true,
  pathPolicyChecked: true,
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
expect(capabilitySnapshot.envelope.allowedActionKinds.includes("observeScreen"), "websocket snapshot missing observeScreen allowlist");
const accessibilityTrees = await readArtifacts(events, "accessibilityTree");
const accessibilityTree = accessibilityTrees.find((tree) => typeof tree?.mode === "string");
assertAccessibilityTreeArtifact(findArtifact(events, "accessibilityTree"), accessibilityTree, {
  mode: ["dry-run"],
  policy: "dry-run",
  label: "websocket accessibility tree",
});
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
  shellPolicyDiagnostic: "dry-run",
  shellRetryableReason: "enable-shell",
  policyChecked: true,
  binaryAllowlistChecked: false,
  structuredCommandChecked: true,
  safetyFlags: ["metadata-only", "structured-arguments-only", "tool-arguments-omitted", "command-omitted", "stdout-omitted", "stderr-omitted", "cwd-omitted", "shell-allowlist-enforced", "dry-run-only", "no-command-executed", "artifact-payload-not-read"],
}, "websocket shell policy");

const browserTraces = await readArtifacts(events, "browserTrace");
const pageTrace = browserTraces.find((trace) => trace.mode === "local-html");
expect(pageTrace?.title === "Gateway Smoke Page", "missing websocket browser title extraction");
expect(pageTrace?.tables?.some((table) => table.rows?.some((row) => row.includes("Gateway"))), "missing websocket browser table extraction");
expect(pageTrace?.forms?.some((form) => form.fields?.some((field) => field.name === "query")), "missing websocket browser form extraction");
const pageTraceArtifact = findArtifactByTitle(events, "browserTrace", "browser-trace-2");
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
const pageControlArtifact = findArtifactByTitle(events, "screenshot", "browser-control-2");
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
expect(!agentTrace?.readiness?.satisfiedSignals?.includes("screenObservation"), "websocket agent loop should not satisfy dry-run screen observation");
expect(!agentTrace?.readiness?.satisfiedSignals?.includes("accessibilityTree"), "websocket agent loop should not satisfy dry-run accessibility tree");
expect(agentTrace?.readiness?.degradedSignals?.includes("screenObservation"), "websocket agent loop should degrade dry-run screen observation");
expect(agentTrace?.readiness?.degradedSignals?.includes("accessibilityTree"), "websocket agent loop should degrade dry-run accessibility tree");
expect(agentTrace?.readiness?.missingSignals?.includes("messageDraft"), "websocket agent loop should flag missing draft signal");
expect(agentTrace?.readiness?.score === 50, "websocket agent loop readiness score should count only satisfied evidence");
expect(agentTrace?.readiness?.canContinue === true, "websocket agent loop should remain continuable with browser/file/command evidence");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "screenObservation" && item.status === "degraded"), "websocket agent loop checklist should degrade screen observation");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "accessibilityTree" && item.status === "degraded"), "websocket agent loop checklist should degrade accessibility tree");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "browserTrace" && item.status === "satisfied"), "websocket agent loop checklist missing browser trace");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "fileDiff" && item.status === "satisfied"), "websocket agent loop checklist missing file diff");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "commandOutput" && item.status === "satisfied"), "websocket agent loop checklist missing command output");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "messageDraft" && item.status === "missing"), "websocket agent loop checklist missing draft gap");
expect(agentTrace?.nextActions?.some((action) => action.kind === agentTrace?.selectedNextAction?.kind), "websocket selected action should come from nextActions");
expect(agentTrace?.riskTags?.includes("approval-required"), "websocket agent loop should tag approval-gated actions");
expect(agentTrace?.riskTags?.includes("degraded-screen-observation"), "websocket agent loop should tag degraded screen observation");
expect(agentTrace?.riskTags?.includes("degraded-accessibility-tree"), "websocket agent loop should tag degraded accessibility tree");
expect(agentTrace?.riskTags?.includes("final-submit-gate") || agentTrace?.stopReason === "final-submit", "websocket agent loop should stop before final delivery");
expect(agentTrace?.handoffStatus === "final-submit-review", "websocket agent loop should expose handoff status");
expect(typeof agentTrace?.handoffSummary === "string" && agentTrace.handoffSummary.includes(agentTrace.selectedNextAction.kind), "websocket agent loop handoff summary should name selected action");
const messageDraftArtifact = findArtifactByTitle(events, "messageDraft", "message-draft-");
assertDeliverySafetyMetadata(messageDraftArtifact?.metadata, {
  mode: "message-draft-pending-approval",
  actionKind: "composeMessage",
  targetKind: "message",
  desktopPolicyDiagnostic: "not-requested",
  desktopRetryableReason: "none",
  automationAttempted: false,
  appPolicyChecked: false,
  keyPolicyChecked: false,
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

const shellIdentityPort = port + 2;
const shellIdentityRoot = path.resolve(`.build/claw-gateway-websocket-shell-identity-${crypto.randomUUID()}`);
const shellIdentityExecutable = path.join(shellIdentityRoot, "pwd");
const shellIdentityMarker = path.join(shellIdentityRoot, "executed");
await fs.mkdir(shellIdentityRoot, { recursive: true });
await fs.writeFile(shellIdentityExecutable, `#!/bin/sh\nprintf executed > ${JSON.stringify(shellIdentityMarker)}\n`, "utf8");
await fs.chmod(shellIdentityExecutable, 0o755);
const shellIdentityServer = spawn(
  process.execPath,
  ["Tools/claw-gateway-server.mjs", "--once"],
  {
    env: {
      ...process.env,
      ...gatewayPolicyDefaults(),
      CLAW_GATEWAY_HOST: host,
      CLAW_GATEWAY_PORT: String(shellIdentityPort),
      CLAW_GATEWAY_TOKEN: token,
      CLAW_WORKSPACE: ".build/claw-gateway-websocket-shell-identity",
      CLAW_ALLOW_SHELL: "1",
      CLAW_SHELL_ALLOWLIST: "pwd",
    },
    stdio: ["ignore", "pipe", "pipe"],
  },
);
let shellIdentityServerOutput = "";
shellIdentityServer.stdout.on("data", (chunk) => {
  shellIdentityServerOutput += chunk.toString("utf8");
});
shellIdentityServer.stderr.on("data", (chunk) => {
  shellIdentityServerOutput += chunk.toString("utf8");
});
await waitFor(
  () => shellIdentityServerOutput.includes("Claw Gateway listening"),
  3000,
  () => shellIdentityServerOutput,
);
const shellIdentityEnvelope = makeEnvelope(token, shellIdentityPort);
shellIdentityEnvelope.gateway.allowedActionKinds = ["runShellCommand"];
shellIdentityEnvelope.task.command = "verify websocket shell executable identity";
shellIdentityEnvelope.task.summary = "websocket shell executable identity smoke";
shellIdentityEnvelope.task.actions = shellIdentityEnvelope.task.actions
  .filter((action) => action.kind === "runShellCommand")
  .map((action) => ({
    ...action,
    title: "Reject same-name executable path",
    toolArguments: {
      ...action.toolArguments,
      shellCommand: shellIdentityExecutable,
    },
  }));
let shellIdentityEvents = [];
try {
  shellIdentityEvents = await connectAndCollectEvents({
    host,
    port: shellIdentityPort,
    token,
    envelope: shellIdentityEnvelope,
  });
} finally {
  shellIdentityServer.kill();
}
expect(shellIdentityEvents.some((event) => event.kind === "actionFailed" && event.actionKind === "runShellCommand"), "websocket same-name shell path should be blocked");
expect(!shellIdentityEvents.some((event) => event.kind === "actionCompleted" && event.actionKind === "runShellCommand"), "websocket same-name shell path unexpectedly completed");
expect(!JSON.stringify(shellIdentityEvents).includes(shellIdentityExecutable), "same-name shell path leaked into websocket events");
const shellIdentityArtifact = findArtifactByTitle(shellIdentityEvents, "commandOutput", "shell-policy-");
assertShellCommandSafetyMetadata(shellIdentityArtifact?.metadata, {
  mode: "shell-policy-blocked",
  actionKind: "runShellCommand",
  shellPolicy: "allowlist-required",
  structuredCommandPresent: true,
  commandParsed: true,
  allowlistConfigured: true,
  allowlistMatched: false,
  executionAttempted: false,
  executed: false,
  timedOut: false,
  exitCodePresent: false,
  exitCodeZero: false,
  stdoutPresent: false,
  stderrPresent: false,
  resultStatus: "failed",
  shellPolicyDiagnostic: "allowlist-blocked",
  shellRetryableReason: "allow-shell-binary",
  policyChecked: true,
  binaryAllowlistChecked: true,
  structuredCommandChecked: true,
  safetyFlags: ["metadata-only", "structured-arguments-only", "tool-arguments-omitted", "command-omitted", "stdout-omitted", "stderr-omitted", "cwd-omitted", "shell-allowlist-enforced", "no-command-executed", "artifact-payload-not-read"],
}, "websocket shell executable identity");
await fs.access(shellIdentityMarker).then(
  () => expect(false, "websocket same-name shell path produced an execution side effect"),
  (error) => expect(error?.code === "ENOENT", "websocket same-name shell path marker check failed unexpectedly"),
);

const shellProvenancePort = port + 3;
const shellProvenanceRoot = path.resolve(`.build/claw-gateway-websocket-shell-provenance-${crypto.randomUUID()}`);
const shellProvenanceBin = path.join(shellProvenanceRoot, "bin");
const shellProvenanceMarker = path.join(shellProvenanceRoot, "executed");
const shellProvenanceCanary = `provenance-${crypto.randomUUID()}`;
await fs.mkdir(shellProvenanceBin, { recursive: true });
await fs.writeFile(
  path.join(shellProvenanceBin, "pwd"),
  `#!/bin/sh\nprintf executed > ${JSON.stringify(shellProvenanceMarker)}\nprintf '%s' "$*"\n`,
  "utf8",
);
await fs.chmod(path.join(shellProvenanceBin, "pwd"), 0o755);
const shellProvenanceServer = spawn(
  process.execPath,
  ["Tools/claw-gateway-server.mjs", "--once"],
  {
    env: {
      ...process.env,
      ...gatewayPolicyDefaults(),
      CLAW_GATEWAY_HOST: host,
      CLAW_GATEWAY_PORT: String(shellProvenancePort),
      CLAW_GATEWAY_TOKEN: token,
      CLAW_WORKSPACE: ".build/claw-gateway-websocket-shell-provenance",
      CLAW_ALLOW_SHELL: "1",
      CLAW_SHELL_ALLOWLIST: "pwd",
      PATH: `${shellProvenanceBin}:${process.env.PATH || ""}`,
    },
    stdio: ["ignore", "pipe", "pipe"],
  },
);
let shellProvenanceServerOutput = "";
shellProvenanceServer.stdout.on("data", (chunk) => {
  shellProvenanceServerOutput += chunk.toString("utf8");
});
shellProvenanceServer.stderr.on("data", (chunk) => {
  shellProvenanceServerOutput += chunk.toString("utf8");
});
await waitFor(
  () => shellProvenanceServerOutput.includes("Claw Gateway listening"),
  3000,
  () => shellProvenanceServerOutput,
);
const shellProvenanceEnvelope = makeEnvelope(token, shellProvenancePort);
shellProvenanceEnvelope.gateway.allowedActionKinds = ["runShellCommand"];
shellProvenanceEnvelope.task.command = "verify websocket shell structured argument provenance";
shellProvenanceEnvelope.task.summary = "websocket shell provenance smoke";
shellProvenanceEnvelope.task.actions = shellProvenanceEnvelope.task.actions
  .filter((action) => action.kind === "runShellCommand")
  .map((action) => {
    const { shellCommand: _, ...toolArguments } = action.toolArguments;
    return {
      ...action,
      title: "Reject top-level shell command alias",
      toolArguments,
      commandLine: `pwd ${shellProvenanceCanary}`,
    };
  });
let shellProvenanceEvents = [];
try {
  shellProvenanceEvents = await connectAndCollectEvents({
    host,
    port: shellProvenancePort,
    token,
    envelope: shellProvenanceEnvelope,
  });
} finally {
  shellProvenanceServer.kill();
}
expect(shellProvenanceEvents.some((event) => event.kind === "actionFailed" && event.actionKind === "runShellCommand"), "websocket top-level shell alias should fail");
expect(!shellProvenanceEvents.some((event) => event.kind === "actionCompleted" && event.actionKind === "runShellCommand"), "websocket top-level shell alias unexpectedly completed");
expect(!shellProvenanceEvents.some((event) => event.artifacts?.some((artifact) => artifact.title?.startsWith("shell-output-"))), "websocket top-level shell alias reached execution output");
expect(!JSON.stringify(shellProvenanceEvents).includes(shellProvenanceCanary), "websocket top-level shell alias leaked into events");
const shellProvenanceArtifact = findArtifactByTitle(shellProvenanceEvents, "commandOutput", "shell-source-");
assertShellCommandSafetyMetadata(shellProvenanceArtifact?.metadata, {
  mode: "invalid-structured-command-source",
  actionKind: "runShellCommand",
  shellPolicy: "allowlist-enabled",
  structuredCommandPresent: false,
  commandParsed: false,
  allowlistConfigured: true,
  allowlistMatched: false,
  executionAttempted: false,
  executed: false,
  timedOut: false,
  exitCodePresent: false,
  exitCodeZero: false,
  stdoutPresent: false,
  stderrPresent: false,
  resultStatus: "failed",
  shellPolicyDiagnostic: "invalid-structured-command-source",
  shellRetryableReason: "provide-structured-command",
  policyChecked: true,
  binaryAllowlistChecked: false,
  structuredCommandChecked: true,
  safetyFlags: ["metadata-only", "structured-arguments-only", "tool-arguments-omitted", "command-omitted", "stdout-omitted", "stderr-omitted", "cwd-omitted", "invalid-command-source-blocked", "no-command-executed", "artifact-payload-not-read"],
}, "websocket shell command provenance");
const shellProvenancePayload = await fs.readFile(new URL(shellProvenanceArtifact.reference), "utf8");
expect(!shellProvenancePayload.includes(shellProvenanceCanary), "websocket top-level shell alias leaked into artifact payload");
await fs.access(shellProvenanceMarker).then(
  () => expect(false, "websocket top-level shell alias produced an execution side effect"),
  (error) => expect(error?.code === "ENOENT", "websocket shell provenance marker check failed unexpectedly"),
);

const browserRedirectPort = port + 4;
const redirectCanary = `redirect-${crypto.randomUUID()}`;
let redirectTargetHits = 0;
const redirectTargetServer = http.createServer((_request, response) => {
  redirectTargetHits += 1;
  response.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
  response.end("<html><head><title>Redirect target reached</title></head></html>");
});
const redirectTargetAddress = await listenHTTPServer(redirectTargetServer, "localhost");
const redirectEntryServer = http.createServer((_request, response) => {
  response.writeHead(302, {
    Location: `http://localhost:${redirectTargetAddress.port}/${redirectCanary}`,
  });
  response.end();
});
const redirectEntryAddress = await listenHTTPServer(redirectEntryServer, host);
const browserRedirectServer = spawn(
  process.execPath,
  ["Tools/claw-gateway-server.mjs", "--once"],
  {
    env: {
      ...process.env,
      ...gatewayPolicyDefaults(),
      CLAW_GATEWAY_HOST: host,
      CLAW_GATEWAY_PORT: String(browserRedirectPort),
      CLAW_GATEWAY_TOKEN: token,
      CLAW_WORKSPACE: ".build/claw-gateway-websocket-browser-redirect",
      CLAW_ALLOW_BROWSER_NETWORK: "1",
      CLAW_BROWSER_HOST_ALLOWLIST: host,
    },
    stdio: ["ignore", "pipe", "pipe"],
  },
);
let browserRedirectServerOutput = "";
browserRedirectServer.stdout.on("data", (chunk) => {
  browserRedirectServerOutput += chunk.toString("utf8");
});
browserRedirectServer.stderr.on("data", (chunk) => {
  browserRedirectServerOutput += chunk.toString("utf8");
});
const browserRedirectEnvelope = makeEnvelope(token, browserRedirectPort);
browserRedirectEnvelope.gateway.allowedActionKinds = ["controlBrowser"];
browserRedirectEnvelope.task.command = "verify websocket browser redirect host policy";
browserRedirectEnvelope.task.summary = "websocket browser redirect host policy smoke";
const browserTemplateAction = browserRedirectEnvelope.task.actions.find((action) => action.kind === "controlBrowser");
const redirectBlockedActionID = crypto.randomUUID();
const redirectFollowUpActionID = crypto.randomUUID();
browserRedirectEnvelope.task.actions = [
  {
    ...browserTemplateAction,
    id: redirectBlockedActionID,
    title: "Block cross-host browser redirect",
    instruction: "Fetch an allowed URL without crossing the host allowlist",
    toolArguments: {
      browserGoal: "verify redirect host policy",
      captureTrace: "true",
      url: `http://${host}:${redirectEntryAddress.port}/start`,
    },
  },
  {
    ...browserTemplateAction,
    id: redirectFollowUpActionID,
    title: "Continue after blocked browser redirect",
    instruction: "Process local HTML after the redirect policy failure",
    toolArguments: {
      browserGoal: "verify session continuity",
      captureTrace: "true",
      html: "<html><head><title>Redirect recovery</title></head><body>continued</body></html>",
    },
  },
];
let browserRedirectEvents = [];
try {
  await waitFor(
    () => browserRedirectServerOutput.includes("Claw Gateway listening"),
    3000,
    () => browserRedirectServerOutput,
  );
  browserRedirectEvents = await connectAndCollectEvents({
    host,
    port: browserRedirectPort,
    token,
    envelope: browserRedirectEnvelope,
  });
} finally {
  browserRedirectServer.kill();
  await Promise.all([
    closeHTTPServer(redirectEntryServer),
    closeHTTPServer(redirectTargetServer),
  ]);
}
expect(redirectTargetHits === 0, "websocket cross-host redirect contacted the blocked target");
const redirectFailureEvent = browserRedirectEvents.find((event) =>
  event.kind === "actionFailed" && event.actionID === redirectBlockedActionID && event.actionKind === "controlBrowser"
);
expect(Boolean(redirectFailureEvent), "websocket cross-host redirect should produce an action-bound failure");
const redirectFailureArtifactEvent = browserRedirectEvents.find((event) =>
  event.kind === "artifactStored" &&
  event.actionID === redirectBlockedActionID &&
  event.artifacts?.some((artifact) => artifact.kind === "browserTrace")
);
const redirectFailureArtifact = redirectFailureArtifactEvent?.artifacts?.find((artifact) => artifact.kind === "browserTrace");
expect(Boolean(redirectFailureArtifact), "websocket cross-host redirect failure missing action-bound browser artifact");
assertBrowserControlReviewMetadata(redirectFailureArtifact.metadata, {
  mode: "browser-network-failed",
  browserControlPolicy: "not-requested",
  browserControlRequested: true,
  openInBrowser: true,
  targetURLPresent: false,
  searchQueryPresent: false,
  localHTMLInput: false,
  networkFetchAttempted: true,
  networkBlocked: true,
  networkPolicyDiagnostic: "redirect-host-blocked",
  redirectPolicyChecked: true,
  redirectCount: 1,
  redirectBlocked: true,
  redirectLimitExceeded: false,
  networkFetchSucceeded: false,
  appAllowlistEnforced: false,
  hostAllowlistEnforced: false,
  policyDiagnostic: "not-requested",
  retryableReason: "none",
  executed: false,
  timedOut: false,
  resultStatus: "failed",
  safetyFlags: ["metadata-only", "network-allowlist-enforced", "redirect-policy-enforced", "redirect-policy-blocked"],
}, "websocket cross-host browser redirect");
const redirectFailurePayload = await fs.readFile(new URL(redirectFailureArtifact.reference), "utf8");
expect(
  browserRedirectEvents.some((event) =>
    event.kind === "actionCompleted" && event.actionID === redirectFollowUpActionID && event.actionKind === "controlBrowser"
  ),
  "websocket redirect policy failure should not block the following action",
);
expect(browserRedirectEvents.some((event) => event.kind === "sessionCompleted"), "websocket redirect policy session should complete");
const serializedBrowserRedirectEvents = JSON.stringify(browserRedirectEvents);
for (const forbidden of [
  redirectCanary,
  `http://${host}:${redirectEntryAddress.port}/start`,
  `http://localhost:${redirectTargetAddress.port}/${redirectCanary}`,
  "localhost",
  "Location",
  token,
  "Authorization",
  "Bearer",
]) {
  expect(!serializedBrowserRedirectEvents.includes(forbidden), `websocket redirect events leaked ${forbidden}`);
  expect(!redirectFailurePayload.includes(forbidden), `websocket redirect failure artifact leaked ${forbidden}`);
}

const agentLoopPolicyPort = port + 5;
const agentLoopPolicyServer = spawn(
  process.execPath,
  ["Tools/claw-gateway-server.mjs", "--once"],
  {
    env: {
      ...process.env,
      ...gatewayPolicyDefaults(),
      CLAW_GATEWAY_HOST: host,
      CLAW_GATEWAY_PORT: String(agentLoopPolicyPort),
      CLAW_GATEWAY_TOKEN: token,
      CLAW_WORKSPACE: ".build/claw-gateway-websocket-agent-loop-policy",
    },
    stdio: ["ignore", "pipe", "pipe"],
  },
);
let agentLoopPolicyServerOutput = "";
agentLoopPolicyServer.stdout.on("data", (chunk) => {
  agentLoopPolicyServerOutput += chunk.toString("utf8");
});
agentLoopPolicyServer.stderr.on("data", (chunk) => {
  agentLoopPolicyServerOutput += chunk.toString("utf8");
});
const agentLoopPolicyEnvelope = makeEnvelope(token, agentLoopPolicyPort);
agentLoopPolicyEnvelope.gateway.allowedActionKinds = ["runAgentLoop"];
agentLoopPolicyEnvelope.task.command = "verify websocket agent loop envelope allowlist intersection";
agentLoopPolicyEnvelope.task.summary = "websocket agent loop allowlist intersection smoke";
const agentLoopPolicyAction = {
  ...agentLoopPolicyEnvelope.task.actions.find((action) => action.kind === "runAgentLoop"),
  id: crypto.randomUUID(),
  title: "Block agent loop actions outside the envelope allowlist",
  instruction: "Stop when requested next actions are not allowed by the envelope",
  toolArguments: {
    maxIterations: "1",
    allowedNextActions: "operateDesktopApp,composeMessage",
    stopBeforeDestructiveAction: "true",
    writeTrace: "true",
  },
};
agentLoopPolicyEnvelope.task.actions = [agentLoopPolicyAction];
let agentLoopPolicyEvents = [];
try {
  await waitFor(
    () => agentLoopPolicyServerOutput.includes("Claw Gateway listening"),
    3000,
    () => agentLoopPolicyServerOutput,
  );
  agentLoopPolicyEvents = await connectAndCollectEvents({
    host,
    port: agentLoopPolicyPort,
    token,
    envelope: agentLoopPolicyEnvelope,
  });
} finally {
  agentLoopPolicyServer.kill();
}
expect(
  agentLoopPolicyEvents.some((event) =>
    event.kind === "actionCompleted" &&
    event.actionID === agentLoopPolicyAction.id &&
    event.actionKind === "runAgentLoop"
  ),
  "websocket agent loop policy action should complete with a blocked handoff",
);
expect(agentLoopPolicyEvents.some((event) => event.kind === "sessionCompleted"), "websocket agent loop policy session should complete");
const agentLoopPolicyArtifact = agentLoopPolicyEvents
  .find((event) =>
    event.kind === "artifactStored" &&
    event.actionID === agentLoopPolicyAction.id &&
    event.artifacts?.some((artifact) => artifact.kind === "agentTrace")
  )
  ?.artifacts?.find((artifact) => artifact.kind === "agentTrace");
expect(Boolean(agentLoopPolicyArtifact), "websocket agent loop policy missing action-bound agentTrace artifact");
const agentLoopPolicyTrace = JSON.parse(await fs.readFile(new URL(agentLoopPolicyArtifact.reference), "utf8"));
assertAgentTraceMetadata(agentLoopPolicyArtifact.metadata, agentLoopPolicyTrace, "websocket agent loop envelope intersection");
expect(
  agentLoopPolicyTrace.nextActions?.length === 1 && agentLoopPolicyTrace.nextActions[0]?.kind === "none",
  "websocket agent loop empty intersection should only propose none",
);
expect(agentLoopPolicyTrace.selectedNextAction?.kind === "none", "websocket agent loop empty intersection should select none");
expect(
  agentLoopPolicyTrace.iterations?.length === 1 && agentLoopPolicyTrace.iterations.every((iteration) => iteration.proposedAction === "none"),
  "websocket agent loop empty intersection iterations should only propose none",
);
expect(agentLoopPolicyTrace.safetyGates?.length === 0, "websocket agent loop empty intersection should have no safety gates");
expect(agentLoopPolicyTrace.stopReason === "policy-blocked", "websocket agent loop empty intersection stop reason mismatch");
expect(agentLoopPolicyTrace.handoffStatus === "blocked", "websocket agent loop empty intersection handoff should be blocked");
expect(agentLoopPolicyArtifact.metadata?.nextActionPolicy === "envelope-intersection", "websocket agent loop policy metadata mismatch");
expect(agentLoopPolicyArtifact.metadata?.nextActionPolicyDiagnostic === "policy-blocked", "websocket agent loop policy diagnostic mismatch");
expect(agentLoopPolicyArtifact.metadata?.requestedNextActionCount === "2", "websocket agent loop requested action count mismatch");
expect(agentLoopPolicyArtifact.metadata?.effectiveNextActionCount === "0", "websocket agent loop effective action count mismatch");
expect(agentLoopPolicyArtifact.metadata?.blockedNextActionCount === "2", "websocket agent loop blocked action count mismatch");
expect(agentLoopPolicyArtifact.metadata?.selectedNextActionAllowedByEnvelope === "true", "websocket agent loop none selection should be allowed by envelope policy");
const requestedAgentLoopActions = "operateDesktopApp,composeMessage";
const serializedAgentLoopPolicyEvents = JSON.stringify(agentLoopPolicyEvents);
const serializedAgentLoopPolicyMetadata = JSON.stringify(agentLoopPolicyArtifact.metadata);
const serializedAgentLoopPolicyTrace = JSON.stringify(agentLoopPolicyTrace);
expect(!serializedAgentLoopPolicyEvents.includes(requestedAgentLoopActions), "websocket agent loop events leaked the requested action list");
expect(!serializedAgentLoopPolicyMetadata.includes(requestedAgentLoopActions), "websocket agent loop metadata leaked the requested action list");
expect(!serializedAgentLoopPolicyTrace.includes(requestedAgentLoopActions), "websocket agent loop trace leaked the requested action list");
for (const blockedAction of ["operateDesktopApp", "composeMessage"]) {
  const serializedAction = JSON.stringify(blockedAction);
  expect(!serializedAgentLoopPolicyEvents.includes(serializedAction), `websocket agent loop events leaked ${blockedAction}`);
  expect(!serializedAgentLoopPolicyMetadata.includes(serializedAction), `websocket agent loop metadata leaked ${blockedAction}`);
  expect(!serializedAgentLoopPolicyTrace.includes(serializedAction), `websocket agent loop trace leaked ${blockedAction}`);
}

const unsupportedHandlerPort = port + 6;
const unsupportedMarker = `unsupported-handler-${crypto.randomUUID()}`;
const unsupportedSideEffectPath = path.resolve(`.build/claw-gateway-websocket-unsupported-side-effect-${unsupportedMarker}`);
let unsupportedTargetHits = 0;
const unsupportedTargetServer = http.createServer((_request, response) => {
  unsupportedTargetHits += 1;
  response.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
  response.end("unexpected unsupported handler request");
});
const unsupportedTargetAddress = await listenHTTPServer(unsupportedTargetServer, host);
const unsupportedHandlerServer = spawn(
  process.execPath,
  ["Tools/claw-gateway-server.mjs"],
  {
    env: {
      ...process.env,
      ...gatewayPolicyDefaults(),
      CLAW_GATEWAY_HOST: host,
      CLAW_GATEWAY_PORT: String(unsupportedHandlerPort),
      CLAW_GATEWAY_TOKEN: token,
      CLAW_WORKSPACE: ".build/claw-gateway-websocket-unsupported-handler",
      CLAW_ALLOW_BROWSER_NETWORK: "1",
      CLAW_BROWSER_HOST_ALLOWLIST: host,
    },
    stdio: ["ignore", "pipe", "pipe"],
  },
);
let unsupportedHandlerServerOutput = "";
unsupportedHandlerServer.stdout.on("data", (chunk) => {
  unsupportedHandlerServerOutput += chunk.toString("utf8");
});
unsupportedHandlerServer.stderr.on("data", (chunk) => {
  unsupportedHandlerServerOutput += chunk.toString("utf8");
});
const unsupportedHandlerEnvelope = makeUnsupportedHandlerEnvelope(
  token,
  unsupportedHandlerPort,
  unsupportedMarker,
  unsupportedSideEffectPath,
  unsupportedTargetAddress.port,
);
let unsupportedHandlerEvents = [];
let unknownActionEvents = [];
try {
  await waitFor(
    () => unsupportedHandlerServerOutput.includes("Claw Gateway listening"),
    3000,
    () => unsupportedHandlerServerOutput,
  );
  unsupportedHandlerEvents = await connectAndCollectEvents({
    host,
    port: unsupportedHandlerPort,
    token,
    envelope: unsupportedHandlerEnvelope,
  });
  const unknownActionEnvelope = JSON.parse(JSON.stringify(unsupportedHandlerEnvelope));
  unknownActionEnvelope.task.id = crypto.randomUUID();
  unknownActionEnvelope.task.actions[0].kind = `futureAction-${unsupportedMarker}`;
  unknownActionEnvelope.gateway.allowedActionKinds = [unknownActionEnvelope.task.actions[0].kind];
  unknownActionEvents = await connectAndCollectEvents({
    host,
    port: unsupportedHandlerPort,
    token,
    envelope: unknownActionEnvelope,
  });
} finally {
  unsupportedHandlerServer.kill();
  await closeHTTPServer(unsupportedTargetServer);
}
expect(unsupportedTargetHits === 0, "websocket unsupported handler contacted the network target");
await fs.access(unsupportedSideEffectPath).then(
  () => expect(false, "websocket unsupported handler produced a file side effect"),
  (error) => expect(error?.code === "ENOENT", "websocket unsupported handler side effect marker check failed unexpectedly"),
);
await assertUnsupportedHandlerFailure(
  unsupportedHandlerEvents,
  unsupportedHandlerEnvelope,
  [unsupportedMarker, unsupportedSideEffectPath, `http://${host}:${unsupportedTargetAddress.port}/${unsupportedMarker}`],
  "websocket unsupported handler",
);
expect(unknownActionEvents.length === 1, "unknown websocket action should emit one envelope error event");
expect(unknownActionEvents[0].kind === "actionFailed", "unknown websocket action should fail the envelope");
expect(unknownActionEvents[0].summary === "gateway error: unsupported_action_kind", "unknown websocket action error mismatch");
expect(unknownActionEvents[0].isRetryable === false, "unknown websocket action schema error should not be retryable");
expect(unknownActionEvents[0].actionID === undefined && unknownActionEvents[0].actionKind === undefined, "unknown websocket action must not echo action identity");
expect(!unknownActionEvents.some((event) => event.kind === "actionStarted" || event.kind === "sessionCompleted"), "unknown websocket action must not enter a session");
expect(!JSON.stringify(unknownActionEvents).includes(unsupportedMarker), "unknown websocket action error leaked the raw kind");

console.log(`Claw Gateway smoke passed (${events.length + firstReplayEvents.length + replayGuardEvents.length + shellIdentityEvents.length + shellProvenanceEvents.length + browserRedirectEvents.length + agentLoopPolicyEvents.length + unsupportedHandlerEvents.length + unknownActionEvents.length} events)`);

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
      allowedActionKinds: ["observeScreen", "controlBrowser", "manageFiles", "runShellCommand", "extractData", "runAgentLoop", "composeMessage"],
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
          kind: "observeScreen",
          title: "Observe screen",
          target: "Desktop Screen",
          instruction: "Collect dry-run screen and accessibility evidence",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            observationGoal: "observe websocket smoke desktop",
            includeScreenshot: "true",
            includeWindowTitles: "true",
            includeAccessibilityTree: "true",
            maxCandidateControls: "8",
            redaction: "required",
          },
        },
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
            inputSources: "screenObservation,accessibilityTree,browserTrace,fileDiff,commandOutput,messageDraft",
            allowedNextActions: "observeScreen,controlBrowser,manageFiles,extractData,composeMessage",
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

function makeUnsupportedHandlerEnvelope(rawToken, endpointPort, marker, sideEffectPath, targetPort) {
  const input = makeEnvelope(rawToken, endpointPort);
  const followUpAction = input.task.actions.find((action) => action.kind === "observeScreen");
  input.gateway.allowedActionKinds = ["openExternalURL", "observeScreen"];
  input.task.command = "verify websocket unsupported Gateway handlers fail closed";
  input.task.summary = "websocket unsupported handler regression";
  input.task.actions = [
    {
      id: crypto.randomUUID(),
      kind: "openExternalURL",
      title: "Reject unsupported handler",
      target: `sensitive-target-${marker}`,
      instruction: `Do not execute unsupported input ${marker}`,
      approval: "gatewayApproval",
      sourceSurface: "clawGateway",
      handlesSensitiveData: true,
      inputPreview: `sensitive-preview-${marker}`,
      toolArguments: {
        url: `http://${host}:${targetPort}/${marker}`,
        writePath: sideEffectPath,
        writeText: marker,
        executable: "touch",
        args: JSON.stringify([sideEffectPath]),
        appName: `sensitive-app-${marker}`,
        pasteText: `sensitive-paste-${marker}`,
        draftText: `sensitive-draft-${marker}`,
        keySequence: `sensitive-key-${marker}`,
      },
    },
    {
      ...followUpAction,
      id: crypto.randomUUID(),
      title: "Continue after unsupported handler",
      instruction: "Collect dry-run evidence after the isolated failure",
      inputPreview: "supported continuation",
      toolArguments: {
        observationGoal: "verify websocket unsupported handler session continuity",
        includeScreenshot: "false",
        includeWindowTitles: "false",
        includeAccessibilityTree: "false",
        redaction: "required",
      },
    },
  ];
  return input;
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

async function assertUnsupportedHandlerFailure(events, input, forbiddenValues, label) {
  const [unsupportedAction, followUpAction] = input.task.actions;
  expect(input.gateway.allowedActionKinds.includes(unsupportedAction.kind), `${label} action should be envelope allowed`);
  const finalEvents = events.filter((event) =>
    event.actionID === unsupportedAction.id &&
    ["actionCompleted", "actionFailed", "actionSkipped", "approvalRequested"].includes(event.kind)
  );
  expect(finalEvents.length === 1, `${label} should have exactly one final action event`);
  expect(finalEvents[0].kind === "actionFailed", `${label} should fail`);
  expect(finalEvents[0].actionKind === unsupportedAction.kind, `${label} failure kind mismatch`);
  expect(finalEvents[0].resultStatus === "failed", `${label} result status mismatch`);
  expect(finalEvents[0].isRetryable === false, `${label} should not be retryable`);
  expect(!events.some((event) => event.actionID === unsupportedAction.id && event.kind === "actionCompleted"), `${label} unexpectedly completed`);
  expect(!events.some((event) => event.actionID === unsupportedAction.id && event.kind === "actionSkipped"), `${label} should not use policy skip`);
  expect(!events.some((event) => event.actionID === unsupportedAction.id && event.kind === "approvalRequested"), `${label} should not request approval`);
  expect(
    events.filter((event) => event.actionID === unsupportedAction.id).map((event) => event.kind).join(",") ===
      "actionStarted,artifactStored,actionFailed",
    `${label} action event order mismatch`,
  );

  const artifactEvents = events.filter((event) => event.kind === "artifactStored" && event.actionID === unsupportedAction.id);
  expect(artifactEvents.length === 1, `${label} should emit one action-bound artifact event`);
  const artifacts = artifactEvents.flatMap((event) => event.artifacts || []);
  expect(artifacts.length === 1, `${label} should write only one audit artifact`);
  const auditArtifact = artifacts[0];
  expect(auditArtifact.kind === "auditLog", `${label} should only write an auditLog`);
  expect(auditArtifact.title?.startsWith("unsupported-action-"), `${label} audit title mismatch`);
  expect(auditArtifact.isRedacted === true, `${label} audit should be redacted`);
  const businessKinds = new Set(["accessibilityTree", "agentTrace", "browserTrace", "commandOutput", "extractedData", "fileDiff", "messageDraft", "screenshot"]);
  expect(!artifacts.some((artifact) => businessKinds.has(artifact.kind)), `${label} wrote a business artifact`);

  const audit = JSON.parse(await fs.readFile(new URL(auditArtifact.reference), "utf8"));
  assertUnsupportedHandlerAudit(auditArtifact.metadata, audit, unsupportedAction, label);
  const actionEvents = events.filter((event) => event.actionID === unsupportedAction.id);
  const serialized = JSON.stringify({ actionEvents, metadata: auditArtifact.metadata, audit });
  for (const forbidden of forbiddenValues) {
    expect(!serialized.includes(forbidden), `${label} leaked ${forbidden}`);
  }

  expect(
    events.some((event) =>
      event.kind === "actionCompleted" &&
      event.actionID === followUpAction.id &&
      event.actionKind === followUpAction.kind &&
      event.resultStatus === "succeeded"
    ),
    `${label} should continue to the following supported action`,
  );
  expect(events.some((event) => event.kind === "sessionCompleted"), `${label} session should complete`);
  expect(events.every((event, index) => index === 0 || event.sequence > events[index - 1].sequence), `${label} sequence should be strictly increasing`);
}

function assertUnsupportedHandlerAudit(metadata, audit, action, label) {
  expect(metadata && typeof metadata === "object", `${label} missing audit metadata`);
  expect(audit?.mode === "gateway-unsupported-action", `${label} payload mode mismatch`);
  expect(audit?.action?.id === action.id, `${label} payload action id mismatch`);
  expect(audit?.action?.kind === action.kind, `${label} payload action kind mismatch`);
  expect(audit?.policy?.diagnostic === "unsupported-action-handler", `${label} payload diagnostic mismatch`);
  expect(audit?.policy?.schemaActionKnown === true, `${label} payload should confirm schema action`);
  expect(audit?.policy?.envelopeAllowed === true, `${label} payload should confirm envelope allowlist`);
  expect(audit?.policy?.handlerSupported === false, `${label} payload should reject handler support`);
  expect(audit?.policy?.handlerExecution === "blocked", `${label} payload should block handler execution`);
  expect(audit?.policy?.handlerExecutionAttempted === false, `${label} payload should record no handler attempt`);
  expect(audit?.result?.businessSideEffectsAttempted === false, `${label} payload should record no business side effects`);
  expect(audit?.result?.status === "failed", `${label} payload result status mismatch`);
  expect(audit?.result?.retryable === false, `${label} payload retryable mismatch`);
  expect(audit?.safety?.instruction === "omitted", `${label} payload should omit instruction`);
  expect(audit?.safety?.inputPreview === "omitted", `${label} payload should omit input preview`);
  expect(audit?.safety?.target === "omitted", `${label} payload should omit target`);
  expect(audit?.safety?.toolArguments === "omitted", `${label} payload should omit tool arguments`);
  expect(audit?.safety?.businessArtifacts === "not-written", `${label} payload should record no business artifacts`);
  expect(metadata.mode === "gateway-unsupported-action", `${label} metadata mode mismatch`);
  expect(metadata.actionID === action.id, `${label} metadata action id mismatch`);
  expect(metadata.actionKind === action.kind, `${label} metadata action kind mismatch`);
  expect(metadata.policyDiagnostic === "unsupported-action-handler", `${label} metadata diagnostic mismatch`);
  expect(metadata.schemaActionKnown === "true", `${label} metadata should confirm schema action`);
  expect(metadata.envelopeAllowed === "true", `${label} metadata should confirm envelope allowlist`);
  expect(metadata.handlerSupported === "false", `${label} metadata should reject handler support`);
  expect(metadata.handlerExecution === "blocked", `${label} metadata should block handler execution`);
  expect(metadata.handlerExecutionAttempted === "false", `${label} metadata should record no handler attempt`);
  expect(metadata.businessSideEffectsAttempted === "false", `${label} metadata should record no business side effects`);
  expect(metadata.resultStatus === "failed", `${label} metadata result status mismatch`);
  expect(metadata.retryable === "false", `${label} metadata retryable mismatch`);
  for (const flag of ["metadata-only", "action-bound", "handler-not-invoked", "business-artifacts-not-written", "tool-arguments-omitted", "instruction-omitted", "input-preview-omitted", "target-omitted"]) {
    expect(metadata.safetyFlags?.includes(flag), `${label} missing ${flag} safety flag`);
  }
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

function assertAccessibilityTreeArtifact(artifact, tree, { mode, policy, label }) {
  expect(Boolean(artifact), `${label} missing artifact`);
  expect(Boolean(tree), `${label} missing payload`);
  expect(artifact.kind === "accessibilityTree", `${label} artifact kind mismatch`);
  expect(artifact.isRedacted === true, `${label} artifact should be redacted`);
  const allowedKeys = [
    "accessibilityPolicy",
    "accessibilityTree",
    "actionExecutionSupported",
    "candidateControlCount",
    "controlCoverage",
    "evidenceTier",
    "includeAccessibilityTree",
    "maxCandidateControls",
    "mode",
    "nodeCount",
    "passwordFieldsOmitted",
    "platform",
    "rawTextOmitted",
    "redaction",
    "safetyFlags",
    "signalQuality",
    "valuesOmitted",
  ].sort();
  expect(
    Object.keys(artifact.metadata || {}).sort().join(",") === allowedKeys.join(","),
    `${label} accessibility metadata includes unexpected keys`,
  );
  expect(artifact.metadata?.accessibilityTree === "observeSummary", `${label} metadata kind mismatch`);
  expect(mode.includes(tree?.mode), `${label} unexpected mode ${tree?.mode}`);
  expect(artifact.metadata?.mode === tree?.mode, `${label} metadata mode mismatch`);
  expect(tree?.accessibilityPolicy === policy, `${label} policy mismatch`);
  expect(artifact.metadata?.accessibilityPolicy === policy, `${label} metadata policy mismatch`);
  expect(Number(artifact.metadata?.maxCandidateControls) === tree?.maxCandidateControls, `${label} max controls metadata mismatch`);
  expect(Number(artifact.metadata?.nodeCount) === tree?.nodeCount, `${label} node count metadata mismatch`);
  expect(Number(artifact.metadata?.candidateControlCount) === tree?.candidateControlCount, `${label} candidate count metadata mismatch`);
  expect(artifact.metadata?.signalQuality === accessibilitySignalQualityForMode(tree?.mode), `${label} signal quality metadata mismatch`);
  expect(artifact.metadata?.evidenceTier === accessibilityEvidenceTierForMode(tree?.mode), `${label} evidence tier metadata mismatch`);
  expect(artifact.metadata?.controlCoverage === accessibilityControlCoverage(tree), `${label} control coverage metadata mismatch`);
  expect(artifact.metadata?.valuesOmitted === "true", `${label} values omission metadata mismatch`);
  expect(artifact.metadata?.passwordFieldsOmitted === "true", `${label} password omission metadata mismatch`);
  expect(artifact.metadata?.rawTextOmitted === "true", `${label} raw text omission metadata mismatch`);
  expect(artifact.metadata?.actionExecutionSupported === "false", `${label} action execution metadata mismatch`);
  expect(tree?.safety?.actionExecution === "not-supported", `${label} should not support actions`);
  expect(artifact.metadata?.safetyFlags?.includes("action-execution-not-supported"), `${label} missing safety flag`);
  const serialized = JSON.stringify({ metadata: artifact.metadata, tree });
  for (const forbidden of [token, "Authorization", "Bearer", "toolArguments", "shellCommand", "pasteText", "/sessions/"]) {
    expect(!serialized.includes(forbidden), `${label} leaked ${forbidden}`);
  }
}

function accessibilitySignalQualityForMode(mode) {
  return ({
    "not-requested": "not-requested",
    "dry-run": "dry-run",
    "window-metadata": "window-metadata",
    "accessibility-summary": "accessibility-summary",
    "accessibility-failed": "permission-missing",
    "accessibility-unavailable": "platform-unavailable",
  })[mode] || "dry-run";
}

function accessibilityEvidenceTierForMode(mode) {
  const signalQuality = accessibilitySignalQualityForMode(mode);
  if (signalQuality === "accessibility-summary") {
    return "satisfied";
  }
  return signalQuality === "not-requested" ? "missing" : "degraded";
}

function accessibilityControlCoverage(tree) {
  if (Number(tree?.candidateControlCount || 0) > 0) {
    return "candidate-controls";
  }
  if (Number(tree?.nodeCount || 0) > 0) {
    return "window-only";
  }
  return "none";
}

function assertAgentTraceMetadata(metadata, trace, label) {
  expect(metadata && typeof metadata === "object", `${label} missing agentTrace metadata`);
  const allowedKeys = [
    "blockedNextActionCount",
    "degradedSignals",
    "effectiveNextActionCount",
    "handoffStatus",
    "handoffSummary",
    "missingSignals",
    "nextActionPolicy",
    "nextActionPolicyDiagnostic",
    "readinessCanContinue",
    "readinessScore",
    "requestedNextActionCount",
    "riskTags",
    "satisfiedSignals",
    "selectedNextActionAllowedByEnvelope",
    "selectedNextActionKind",
    "selectedNextActionRequiresApproval",
    "stopReason",
  ];
  const expectedKeys = allowedKeys.filter((key) => {
    if (key === "satisfiedSignals") {
      return trace.readiness.satisfiedSignals?.length > 0;
    }
    if (key === "degradedSignals") {
      return trace.readiness.degradedSignals?.length > 0;
    }
    return true;
  });
  expect(
    Object.keys(metadata).sort().join(",") === expectedKeys.join(","),
    `${label} agentTrace metadata includes unexpected keys`,
  );
  expect(metadata.readinessScore === String(trace.readiness.score), `${label} readiness score metadata mismatch`);
  expect(metadata.readinessCanContinue === String(trace.readiness.canContinue), `${label} readiness continuation metadata mismatch`);
  if (trace.readiness.satisfiedSignals?.length > 0) {
    expect(metadata.satisfiedSignals === trace.readiness.satisfiedSignals.join(","), `${label} satisfied signals metadata mismatch`);
  } else {
    expect(metadata.satisfiedSignals === undefined, `${label} unexpected satisfied signals metadata`);
  }
  if (trace.readiness.degradedSignals?.length > 0) {
    expect(metadata.degradedSignals === trace.readiness.degradedSignals.join(","), `${label} degraded signals metadata mismatch`);
  } else {
    expect(metadata.degradedSignals === undefined, `${label} unexpected degraded signals metadata`);
  }
  expect(metadata.missingSignals === trace.readiness.missingSignals.join(","), `${label} missing signals metadata mismatch`);
  expect(metadata.selectedNextActionKind === trace.selectedNextAction.kind, `${label} selected action metadata mismatch`);
  expect(metadata.selectedNextActionRequiresApproval === String(trace.selectedNextAction.requiresApproval), `${label} selected approval metadata mismatch`);
  expect(metadata.nextActionPolicy === trace.nextActionPolicy, `${label} next action policy metadata mismatch`);
  expect(metadata.nextActionPolicyDiagnostic === trace.nextActionPolicyDiagnostic, `${label} next action policy diagnostic metadata mismatch`);
  expect(Number(metadata.requestedNextActionCount) === trace.requestedNextActionCount, `${label} requested next action count metadata mismatch`);
  expect(Number(metadata.effectiveNextActionCount) === trace.effectiveNextActionCount, `${label} effective next action count metadata mismatch`);
  expect(Number(metadata.blockedNextActionCount) === trace.blockedNextActionCount, `${label} blocked next action count metadata mismatch`);
  expect(
    metadata.selectedNextActionAllowedByEnvelope === String(trace.selectedNextActionAllowedByEnvelope),
    `${label} selected action envelope policy metadata mismatch`,
  );
  expect(metadata.riskTags === trace.riskTags.join(","), `${label} risk tags metadata mismatch`);
  expect(metadata.stopReason === trace.stopReason, `${label} stop reason metadata mismatch`);
  expect(metadata.handoffStatus === trace.handoffStatus, `${label} handoff status metadata mismatch`);
  expect(
    ["needs-evidence", "waiting-for-approval", "final-submit-review", "blocked", "ready-to-continue", "complete"].includes(metadata.handoffStatus),
    `${label} handoff status metadata invalid`,
  );
  expect(metadata.handoffSummary === trace.handoffSummary, `${label} handoff summary metadata mismatch`);
}

function assertExtractionCompletenessMetadata(metadata, extraction, label) {
  expect(metadata && typeof metadata === "object", `${label} missing extraction metadata`);
  const allowedKeys = [
    "accessibilityTreeCount",
    "browserTraceCount",
    "commandOutputCount",
    "completenessChecked",
    "completenessStatus",
    "extractionPolicyDiagnostic",
    "extractionRetryableReason",
    "extractionReview",
    "fileDiffCount",
    "messageDraftCount",
    "mode",
    "policyChecked",
    "rowCount",
    "safetyFlags",
    "screenObservationCount",
    "sourceArtifactKinds",
    "sourceCoverageChecked",
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
  expect(metadata.extractionPolicyDiagnostic === "complete", `${label} extraction policy diagnostic mismatch`);
  expect(metadata.extractionRetryableReason === "none", `${label} extraction retry reason mismatch`);
  expect(metadata.policyChecked === "true", `${label} policy checked mismatch`);
  expect(metadata.sourceCoverageChecked === "true", `${label} source coverage checked mismatch`);
  expect(metadata.completenessChecked === "true", `${label} completeness checked mismatch`);
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
    "appPolicyChecked",
    "browserControlPolicy",
    "browserControlRequested",
    "browserReview",
    "executed",
    "hostAllowlistEnforced",
    "hostPolicyChecked",
    "localHTMLInput",
    "mode",
    "networkBlocked",
    "networkFetchAttempted",
    "networkFetchSucceeded",
    "networkPolicyDiagnostic",
    "openAttempted",
    "openInBrowser",
    "policyDiagnostic",
    "redirectBlocked",
    "redirectCount",
    "redirectLimitExceeded",
    "redirectPolicyChecked",
    "resultStatus",
    "retryableReason",
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
  const expectedDiagnostic = expected.policyDiagnostic ?? browserPolicyDiagnosticForMode(expected.mode);
  const expectedRetryableReason = expected.retryableReason ?? browserRetryableReasonForMode(expected.mode);
  const expectedOpenAttempted = expected.openAttempted ?? ["browser-control-opened", "browser-control-failed"].includes(expected.mode);
  const expectedAppPolicyChecked = expected.appPolicyChecked ?? ["browser-control-policy-blocked", "browser-control-host-blocked", "browser-control-opened", "browser-control-failed"].includes(expected.mode);
  const expectedHostPolicyChecked = expected.hostPolicyChecked ?? ["browser-control-host-blocked", "browser-control-opened", "browser-control-failed"].includes(expected.mode);
  expect(metadata.policyDiagnostic === expectedDiagnostic, `${label} policy diagnostic metadata mismatch`);
  expect(metadata.retryableReason === expectedRetryableReason, `${label} retryable reason metadata mismatch`);
  expect(metadata.browserControlRequested === String(expected.browserControlRequested), `${label} request metadata mismatch`);
  expect(metadata.openInBrowser === String(expected.openInBrowser), `${label} openInBrowser metadata mismatch`);
  expect(metadata.openAttempted === String(expectedOpenAttempted), `${label} openAttempted metadata mismatch`);
  expect(metadata.targetURLPresent === String(expected.targetURLPresent), `${label} URL presence metadata mismatch`);
  expect(metadata.searchQueryPresent === String(expected.searchQueryPresent), `${label} search presence metadata mismatch`);
  expect(metadata.localHTMLInput === String(expected.localHTMLInput), `${label} HTML input metadata mismatch`);
  expect(metadata.networkFetchAttempted === String(expected.networkFetchAttempted), `${label} network fetch metadata mismatch`);
  expect(metadata.networkBlocked === String(expected.networkBlocked), `${label} network block metadata mismatch`);
  const expectedNetworkPolicyDiagnostic = expected.networkPolicyDiagnostic ?? "not-requested";
  const allowedNetworkPolicyDiagnostics = new Set([
    "not-requested",
    "fetch-succeeded",
    "initial-host-blocked",
    "initial-protocol-blocked",
    "initial-credentials-blocked",
    "redirect-host-blocked",
    "redirect-protocol-blocked",
    "redirect-credentials-blocked",
    "redirect-location-invalid",
    "redirect-limit-exceeded",
    "fetch-timeout",
    "http-error",
    "network-error",
  ]);
  expect(allowedNetworkPolicyDiagnostics.has(metadata.networkPolicyDiagnostic), `${label} network policy diagnostic metadata invalid`);
  expect(metadata.networkPolicyDiagnostic === expectedNetworkPolicyDiagnostic, `${label} network policy diagnostic metadata mismatch`);
  expect(metadata.redirectPolicyChecked === String(expected.redirectPolicyChecked ?? false), `${label} redirect policy checked metadata mismatch`);
  expect(Number(metadata.redirectCount) === (expected.redirectCount ?? 0), `${label} redirect count metadata mismatch`);
  expect(metadata.redirectBlocked === String(expected.redirectBlocked ?? false), `${label} redirect block metadata mismatch`);
  expect(metadata.redirectLimitExceeded === String(expected.redirectLimitExceeded ?? false), `${label} redirect limit metadata mismatch`);
  expect(metadata.networkFetchSucceeded === String(expected.networkFetchSucceeded ?? false), `${label} network fetch success metadata mismatch`);
  expect(
    metadata.safetyFlags.includes("redirect-policy-enforced") === (metadata.redirectPolicyChecked === "true"),
    `${label} redirect policy safety flag mismatch`,
  );
  expect(
    metadata.safetyFlags.includes("redirect-policy-blocked") === (metadata.redirectBlocked === "true"),
    `${label} redirect blocked safety flag mismatch`,
  );
  expect(
    metadata.safetyFlags.includes("redirect-limit-exceeded") === (metadata.redirectLimitExceeded === "true"),
    `${label} redirect limit safety flag mismatch`,
  );
  expect(metadata.appAllowlistEnforced === String(expected.appAllowlistEnforced), `${label} app allowlist metadata mismatch`);
  expect(metadata.hostAllowlistEnforced === String(expected.hostAllowlistEnforced), `${label} host allowlist metadata mismatch`);
  expect(metadata.appPolicyChecked === String(expectedAppPolicyChecked), `${label} app policy checked metadata mismatch`);
  expect(metadata.hostPolicyChecked === String(expectedHostPolicyChecked), `${label} host policy checked metadata mismatch`);
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
    "http://",
    "127.0.0.1",
    "localhost",
    "Location",
    "file://",
    "/sessions/",
    "stdout",
    "stderr",
  ]) {
    expect(!serialized.includes(forbidden), `${label} metadata leaked ${forbidden}`);
  }
}

function browserPolicyDiagnosticForMode(mode) {
  return ({
    "browser-control-not-requested": "not-requested",
    "browser-control-dry-run": "dry-run",
    "browser-control-unavailable": "platform-unavailable",
    "browser-control-policy-blocked": "app-blocked",
    "browser-control-host-blocked": "host-blocked",
    "browser-control-opened": "opened",
    "browser-control-failed": "automation-failed",
  })[mode];
}

function browserRetryableReasonForMode(mode) {
  return ({
    "browser-control-not-requested": "none",
    "browser-control-dry-run": "enable-browser-control",
    "browser-control-unavailable": "requires-macos",
    "browser-control-policy-blocked": "allow-browser-app",
    "browser-control-host-blocked": "allow-browser-host",
    "browser-control-opened": "none",
    "browser-control-failed": "automation-failed",
  })[mode];
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
    "filePolicyDiagnostic",
    "fileRetryableReason",
    "mode",
    "modifiedFileCount",
    "pathEscapeBlocked",
    "pathPolicyChecked",
    "policyChecked",
    "rawPathOmitted",
    "requestedPathPresent",
    "resultStatus",
    "safetyFlags",
    "workspacePolicy",
    "workspacePolicyChecked",
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
  expect(metadata.filePolicyDiagnostic === expected.filePolicyDiagnostic, `${label} file policy diagnostic mismatch`);
  expect(metadata.fileRetryableReason === expected.fileRetryableReason, `${label} file retry reason mismatch`);
  expect(metadata.policyChecked === String(expected.policyChecked), `${label} policy checked mismatch`);
  expect(metadata.workspacePolicyChecked === String(expected.workspacePolicyChecked), `${label} workspace policy checked mismatch`);
  expect(metadata.pathPolicyChecked === String(expected.pathPolicyChecked), `${label} path policy checked mismatch`);
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
    "binaryAllowlistChecked",
    "commandOmitted",
    "commandParsed",
    "cwdOmitted",
    "executed",
    "executionAttempted",
    "exitCodePresent",
    "exitCodeZero",
    "mode",
    "policyChecked",
    "resultStatus",
    "safetyFlags",
    "shellPolicy",
    "shellPolicyDiagnostic",
    "shellRetryableReason",
    "shellReview",
    "stderrOmitted",
    "stderrPresent",
    "stdoutOmitted",
    "stdoutPresent",
    "structuredCommandChecked",
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
  expect(metadata.shellPolicyDiagnostic === expected.shellPolicyDiagnostic, `${label} shell policy diagnostic mismatch`);
  expect(metadata.shellRetryableReason === expected.shellRetryableReason, `${label} shell retry reason mismatch`);
  expect(metadata.policyChecked === String(expected.policyChecked), `${label} policy checked mismatch`);
  expect(metadata.binaryAllowlistChecked === String(expected.binaryAllowlistChecked), `${label} binary allowlist checked mismatch`);
  expect(metadata.structuredCommandChecked === String(expected.structuredCommandChecked), `${label} structured command checked mismatch`);
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
    "appPolicyChecked",
    "automationAttempted",
    "blockedKeyCount",
    "blockedSubmitKeyCount",
    "deliveryReview",
    "desktopPolicyDiagnostic",
    "desktopRetryableReason",
    "draftBodyOmitted",
    "finalSubmitRequiresApproval",
    "keyPolicyChecked",
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
  expect(metadata.desktopPolicyDiagnostic === expected.desktopPolicyDiagnostic, `${label} desktop policy diagnostic mismatch`);
  expect(metadata.desktopRetryableReason === expected.desktopRetryableReason, `${label} desktop retry reason mismatch`);
  expect(metadata.automationAttempted === String(expected.automationAttempted), `${label} automation attempted mismatch`);
  expect(metadata.appPolicyChecked === String(expected.appPolicyChecked), `${label} app policy checked mismatch`);
  expect(metadata.keyPolicyChecked === String(expected.keyPolicyChecked), `${label} key policy checked mismatch`);
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

function listenHTTPServer(server, listenHost) {
  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, listenHost, () => {
      server.off("error", reject);
      resolve(server.address());
    });
  });
}

function closeHTTPServer(server) {
  return new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  });
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
