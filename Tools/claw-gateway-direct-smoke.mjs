#!/usr/bin/env node
import { spawn } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs/promises";

const token = "smoke-token";
const workspace = ".build/claw-gateway-direct-smoke";
const envelope = makeEnvelope(token);

const dryRunEvents = await runEmitEvents({
  CLAW_GATEWAY_TOKEN: token,
  CLAW_WORKSPACE: workspace,
});

expect(dryRunEvents.some((event) => event.kind === "gatewayConnected"), "missing gatewayConnected event");
expect(dryRunEvents.some((event) => event.kind === "actionCompleted"), "missing actionCompleted event");
expect(dryRunEvents.some((event) => event.kind === "actionFailed"), "missing shell policy failure event");
expect(dryRunEvents.some((event) => event.kind === "sessionCompleted"), "missing sessionCompleted event");
expect(dryRunEvents.some((event) => hasArtifact(event, "browserTrace")), "missing browserTrace artifact");
expect(dryRunEvents.some((event) => hasArtifact(event, "screenshot")), "missing screenshot artifact");
expect(dryRunEvents.some((event) => hasArtifact(event, "accessibilityTree")), "missing accessibilityTree artifact");
expect(dryRunEvents.some((event) => hasArtifact(event, "fileDiff")), "missing fileDiff artifact");
expect(dryRunEvents.some((event) => hasArtifact(event, "commandOutput")), "missing commandOutput artifact");
expect(dryRunEvents.some((event) => hasArtifact(event, "agentTrace")), "missing agentTrace artifact");
expect(dryRunEvents.some((event) => hasArtifact(event, "messageDraft")), "missing messageDraft artifact");
expect(dryRunEvents.some((event) => event.kind === "approvalRequested" && event.actionKind === "operateDesktopApp"), "missing desktop app approval gate");
await assertArtifactsExist(dryRunEvents);
const dryRunSnapshot = await assertCapabilitySnapshot(dryRunEvents, {
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
expect(dryRunSnapshot.policies.shell.allowlist.length === 0, "dry-run shell allowlist should be empty");
const shellPolicyArtifact = findArtifactByTitle(dryRunEvents, "commandOutput", "shell-policy-");
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
  binaryAllowlistChecked: true,
  structuredCommandChecked: true,
  safetyFlags: ["metadata-only", "structured-arguments-only", "tool-arguments-omitted", "command-omitted", "stdout-omitted", "stderr-omitted", "cwd-omitted", "shell-allowlist-enforced", "dry-run-only", "no-command-executed", "artifact-payload-not-read"],
}, "direct shell policy");
const dryRunRoot = workspaceFileRoot(dryRunEvents);
await fs.access(`${dryRunRoot}/notes/result.txt`);
await fs.access(`${dryRunRoot}/notes/extracted.json`);
const fileDiffArtifact = findArtifactByTitle(dryRunEvents, "fileDiff", "file-diff-4");
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
}, "direct file change");
const browserTraces = await readArtifacts(dryRunEvents, "browserTrace");
const localBrowserTrace = browserTraces.find((trace) => trace.mode === "local-html" && trace.title === "Smoke Page");
expect(Boolean(localBrowserTrace), "missing local HTML browser extraction");
expect(localBrowserTrace?.links?.some((link) => link.href === "https://example.com/docs"), "missing extracted browser link");
expect(localBrowserTrace?.headings?.some((heading) => heading.text === "Smoke Heading"), "missing extracted browser heading");
expect(localBrowserTrace?.tables?.some((table) => table.headers?.includes("Name") && table.rows?.some((row) => row.includes("Claw"))), "missing extracted browser table");
expect(localBrowserTrace?.forms?.some((form) => form.fields?.some((field) => field.name === "query")), "missing extracted browser form");
expect(localBrowserTrace?.candidateControls?.some((control) => control.label === "Run search"), "missing browser candidate control");
expect(localBrowserTrace?.browserControl?.mode === "browser-control-dry-run", "missing browser control dry-run plan");
expect(localBrowserTrace?.browserControl?.browserApp === "Safari", "missing browser app plan");
expect(localBrowserTrace?.browserControl?.searchQuery === "claw gateway smoke search", "missing browser search query plan");
expect(localBrowserTrace?.browserControl?.targetURL?.startsWith("https://www.google.com/search"), "missing browser search URL plan");
const localBrowserTraceArtifact = findArtifactByTitle(dryRunEvents, "browserTrace", "browser-trace-2");
assertBrowserControlReviewMetadata(localBrowserTraceArtifact?.metadata, {
  mode: "browser-control-dry-run",
  browserControlPolicy: "dry-run",
  browserControlRequested: true,
  openInBrowser: true,
  targetURLPresent: true,
  searchQueryPresent: true,
  localHTMLInput: true,
  networkFetchAttempted: false,
  networkBlocked: false,
  appAllowlistEnforced: false,
  hostAllowlistEnforced: false,
  executed: false,
  timedOut: false,
  resultStatus: "succeeded",
  safetyFlags: ["metadata-only", "tool-arguments-omitted", "url-omitted", "search-query-omitted", "page-content-omitted", "form-fields-omitted", "candidate-labels-omitted", "artifact-payload-not-read"],
}, "direct local browser trace");
const localBrowserControlArtifact = findArtifactByTitle(dryRunEvents, "screenshot", "browser-control-2");
assertBrowserControlReviewMetadata(localBrowserControlArtifact?.metadata, {
  mode: "browser-control-dry-run",
  browserControlPolicy: "dry-run",
  browserControlRequested: true,
  openInBrowser: true,
  targetURLPresent: true,
  searchQueryPresent: true,
  localHTMLInput: true,
  networkFetchAttempted: false,
  networkBlocked: false,
  appAllowlistEnforced: false,
  hostAllowlistEnforced: false,
  executed: false,
  timedOut: false,
  resultStatus: "succeeded",
  safetyFlags: ["metadata-only", "tool-arguments-omitted", "url-omitted", "search-query-omitted", "page-content-omitted", "form-fields-omitted", "candidate-labels-omitted", "artifact-payload-not-read"],
}, "direct local browser control");
expect(browserTraces.some((trace) => trace.mode === "network-blocked" && trace.source === "https://blocked.example/"), "missing blocked URL browser trace");
const blockedBrowserTraceArtifact = findArtifactByTitle(dryRunEvents, "browserTrace", "browser-trace-3");
assertBrowserControlReviewMetadata(blockedBrowserTraceArtifact?.metadata, {
  mode: "browser-control-dry-run",
  browserControlPolicy: "dry-run",
  browserControlRequested: true,
  openInBrowser: true,
  targetURLPresent: false,
  searchQueryPresent: false,
  localHTMLInput: false,
  networkFetchAttempted: false,
  networkBlocked: true,
  appAllowlistEnforced: false,
  hostAllowlistEnforced: false,
  executed: false,
  timedOut: false,
  resultStatus: "succeeded",
  safetyFlags: ["metadata-only", "tool-arguments-omitted", "url-omitted", "search-query-omitted", "page-content-omitted", "form-fields-omitted", "candidate-labels-omitted", "artifact-payload-not-read", "network-allowlist-enforced"],
}, "direct blocked URL browser trace");
const extractedTrace = browserTraces.find((trace) => trace.mode === "artifact-grounded-extraction" && trace.outputPath === "notes/extracted.json");
expect(Boolean(extractedTrace), "missing artifact-grounded extraction trace");
expect(extractedTrace?.sourceArtifacts?.browserTraceCount >= 2, "extraction did not consume browser traces");
expect(extractedTrace?.sourceArtifacts?.fileDiffCount >= 1, "extraction did not consume file diff");
expect(extractedTrace?.sourceArtifacts?.commandOutputCount >= 1, "extraction did not consume command output");
expect(extractedTrace?.rows?.some((row) => row.title === "Smoke Page"), "extraction missing browser page row");
expect(extractedTrace?.rows?.some((row) => row.title === "Docs"), "extraction missing browser link row");
expect(extractedTrace?.rows?.some((row) => row.source?.includes("notes/result.txt")), "extraction missing file row");
const extractionArtifact = findArtifactByTitle(dryRunEvents, "browserTrace", "extracted-data-");
assertExtractionCompletenessMetadata(extractionArtifact?.metadata, extractedTrace, "direct extraction");
const agentTraces = await readArtifacts(dryRunEvents, "agentTrace");
const agentTrace = agentTraces.find((trace) => trace.mode === "agent-loop-trace");
expect(Boolean(agentTrace), "missing observe-plan-act-verify agent trace");
const agentTraceArtifact = findArtifact(dryRunEvents, "agentTrace");
assertAgentTraceMetadata(agentTraceArtifact?.metadata, agentTrace, "agent loop");
expect(agentTrace?.sourceArtifacts?.browserTraceCount >= 2, "agent loop did not consume browser traces");
expect(agentTrace?.sourceArtifacts?.fileDiffCount >= 1, "agent loop did not consume file diff");
expect(agentTrace?.sourceArtifacts?.commandOutputCount >= 1, "agent loop did not consume command output");
expect(agentTrace?.nextActions?.some((action) => action.kind === "composeMessage"), "agent loop should propose a delivery draft");
expect(agentTrace?.safetyGates?.some((gate) => gate.actionKind === "composeMessage"), "agent loop should gate delivery draft");
expect(typeof agentTrace?.readiness?.score === "number", "agent loop readiness score should be numeric");
expect(agentTrace?.readiness?.satisfiedSignals?.includes("browserTrace"), "agent loop should satisfy browser trace signal");
expect(agentTrace?.readiness?.satisfiedSignals?.includes("fileDiff"), "agent loop should satisfy file diff signal");
expect(agentTrace?.readiness?.satisfiedSignals?.includes("commandOutput"), "agent loop should satisfy command output signal");
expect(!agentTrace?.readiness?.satisfiedSignals?.includes("screenObservation"), "agent loop should not satisfy dry-run screen observation");
expect(!agentTrace?.readiness?.satisfiedSignals?.includes("accessibilityTree"), "agent loop should not satisfy dry-run accessibility tree");
expect(agentTrace?.readiness?.degradedSignals?.includes("screenObservation"), "agent loop should degrade dry-run screen observation");
expect(agentTrace?.readiness?.degradedSignals?.includes("accessibilityTree"), "agent loop should degrade dry-run accessibility tree");
expect(agentTrace?.readiness?.missingSignals?.includes("messageDraft"), "agent loop should flag missing draft signal");
expect(agentTrace?.readiness?.score === 50, "agent loop readiness score should count only satisfied evidence");
expect(agentTrace?.readiness?.canContinue === true, "agent loop should remain continuable with browser/file/command evidence");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "screenObservation" && item.status === "degraded"), "agent loop checklist should degrade screen observation");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "accessibilityTree" && item.status === "degraded"), "agent loop checklist should degrade accessibility tree");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "browserTrace" && item.status === "satisfied"), "agent loop checklist missing browser trace");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "fileDiff" && item.status === "satisfied"), "agent loop checklist missing file diff");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "commandOutput" && item.status === "satisfied"), "agent loop checklist missing command output");
expect(agentTrace?.decisionChecklist?.some((item) => item.signal === "messageDraft" && item.status === "missing"), "agent loop checklist missing draft gap");
expect(agentTrace?.nextActions?.some((action) => action.kind === agentTrace?.selectedNextAction?.kind), "agent loop selected action should come from nextActions");
expect(agentTrace?.riskTags?.includes("approval-required"), "agent loop should tag approval-gated actions");
expect(agentTrace?.riskTags?.includes("degraded-screen-observation"), "agent loop should tag degraded screen observation");
expect(agentTrace?.riskTags?.includes("degraded-accessibility-tree"), "agent loop should tag degraded accessibility tree");
expect(agentTrace?.riskTags?.includes("final-submit-gate") || agentTrace?.stopReason === "final-submit", "agent loop should stop before final delivery");
expect(agentTrace?.handoffStatus === "final-submit-review", "agent loop should expose handoff status");
expect(typeof agentTrace?.handoffSummary === "string" && agentTrace.handoffSummary.includes(agentTrace.selectedNextAction.kind), "agent loop handoff summary should name selected action");
const screenArtifacts = await readArtifacts(dryRunEvents, "screenshot");
expect(screenArtifacts.some((artifact) => artifact.observationGoal === "observe smoke desktop"), "missing screen observation goal");
const desktopDryRun = screenArtifacts.find((artifact) => artifact.targetApp === "Slack" && artifact.desktopControlPolicy === "dry-run");
expect(Boolean(desktopDryRun), "missing desktop app dry-run policy artifact");
expect(desktopDryRun?.finalSubmitRequiresApproval === true, "desktop app final submit should require approval");
expect(desktopDryRun?.pasteTextPreview?.includes("Smoke summary ready") === true, "missing desktop app paste preview");
expect(desktopDryRun?.executableKeys?.includes("command+k"), "missing allowlisted desktop key plan");
expect(desktopDryRun?.blockedKeys?.some((item) => item.key === "return" && item.reason === "final_submit_requires_approval"), "missing blocked final submit key");
const desktopDeliveryArtifact = findArtifactByTitle(dryRunEvents, "screenshot", "desktop-app-confirm-");
assertDeliverySafetyMetadata(desktopDeliveryArtifact?.metadata, {
  mode: "desktop-control-dry-run",
  actionKind: "operateDesktopApp",
  targetKind: "desktopApp",
  desktopPolicyDiagnostic: "dry-run",
  desktopRetryableReason: "enable-desktop-control",
  automationAttempted: false,
  appPolicyChecked: false,
  keyPolicyChecked: true,
  finalSubmitRequiresApproval: true,
  userApprovalRequired: true,
  draftBodyOmitted: true,
  pasteTextOmitted: true,
  submitBlocked: true,
  allowedKeyCount: 1,
  blockedKeyCount: 1,
  blockedSubmitKeyCount: 1,
  safetyFlags: ["metadata-only", "final-submit-gated", "user-approval-required", "tool-arguments-omitted", "artifact-payload-not-read", "draft-body-omitted", "paste-text-omitted"],
}, "desktop app delivery safety");
const messageDraftArtifact = findArtifactByTitle(dryRunEvents, "messageDraft", "message-draft-");
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
}, "message draft delivery safety");
const axTrees = await readArtifacts(dryRunEvents, "accessibilityTree");
expect(axTrees.some((tree) => tree.includeAccessibilityTree === true && tree.maxCandidateControls === 12), "missing accessibility tree metadata");
const dryRunAccessibilityArtifact = findArtifact(dryRunEvents, "accessibilityTree");
assertAccessibilityTreeArtifact(dryRunAccessibilityArtifact, axTrees[0], {
  mode: ["dry-run", "window-metadata"],
  policy: "dry-run",
  label: "dry-run accessibility tree",
});

const emptyExtractionEvents = await runEmitEvents(
  {
    CLAW_GATEWAY_TOKEN: token,
    CLAW_WORKSPACE: `${workspace}-empty-extraction`,
  },
  makeEmptyExtractionEnvelope(token),
);
await assertArtifactsExist(emptyExtractionEvents);
const emptyExtractionTraces = await readArtifacts(emptyExtractionEvents, "browserTrace");
const emptyExtractionTrace = emptyExtractionTraces.find((trace) => trace.mode === "dry-run-extraction" && trace.outputPath === "notes/empty-extracted.json");
expect(Boolean(emptyExtractionTrace), "missing empty extraction trace");
expect(Array.isArray(emptyExtractionTrace?.rows) && emptyExtractionTrace.rows.length === 0, "empty extraction should not emit placeholder rows");
const emptyExtractionArtifact = findArtifactByTitle(emptyExtractionEvents, "browserTrace", "extracted-data-");
assertEmptyExtractionCompletenessMetadata(emptyExtractionArtifact?.metadata, emptyExtractionTrace, "empty direct extraction");

const pathEscapeEnvelope = makePathEscapeEnvelope(token);
const pathEscapeEvents = await runEmitEvents(
  {
    CLAW_GATEWAY_TOKEN: token,
    CLAW_WORKSPACE: `${workspace}-path-escape`,
  },
  pathEscapeEnvelope,
);
await assertArtifactsExist(pathEscapeEvents);
expect(pathEscapeEvents.some((event) => event.kind === "actionFailed" && event.actionKind === "manageFiles"), "missing path escape failure event");
const pathEscapeArtifact = findArtifactByTitle(pathEscapeEvents, "auditLog", "file-change-blocked-");
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
}, "direct path escape file change");

const writeFailureEvents = await runEmitEvents(
  {
    CLAW_GATEWAY_TOKEN: token,
    CLAW_WORKSPACE: `${workspace}-write-failure`,
  },
  makeWriteFailureEnvelope(token),
);
await assertArtifactsExist(writeFailureEvents);
expect(writeFailureEvents.some((event) => event.kind === "actionFailed" && event.actionKind === "manageFiles"), "missing write failure event");
const writeFailureArtifact = findArtifactByTitle(writeFailureEvents, "auditLog", "file-change-failed-");
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
}, "direct write failure file change");

const symlinkWorkspace = `${workspace}-symlink-${crypto.randomUUID()}`;
const symlinkTarget = `/private/tmp/claw-gateway-symlink-target-${crypto.randomUUID()}`;
await fs.mkdir(symlinkWorkspace, { recursive: true });
await fs.mkdir(symlinkTarget, { recursive: true });
await fs.symlink(symlinkTarget, `${symlinkWorkspace}/sessions`, "dir");
const symlinkFailure = await runEmitEventsExpectFailure(
  {
    CLAW_GATEWAY_TOKEN: token,
    CLAW_WORKSPACE: symlinkWorkspace,
  },
  makeWriteFailureEnvelope(token),
);
expect(symlinkFailure.stderr.includes("workspace_symlink_blocked"), "workspace symlink failure should report symlink block");
expect((await fs.readdir(symlinkTarget)).length === 0, "workspace symlink target should not receive Gateway files");

const replayEvents = await runEmitEvents(
  {
    CLAW_GATEWAY_TOKEN: token,
    CLAW_WORKSPACE: `${workspace}-replay`,
  },
  [envelope, envelope],
);
const replayGroups = groupEventsBySession(replayEvents);
expect(replayGroups.length === 2, "direct replay guard should create exactly two sessions");
const replayGuardEvents = replayGroups.find((group) => group.some((event) => event.artifacts?.some(isTaskReplayGuardArtifact)));
expect(Boolean(replayGuardEvents), "direct replay guard session missing audit artifact");
const firstReplayEvents = replayGroups.find((group) => group !== replayGuardEvents);
expect(firstReplayEvents?.some((event) => hasArtifact(event, "browserTrace")), "direct replay first session should still run browser trace");
expect(
  replayEvents.filter((event) => event.kind === "actionStarted").length === envelope.task.actions.length,
  "direct replay guard should not duplicate actionStarted events",
);
await assertTaskReplayGuard(replayGuardEvents, envelope.task.actions.length, "direct replay guard");
await assertArtifactsExist(replayEvents);

const allowlistEvents = await runEmitEvents({
  CLAW_GATEWAY_TOKEN: token,
  CLAW_WORKSPACE: `${workspace}-allowlist`,
  CLAW_ALLOW_SHELL: "1",
  CLAW_SHELL_ALLOWLIST: "pwd",
});

expect(allowlistEvents.some((event) => event.kind === "actionCompleted" && event.actionKind === "runShellCommand"), "allowlisted shell did not complete");
expect(!allowlistEvents.some((event) => event.kind === "actionFailed" && event.actionKind === "runShellCommand"), "allowlisted shell unexpectedly failed");
await assertArtifactsExist(allowlistEvents);
const allowlistSnapshot = await assertCapabilitySnapshot(allowlistEvents, {
  allowedActionKinds: envelope.gateway.allowedActionKinds,
  capabilities: {
    shell: "real",
  },
});
expect(allowlistSnapshot.policies.shell.allowlist.includes("pwd"), "shell snapshot missing pwd allowlist");
const allowlistShellArtifact = findArtifactByTitle(allowlistEvents, "commandOutput", "shell-output-");
assertShellCommandSafetyMetadata(allowlistShellArtifact?.metadata, {
  mode: "shell-executed",
  actionKind: "runShellCommand",
  shellPolicy: "allowlist-enabled",
  structuredCommandPresent: true,
  commandParsed: true,
  allowlistConfigured: true,
  allowlistMatched: true,
  executionAttempted: true,
  executed: true,
  timedOut: false,
  exitCodePresent: true,
  exitCodeZero: true,
  stdoutPresent: true,
  stderrPresent: false,
  resultStatus: "succeeded",
  shellPolicyDiagnostic: "execution-attempted",
  shellRetryableReason: "none",
  policyChecked: true,
  binaryAllowlistChecked: true,
  structuredCommandChecked: true,
  safetyFlags: ["metadata-only", "structured-arguments-only", "tool-arguments-omitted", "command-omitted", "stdout-omitted", "stderr-omitted", "cwd-omitted", "shell-allowlist-enforced", "artifact-payload-not-read"],
}, "direct shell allowlist");

const missingShellEvents = await runEmitEvents({
  CLAW_GATEWAY_TOKEN: token,
  CLAW_WORKSPACE: `${workspace}-missing-shell`,
}, makeMissingShellEnvelope(token));
expect(missingShellEvents.some((event) => event.kind === "actionFailed" && event.actionKind === "runShellCommand"), "missing shell command should fail");
const missingShellArtifact = findArtifactByTitle(missingShellEvents, "commandOutput", "shell-dry-run-");
assertShellCommandSafetyMetadata(missingShellArtifact?.metadata, {
  mode: "missing-structured-command",
  actionKind: "runShellCommand",
  shellPolicy: "dry-run",
  structuredCommandPresent: false,
  commandParsed: false,
  allowlistConfigured: false,
  allowlistMatched: false,
  executionAttempted: false,
  executed: false,
  timedOut: false,
  exitCodePresent: false,
  exitCodeZero: false,
  stdoutPresent: false,
  stderrPresent: false,
  shellPolicyDiagnostic: "missing-structured-command",
  shellRetryableReason: "provide-structured-command",
  policyChecked: true,
  binaryAllowlistChecked: false,
  structuredCommandChecked: true,
  resultStatus: "failed",
  safetyFlags: ["metadata-only", "structured-arguments-only", "tool-arguments-omitted", "command-omitted", "stdout-omitted", "stderr-omitted", "cwd-omitted", "natural-language-not-executed", "no-command-executed", "artifact-payload-not-read"],
}, "direct missing shell");

const desktopPolicyEvents = await runEmitEvents({
  CLAW_GATEWAY_TOKEN: token,
  CLAW_WORKSPACE: `${workspace}-desktop-policy`,
  CLAW_ALLOW_DESKTOP_CONTROL: "1",
  CLAW_DESKTOP_APP_ALLOWLIST: "Notes",
  CLAW_DESKTOP_KEY_ALLOWLIST: "command+k",
});

expect(desktopPolicyEvents.some((event) => event.kind === "actionFailed" && event.actionKind === "operateDesktopApp"), "desktop app policy should fail when app is not allowlisted");
const desktopPolicyArtifacts = await readArtifacts(desktopPolicyEvents, "screenshot");
expect(desktopPolicyArtifacts.some((artifact) => artifact.targetApp === "Slack" && artifact.mode === "policy-blocked"), "missing desktop app policy-blocked artifact");
const desktopPolicyArtifact = findArtifactByTitle(desktopPolicyEvents, "screenshot", "desktop-app-policy-");
assertDeliverySafetyMetadata(desktopPolicyArtifact?.metadata, {
  mode: "desktop-control-policy-blocked",
  actionKind: "operateDesktopApp",
  targetKind: "desktopApp",
  desktopPolicyDiagnostic: "app-blocked",
  desktopRetryableReason: "allow-desktop-app",
  automationAttempted: false,
  appPolicyChecked: true,
  keyPolicyChecked: true,
  finalSubmitRequiresApproval: true,
  userApprovalRequired: true,
  draftBodyOmitted: true,
  pasteTextOmitted: true,
  submitBlocked: true,
  allowedKeyCount: 1,
  blockedKeyCount: 1,
  blockedSubmitKeyCount: 1,
  safetyFlags: ["metadata-only", "final-submit-gated", "user-approval-required", "tool-arguments-omitted", "artifact-payload-not-read", "draft-body-omitted", "paste-text-omitted"],
}, "desktop app policy delivery safety");
await assertArtifactsExist(desktopPolicyEvents);
const desktopPolicySnapshot = await assertCapabilitySnapshot(desktopPolicyEvents, {
  allowedActionKinds: envelope.gateway.allowedActionKinds,
});
expect(desktopPolicySnapshot.policies.desktopControl.appAllowlist.includes("Notes"), "desktop snapshot missing Notes allowlist");
expect(
  ["real", "unavailable"].includes(desktopPolicySnapshot.capabilities.desktopControl.state),
  "desktop control snapshot should be real on macOS or unavailable off macOS",
);

const browserPolicyEvents = await runEmitEvents({
  CLAW_GATEWAY_TOKEN: token,
  CLAW_WORKSPACE: `${workspace}-browser-policy`,
  CLAW_ALLOW_BROWSER_CONTROL: "1",
  CLAW_BROWSER_APP_ALLOWLIST: "Firefox",
  CLAW_BROWSER_HOST_ALLOWLIST: "www.google.com",
});

expect(browserPolicyEvents.some((event) => event.kind === "actionFailed" && event.actionKind === "controlBrowser"), "browser policy should fail when browser app is not allowlisted");
const browserPolicyArtifacts = await readArtifacts(browserPolicyEvents, "screenshot");
expect(browserPolicyArtifacts.some((artifact) => artifact.browserApp === "Safari" && artifact.mode === "browser-control-policy-blocked"), "missing browser policy-blocked artifact");
const browserPolicyArtifact = findArtifactByTitle(browserPolicyEvents, "screenshot", "browser-control-2");
assertBrowserControlReviewMetadata(browserPolicyArtifact?.metadata, {
  mode: "browser-control-policy-blocked",
  browserControlPolicy: "enabled",
  browserControlRequested: true,
  openInBrowser: true,
  targetURLPresent: true,
  searchQueryPresent: true,
  localHTMLInput: true,
  networkFetchAttempted: false,
  networkBlocked: false,
  appAllowlistEnforced: true,
  hostAllowlistEnforced: false,
  executed: false,
  timedOut: false,
  resultStatus: "failed",
  safetyFlags: ["metadata-only", "tool-arguments-omitted", "url-omitted", "search-query-omitted", "page-content-omitted", "form-fields-omitted", "candidate-labels-omitted", "artifact-payload-not-read", "browser-app-allowlist-enforced"],
}, "browser app policy");
await assertArtifactsExist(browserPolicyEvents);
const browserPolicySnapshot = await assertCapabilitySnapshot(browserPolicyEvents, {
  allowedActionKinds: envelope.gateway.allowedActionKinds,
});
expect(browserPolicySnapshot.policies.browserControl.appAllowlist.includes("Firefox"), "browser snapshot missing Firefox allowlist");
expect(browserPolicySnapshot.policies.browserControl.hostAllowlist.includes("www.google.com"), "browser snapshot missing host allowlist");
expect(
  ["real", "unavailable"].includes(browserPolicySnapshot.capabilities.browserControl.state),
  "browser control snapshot should be real on macOS or unavailable off macOS",
);

const accessibilityPolicyEvents = await runEmitEvents({
  CLAW_GATEWAY_TOKEN: token,
  CLAW_WORKSPACE: `${workspace}-accessibility-policy`,
  CLAW_ALLOW_ACCESSIBILITY_OBSERVE: "1",
});
await assertArtifactsExist(accessibilityPolicyEvents);
const accessibilityPolicySnapshot = await assertCapabilitySnapshot(accessibilityPolicyEvents, {
  allowedActionKinds: envelope.gateway.allowedActionKinds,
});
expect(
  ["real", "unavailable"].includes(accessibilityPolicySnapshot.capabilities.accessibilityTree.state),
  "accessibility snapshot should be real on macOS or unavailable off macOS",
);
const accessibilityPolicyTrees = await readArtifacts(accessibilityPolicyEvents, "accessibilityTree");
const accessibilityPolicyArtifact = findArtifact(accessibilityPolicyEvents, "accessibilityTree");
assertAccessibilityTreeArtifact(accessibilityPolicyArtifact, accessibilityPolicyTrees[0], {
  mode: ["accessibility-summary", "accessibility-failed", "accessibility-unavailable"],
  policy: "enabled",
  label: "enabled accessibility tree",
});

console.log(`Claw Gateway direct smoke passed (${dryRunEvents.length + emptyExtractionEvents.length + pathEscapeEvents.length + writeFailureEvents.length + replayEvents.length + allowlistEvents.length + missingShellEvents.length + desktopPolicyEvents.length + browserPolicyEvents.length + accessibilityPolicyEvents.length} events)`);

async function runEmitEvents(env, input = envelope) {
  const inputPath = `/private/tmp/claw-gateway-direct-smoke-${crypto.randomUUID()}.json`;
  await fs.writeFile(inputPath, JSON.stringify(input), "utf8");
  const child = spawn(
    process.execPath,
    ["Tools/claw-gateway-server.mjs", "--emit-events", inputPath],
    {
      env: {
        ...process.env,
        ...gatewayPolicyDefaults(),
        ...env,
      },
      stdio: ["ignore", "pipe", "pipe"],
    },
  );

  let stdout = "";
  let stderr = "";
  child.stdout.on("data", (chunk) => {
    stdout += chunk.toString("utf8");
  });
  child.stderr.on("data", (chunk) => {
    stderr += chunk.toString("utf8");
  });

  const exitCode = await new Promise((resolve) => {
    child.on("close", resolve);
  });
  await fs.unlink(inputPath).catch(() => {});

  if (exitCode !== 0) {
    throw new Error(`direct smoke failed with exit ${exitCode}\n${stderr}`);
  }

  return stdout
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line));
}

async function runEmitEventsExpectFailure(env, input = envelope) {
  const inputPath = `/private/tmp/claw-gateway-direct-smoke-${crypto.randomUUID()}.json`;
  await fs.writeFile(inputPath, JSON.stringify(input), "utf8");
  const child = spawn(
    process.execPath,
    ["Tools/claw-gateway-server.mjs", "--emit-events", inputPath],
    {
      env: {
        ...process.env,
        ...gatewayPolicyDefaults(),
        ...env,
      },
      stdio: ["ignore", "pipe", "pipe"],
    },
  );
  let stdout = "";
  let stderr = "";
  child.stdout.on("data", (chunk) => {
    stdout += chunk.toString("utf8");
  });
  child.stderr.on("data", (chunk) => {
    stderr += chunk.toString("utf8");
  });
  const exitCode = await new Promise((resolve) => child.on("close", resolve));
  expect(exitCode !== 0, "direct smoke expected Gateway failure");
  return { stdout, stderr };
}

function groupEventsBySession(events) {
  const groups = new Map();
  for (const event of events) {
    const group = groups.get(event.sessionID) || [];
    group.push(event);
    groups.set(event.sessionID, group);
  }
  return [...groups.values()];
}

function gatewayPolicyDefaults() {
  return {
    CLAW_GATEWAY_HOST: "127.0.0.1",
    CLAW_GATEWAY_PORT: "18789",
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

async function assertArtifactsExist(events) {
  for (const artifact of events.flatMap((event) => event.artifacts || [])) {
    if (artifact.reference?.startsWith("file://")) {
      await fs.access(new URL(artifact.reference));
    }
  }
}

function workspaceFileRoot(events) {
  const diff = events
    .flatMap((event) => event.artifacts || [])
    .find((artifact) => artifact.kind === "fileDiff");
  if (!diff?.reference?.startsWith("file://")) {
    throw new Error("missing fileDiff reference");
  }
  const diffURL = new URL(diff.reference);
  return diffURL.pathname.split("/sessions/")[0] + `/sessions/${diffURL.pathname.split("/sessions/")[1].split("/")[0]}`;
}

function hasArtifact(event, kind) {
  return event.artifacts?.some((artifact) => artifact.kind === kind);
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

async function assertTaskReplayGuard(events, expectedActionCount, label) {
  expect(Array.isArray(events) && events.length > 0, `${label} missing events`);
  const allowedEventKinds = new Set(["gatewayConnected", "artifactStored", "actionSkipped", "sessionCompleted"]);
  expect(events.every((event) => allowedEventKinds.has(event.kind)), `${label} emitted unexpected event kind`);
  expect(!events.some((event) => event.kind === "actionStarted"), `${label} should not start actions`);
  const skippedEvents = events.filter((event) => event.kind === "actionSkipped");
  expect(skippedEvents.length === expectedActionCount, `${label} actionSkipped count mismatch`);
  for (const skipped of skippedEvents) {
    const action = envelope.task.actions.find((candidate) => candidate.id === skipped.actionID);
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
  expect(audit.task?.id === envelope.task.id, `${label} task id mismatch`);
  expect(audit.task?.actionCount === expectedActionCount, `${label} action count mismatch`);
  expect(audit.replay?.count === 1, `${label} replay count mismatch`);
  expect(audit.safety?.businessArtifacts === "not-written", `${label} should not write business artifacts`);
  expect(audit.safety?.handlerExecution === "blocked", `${label} should block handler execution`);
  const serialized = JSON.stringify({ audit, metadata: replayArtifact.metadata });
  for (const forbidden of [
    token,
    "Authorization",
    "Bearer",
    "toolArguments",
    "shellCommand",
    "Open a page and extract structured data",
    "Smoke Page",
    "workspace write verified",
    "targetApp",
    "pasteText",
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
  expect(connectedIndex >= 0, "capability snapshot order check missing gatewayConnected");
  expect(snapshotEventIndex > connectedIndex, "capability snapshot must follow gatewayConnected");
  expect(firstActionIndex > snapshotEventIndex, "capability snapshot must precede first actionStarted");
  const snapshotArtifact = events[snapshotEventIndex].artifacts.find(isCapabilitySnapshotArtifact);
  expect(snapshotArtifact.isRedacted === true, "capability snapshot artifact should be redacted");
  const snapshot = JSON.parse(await fs.readFile(new URL(snapshotArtifact.reference), "utf8"));
  assertCapabilitySnapshotMetadata(snapshotArtifact.metadata, snapshot, "capability snapshot");
  expect(snapshot.mode === "gateway-capability-snapshot", "capability snapshot mode mismatch");
  expect(!JSON.stringify(snapshot).includes(token), "capability snapshot leaked raw token");
  expect(snapshot.token.configured === true, "capability snapshot token should be configured");
  expect(snapshot.token.fingerprint === tokenFingerprint(token), "capability snapshot token fingerprint mismatch");
  expect(snapshot.envelope.tokenFingerprint === tokenFingerprint(token), "capability snapshot envelope fingerprint mismatch");
  if (expected.allowedActionKinds) {
    expect(
      snapshot.envelope.allowedActionKinds.join(",") === [...expected.allowedActionKinds].sort().join(","),
      "capability snapshot allowedActionKinds mismatch",
    );
  }
  expect(snapshot.envelope.actionCount === envelope.task.actions.length, "capability snapshot action count mismatch");
  expect(snapshot.gateway.platform === process.platform, "capability snapshot platform mismatch");
  expect(snapshot.gateway.sessionWorkspace.startsWith(`${snapshot.gateway.workspaceRoot}/sessions/`), "capability snapshot workspace is not session-scoped");
  expect(snapshot.policies.workspace.sessionWorkspace === snapshot.gateway.sessionWorkspace, "capability snapshot workspace policy mismatch");
  expect(snapshot.safety.rawToken === "omitted", "capability snapshot should omit raw token");
  expect(snapshot.safety.toolArguments === "omitted", "capability snapshot should omit toolArguments");
  for (const [capability, state] of Object.entries(expected.capabilities || {})) {
    expect(snapshot.capabilities?.[capability]?.state === state, `capability snapshot ${capability} state mismatch`);
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
    "degradedSignals",
    "handoffStatus",
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
  const expectedKeys = trace.readiness.degradedSignals?.length > 0
    ? allowedKeys
    : allowedKeys.filter((key) => key !== "degradedSignals");
  expect(
    Object.keys(metadata).sort().join(",") === expectedKeys.join(","),
    `${label} agentTrace metadata includes unexpected keys`,
  );
  expect(metadata.readinessScore === String(trace.readiness.score), `${label} readiness score metadata mismatch`);
  expect(metadata.readinessCanContinue === String(trace.readiness.canContinue), `${label} readiness continuation metadata mismatch`);
  expect(metadata.satisfiedSignals === trace.readiness.satisfiedSignals.join(","), `${label} satisfied signals metadata mismatch`);
  if (trace.readiness.degradedSignals?.length > 0) {
    expect(metadata.degradedSignals === trace.readiness.degradedSignals.join(","), `${label} degraded signals metadata mismatch`);
  } else {
    expect(metadata.degradedSignals === undefined, `${label} unexpected degraded signals metadata`);
  }
  expect(metadata.missingSignals === trace.readiness.missingSignals.join(","), `${label} missing signals metadata mismatch`);
  expect(metadata.selectedNextActionKind === trace.selectedNextAction.kind, `${label} selected action metadata mismatch`);
  expect(metadata.selectedNextActionRequiresApproval === String(trace.selectedNextAction.requiresApproval), `${label} selected approval metadata mismatch`);
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
  for (const forbidden of [token, "Authorization", "Bearer", "toolArguments", "sourcePriority", "Smoke Page", "Docs", "notes/result.txt", "https://", "file://", "/sessions/"]) {
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
    "openAttempted",
    "openInBrowser",
    "policyDiagnostic",
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
    "claw gateway smoke search",
    "Smoke Page",
    "Gateway Smoke Page",
    "Run search",
    "Browser extraction works",
    "https://",
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
    "workspace write verified",
	    "notes/result.txt",
	    "../escape.txt",
	    "escape write",
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
    "Shell action was not executed",
    "Run a structured command only if policy allows it",
    "direct missing shell instruction",
    "https://",
    "file://",
    "/sessions/",
    ".build/claw-gateway-direct-smoke",
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
    "Smoke summary ready",
    "https://",
    "file://",
    "/sessions/",
  ]) {
    expect(!serialized.includes(forbidden), `${label} metadata leaked ${forbidden}`);
  }
}

function assertEmptyExtractionCompletenessMetadata(metadata, extraction, label) {
  expect(metadata && typeof metadata === "object", `${label} missing extraction metadata`);
  expect(metadata.extractionReview === "artifactGrounded", `${label} extraction review metadata mismatch`);
  expect(metadata.mode === extraction.mode, `${label} mode metadata mismatch`);
  expect(metadata.validateCompleteness === String(extraction.validateCompleteness), `${label} completeness validation metadata mismatch`);
  expect(Number(metadata.rowCount) === 0, `${label} row count metadata mismatch`);
  expect(metadata.completenessStatus === "empty", `${label} completeness status mismatch`);
  expect(Number(metadata.browserTraceCount) === 0, `${label} browser trace count metadata mismatch`);
  expect(Number(metadata.fileDiffCount) === 0, `${label} file diff count metadata mismatch`);
  expect(Number(metadata.commandOutputCount) === 0, `${label} command output count metadata mismatch`);
  expect(!metadata.sourceArtifactKinds, `${label} source kinds should be omitted when empty`);
  expect(metadata.safetyFlags.includes("row-content-omitted"), `${label} missing row omission safety flag`);
  const serialized = JSON.stringify(metadata);
  for (const forbidden of [token, "Authorization", "Bearer", "toolArguments", "sourcePriority", "Structured result placeholder", "https://", "file://", "/sessions/"]) {
    expect(!serialized.includes(forbidden), `${label} metadata leaked ${forbidden}`);
  }
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

function makeEnvelope(rawToken) {
  const taskID = crypto.randomUUID();
  return {
    schemaVersion: "claw.computer.control.v1",
    sourceApp: "Claw Controller",
    gateway: {
      endpoint: "ws://127.0.0.1:18789",
      deviceName: "smoke",
      securityMode: "mutualApproval",
      tokenFingerprint: tokenFingerprint(rawToken),
      allowedActionKinds: ["observeScreen", "controlBrowser", "manageFiles", "runShellCommand", "extractData", "operateDesktopApp", "runAgentLoop", "composeMessage"],
      requiresApprovalForSensitiveData: true,
      auditEnabled: true,
    },
    task: {
      id: taskID,
      command: "open browser, write files, and dry-run shell",
      summary: "direct smoke",
      sourceDevice: "smoke",
      destinationGateway: "ws://127.0.0.1:18789",
      actions: [
        {
          id: crypto.randomUUID(),
          kind: "observeScreen",
          title: "Observe desktop",
          target: "Desktop Screen",
          instruction: "Capture current screen and accessibility context",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            observationGoal: "observe smoke desktop",
            includeScreenshot: "true",
            includeAccessibilityTree: "true",
            includeWindowTitles: "true",
            maxCandidateControls: "12",
            redaction: "maskSensitiveText",
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
            browserApp: "Safari",
            openInBrowser: "true",
            searchQuery: "claw gateway smoke search",
            searchURLTemplate: "https://www.google.com/search?q={query}",
            captureTrace: "true",
            html: [
              "<html><head><title>Smoke Page</title></head><body>",
              "<h1>Smoke Heading</h1>",
              "<main>Browser extraction works.</main>",
              "<a href=\"https://example.com/docs\">Docs</a>",
              "<table><tr><th>Name</th><th>Status</th></tr><tr><td>Claw</td><td>Ready</td></tr></table>",
              "<form action=\"/search\"><input name=\"query\" placeholder=\"Search\"><button>Run search</button></form>",
              "</body></html>",
            ].join(""),
          },
        },
        {
          id: crypto.randomUUID(),
          kind: "controlBrowser",
          title: "Blocked URL fetch",
          target: "Desktop Browser",
          instruction: "Try to fetch a URL without enabling network policy",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            url: "https://blocked.example/",
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
            writePath: "notes/result.txt",
            writeText: "workspace write verified",
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
          instruction: "Extract data from browser and file artifacts",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            extractionGoal: "collect smoke rows",
            sourcePriority: "browserTrace,fileDiff,commandOutput,accessibilityTree",
            schema: "title:string,source:string,summary:string,confidence:number",
            outputPath: "notes/extracted.json",
            validateCompleteness: "true",
          },
        },
        {
          id: crypto.randomUUID(),
          kind: "runAgentLoop",
          title: "Run agent loop",
          target: "Desktop Agent Loop",
          instruction: "Review observed artifacts and decide the next safe desktop action",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            objective: "finish smoke task with artifact-backed decisions",
            loopMode: "observe-plan-act-verify",
            maxIterations: "3",
            inputSources: "screenObservation,accessibilityTree,browserTrace,fileDiff,commandOutput,messageDraft",
            allowedNextActions: "observeScreen,controlBrowser,manageFiles,extractData,operateDesktopApp,composeMessage",
            approvalRequiredFor: "runShellCommand,operateDesktopAppFinalSubmit,externalNetwork,destructiveFileChange",
            stopBeforeDestructiveAction: "true",
            writeTrace: "true",
          },
        },
        {
          id: crypto.randomUUID(),
          kind: "operateDesktopApp",
          title: "Prepare Slack message",
          target: "Desktop Apps",
          instruction: "Prepare the final Slack message but stop before send",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            targetApp: "Slack",
            automationMode: "accessibility",
            inputMode: "typeOrPaste",
            draftText: "Smoke summary ready for Slack approval.",
            keySequence: "command+k,return",
            finalSubmitRequiresApproval: "true",
            captureBeforeAfter: "true",
          },
        },
        {
          id: crypto.randomUUID(),
          kind: "composeMessage",
          title: "Draft Slack follow-up",
          target: "Slack",
          instruction: "Create a delivery draft and wait for confirmation",
          approval: "gatewayApproval",
          sourceSurface: "composeController",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            channel: "Slack",
            recipient: "reviewer",
            body: "Smoke summary ready for Slack approval.",
          },
        },
      ],
      status: "sent",
      riskScore: 80,
      createdAt: isoNow(),
    },
    approvalSummary: "smoke",
    auditRequired: true,
  };
}

function makeEmptyExtractionEnvelope(rawToken) {
  const taskID = crypto.randomUUID();
  return {
    schemaVersion: "claw.computer.control.v1",
    sourceApp: "Claw Controller",
    gateway: {
      endpoint: "ws://127.0.0.1:18789",
      deviceName: "smoke",
      securityMode: "mutualApproval",
      tokenFingerprint: tokenFingerprint(rawToken),
      allowedActionKinds: ["extractData"],
      requiresApprovalForSensitiveData: true,
      auditEnabled: true,
    },
    task: {
      id: taskID,
      command: "extract without source artifacts",
      summary: "empty extraction smoke",
      sourceDevice: "smoke",
      destinationGateway: "ws://127.0.0.1:18789",
      actions: [
        {
          id: crypto.randomUUID(),
          kind: "extractData",
          title: "Extract empty structured result",
          target: "Desktop Data",
          instruction: "Extract data when no prior artifacts exist",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            extractionGoal: "collect no rows",
            sourcePriority: "browserTrace,fileDiff,commandOutput,accessibilityTree",
            schema: "title:string,source:string,summary:string,confidence:number",
            outputPath: "notes/empty-extracted.json",
            validateCompleteness: "true",
          },
        },
      ],
      status: "sent",
      riskScore: 32,
      createdAt: isoNow(),
    },
    approvalSummary: "empty extraction smoke",
    auditRequired: true,
  };
}

function makeMissingShellEnvelope(rawToken) {
  const taskID = crypto.randomUUID();
  return {
    schemaVersion: "claw.computer.control.v1",
    sourceApp: "Claw Controller",
    gateway: {
      endpoint: "ws://127.0.0.1:18789",
      deviceName: "smoke",
      securityMode: "mutualApproval",
      tokenFingerprint: tokenFingerprint(rawToken),
      allowedActionKinds: ["runShellCommand"],
      requiresApprovalForSensitiveData: true,
      auditEnabled: true,
    },
    task: {
      id: taskID,
      command: "missing structured shell command",
      summary: "missing shell smoke",
      sourceDevice: "smoke",
      destinationGateway: "ws://127.0.0.1:18789",
      actions: [
        {
          id: crypto.randomUUID(),
          kind: "runShellCommand",
          title: "Reject missing shell command",
          target: "Desktop Shell",
          instruction: "direct missing shell instruction",
          approval: "gatewayApproval",
          sourceSurface: "clawGateway",
          handlesSensitiveData: true,
          inputPreview: "smoke",
          toolArguments: {
            cwdPolicy: "workspaceOnly",
          },
        },
      ],
      status: "sent",
      riskScore: 64,
      createdAt: isoNow(),
    },
    approvalSummary: "missing shell smoke",
    auditRequired: true,
  };
}

function makePathEscapeEnvelope(rawToken) {
  const taskID = crypto.randomUUID();
  return {
    schemaVersion: "claw.computer.control.v1",
    sourceApp: "Claw Controller",
    gateway: {
      endpoint: "ws://127.0.0.1:18789",
      deviceName: "smoke",
      securityMode: "mutualApproval",
      tokenFingerprint: tokenFingerprint(rawToken),
      allowedActionKinds: ["manageFiles"],
      requiresApprovalForSensitiveData: true,
      auditEnabled: true,
    },
    task: {
      id: taskID,
      command: "block workspace path escape",
      summary: "path escape smoke",
      sourceDevice: "smoke",
      destinationGateway: "ws://127.0.0.1:18789",
      actions: [
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
            writeText: "escape write",
          },
        },
      ],
      status: "sent",
      riskScore: 52,
      createdAt: isoNow(),
    },
    approvalSummary: "path escape smoke",
    auditRequired: true,
  };
}

function makeWriteFailureEnvelope(rawToken) {
  const taskID = crypto.randomUUID();
  return {
    schemaVersion: "claw.computer.control.v1",
    sourceApp: "Claw Controller",
    gateway: {
      endpoint: "ws://127.0.0.1:18789",
      deviceName: "smoke",
      securityMode: "mutualApproval",
      tokenFingerprint: tokenFingerprint(rawToken),
      allowedActionKinds: ["manageFiles"],
      requiresApprovalForSensitiveData: true,
      auditEnabled: true,
    },
    task: {
      id: taskID,
      command: "record workspace write failure metadata",
      summary: "write failure smoke",
      sourceDevice: "smoke",
      destinationGateway: "ws://127.0.0.1:18789",
      actions: [
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
      ],
      status: "sent",
      riskScore: 52,
      createdAt: isoNow(),
    },
    approvalSummary: "write failure smoke",
    auditRequired: true,
  };
}

function tokenFingerprint(value) {
  return `sha256:${crypto.createHash("sha256").update(value.trim()).digest("hex").slice(0, 12)}`;
}

function isoNow() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

function expect(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}
