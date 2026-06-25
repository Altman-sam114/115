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
expect(dryRunEvents.some((event) => event.kind === "approvalRequested" && event.actionKind === "operateDesktopApp"), "missing desktop app approval gate");
await assertArtifactsExist(dryRunEvents);
const dryRunRoot = workspaceFileRoot(dryRunEvents);
await fs.access(`${dryRunRoot}/notes/result.txt`);
await fs.access(`${dryRunRoot}/notes/extracted.json`);
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
expect(browserTraces.some((trace) => trace.mode === "network-blocked" && trace.source === "https://blocked.example/"), "missing blocked URL browser trace");
const extractedTrace = browserTraces.find((trace) => trace.mode === "artifact-grounded-extraction" && trace.outputPath === "notes/extracted.json");
expect(Boolean(extractedTrace), "missing artifact-grounded extraction trace");
expect(extractedTrace?.sourceArtifacts?.browserTraceCount >= 2, "extraction did not consume browser traces");
expect(extractedTrace?.sourceArtifacts?.fileDiffCount >= 1, "extraction did not consume file diff");
expect(extractedTrace?.sourceArtifacts?.commandOutputCount >= 1, "extraction did not consume command output");
expect(extractedTrace?.rows?.some((row) => row.title === "Smoke Page"), "extraction missing browser page row");
expect(extractedTrace?.rows?.some((row) => row.title === "Docs"), "extraction missing browser link row");
expect(extractedTrace?.rows?.some((row) => row.source?.includes("notes/result.txt")), "extraction missing file row");
const agentTraces = await readArtifacts(dryRunEvents, "agentTrace");
const agentTrace = agentTraces.find((trace) => trace.mode === "agent-loop-trace");
expect(Boolean(agentTrace), "missing observe-plan-act-verify agent trace");
expect(agentTrace?.sourceArtifacts?.browserTraceCount >= 2, "agent loop did not consume browser traces");
expect(agentTrace?.sourceArtifacts?.fileDiffCount >= 1, "agent loop did not consume file diff");
expect(agentTrace?.sourceArtifacts?.commandOutputCount >= 1, "agent loop did not consume command output");
expect(agentTrace?.nextActions?.some((action) => action.kind === "composeMessage"), "agent loop should propose a delivery draft");
expect(agentTrace?.safetyGates?.some((gate) => gate.actionKind === "composeMessage"), "agent loop should gate delivery draft");
const screenArtifacts = await readArtifacts(dryRunEvents, "screenshot");
expect(screenArtifacts.some((artifact) => artifact.observationGoal === "observe smoke desktop"), "missing screen observation goal");
const desktopDryRun = screenArtifacts.find((artifact) => artifact.targetApp === "Slack" && artifact.desktopControlPolicy === "dry-run");
expect(Boolean(desktopDryRun), "missing desktop app dry-run policy artifact");
expect(desktopDryRun?.finalSubmitRequiresApproval === true, "desktop app final submit should require approval");
expect(desktopDryRun?.pasteTextPreview?.includes("Smoke summary ready") === true, "missing desktop app paste preview");
expect(desktopDryRun?.executableKeys?.includes("command+k"), "missing allowlisted desktop key plan");
expect(desktopDryRun?.blockedKeys?.some((item) => item.key === "return" && item.reason === "final_submit_requires_approval"), "missing blocked final submit key");
const axTrees = await readArtifacts(dryRunEvents, "accessibilityTree");
expect(axTrees.some((tree) => tree.includeAccessibilityTree === true && tree.maxCandidateControls === 12), "missing accessibility tree metadata");

const allowlistEvents = await runEmitEvents({
  CLAW_GATEWAY_TOKEN: token,
  CLAW_WORKSPACE: `${workspace}-allowlist`,
  CLAW_ALLOW_SHELL: "1",
  CLAW_SHELL_ALLOWLIST: "pwd",
});

expect(allowlistEvents.some((event) => event.kind === "actionCompleted" && event.actionKind === "runShellCommand"), "allowlisted shell did not complete");
expect(!allowlistEvents.some((event) => event.kind === "actionFailed" && event.actionKind === "runShellCommand"), "allowlisted shell unexpectedly failed");
await assertArtifactsExist(allowlistEvents);

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
await assertArtifactsExist(desktopPolicyEvents);

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
await assertArtifactsExist(browserPolicyEvents);

console.log(`Claw Gateway direct smoke passed (${dryRunEvents.length + allowlistEvents.length + desktopPolicyEvents.length + browserPolicyEvents.length} events)`);

async function runEmitEvents(env) {
  const child = spawn(
    process.execPath,
    ["Tools/claw-gateway-server.mjs", "--emit-events"],
    {
      env: {
        ...process.env,
        ...env,
      },
      stdio: ["pipe", "pipe", "pipe"],
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

  child.stdin.end(JSON.stringify(envelope));

  const exitCode = await new Promise((resolve) => {
    child.on("close", resolve);
  });

  if (exitCode !== 0) {
    throw new Error(`direct smoke failed with exit ${exitCode}\n${stderr}`);
  }

  return stdout
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line));
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
      allowedActionKinds: ["observeScreen", "controlBrowser", "manageFiles", "runShellCommand", "extractData", "operateDesktopApp", "runAgentLoop"],
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
      ],
      status: "sent",
      riskScore: 80,
      createdAt: isoNow(),
    },
    approvalSummary: "smoke",
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
