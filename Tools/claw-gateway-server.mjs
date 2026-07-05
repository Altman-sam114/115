#!/usr/bin/env node
import http from "node:http";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";

const DEFAULT_PORT = 18789;
const SCHEMA_VERSION = "claw.computer.control.v1";
const TASK_REPLAY_CACHE_LIMIT = 128;

function printHelp() {
  console.log(`usage: node Tools/claw-gateway-server.mjs [--once]
       node Tools/claw-gateway-server.mjs --emit-events [envelope.json]

Environment:
  CLAW_GATEWAY_HOST       Host to bind. Default: 127.0.0.1
  CLAW_GATEWAY_PORT       Port to bind. Default: ${DEFAULT_PORT}
  CLAW_GATEWAY_TOKEN      Optional bearer token required from iOS live mode
  CLAW_REQUIRE_TOKEN      Set to 1 to reject requests without a configured token
  CLAW_WORKSPACE          Workspace path. Default: .build/claw-gateway-workspace
  CLAW_ALLOW_SHELL        Set to 1 to allow shell commands after allowlist check
  CLAW_SHELL_ALLOWLIST    Comma-separated shell binaries allowed for real execution
  CLAW_ALLOW_BROWSER_NETWORK
                         Set to 1 to allow browser fetch after host allowlist check
  CLAW_BROWSER_HOST_ALLOWLIST
                         Comma-separated hostnames allowed for browser fetch/open
  CLAW_ALLOW_BROWSER_CONTROL
                         Set to 1 to allow macOS desktop browser open/search
  CLAW_BROWSER_APP_ALLOWLIST
                         Comma-separated browser app names allowed for control
  CLAW_ALLOW_SCREEN_CAPTURE
                         Set to 1 to allow macOS screencapture artifacts
  CLAW_ALLOW_WINDOW_METADATA
                         Set to 1 to allow macOS front window metadata
  CLAW_ALLOW_ACCESSIBILITY_OBSERVE
                         Set to 1 to allow read-only macOS Accessibility summaries
  CLAW_ALLOW_DESKTOP_CONTROL
                         Set to 1 to allow macOS app focus/paste/key actions
  CLAW_DESKTOP_APP_ALLOWLIST
                         Comma-separated app names allowed for desktop control
  CLAW_DESKTOP_KEY_ALLOWLIST
                         Comma-separated key chords allowed for desktop control

This is a local desktop Gateway prototype. It validates a Claw envelope over
WebSocket and streams ClawGatewayEvent JSON back to the iOS controller. It writes
artifact files into the configured workspace. Shell, screen capture, and desktop
UI actions stay dry-run unless explicitly enabled by policy.`);
}

if (process.argv.includes("--help")) {
  printHelp();
  process.exit(0);
}

const options = {
  once: process.argv.includes("--once"),
  host: process.env.CLAW_GATEWAY_HOST || "127.0.0.1",
  port: Number(process.env.CLAW_GATEWAY_PORT || DEFAULT_PORT),
  token: process.env.CLAW_GATEWAY_TOKEN || "",
  requireToken: process.env.CLAW_REQUIRE_TOKEN === "1",
  workspace: resolveWorkspace(process.env.CLAW_WORKSPACE),
  allowShell: process.env.CLAW_ALLOW_SHELL === "1",
  shellAllowlist: parseAllowlist(process.env.CLAW_SHELL_ALLOWLIST),
  allowBrowserNetwork: process.env.CLAW_ALLOW_BROWSER_NETWORK === "1",
  browserHostAllowlist: parseAllowlist(process.env.CLAW_BROWSER_HOST_ALLOWLIST),
  allowBrowserControl: process.env.CLAW_ALLOW_BROWSER_CONTROL === "1",
  browserAppAllowlist: parseAllowlist(process.env.CLAW_BROWSER_APP_ALLOWLIST),
  allowScreenCapture: process.env.CLAW_ALLOW_SCREEN_CAPTURE === "1",
  allowWindowMetadata: process.env.CLAW_ALLOW_WINDOW_METADATA === "1",
  allowAccessibilityObserve: process.env.CLAW_ALLOW_ACCESSIBILITY_OBSERVE === "1",
  allowDesktopControl: process.env.CLAW_ALLOW_DESKTOP_CONTROL === "1",
  desktopAppAllowlist: parseAllowlist(process.env.CLAW_DESKTOP_APP_ALLOWLIST),
  desktopKeyAllowlist: parseAllowlist(
    process.env.CLAW_DESKTOP_KEY_ALLOWLIST || "tab,escape,esc,command+k,command+l,command+t,command+a,command+f,command+c",
  ),
  taskReplayCache: new Map(),
  taskReplayCacheLimit: TASK_REPLAY_CACHE_LIMIT,
};

if (process.argv.includes("--emit-events")) {
  const input = JSON.parse(await readEnvelopeInput());
  const envelopes = Array.isArray(input) ? input : [input];
  for (const envelope of envelopes) {
    const events = await makeGatewayEvents(envelope, options);
    for (const event of events) {
      console.log(JSON.stringify(event));
    }
  }
  process.exit(0);
}

const server = http.createServer((request, response) => {
  response.writeHead(426, { "Content-Type": "application/json" });
  response.end(JSON.stringify({ error: "websocket_required" }));
});

server.on("upgrade", (request, socket, head) => {
  try {
    assertUpgradeRequest(request);
    assertAuthorized(request, options);
    acceptWebSocket(request, socket);
    const connection = new WebSocketConnection(socket);
    if (head.length > 0) {
      connection.push(head);
    }
    connection.onText = async (text) => {
      try {
        const envelope = JSON.parse(text);
        const events = await makeGatewayEvents(envelope, options);
        for (const event of events) {
          connection.send(JSON.stringify(event));
          await sleep(8);
        }
        connection.close();
        if (options.once) {
          server.close();
        }
      } catch (error) {
        connection.send(JSON.stringify(errorEvent(error)));
        connection.close();
      }
    };
  } catch (error) {
    rejectUpgrade(socket, error);
  }
});

server.listen(options.port, options.host, () => {
  console.log(`Claw Gateway listening on ws://${options.host}:${options.port}`);
  console.log(`workspace ${options.workspace}`);
  console.log(
    `shell ${options.allowShell ? "enabled" : "dry-run"} allowlist=${[...options.shellAllowlist].join(",") || "empty"}`,
  );
  console.log(
    `screenCapture ${options.allowScreenCapture ? "enabled" : "dry-run"} windowMetadata=${options.allowWindowMetadata ? "enabled" : "dry-run"}`,
  );
  console.log(
    `accessibilityObserve ${options.allowAccessibilityObserve ? "enabled" : "dry-run"}`,
  );
  console.log(
    `browserControl ${options.allowBrowserControl ? "enabled" : "dry-run"} appAllowlist=${[...options.browserAppAllowlist].join(",") || "empty"}`,
  );
  console.log(
    `desktopControl ${options.allowDesktopControl ? "enabled" : "dry-run"} appAllowlist=${[...options.desktopAppAllowlist].join(",") || "empty"}`,
  );
  if (options.token) {
    console.log(`token fingerprint ${tokenFingerprint(options.token)}`);
  } else {
    console.log("token disabled; set CLAW_GATEWAY_TOKEN for paired iOS live mode");
  }
});

function assertUpgradeRequest(request) {
  const upgrade = String(request.headers.upgrade || "").toLowerCase();
  const key = request.headers["sec-websocket-key"];
  if (upgrade !== "websocket" || typeof key !== "string") {
    throw new GatewayError(400, "invalid_websocket_upgrade");
  }
  const schema = request.headers["x-claw-schema"];
  if (schema && schema !== SCHEMA_VERSION) {
    throw new GatewayError(400, "unsupported_schema_header");
  }
}

function assertAuthorized(request, config) {
  if (!config.token && !config.requireToken) {
    return;
  }
  if (!config.token) {
    throw new GatewayError(401, "gateway_token_not_configured");
  }
  const authorization = String(request.headers.authorization || "");
  if (authorization !== `Bearer ${config.token}`) {
    throw new GatewayError(401, "invalid_bearer_token");
  }
}

function acceptWebSocket(request, socket) {
  const key = request.headers["sec-websocket-key"];
  const accept = crypto
    .createHash("sha1")
    .update(`${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`)
    .digest("base64");
  socket.write(
    [
      "HTTP/1.1 101 Switching Protocols",
      "Upgrade: websocket",
      "Connection: Upgrade",
      `Sec-WebSocket-Accept: ${accept}`,
      "\r\n",
    ].join("\r\n"),
  );
}

function rejectUpgrade(socket, error) {
  const status = error instanceof GatewayError ? error.status : 500;
  const code = error instanceof GatewayError ? error.code : "internal_error";
  socket.write(
    [
      `HTTP/1.1 ${status} ${statusText(status)}`,
      "Content-Type: application/json",
      "Connection: close",
      "",
      JSON.stringify({ error: code }),
    ].join("\r\n"),
  );
  socket.destroy();
}

async function readEnvelopeInput() {
  const args = process.argv.slice(2).filter((arg) => !arg.startsWith("--"));
  if (args.length > 0) {
    return fs.readFile(args[0], "utf8");
  }
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString("utf8");
}

class WebSocketConnection {
  constructor(socket) {
    this.socket = socket;
    this.buffer = Buffer.alloc(0);
    this.onText = () => {};
    socket.on("data", (chunk) => this.push(chunk));
    socket.on("error", () => {});
  }

  push(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    while (this.buffer.length >= 2) {
      const parsed = parseFrame(this.buffer);
      if (!parsed) {
        return;
      }
      this.buffer = this.buffer.subarray(parsed.consumed);
      if (parsed.opcode === 0x8) {
        this.close();
        return;
      }
      if (parsed.opcode === 0x9) {
        this.socket.write(encodeFrame(parsed.payload, 0xA));
        continue;
      }
      if (parsed.opcode === 0x1) {
        this.onText(parsed.payload.toString("utf8"));
      }
    }
  }

  send(text) {
    if (!this.socket.destroyed) {
      this.socket.write(encodeFrame(Buffer.from(text, "utf8"), 0x1));
    }
  }

  close() {
    if (!this.socket.destroyed) {
      this.socket.end(encodeFrame(Buffer.alloc(0), 0x8));
    }
  }
}

function parseFrame(buffer) {
  const first = buffer[0];
  const second = buffer[1];
  const opcode = first & 0x0f;
  const masked = (second & 0x80) !== 0;
  let length = second & 0x7f;
  let offset = 2;

  if (length === 126) {
    if (buffer.length < offset + 2) {
      return null;
    }
    length = buffer.readUInt16BE(offset);
    offset += 2;
  } else if (length === 127) {
    if (buffer.length < offset + 8) {
      return null;
    }
    const high = buffer.readUInt32BE(offset);
    if (high !== 0) {
      throw new GatewayError(1009, "frame_too_large");
    }
    length = buffer.readUInt32BE(offset + 4);
    offset += 8;
  }

  const maskOffset = offset;
  if (masked) {
    offset += 4;
  }
  if (buffer.length < offset + length) {
    return null;
  }

  let payload = buffer.subarray(offset, offset + length);
  if (masked) {
    const mask = buffer.subarray(maskOffset, maskOffset + 4);
    payload = Buffer.from(payload.map((byte, index) => byte ^ mask[index % 4]));
  }

  return {
    opcode,
    payload,
    consumed: offset + length,
  };
}

function encodeFrame(payload, opcode) {
  const length = payload.length;
  let header;
  if (length < 126) {
    header = Buffer.from([0x80 | opcode, length]);
  } else if (length < 65536) {
    header = Buffer.alloc(4);
    header[0] = 0x80 | opcode;
    header[1] = 126;
    header.writeUInt16BE(length, 2);
  } else {
    header = Buffer.alloc(10);
    header[0] = 0x80 | opcode;
    header[1] = 127;
    header.writeUInt32BE(0, 2);
    header.writeUInt32BE(length, 6);
  }
  return Buffer.concat([header, payload]);
}

async function makeGatewayEvents(envelope, config) {
  validateEnvelope(envelope, config);
  const replayKey = taskReplayKey(envelope);
  const cache = config.taskReplayCache;
  if (!cache) {
    return buildGatewayEvents(envelope, config);
  }

  const existingRecord = cache.get(replayKey);
  if (existingRecord) {
    return makeTaskReplayGuardEvents(envelope, config, existingRecord);
  }

  const firstSessionID = crypto.randomUUID();
  const replayRecord = makeTaskReplayRecord(envelope, replayKey, firstSessionID);
  cache.set(replayKey, replayRecord);
  pruneTaskReplayCache(cache, config.taskReplayCacheLimit || TASK_REPLAY_CACHE_LIMIT);

  try {
    const events = await buildGatewayEvents(envelope, config, firstSessionID);
    markTaskReplayCompleted(replayRecord, events);
    return events;
  } catch (error) {
    markTaskReplayFailed(replayRecord, error);
    throw error;
  }
}

async function buildGatewayEvents(envelope, config, sessionID = crypto.randomUUID()) {
  const task = envelope.task;
  const sessionWorkspace = path.join(config.workspace, "sessions", sessionID);
  await fs.mkdir(sessionWorkspace, { recursive: true });
  const sessionContext = makeSessionContext();
  let sequence = 0;
  const events = [
    event({
      sessionID,
      taskID: task.id,
      sequence: sequence++,
      kind: "gatewayConnected",
      summary: `Gateway accepted task from ${envelope.sourceApp}; workspace=${sessionWorkspace}`,
    }),
  ];
  const sessionConfig = { ...config, sessionWorkspace, sessionContext };
  const capabilitySnapshot = gatewayCapabilitySnapshot(envelope, config, sessionID, sessionWorkspace);
  const capabilitySnapshotArtifact = await writeArtifact(
    "auditLog",
    "gateway-capability-snapshot.json",
    capabilitySnapshot,
    true,
    sessionConfig,
    gatewayCapabilitySnapshotMetadata(capabilitySnapshot),
  );
  events.push(
    event({
      sessionID,
      taskID: task.id,
      sequence: sequence++,
      kind: "artifactStored",
      artifacts: [capabilitySnapshotArtifact],
      summary: "Stored Gateway capability snapshot audit artifact",
    }),
  );

  for (const [index, action] of task.actions.entries()) {
    events.push(
      event({
        sessionID,
        taskID: task.id,
        sequence: sequence++,
        kind: "actionStarted",
        action,
        resultStatus: "running",
        summary: `Starting ${action.kind} on ${action.target}`,
      }),
    );

    const result = await runAction(action, index, envelope.gateway, sessionConfig);
    if (result.artifacts.length > 0) {
      events.push(
        event({
          sessionID,
          taskID: task.id,
          sequence: sequence++,
          kind: "artifactStored",
          action,
          resultStatus: "running",
          artifacts: result.artifacts,
          summary: `Stored ${result.artifacts.length} artifact references`,
        }),
      );
    }

    events.push(
      event({
        sessionID,
        taskID: task.id,
        sequence: sequence++,
        kind: eventKindForStatus(result.status),
        action,
        resultStatus: result.status,
        summary: result.summary,
        isRetryable: result.isRetryable,
      }),
    );
  }

  events.push(
    event({
      sessionID,
      taskID: task.id,
      sequence,
      kind: "sessionCompleted",
      summary: "Gateway event stream completed",
    }),
  );
  return events;
}

async function makeTaskReplayGuardEvents(envelope, config, record) {
  record.replayCount += 1;
  record.lastReplayAt = isoNow();
  const sessionID = crypto.randomUUID();
  const task = envelope.task;
  const sessionWorkspace = path.join(config.workspace, "sessions", sessionID);
  await fs.mkdir(sessionWorkspace, { recursive: true });
  const sessionConfig = {
    ...config,
    sessionWorkspace,
    sessionContext: makeSessionContext(),
  };
  let sequence = 0;
  const events = [
    event({
      sessionID,
      taskID: task.id,
      sequence: sequence++,
      kind: "gatewayConnected",
      summary: `Gateway replay guard recognized duplicate task; firstSession=${record.firstSessionID} status=${record.status}`,
    }),
  ];

  const audit = taskReplayGuardAudit(envelope, record, sessionID);
  const replayArtifact = await writeArtifact(
    "auditLog",
    "task-replay-guard.json",
    audit,
    true,
    sessionConfig,
    taskReplayGuardMetadata(audit),
  );
  events.push(
    event({
      sessionID,
      taskID: task.id,
      sequence: sequence++,
      kind: "artifactStored",
      artifacts: [replayArtifact],
      summary: "Stored Gateway task replay guard audit artifact",
    }),
  );

  for (const action of task.actions) {
    events.push(
      event({
        sessionID,
        taskID: task.id,
        sequence: sequence++,
        kind: "actionSkipped",
        action,
        resultStatus: "skipped",
        summary: `${action.title} skipped by Gateway replay guard; first session ${record.firstSessionID} already accepted this task`,
      }),
    );
  }

  events.push(
    event({
      sessionID,
      taskID: task.id,
      sequence,
      kind: "sessionCompleted",
      summary: "Gateway replay guard completed without re-running actions",
    }),
  );
  return events;
}

function makeSessionContext() {
  return {
    artifacts: [],
    browserTraces: [],
    screenObservations: [],
    accessibilityTrees: [],
    fileDiffs: [],
    commandOutputs: [],
    messageDrafts: [],
    agentTraces: [],
  };
}

function taskReplayKey(envelope) {
  return `task:${hashJSON({
    schemaVersion: envelope.schemaVersion,
    taskID: envelope.task.id,
    tokenFingerprint: envelope.gateway?.tokenFingerprint || "",
  })}`;
}

function taskReplayDigest(envelope) {
  return `sha256:${hashJSON({
    schemaVersion: envelope.schemaVersion,
    taskID: envelope.task.id,
    tokenFingerprint: envelope.gateway?.tokenFingerprint || "",
    actionRefs: sortedStrings(envelope.task.actions.map((action) => `${action?.id || ""}:${action?.kind || ""}`)),
  }).slice(0, 16)}`;
}

function hashJSON(value) {
  return crypto.createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function makeTaskReplayRecord(envelope, replayKey, firstSessionID) {
  const actionKinds = sortedStrings(envelope.task.actions.map((action) => action?.kind).filter(Boolean));
  return {
    replayKey,
    taskID: envelope.task.id,
    taskDigest: taskReplayDigest(envelope),
    firstSessionID,
    firstSeenAt: isoNow(),
    completedAt: "",
    failedAt: "",
    lastReplayAt: "",
    replayCount: 0,
    status: "running",
    actionCount: envelope.task.actions.length,
    actionKinds,
    eventCount: 0,
    finalSequence: null,
    finalEventKind: "",
    failureCode: "",
  };
}

function markTaskReplayCompleted(record, events) {
  const finalEvent = events.at(-1);
  record.status = "completed";
  record.completedAt = isoNow();
  record.eventCount = events.length;
  record.finalSequence = finalEvent?.sequence ?? null;
  record.finalEventKind = finalEvent?.kind || "";
}

function markTaskReplayFailed(record, error) {
  record.status = "failed";
  record.failedAt = isoNow();
  record.failureCode = error instanceof GatewayError ? error.code : "internal_error";
}

function pruneTaskReplayCache(cache, limit) {
  while (cache.size > limit) {
    const oldestKey = cache.keys().next().value;
    if (!oldestKey) {
      return;
    }
    cache.delete(oldestKey);
  }
}

function taskReplayGuardAudit(envelope, record, replaySessionID) {
  const replayDigest = taskReplayDigest(envelope);
  return {
    mode: "gateway-task-replay-guard",
    createdAt: isoNow(),
    decision: "skip-duplicate-task",
    reason: "task id was already accepted by this Gateway process",
    task: {
      id: record.taskID,
      replayDigest,
      digestMatchesFirst: replayDigest === record.taskDigest,
      actionCount: envelope.task.actions.length,
      actionKinds: sortedStrings(envelope.task.actions.map((action) => action?.kind).filter(Boolean)),
    },
    sessions: {
      firstSessionID: record.firstSessionID,
      replaySessionID,
    },
    firstRun: {
      status: record.status,
      firstSeenAt: record.firstSeenAt,
      completedAt: record.completedAt,
      failedAt: record.failedAt,
      eventCount: record.eventCount,
      finalSequence: record.finalSequence,
      finalEventKind: record.finalEventKind,
      failureCode: record.failureCode,
    },
    replay: {
      count: record.replayCount,
      replayedAt: record.lastReplayAt,
    },
    safety: {
      rawCredential: "omitted",
      authorization: "omitted",
      naturalLanguage: "omitted",
      structuredArguments: "omitted",
      actionPayloads: "omitted",
      workspacePaths: "omitted",
      businessArtifacts: "not-written",
      handlerExecution: "blocked",
    },
  };
}

function taskReplayGuardMetadata(audit) {
  return compactMetadata({
    replayGuard: "taskReplayGuard",
    decision: audit.decision,
    taskID: audit.task?.id,
    replayDigest: audit.task?.replayDigest,
    digestMatchesFirst: audit.task?.digestMatchesFirst,
    firstSessionID: audit.sessions?.firstSessionID,
    originalStatus: audit.firstRun?.status,
    replayCount: audit.replay?.count,
    actionCount: audit.task?.actionCount,
    actionKinds: audit.task?.actionKinds,
    safetyFlags: [
      "process-local",
      "actions-skipped",
      "business-artifacts-not-written",
      "credentials-omitted",
      "structured-arguments-omitted",
    ],
  });
}

function validateEnvelope(envelope, config) {
  if (envelope.schemaVersion !== SCHEMA_VERSION) {
    throw new GatewayError(400, "unsupported_schema");
  }
  if (!envelope.task || !Array.isArray(envelope.task.actions)) {
    throw new GatewayError(400, "invalid_task");
  }
  if (typeof envelope.task.id !== "string" || envelope.task.id.trim().length === 0) {
    throw new GatewayError(400, "invalid_task_id");
  }
  if (config.token) {
    const expected = tokenFingerprint(config.token);
    if (envelope.gateway?.tokenFingerprint !== expected) {
      throw new GatewayError(401, "token_fingerprint_mismatch");
    }
  }
}

function gatewayCapabilitySnapshot(envelope, config, sessionID, sessionWorkspace) {
  const actions = Array.isArray(envelope.task?.actions) ? envelope.task.actions : [];
  const actionKinds = sortedStrings(actions.map((action) => action?.kind).filter(Boolean));
  const allowedActionKinds = sortedStrings(envelope.gateway?.allowedActionKinds || []);
  return {
    mode: "gateway-capability-snapshot",
    createdAt: isoNow(),
    session: {
      id: sessionID,
    },
    gateway: {
      workspaceRoot: config.workspace,
      sessionWorkspace,
      platform: process.platform,
      arch: process.arch,
      nodeVersion: process.version,
      host: config.host || "",
      port: Number.isFinite(config.port) ? config.port : null,
    },
    token: {
      configured: Boolean(config.token),
      required: Boolean(config.requireToken),
      fingerprint: config.token ? tokenFingerprint(config.token) : "",
    },
    envelope: {
      schemaVersion: envelope.schemaVersion || "",
      sourceApp: envelope.sourceApp || "",
      gatewayEndpoint: envelope.gateway?.endpoint || "",
      gatewayDeviceName: envelope.gateway?.deviceName || "",
      securityMode: envelope.gateway?.securityMode || "",
      tokenFingerprint: envelope.gateway?.tokenFingerprint || "",
      allowedActionKinds,
      auditEnabled: Boolean(envelope.gateway?.auditEnabled),
      requiresApprovalForSensitiveData: Boolean(envelope.gateway?.requiresApprovalForSensitiveData),
      actionCount: actions.length,
      actionKinds,
    },
    policies: {
      workspace: {
        root: config.workspace,
        sessionWorkspace,
        pathPolicy: "session-workspace-only",
      },
      shell: {
        enabled: Boolean(config.allowShell),
        allowlist: sortedAllowlist(config.shellAllowlist),
      },
      browserNetwork: {
        enabled: Boolean(config.allowBrowserNetwork),
        hostAllowlist: sortedAllowlist(config.browserHostAllowlist),
      },
      browserControl: {
        enabled: Boolean(config.allowBrowserControl),
        appAllowlist: sortedAllowlist(config.browserAppAllowlist),
        hostAllowlist: sortedAllowlist(config.browserHostAllowlist),
      },
      screenCapture: {
        enabled: Boolean(config.allowScreenCapture),
      },
      windowMetadata: {
        enabled: Boolean(config.allowWindowMetadata),
      },
      accessibilityTree: {
        enabled: Boolean(config.allowAccessibilityObserve),
        maxCandidateControlsHardLimit: 50,
        scope: "front-application-window-summary",
      },
      desktopControl: {
        enabled: Boolean(config.allowDesktopControl),
        appAllowlist: sortedAllowlist(config.desktopAppAllowlist),
        keyAllowlist: sortedAllowlist(config.desktopKeyAllowlist),
        finalSubmitGate: "required",
      },
    },
    capabilities: {
      workspace: workspaceCapability(config, sessionWorkspace),
      shell: shellCapability(config),
      browserNetwork: browserNetworkCapability(config),
      browserControl: browserControlCapability(config),
      screenCapture: macPolicyCapability({
        enabled: config.allowScreenCapture,
        realReason: "macOS screencapture can run when the host has Screen Recording permission.",
        dryRunReason: "CLAW_ALLOW_SCREEN_CAPTURE is not enabled.",
        unavailableReason: "Screen capture is currently implemented only for macOS Gateway hosts.",
      }),
      windowMetadata: macPolicyCapability({
        enabled: config.allowWindowMetadata,
        realReason: "macOS front window metadata can be collected through System Events.",
        dryRunReason: "CLAW_ALLOW_WINDOW_METADATA is not enabled.",
        unavailableReason: "Window metadata is currently implemented only for macOS Gateway hosts.",
      }),
      accessibilityTree: accessibilityTreeCapability(config),
      desktopControl: desktopControlCapability(config),
    },
    safety: {
      rawToken: "omitted",
      authorizationHeader: "omitted",
      naturalLanguageDirectExecution: "blocked",
      actionInstructions: "omitted",
      toolArguments: "omitted",
      browserPageContent: "omitted",
      commandOutput: "omitted",
      screenshotContent: "omitted",
      accessibilityText: "summary-only",
      draftContent: "omitted",
      workspacePolicy: "session-workspace-only",
      allowlistsEnforced: true,
      finalSubmitGated: true,
      executionSource: "structured-tool-arguments-only",
    },
  };
}

function gatewayCapabilitySnapshotMetadata(snapshot) {
  return compactMetadata({
    snapshotKind: "gatewayCapability",
    tokenConfigured: snapshot.token?.configured,
    tokenRequired: snapshot.token?.required,
    tokenFingerprint: snapshot.token?.fingerprint,
    allowedActionKinds: snapshot.envelope?.allowedActionKinds,
    workspaceState: snapshot.capabilities?.workspace?.state,
    shellState: snapshot.capabilities?.shell?.state,
    browserControlState: snapshot.capabilities?.browserControl?.state,
    browserNetworkState: snapshot.capabilities?.browserNetwork?.state,
    screenCaptureState: snapshot.capabilities?.screenCapture?.state,
    windowMetadataState: snapshot.capabilities?.windowMetadata?.state,
    accessibilityTreeState: snapshot.capabilities?.accessibilityTree?.state,
    desktopControlState: snapshot.capabilities?.desktopControl?.state,
    safetyFlags: [
      "allowlists-enforced",
      "workspace-only",
      "raw-token-omitted",
      "final-submit-gated",
    ],
    platform: snapshot.gateway?.platform,
  });
}

function workspaceCapability(config, sessionWorkspace) {
  return {
    state: "workspace-only",
    reason: "File artifacts and managed writes are constrained to the session workspace.",
    root: config.workspace,
    sessionWorkspace,
  };
}

function shellCapability(config) {
  if (config.allowShell && config.shellAllowlist?.size > 0) {
    return {
      state: "real",
      reason: "CLAW_ALLOW_SHELL is enabled and shell binaries must match CLAW_SHELL_ALLOWLIST.",
    };
  }
  return {
    state: "dry-run",
    reason: config.allowShell
      ? "CLAW_SHELL_ALLOWLIST is empty, so shell commands remain dry-run."
      : "CLAW_ALLOW_SHELL is not enabled.",
  };
}

function browserNetworkCapability(config) {
  if (config.allowBrowserNetwork && config.browserHostAllowlist?.size > 0) {
    return {
      state: "real",
      reason: "Browser fetch can run for hosts in CLAW_BROWSER_HOST_ALLOWLIST.",
    };
  }
  return {
    state: "disabled",
    reason: config.allowBrowserNetwork
      ? "CLAW_BROWSER_HOST_ALLOWLIST is empty, so browser fetch is disabled."
      : "CLAW_ALLOW_BROWSER_NETWORK is not enabled.",
  };
}

function browserControlCapability(config) {
  if (!config.allowBrowserControl) {
    return {
      state: "dry-run",
      reason: "CLAW_ALLOW_BROWSER_CONTROL is not enabled.",
    };
  }
  if (process.platform !== "darwin") {
    return {
      state: "unavailable",
      reason: "Desktop browser control is currently implemented only for macOS Gateway hosts.",
    };
  }
  if (config.browserAppAllowlist?.size === 0 || config.browserHostAllowlist?.size === 0) {
    return {
      state: "disabled",
      reason: "Browser control requires both browser app and host allowlists.",
    };
  }
  return {
    state: "real",
    reason: "Allowed desktop browsers can be opened on macOS for allowlisted hosts.",
  };
}

function macPolicyCapability({ enabled, realReason, dryRunReason, unavailableReason }) {
  if (!enabled) {
    return {
      state: "dry-run",
      reason: dryRunReason,
    };
  }
  if (process.platform !== "darwin") {
    return {
      state: "unavailable",
      reason: unavailableReason,
    };
  }
  return {
    state: "real",
    reason: realReason,
  };
}

function accessibilityTreeCapability(config) {
  if (!config.allowAccessibilityObserve) {
    return {
      state: "dry-run",
      reason: "CLAW_ALLOW_ACCESSIBILITY_OBSERVE is not enabled.",
    };
  }
  if (process.platform !== "darwin") {
    return {
      state: "unavailable",
      reason: "Accessibility observation summaries are currently implemented only for macOS Gateway hosts.",
    };
  }
  return {
    state: "real",
    reason: "Read-only macOS Accessibility summaries can run for the front application after user-granted Accessibility permission.",
  };
}

function desktopControlCapability(config) {
  if (!config.allowDesktopControl) {
    return {
      state: "dry-run",
      reason: "CLAW_ALLOW_DESKTOP_CONTROL is not enabled.",
    };
  }
  if (process.platform !== "darwin") {
    return {
      state: "unavailable",
      reason: "Desktop app control is currently implemented only for macOS Gateway hosts.",
    };
  }
  if (config.desktopAppAllowlist?.size === 0) {
    return {
      state: "disabled",
      reason: "Desktop app control requires CLAW_DESKTOP_APP_ALLOWLIST.",
    };
  }
  return {
    state: "real",
    reason: "Allowlisted macOS apps can be focused, receive prepared text, and run allowlisted non-submit keys.",
  };
}

function event({
  sessionID,
  taskID,
  sequence,
  kind,
  action = null,
  resultStatus = null,
  summary,
  artifacts = [],
  isRetryable = false,
}) {
  return {
    id: crypto.randomUUID(),
    sessionID,
    taskID,
    sequence,
    kind,
    ...(action
      ? {
          actionID: action.id,
          actionKind: action.kind,
          actionTitle: action.title,
          resultStatus,
        }
      : {}),
    summary,
    artifacts,
    isRetryable,
    retryCount: 0,
    createdAt: isoNow(),
  };
}

async function runAction(action, index, gateway, config) {
  const policy = actionPolicy(action, gateway);
  if (!policy.allowed) {
    const artifacts = [
      await writeArtifact(
        "auditLog",
        `policy-skip-${index + 1}.json`,
        {
          actionID: action.id,
          actionKind: action.kind,
          reason: policy.reason,
          target: action.target,
        },
        true,
        config,
      ),
    ];
    return {
      status: "skipped",
      summary: `${action.title} skipped: ${policy.reason}`,
      artifacts,
      isRetryable: false,
    };
  }

  switch (action.kind) {
    case "runAgentLoop":
      return agentLoopAction(action, index, config);
    case "observeScreen":
      return observeScreenAction(action, index, config);
    case "controlBrowser":
      return controlBrowserAction(action, index, config);
    case "manageFiles":
      return manageFilesAction(action, index, config);
    case "runShellCommand":
      return runShellAction(action, index, config);
    case "extractData":
      return extractDataAction(action, index, config);
    case "operateDesktopApp":
      return desktopAppAction(action, index, config);
    case "composeMessage":
    case "composeEmail":
      return messageDraftAction(action, index, config);
    default:
      return genericAuditAction(action, index, config);
  }
}

function actionPolicy(action, gateway) {
  const allowed = new Set(gateway?.allowedActionKinds || []);
  if (action.approval === "blocked" || !allowed.has(action.kind)) {
    return { allowed: false, reason: "approval or action whitelist blocked this action" };
  }
  return { allowed: true, reason: "allowed" };
}

async function observeScreenAction(action, index, config) {
  const args = action.toolArguments || {};
  const observationGoal = args.observationGoal || action.instruction;
  const windows = await collectWindowMetadata(config);
  const capture = await captureScreenIfAllowed(index, config);
  const accessibilityTree = await collectAccessibilityTreeSummary(action, windows, config);
  const observation = {
    mode: capture.mode,
    observationGoal,
    includeScreenshot: args.includeScreenshot !== "false",
    includeWindowTitles: args.includeWindowTitles !== "false",
    capturePolicy: config.allowScreenCapture ? "enabled" : "dry-run",
    windowMetadataPolicy: config.allowWindowMetadata ? "enabled" : "dry-run",
    screenshotArtifact: capture.artifact?.reference || null,
    screenshotError: capture.error || null,
    note: capture.note,
    platform: process.platform,
    redaction: args.redaction || "required",
    target: action.target,
    windows,
  };
  const artifacts = [];
  if (capture.artifact) {
    artifacts.push(capture.artifact);
  }
  artifacts.push(
    await writeArtifact(
      "screenshot",
      `screen-observation-${index + 1}.json`,
      observation,
      true,
      config,
    ),
  );
  artifacts.push(
    await writeArtifact(
      "accessibilityTree",
      `accessibility-tree-${index + 1}.json`,
      accessibilityTree,
      true,
      config,
      accessibilityTreeMetadata(accessibilityTree),
    ),
  );
  return {
    status: "succeeded",
    summary: `${action.title} produced ${capture.mode} screen observation artifacts`,
    artifacts,
    isRetryable: false,
  };
}

async function captureScreenIfAllowed(index, config) {
  if (!config.allowScreenCapture) {
    return {
      mode: "dry-run",
      note: "Screen capture policy disabled. Set CLAW_ALLOW_SCREEN_CAPTURE=1 to allow macOS screencapture.",
    };
  }
  if (process.platform !== "darwin") {
    return {
      mode: "screen-capture-unavailable",
      error: `unsupported platform ${process.platform}`,
      note: "Screen capture is currently implemented only for macOS Gateway hosts.",
    };
  }

  const screenshotPath = path.join(config.sessionWorkspace, `screen-capture-${index + 1}.png`);
  const result = await runProcess("/usr/sbin/screencapture", ["-x", screenshotPath], config.sessionWorkspace, 10000);
  if (result.exitCode !== 0) {
    return {
      mode: "screen-capture-failed",
      error: normalizeText(result.stderr || result.stdout || "screencapture failed").slice(0, 500),
      note: "macOS may require Screen Recording permission for the terminal or Gateway host.",
    };
  }

  return {
    mode: "screen-capture",
    artifact: rememberExistingArtifact(
      "screenshot",
      `screen-capture-${index + 1}.png`,
      screenshotPath,
      true,
      {
        mode: "screen-capture",
        filePath: screenshotPath,
        note: "PNG screenshot captured by macOS screencapture under explicit Gateway policy.",
      },
      config,
    ),
    note: "PNG screenshot captured by macOS screencapture under explicit Gateway policy.",
  };
}

async function collectWindowMetadata(config) {
  if (!config.allowWindowMetadata || process.platform !== "darwin") {
    return [
      {
        title: "Active Window Placeholder",
        app: "Claw Gateway Prototype",
        focused: true,
        mode: "dry-run",
      },
    ];
  }

  const script = [
    'tell application "System Events"',
    'set frontProcess to first application process whose frontmost is true',
    'set appName to name of frontProcess',
    'set windowTitle to ""',
    'try',
    'set windowTitle to name of front window of frontProcess',
    'end try',
    'return appName & "\\n" & windowTitle',
    'end tell',
  ].join("\n");
  const result = await runProcess("/usr/bin/osascript", ["-e", script], config.sessionWorkspace, 8000);
  if (result.exitCode !== 0) {
    return [
      {
        title: "Window metadata unavailable",
        app: "macOS",
        focused: true,
        mode: "metadata-failed",
        error: normalizeText(result.stderr || result.stdout || "osascript failed").slice(0, 300),
      },
    ];
  }
  const [appName, windowTitle] = result.stdout.split("\n");
  return [
    {
      title: windowTitle?.trim() || "Untitled front window",
      app: appName?.trim() || "Unknown App",
      focused: true,
      mode: "front-window-metadata",
    },
  ];
}

function accessibilityNodesFromWindows(windows) {
  return windows.map((window, index) => ({
    role: "AXWindow",
    title: safeAccessibilityText(window.title || `Window ${index + 1}`),
    app: safeAccessibilityText(window.app || "Unknown App"),
    focused: Boolean(window.focused),
    sourceMode: window.mode || "unknown",
    children: [
      { role: "AXButton", label: "Confirm", action: "press", confidence: 0.4 },
      { role: "AXTextField", label: "Input", action: "type", confidence: 0.4 },
    ],
  }));
}

async function collectAccessibilityTreeSummary(action, windows, config) {
  const args = action.toolArguments || {};
  const includeAccessibilityTree = args.includeAccessibilityTree !== "false";
  const maxCandidateControls = clampInteger(Number(args.maxCandidateControls || 20), 1, 50);
  const base = {
    mode: "dry-run",
    accessibilityPolicy: "dry-run",
    includeAccessibilityTree,
    maxCandidateControls,
    observationGoal: safeAccessibilityText(args.observationGoal || action.target || ""),
    redaction: args.redaction || "required",
    platform: process.platform,
    target: safeAccessibilityText(action.target || ""),
    nodeCount: 0,
    candidateControlCount: 0,
    nodes: [],
    safety: {
      textPolicy: "label-title-summary-only",
      values: "omitted",
      passwordFields: "omitted",
      actionExecution: "not-supported",
      source: "structured-tool-arguments-only",
    },
  };

  if (!includeAccessibilityTree) {
    return {
      ...base,
      mode: "not-requested",
      accessibilityPolicy: "not-requested",
      note: "toolArguments.includeAccessibilityTree=false; Gateway wrote an audit summary without UI nodes.",
    };
  }

  if (!config.allowAccessibilityObserve) {
    const nodes = accessibilityNodesFromWindows(windows).slice(0, maxCandidateControls);
    return {
      ...base,
      mode: config.allowWindowMetadata && process.platform === "darwin" ? "window-metadata" : "dry-run",
      accessibilityPolicy: "dry-run",
      nodes,
      nodeCount: nodes.length,
      candidateControlCount: countAccessibilityCandidates(nodes),
      note: config.allowWindowMetadata
        ? "Window metadata collected through approved local desktop policy; set CLAW_ALLOW_ACCESSIBILITY_OBSERVE=1 for read-only Accessibility summaries."
        : "Accessibility observation is dry-run. Set CLAW_ALLOW_ACCESSIBILITY_OBSERVE=1 on an authorized macOS Gateway to collect a read-only summary.",
    };
  }

  if (process.platform !== "darwin") {
    return {
      ...base,
      mode: "accessibility-unavailable",
      accessibilityPolicy: "enabled",
      note: "Accessibility observation summaries are currently implemented only for macOS Gateway hosts.",
    };
  }

  const result = await collectMacAccessibilitySummary(maxCandidateControls, config);
  if (result.status !== "succeeded") {
    const nodes = accessibilityNodesFromWindows(windows).slice(0, maxCandidateControls);
    return {
      ...base,
      mode: result.mode,
      accessibilityPolicy: "enabled",
      nodes,
      nodeCount: nodes.length,
      candidateControlCount: countAccessibilityCandidates(nodes),
      error: result.error,
      note: result.note,
    };
  }

  return {
    ...base,
    mode: "accessibility-summary",
    accessibilityPolicy: "enabled",
    app: result.app,
    windowTitle: result.windowTitle,
    nodes: result.nodes,
    nodeCount: result.nodes.length,
    candidateControlCount: countAccessibilityCandidates(result.nodes),
    note: "Read-only macOS Accessibility summary collected from the front application. Values, password fields, raw text bodies, and action execution are omitted.",
  };
}

async function collectMacAccessibilitySummary(maxCandidateControls, config) {
  const script = [
    'tell application "System Events"',
    'set maxControls to ' + maxCandidateControls,
    'set frontProcess to first application process whose frontmost is true',
    'set appName to name of frontProcess',
    'set windowTitle to ""',
    'try',
    'set windowTitle to name of front window of frontProcess',
    'end try',
    'set output to appName & tab & windowTitle',
    'set controlCount to 0',
    'try',
    'set uiItems to entire contents of front window of frontProcess',
    'repeat with uiItem in uiItems',
    'if controlCount >= maxControls then exit repeat',
    'set itemRole to ""',
    'set itemName to ""',
    'set itemDescription to ""',
    'try',
    'set itemRole to role of uiItem',
    'end try',
    'try',
    'set itemName to name of uiItem',
    'end try',
    'try',
    'set itemDescription to description of uiItem',
    'end try',
    'if itemRole is not "" then',
    'set output to output & linefeed & itemRole & tab & itemName & tab & itemDescription',
    'set controlCount to controlCount + 1',
    'end if',
    'end repeat',
    'end try',
    'return output',
    'end tell',
  ].join("\n");
  const result = await runProcess("/usr/bin/osascript", ["-e", script], config.sessionWorkspace, 9000);
  if (result.exitCode !== 0) {
    return {
      status: "failed",
      mode: "accessibility-failed",
      error: normalizeText(result.stderr || result.stdout || "osascript failed").slice(0, 300),
      note: "macOS Accessibility permission may be missing for the Gateway host process.",
    };
  }
  const lines = result.stdout.split(/\r?\n/).filter((line) => line.trim().length > 0);
  const [app = "Unknown App", windowTitle = "Untitled front window"] = splitAccessibilityLine(lines[0] || "");
  const controls = lines.slice(1, maxCandidateControls + 1).map((line, index) => {
    const [role = "AXUnknown", name = "", description = ""] = splitAccessibilityLine(line);
    return {
      role: safeAccessibilityText(role) || "AXUnknown",
      label: safeAccessibilityText(name || description || `Control ${index + 1}`),
      description: safeAccessibilityText(description),
      focused: false,
      enabled: null,
      action: "observe-only",
      confidence: 0.65,
      sourceMode: "macos-accessibility-summary",
    };
  });
  return {
    status: "succeeded",
    app: safeAccessibilityText(app) || "Unknown App",
    windowTitle: safeAccessibilityText(windowTitle) || "Untitled front window",
    nodes: [
      {
        role: "AXWindow",
        title: safeAccessibilityText(windowTitle) || "Untitled front window",
        app: safeAccessibilityText(app) || "Unknown App",
        focused: true,
        sourceMode: "macos-accessibility-summary",
        children: controls,
      },
    ],
  };
}

function splitAccessibilityLine(line) {
  return String(line).split("\t").map((item) => item.trim());
}

function safeAccessibilityText(value) {
  const text = normalizeText(value).slice(0, 120);
  if (!text) {
    return "";
  }
  if (/\b(password|passcode|secret|token|authorization|bearer)\b/i.test(text)) {
    return "<redacted>";
  }
  return text;
}

function countAccessibilityCandidates(nodes) {
  let count = 0;
  for (const node of nodes || []) {
    if (node && typeof node.action === "string" && node.action.length > 0) {
      count += 1;
    }
    count += countAccessibilityCandidates(node.children || []);
  }
  return count;
}

function accessibilityTreeMetadata(tree) {
  return compactMetadata({
    accessibilityTree: "observeSummary",
    mode: tree.mode,
    accessibilityPolicy: tree.accessibilityPolicy,
    includeAccessibilityTree: tree.includeAccessibilityTree,
    maxCandidateControls: tree.maxCandidateControls,
    nodeCount: tree.nodeCount,
    candidateControlCount: tree.candidateControlCount,
    platform: tree.platform,
    redaction: tree.redaction,
    safetyFlags: [
      "observe-only",
      "values-omitted",
      "password-fields-omitted",
      "action-execution-not-supported",
      "structured-arguments-only",
    ],
  });
}

async function controlBrowserAction(action, index, config) {
  const browserInput = await resolveBrowserInput(action, config);
  const browserControl = await browserControlArtifact(action, index, browserInput, config);
  const extracted = extractHTML(browserInput.html);
  const trace = {
    mode: browserInput.mode,
    target: action.target,
    instruction: action.instruction,
    inputPreview: action.inputPreview,
    toolArguments: action.toolArguments || {},
    source: browserInput.source,
    title: extracted.title,
    links: extracted.links.slice(0, 20),
    headings: extracted.headings.slice(0, 20),
    tables: extracted.tables.slice(0, 8),
    forms: extracted.forms.slice(0, 8),
    candidateControls: extracted.candidateControls.slice(0, 20),
    textPreview: extracted.textPreview,
    extractionHints: makeBrowserExtractionHints(extracted),
    browserControl: browserControl.payload,
    nextTool: "Attach Playwright or browser-use compatible click/form controller after browser open/search.",
  };
  const artifacts = [
    await writeArtifact("browserTrace", `browser-trace-${index + 1}.json`, trace, false, config),
    browserControl.artifact,
  ];
  return {
    status: browserControl.status === "failed" ? "failed" : "succeeded",
    summary: browserControl.status === "failed"
      ? browserControl.summary
      : `${action.title} extracted browser content from ${browserInput.mode}; ${browserControl.summary}`,
    artifacts,
    isRetryable: browserControl.isRetryable,
  };
}

async function resolveBrowserInput(action, config) {
  const args = action.toolArguments || {};
  if (typeof args.html === "string" && args.html.trim()) {
    return {
      mode: "local-html",
      source: "toolArguments.html",
      html: args.html,
    };
  }
  if (typeof args.url === "string" && args.url.trim()) {
    const url = new URL(args.url);
    if (!["http:", "https:"].includes(url.protocol)) {
      throw new GatewayError(400, "browser_url_protocol_blocked");
    }
    if (!config.allowBrowserNetwork || !config.browserHostAllowlist.has(url.hostname)) {
      return {
        mode: "network-blocked",
        source: url.toString(),
        html: [
          "<html><head><title>Network blocked</title></head><body>",
          `<p>Fetch blocked for ${escapeHTML(url.hostname)}. Set CLAW_ALLOW_BROWSER_NETWORK=1 and add the host to CLAW_BROWSER_HOST_ALLOWLIST.</p>`,
          "</body></html>",
        ].join(""),
      };
    }
    const response = await fetchWithTimeout(url.toString(), 12000);
    return {
      mode: "network-fetch",
      source: url.toString(),
      html: response,
    };
  }
  return {
    mode: "dry-run",
    source: "empty-browser-input",
    html: [
      "<html><head><title>Dry-run browser task</title></head><body>",
      `<p>${escapeHTML(action.instruction)}</p>`,
      "</body></html>",
    ].join(""),
  };
}

async function browserControlArtifact(action, index, browserInput, config) {
  const args = action.toolArguments || {};
  const plan = makeBrowserControlPlan(action, args, browserInput);
  const basePayload = {
    target: action.target,
    instruction: action.instruction,
    browserGoal: args.browserGoal || action.instruction,
    browserApp: plan.browserApp,
    openInBrowser: plan.requested,
    targetURL: plan.targetURL,
    searchQuery: plan.searchQuery,
    source: browserInput.source,
    platform: process.platform,
  };

  if (!plan.requested) {
    const payload = {
      ...basePayload,
      mode: "browser-control-not-requested",
      browserControlPolicy: "not-requested",
      note: "Browser content extraction ran without requesting desktop browser control.",
    };
    return {
      status: "skipped",
      summary: "desktop browser control was not requested",
      artifact: await writeArtifact("screenshot", `browser-control-${index + 1}.json`, payload, true, config),
      payload,
      isRetryable: false,
    };
  }

  if (!config.allowBrowserControl) {
    const payload = {
      ...basePayload,
      mode: "browser-control-dry-run",
      browserControlPolicy: "dry-run",
      note: "Set CLAW_ALLOW_BROWSER_CONTROL=1, CLAW_BROWSER_APP_ALLOWLIST, and CLAW_BROWSER_HOST_ALLOWLIST to let the Gateway open/search a desktop browser.",
    };
    return {
      status: "succeeded",
      summary: `desktop browser control planned for ${plan.browserApp}`,
      artifact: await writeArtifact("screenshot", `browser-control-${index + 1}.json`, payload, true, config),
      payload,
      isRetryable: false,
    };
  }

  if (process.platform !== "darwin") {
    const payload = {
      ...basePayload,
      mode: "browser-control-unavailable",
      browserControlPolicy: "enabled",
      note: "Desktop browser control is currently implemented for macOS Gateway hosts through osascript.",
    };
    return {
      status: "failed",
      summary: `${action.title} requires macOS browser control; current platform is ${process.platform}`,
      artifact: await writeArtifact("screenshot", `browser-control-${index + 1}.json`, payload, true, config),
      payload,
      isRetryable: true,
    };
  }

  if (!allowlistContains(config.browserAppAllowlist, plan.browserApp)) {
    const payload = {
      ...basePayload,
      mode: "browser-control-policy-blocked",
      browserControlPolicy: "enabled",
      appAllowlist: [...config.browserAppAllowlist],
      note: "The requested browser app is not in CLAW_BROWSER_APP_ALLOWLIST.",
    };
    return {
      status: "failed",
      summary: `${action.title} blocked: browser app '${plan.browserApp}' is not enabled by Gateway policy`,
      artifact: await writeArtifact("screenshot", `browser-control-${index + 1}.json`, payload, true, config),
      payload,
      isRetryable: true,
    };
  }

  if (plan.targetURL) {
    const url = new URL(plan.targetURL);
    if (!config.browserHostAllowlist.has(url.hostname)) {
      const payload = {
        ...basePayload,
        mode: "browser-control-host-blocked",
        browserControlPolicy: "enabled",
        hostAllowlist: [...config.browserHostAllowlist],
        note: "The target URL host is not in CLAW_BROWSER_HOST_ALLOWLIST.",
      };
      return {
        status: "failed",
        summary: `${action.title} blocked: browser host '${url.hostname}' is not enabled by Gateway policy`,
        artifact: await writeArtifact("screenshot", `browser-control-${index + 1}.json`, payload, true, config),
        payload,
        isRetryable: true,
      };
    }
  }

  const execution = await runBrowserAutomation(plan, config.sessionWorkspace);
  const payload = {
    ...basePayload,
    mode: execution.exitCode === 0 ? "browser-control-opened" : "browser-control-failed",
    browserControlPolicy: "enabled",
    appAllowlist: [...config.browserAppAllowlist],
    hostAllowlist: [...config.browserHostAllowlist],
    executed: execution.exitCode === 0,
    exitCode: execution.exitCode,
    stdout: normalizeText(execution.stdout).slice(0, 500),
    stderr: normalizeText(execution.stderr).slice(0, 500),
    timedOut: Boolean(execution.timedOut),
    note: execution.exitCode === 0
      ? "Gateway opened or searched in an allowlisted desktop browser."
      : "Browser automation failed before the browser reached the requested state.",
  };
  return {
    status: execution.exitCode === 0 ? "succeeded" : "failed",
    summary: execution.exitCode === 0
      ? `${action.title} opened ${plan.browserApp}`
      : `${action.title} failed while opening ${plan.browserApp}: ${normalizeText(execution.stderr || execution.stdout || "osascript failed").slice(0, 160)}`,
    artifact: await writeArtifact("screenshot", `browser-control-${index + 1}.json`, payload, true, config),
    payload,
    isRetryable: execution.exitCode !== 0,
  };
}

function makeBrowserControlPlan(action, args, browserInput) {
  const browserApp = String(args.browserApp || args.targetBrowser || "Safari").trim();
  const searchQuery = String(args.searchQuery || "").trim();
  const targetURL = browserTargetURL(args, browserInput, searchQuery);
  const requested = args.openInBrowser === "true" ||
    Boolean(searchQuery) ||
    Boolean(args.openURL) ||
    (Boolean(args.url) && args.openInBrowser !== "false");
  return { requested, browserApp, searchQuery, targetURL };
}

function browserTargetURL(args, browserInput, searchQuery) {
  const direct = String(args.openURL || "").trim();
  if (direct) {
    return normalizeBrowserURL(direct);
  }
  if (searchQuery) {
    const template = String(args.searchURLTemplate || "https://www.google.com/search?q={query}").trim();
    return normalizeBrowserURL(template.replace("{query}", encodeURIComponent(searchQuery)));
  }
  const sourceURL = String(args.url || "").trim();
  if (sourceURL && browserInput.mode !== "network-blocked") {
    return normalizeBrowserURL(sourceURL);
  }
  return "";
}

function normalizeBrowserURL(value) {
  const raw = String(value || "").trim();
  const normalized = /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(raw) ? raw : `https://${raw}`;
  const url = new URL(normalized);
  if (!["http:", "https:"].includes(url.protocol)) {
    throw new GatewayError(400, "browser_url_protocol_blocked");
  }
  return url.toString();
}

async function runBrowserAutomation(plan, workspace) {
  const script = [
    `tell application ${appleScriptString(plan.browserApp)} to activate`,
    "delay 0.35",
    plan.targetURL
      ? `tell application ${appleScriptString(plan.browserApp)} to open location ${appleScriptString(plan.targetURL)}`
      : "",
  ].filter(Boolean).join("\n");
  return runProcess("/usr/bin/osascript", ["-e", script], workspace, 12000);
}

async function fetchWithTimeout(url, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      signal: controller.signal,
      redirect: "follow",
      headers: {
        "User-Agent": "ClawGatewayPrototype/0.1",
      },
    });
    if (!response.ok) {
      throw new GatewayError(502, `browser_fetch_http_${response.status}`);
    }
    return await response.text();
  } finally {
    clearTimeout(timer);
  }
}

function extractHTML(html) {
  const title = decodeEntities(matchFirst(html, /<title[^>]*>([\s\S]*?)<\/title>/i) || "");
  const links = [...html.matchAll(/<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi)].map((match) => ({
    href: decodeEntities(match[1]),
    text: normalizeText(stripTags(match[2])).slice(0, 160),
  }));
  const headings = [...html.matchAll(/<h([1-6])\b[^>]*>([\s\S]*?)<\/h\1>/gi)].map((match) => ({
    level: Number(match[1]),
    text: normalizeText(stripTags(match[2])).slice(0, 180),
  }));
  const tables = [...html.matchAll(/<table\b[^>]*>([\s\S]*?)<\/table>/gi)].map((match, tableIndex) => {
    const rows = [...match[1].matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/gi)].map((rowMatch) =>
      [...rowMatch[1].matchAll(/<t[hd]\b[^>]*>([\s\S]*?)<\/t[hd]>/gi)]
        .map((cellMatch) => normalizeText(stripTags(cellMatch[1])).slice(0, 160))
        .filter(Boolean),
    );
    return {
      index: tableIndex,
      headers: rows[0] || [],
      rows: rows.slice(1, 8),
    };
  });
  const forms = [...html.matchAll(/<form\b([^>]*)>([\s\S]*?)<\/form>/gi)].map((match, formIndex) => ({
    index: formIndex,
    action: decodeEntities(matchFirst(match[1], /\baction=["']([^"']+)["']/i) || ""),
    method: (matchFirst(match[1], /\bmethod=["']([^"']+)["']/i) || "GET").toUpperCase(),
    fields: extractFormFields(match[2]).slice(0, 20),
  }));
  const buttons = [...html.matchAll(/<(button|input)\b([^>]*)>([\s\S]*?)<\/button>|<input\b([^>]*)>/gi)].map((match, index) => {
    const tag = (match[1] || "input").toLowerCase();
    const attrs = match[2] || match[4] || "";
    const label = normalizeText(stripTags(match[3] || "")) ||
      matchFirst(attrs, /\b(?:value|aria-label|title)=["']([^"']+)["']/i) ||
      `${tag}-${index + 1}`;
    return {
      kind: tag,
      label: decodeEntities(label).slice(0, 120),
      type: (matchFirst(attrs, /\btype=["']([^"']+)["']/i) || "button").toLowerCase(),
    };
  });
  const textPreview = normalizeText(stripTags(html)).slice(0, 600);
  return { title, links, headings, tables, forms, candidateControls: [...links.map((link) => ({ kind: "link", label: link.text || link.href, href: link.href })), ...buttons], textPreview };
}

function extractFormFields(html) {
  return [...html.matchAll(/<(input|textarea|select)\b([^>]*)>/gi)].map((match) => {
    const attrs = match[2] || "";
    return {
      tag: match[1].toLowerCase(),
      name: decodeEntities(matchFirst(attrs, /\bname=["']([^"']+)["']/i) || ""),
      label: decodeEntities(matchFirst(attrs, /\b(?:aria-label|placeholder|title)=["']([^"']+)["']/i) || ""),
      type: (matchFirst(attrs, /\btype=["']([^"']+)["']/i) || "text").toLowerCase(),
    };
  });
}

function makeBrowserExtractionHints(extracted) {
  const hints = [];
  if (extracted.tables.length > 0) {
    hints.push("table-data");
  }
  if (extracted.forms.length > 0) {
    hints.push("form-fill-candidates");
  }
  if (extracted.links.length > 0) {
    hints.push("navigation-links");
  }
  if (extracted.headings.length > 0) {
    hints.push("section-headings");
  }
  return hints;
}

function matchFirst(text, pattern) {
  const match = text.match(pattern);
  return match ? match[1] : "";
}

function stripTags(html) {
  return html
    .replace(/<script\b[\s\S]*?<\/script>/gi, " ")
    .replace(/<style\b[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ");
}

function normalizeText(text) {
  return decodeEntities(text).replace(/\s+/g, " ").trim();
}

function decodeEntities(text) {
  return String(text)
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function escapeHTML(text) {
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

async function manageFilesAction(action, index, config) {
  const requestedPath = action.toolArguments?.writePath || `managed-file-${index + 1}.txt`;
  const markerPath = safeWorkspacePath(config.sessionWorkspace, requestedPath);
  const content =
    action.toolArguments?.writeText ||
    [
      "Claw Gateway file action",
      `action=${action.title}`,
      `target=${action.target}`,
      `instruction=${action.instruction}`,
      `toolArguments=${JSON.stringify(action.toolArguments || {})}`,
    ].join("\n");
  await fs.mkdir(path.dirname(markerPath), { recursive: true });
  await fs.writeFile(markerPath, content, "utf8");
  const artifacts = [
    await writeArtifact(
      "fileDiff",
      `file-diff-${index + 1}.json`,
      {
        mode: "workspace-write",
        created: [markerPath],
        workspace: config.sessionWorkspace,
        requestedPath,
      },
      false,
      config,
    ),
  ];
  return {
    status: "succeeded",
    summary: `${action.title} wrote a workspace-scoped file`,
    artifacts,
    isRetryable: false,
  };
}

async function runShellAction(action, index, config) {
  const commandLine = structuredShellCommand(action);
  if (!commandLine) {
    const artifacts = [
      await writeArtifact(
        "commandOutput",
        `shell-dry-run-${index + 1}.log`,
        [
          "Shell action was not executed.",
          "Reason: no structured shellCommand field was provided.",
          `Instruction: ${action.instruction}`,
        ].join("\n"),
        true,
        config,
      ),
    ];
    return {
      status: "failed",
      summary: `${action.title} paused: missing structured shellCommand; natural-language instructions are never executed`,
      artifacts,
      isRetryable: true,
    };
  }

  const parsed = parseCommandLine(commandLine);
  if (!parsed) {
    const artifacts = [
      await writeArtifact("commandOutput", `shell-parse-${index + 1}.log`, `Unable to parse: ${commandLine}`, true, config),
    ];
    return {
      status: "failed",
      summary: `${action.title} paused: shellCommand could not be parsed`,
      artifacts,
      isRetryable: true,
    };
  }

  const binary = path.basename(parsed.command);
  if (!config.allowShell || !config.shellAllowlist.has(binary)) {
    const artifacts = [
      await writeArtifact(
        "commandOutput",
        `shell-policy-${index + 1}.log`,
        [
          `Command: ${commandLine}`,
          `Shell enabled: ${config.allowShell}`,
          `Allowlist: ${[...config.shellAllowlist].join(",") || "empty"}`,
          "Result: dry-run only",
        ].join("\n"),
        true,
        config,
      ),
    ];
    return {
      status: "failed",
      summary: `${action.title} paused: command '${binary}' is not enabled by Gateway policy`,
      artifacts,
      isRetryable: true,
    };
  }

  const result = await runProcess(parsed.command, parsed.args, config.sessionWorkspace);
  const artifacts = [
    await writeArtifact(
      "commandOutput",
      `shell-output-${index + 1}.log`,
      [
        `$ ${commandLine}`,
        "",
        "stdout:",
        result.stdout,
        "",
        "stderr:",
        result.stderr,
        "",
        `exitCode=${result.exitCode}`,
      ].join("\n"),
      true,
      config,
    ),
  ];
  return {
    status: result.exitCode === 0 ? "succeeded" : "failed",
    summary: `${action.title} executed '${binary}' with exit code ${result.exitCode}`,
    artifacts,
    isRetryable: result.exitCode !== 0,
  };
}

async function extractDataAction(action, index, config) {
  const args = action.toolArguments || {};
  const outputPath = args.outputPath || `claw-output/extracted-data-${index + 1}.json`;
  const outputFile = safeWorkspacePath(config.sessionWorkspace, outputPath);
  const sourcePriority = String(args.sourcePriority || "browserTrace,accessibilityTree,commandOutput")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  const contextRows = buildExtractionRows(config.sessionContext, sourcePriority, action);
  const extracted = {
    mode: contextRows.length > 0 ? "artifact-grounded-extraction" : "dry-run-extraction",
    extractionGoal: args.extractionGoal || action.instruction,
    sourcePriority,
    schema: args.schema || "title:string,source:string,summary:string,confidence:number",
    validateCompleteness: args.validateCompleteness !== "false",
    sourceArtifacts: summarizeArtifactContext(config.sessionContext),
    rows: contextRows,
  };
  await fs.mkdir(path.dirname(outputFile), { recursive: true });
  await fs.writeFile(outputFile, JSON.stringify(extracted, null, 2), "utf8");
  const artifacts = [
    await writeArtifact(
      "browserTrace",
      `extracted-data-${index + 1}.json`,
      {
        ...extracted,
        outputPath,
        workspaceFile: outputFile,
      },
      false,
      config,
      extractionCompletenessMetadata(extracted),
    ),
  ];
  return {
    status: "succeeded",
    summary: `${action.title} wrote structured extraction output to ${outputPath}`,
    artifacts,
    isRetryable: false,
  };
}

function extractionCompletenessMetadata(extracted) {
  const sourceArtifacts = extracted.sourceArtifacts || {};
  const sourceArtifactKinds = [
    ["browserTrace", sourceArtifacts.browserTraceCount],
    ["fileDiff", sourceArtifacts.fileDiffCount],
    ["commandOutput", sourceArtifacts.commandOutputCount],
    ["screenObservation", sourceArtifacts.screenObservationCount],
    ["accessibilityTree", sourceArtifacts.accessibilityTreeCount],
    ["messageDraft", sourceArtifacts.messageDraftCount],
  ]
    .filter(([, count]) => Number(count) > 0)
    .map(([kind]) => kind);
  const rowCount = Array.isArray(extracted.rows) ? extracted.rows.length : 0;
  const completenessStatus = rowCount === 0
    ? "empty"
    : extracted.mode === "artifact-grounded-extraction" && sourceArtifactKinds.length > 0
      ? "complete"
      : "partial";
  return compactMetadata({
    extractionReview: "artifactGrounded",
    mode: extracted.mode,
    validateCompleteness: extracted.validateCompleteness,
    rowCount,
    completenessStatus,
    browserTraceCount: sourceArtifacts.browserTraceCount,
    fileDiffCount: sourceArtifacts.fileDiffCount,
    commandOutputCount: sourceArtifacts.commandOutputCount,
    screenObservationCount: sourceArtifacts.screenObservationCount,
    accessibilityTreeCount: sourceArtifacts.accessibilityTreeCount,
    messageDraftCount: sourceArtifacts.messageDraftCount,
    sourceArtifactKinds,
    safetyFlags: [
      "metadata-only",
      "row-content-omitted",
      "source-values-omitted",
      "tool-arguments-omitted",
      "artifact-payload-not-read",
    ],
  });
}

async function desktopAppAction(action, index, config) {
  const args = action.toolArguments || {};
  const targetApp = String(args.targetApp || action.target || "").trim();
  const finalSubmitRequiresApproval = args.finalSubmitRequiresApproval !== "false";
  const captureBeforeAfter = args.captureBeforeAfter !== "false";
  const pasteText = desktopPasteText(action, args);
  const requestedKeys = parseDesktopKeySequence(args.keySequence || args.keyChords || args.shortcutSequence);
  const keyPlan = planDesktopKeys(requestedKeys, finalSubmitRequiresApproval, config.desktopKeyAllowlist);
  const beforeWindows = captureBeforeAfter ? await collectWindowMetadata(config) : [];
  const basePayload = {
    targetApp,
    automationMode: args.automationMode || "accessibility",
    inputMode: args.inputMode || "typeOrPaste",
    finalSubmitRequiresApproval,
    captureBeforeAfter,
    instruction: action.instruction,
    requestedKeys,
    executableKeys: keyPlan.allowed,
    blockedKeys: keyPlan.blocked,
    pasteTextPreview: pasteText ? normalizeText(pasteText).slice(0, 180) : "",
    beforeWindows,
    platform: process.platform,
  };

  if (!config.allowDesktopControl) {
    const artifacts = [
      await writeArtifact(
        "screenshot",
        `desktop-app-confirm-${index + 1}.json`,
        {
          ...basePayload,
          mode: "approval-required",
          desktopControlPolicy: "dry-run",
          note: "Set CLAW_ALLOW_DESKTOP_CONTROL=1 and CLAW_DESKTOP_APP_ALLOWLIST to let the Gateway focus apps, paste prepared text, and run allowlisted keys.",
        },
        true,
        config,
      ),
    ];
    return {
      status: "waitingForApproval",
      summary: `${action.title} paused before desktop control because Gateway desktop policy is dry-run`,
      artifacts,
      isRetryable: false,
    };
  }

  if (process.platform !== "darwin") {
    const artifacts = [
      await writeArtifact(
        "screenshot",
        `desktop-app-unavailable-${index + 1}.json`,
        {
          ...basePayload,
          mode: "desktop-control-unavailable",
          desktopControlPolicy: "enabled",
          note: "Desktop app control is currently implemented for macOS Gateway hosts through osascript/System Events.",
        },
        true,
        config,
      ),
    ];
    return {
      status: "failed",
      summary: `${action.title} requires macOS desktop control; current platform is ${process.platform}`,
      artifacts,
      isRetryable: true,
    };
  }

  if (!targetApp) {
    const artifacts = [
      await writeArtifact(
        "screenshot",
        `desktop-app-missing-target-${index + 1}.json`,
        {
          ...basePayload,
          mode: "desktop-control-missing-target",
          desktopControlPolicy: "enabled",
          note: "toolArguments.targetApp is required before real desktop control can run.",
        },
        true,
        config,
      ),
    ];
    return {
      status: "failed",
      summary: `${action.title} paused: missing targetApp for desktop control`,
      artifacts,
      isRetryable: true,
    };
  }

  if (!allowlistContains(config.desktopAppAllowlist, targetApp)) {
    const artifacts = [
      await writeArtifact(
        "screenshot",
        `desktop-app-policy-${index + 1}.json`,
        {
          ...basePayload,
          mode: "policy-blocked",
          desktopControlPolicy: "enabled",
          appAllowlist: [...config.desktopAppAllowlist],
          note: "The target app is not in CLAW_DESKTOP_APP_ALLOWLIST.",
        },
        true,
        config,
      ),
    ];
    return {
      status: "failed",
      summary: `${action.title} blocked: app '${targetApp}' is not enabled by Gateway desktop policy`,
      artifacts,
      isRetryable: true,
    };
  }

  const execution = await runDesktopAutomation({
    targetApp,
    pasteText,
    keyChords: keyPlan.allowed,
    workspace: config.sessionWorkspace,
  });
  const afterWindows = captureBeforeAfter ? await collectWindowMetadata(config) : [];
  const mode = execution.exitCode === 0
    ? finalSubmitRequiresApproval || keyPlan.blocked.length > 0
      ? "desktop-control-paused"
      : "desktop-control-completed"
    : "desktop-control-failed";
  const artifacts = [
    await writeArtifact(
      "screenshot",
      `desktop-app-result-${index + 1}.json`,
      {
        ...basePayload,
        mode,
        desktopControlPolicy: "enabled",
        appAllowlist: [...config.desktopAppAllowlist],
        afterWindows,
        executed: execution.exitCode === 0,
        exitCode: execution.exitCode,
        stdout: normalizeText(execution.stdout).slice(0, 500),
        stderr: normalizeText(execution.stderr).slice(0, 500),
        timedOut: Boolean(execution.timedOut),
        note: finalSubmitRequiresApproval
          ? "Gateway focused the app and prepared input, then stopped before final submit for user approval."
          : "Gateway completed the allowlisted desktop control sequence.",
      },
      true,
      config,
    ),
  ];
  return {
    status: execution.exitCode === 0
      ? finalSubmitRequiresApproval || keyPlan.blocked.length > 0
        ? "waitingForApproval"
        : "succeeded"
      : "failed",
    summary: execution.exitCode === 0
      ? `${action.title} prepared ${targetApp} and stopped before final submit`
      : `${action.title} failed while controlling ${targetApp}: ${normalizeText(execution.stderr || execution.stdout || "osascript failed").slice(0, 160)}`,
    artifacts,
    isRetryable: execution.exitCode !== 0,
  };
}

function desktopPasteText(action, args) {
  const candidates = [
    args.pasteText,
    args.draftText,
    args.messageText,
    args.textToPaste,
    args.text,
    action.inputPreview,
  ];
  return String(candidates.find((value) => typeof value === "string" && value.trim()) || "").trim();
}

function parseDesktopKeySequence(value) {
  if (Array.isArray(value)) {
    return value.map((item) => String(item).trim()).filter(Boolean);
  }
  return String(value || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function planDesktopKeys(requestedKeys, finalSubmitRequiresApproval, allowlist) {
  const allowed = [];
  const blocked = [];
  for (const key of requestedKeys) {
    const normalized = normalizeKeyChord(key);
    if (!normalized) {
      continue;
    }
    if (finalSubmitRequiresApproval && isSubmitKey(normalized)) {
      blocked.push({ key, reason: "final_submit_requires_approval" });
      continue;
    }
    if (!allowlistContains(allowlist, normalized)) {
      blocked.push({ key, reason: "key_not_allowlisted" });
      continue;
    }
    allowed.push(normalized);
  }
  return { allowed, blocked };
}

async function runDesktopAutomation({ targetApp, pasteText, keyChords, workspace }) {
  const script = buildDesktopAutomationScript(targetApp, pasteText, keyChords);
  return runProcess("/usr/bin/osascript", ["-e", script], workspace, 12000);
}

function buildDesktopAutomationScript(targetApp, pasteText, keyChords) {
  const lines = [
    `tell application ${appleScriptString(targetApp)} to activate`,
    "delay 0.35",
  ];
  if (pasteText) {
    lines.push(`set the clipboard to ${appleScriptString(pasteText)}`);
    lines.push('tell application "System Events" to keystroke "v" using {command down}');
    lines.push("delay 0.1");
  }
  for (const chord of keyChords) {
    lines.push(appleScriptKeyCommand(chord));
    lines.push("delay 0.08");
  }
  return lines.join("\n");
}

function appleScriptKeyCommand(chord) {
  const parsed = parseKeyChord(chord);
  const modifiers = parsed.modifiers.length > 0 ? ` using {${parsed.modifiers.map((item) => `${item} down`).join(", ")}}` : "";
  if (parsed.keyCode !== null) {
    return `tell application "System Events" to key code ${parsed.keyCode}${modifiers}`;
  }
  return `tell application "System Events" to keystroke ${appleScriptString(parsed.key)}${modifiers}`;
}

function parseKeyChord(chord) {
  const parts = normalizeKeyChord(chord).split("+").filter(Boolean);
  const key = parts.pop() || "";
  const modifiers = parts.map((part) => (part === "cmd" ? "command" : part));
  const keyCodes = {
    tab: 48,
    escape: 53,
    esc: 53,
    left: 123,
    right: 124,
    down: 125,
    up: 126,
  };
  return {
    key,
    modifiers,
    keyCode: Object.prototype.hasOwnProperty.call(keyCodes, key) ? keyCodes[key] : null,
  };
}

function normalizeKeyChord(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "")
    .replace(/^⌘\+?/, "command+")
    .replace(/^cmd\+/, "command+")
    .replace("option+", "option+")
    .replace("control+", "control+");
}

function isSubmitKey(chord) {
  const normalized = normalizeKeyChord(chord);
  return normalized.endsWith("return") || normalized.endsWith("enter");
}

function appleScriptString(value) {
  return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\r?\n/g, "\\n")}"`;
}

async function agentLoopAction(action, index, config) {
  const args = action.toolArguments || {};
  const maxIterations = clampInteger(Number(args.maxIterations || 3), 1, 8);
  const inputSources = parseCSV(args.inputSources || "screenObservation,accessibilityTree,browserTrace,fileDiff,commandOutput,messageDraft");
  const allowedNextActions = parseCSV(args.allowedNextActions || "observeScreen,controlBrowser,manageFiles,extractData,operateDesktopApp,composeMessage");
  const approvalRequiredFor = parseCSV(args.approvalRequiredFor || "runShellCommand,operateDesktopAppFinalSubmit,externalNetwork,destructiveFileChange");
  const stopBeforeDestructiveAction = args.stopBeforeDestructiveAction !== "false";
  const contextSummary = summarizeArtifactContext(config.sessionContext);
  const evidenceRows = buildExtractionRows(config.sessionContext, inputSources, action).slice(0, 12);
  const proposedActions = proposeAgentNextActions(contextSummary, allowedNextActions);
  const safetyGates = makeAgentSafetyGates(proposedActions, approvalRequiredFor);
  const decisionChecklist = makeAgentDecisionChecklist(contextSummary, inputSources);
  const readiness = makeAgentReadiness(decisionChecklist, evidenceRows);
  const selectedNextAction = selectAgentNextAction(proposedActions, readiness);
  const riskTags = makeAgentRiskTags({
    readiness,
    decisionChecklist,
    proposedActions,
    safetyGates,
    approvalRequiredFor,
    stopBeforeDestructiveAction,
  });
  const stopReason = makeAgentStopReason({
    readiness,
    selectedNextAction,
    riskTags,
    stopBeforeDestructiveAction,
  });
  const handoffSummary = makeAgentHandoffSummary(readiness, selectedNextAction, stopReason);
  const iterations = [];

  for (let iteration = 1; iteration <= maxIterations; iteration += 1) {
    const proposal = proposedActions[Math.min(iteration - 1, proposedActions.length - 1)];
    iterations.push({
      iteration,
      phase: iteration === 1 ? "observe" : iteration === maxIterations ? "verify" : "plan",
      observation: summarizeAgentObservation(config.sessionContext, iteration),
      decision: proposal?.reason || "No additional action is needed from the current artifact context.",
      proposedAction: proposal?.kind || "none",
      status: proposal?.requiresApproval ? "waiting-for-approval" : "planned",
    });
  }

  const trace = {
    mode: "agent-loop-trace",
    target: action.target,
    instruction: action.instruction,
    objective: args.objective || action.instruction,
    loopMode: args.loopMode || "observe-plan-act-verify",
    maxIterations,
    inputSources,
    allowedNextActions,
    approvalRequiredFor,
    stopBeforeDestructiveAction,
    sourceArtifacts: contextSummary,
    evidenceRows,
    observations: agentObservationSnapshot(config.sessionContext),
    nextActions: proposedActions,
    safetyGates,
    readiness,
    decisionChecklist,
    selectedNextAction,
    riskTags,
    stopReason,
    handoffSummary,
    iterations,
    finalState: proposedActions.some((item) => item.requiresApproval)
      ? "ready-for-user-or-gateway-approval"
      : "ready-for-next-safe-action",
  };

  const artifacts = [
    await writeArtifact(
      "agentTrace",
      `agent-loop-${index + 1}.json`,
      trace,
      true,
      config,
      agentTraceMetadata(trace),
    ),
  ];
  return {
    status: "succeeded",
    summary: `${action.title} wrote an observe-plan-act-verify agent trace with ${proposedActions.length} proposed next actions`,
    artifacts,
    isRetryable: false,
  };
}

function agentTraceMetadata(trace) {
  return compactMetadata({
    readinessScore: trace.readiness?.score,
    readinessCanContinue: trace.readiness?.canContinue,
    satisfiedSignals: trace.readiness?.satisfiedSignals,
    missingSignals: trace.readiness?.missingSignals,
    selectedNextActionKind: trace.selectedNextAction?.kind,
    selectedNextActionRequiresApproval: trace.selectedNextAction?.requiresApproval,
    riskTags: trace.riskTags,
    stopReason: trace.stopReason,
    handoffSummary: trace.handoffSummary,
  });
}

function compactMetadata(values) {
  const metadata = {};
  for (const [key, value] of Object.entries(values)) {
    const normalized = metadataValue(value);
    if (normalized) {
      metadata[key] = normalized;
    }
  }
  return metadata;
}

function metadataValue(value) {
  if (value === undefined || value === null) {
    return "";
  }
  if (Array.isArray(value)) {
    return value.map((item) => String(item).trim()).filter(Boolean).join(",");
  }
  if (typeof value === "boolean") {
    return value ? "true" : "false";
  }
  return String(value).trim();
}

function parseCSV(value) {
  return String(value || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function clampInteger(value, min, max) {
  if (!Number.isFinite(value)) {
    return min;
  }
  return Math.max(min, Math.min(max, Math.trunc(value)));
}

function proposeAgentNextActions(summary, allowlist) {
  const proposals = [];
  const allow = (kind) => allowlist.length === 0 || allowlist.includes(kind);
  if (summary.screenObservationCount === 0 && allow("observeScreen")) {
    proposals.push({
      kind: "observeScreen",
      priority: "high",
      requiresApproval: true,
      reason: "No screen observation is available; collect the current window and candidate controls first.",
    });
  }
  if (summary.browserTraceCount === 0 && allow("controlBrowser")) {
    proposals.push({
      kind: "controlBrowser",
      priority: "high",
      requiresApproval: true,
      reason: "No browser trace is available; open or inspect the desktop browser before extraction.",
    });
  }
  if (summary.browserTraceCount > 0 && allow("extractData")) {
    proposals.push({
      kind: "extractData",
      priority: "medium",
      requiresApproval: false,
      reason: "Browser context is available; extract structured rows from the observed page data.",
    });
  }
  if (summary.fileDiffCount === 0 && allow("manageFiles")) {
    proposals.push({
      kind: "manageFiles",
      priority: "medium",
      requiresApproval: true,
      reason: "No workspace output file exists yet; write a bounded result artifact in the Gateway workspace.",
    });
  }
  if (summary.messageDraftCount === 0 && allow("composeMessage")) {
    proposals.push({
      kind: "composeMessage",
      priority: "low",
      requiresApproval: true,
      reason: "No delivery draft is available; prepare a message draft but stop before final send.",
    });
  }
  if (summary.screenObservationCount > 0 && allow("operateDesktopApp")) {
    proposals.push({
      kind: "operateDesktopApp",
      priority: "low",
      requiresApproval: true,
      reason: "Screen context is available; desktop app input can be prepared under allowlist and final-submit gates.",
    });
  }
  if (proposals.length === 0) {
    proposals.push({
      kind: "none",
      priority: "low",
      requiresApproval: false,
      reason: "Existing artifacts are sufficient for review; wait for user confirmation or a new task.",
    });
  }
  return proposals.slice(0, 6);
}

function summarizeAgentObservation(context, iteration) {
  const snapshot = agentObservationSnapshot(context);
  const available = Object.entries(snapshot)
    .filter(([, value]) => Boolean(value))
    .map(([key]) => key);
  return {
    iteration,
    availableSignals: available,
    summary: available.length > 0
      ? `Available signals: ${available.join(", ")}.`
      : "No artifact-backed signals are available yet.",
  };
}

function agentObservationSnapshot(context) {
  const latestScreen = context?.screenObservations?.at(-1);
  const latestBrowser = context?.browserTraces?.at(-1);
  const latestFile = context?.fileDiffs?.at(-1);
  const latestCommand = context?.commandOutputs?.at(-1);
  const latestDraft = context?.messageDrafts?.at(-1);
  return {
    hasScreenObservation: Boolean(latestScreen),
    focusedWindow: latestScreen?.windows?.[0]?.title || latestScreen?.target || "",
    hasBrowserTrace: Boolean(latestBrowser),
    browserTitle: latestBrowser?.title || "",
    browserSource: latestBrowser?.source || "",
    hasWorkspaceFile: Boolean(latestFile),
    workspaceCreated: latestFile?.created || [],
    hasCommandOutput: Boolean(latestCommand),
    commandPreview: latestCommand ? normalizeText(latestCommand).slice(0, 180) : "",
    hasMessageDraft: Boolean(latestDraft),
    messagePreview: latestDraft ? normalizeText(latestDraft).slice(0, 180) : "",
  };
}

function makeAgentSafetyGates(proposedActions, approvalRequiredFor) {
  return proposedActions
    .filter((action) => action.requiresApproval || approvalRequiredFor.includes(action.kind))
    .map((action) => ({
      actionKind: action.kind,
      gate: "user-or-gateway-approval",
      reason: action.reason,
    }));
}

function makeAgentDecisionChecklist(summary, inputSources) {
  const sources = [...new Set(inputSources.length > 0 ? inputSources : ["browserTrace", "fileDiff", "commandOutput"])];
  return sources.map((source) => {
    const count = sourceEvidenceCount(summary, source);
    const status = count > 0 ? "satisfied" : "missing";
    return {
      signal: source,
      status,
      count,
      reason: status === "satisfied"
        ? `${count} ${source} artifact signal(s) are available for grounded decisions.`
        : `No ${source} artifact signal is available; gather it before relying on this input.`,
    };
  });
}

function makeAgentReadiness(decisionChecklist, evidenceRows) {
  const satisfiedSignals = decisionChecklist
    .filter((item) => item.status === "satisfied")
    .map((item) => item.signal);
  const missingSignals = decisionChecklist
    .filter((item) => item.status === "missing")
    .map((item) => item.signal);
  const totalSignals = decisionChecklist.length || 1;
  const score = Math.round((satisfiedSignals.length / totalSignals) * 100);
  return {
    score,
    evidenceRowCount: evidenceRows.length,
    satisfiedSignals,
    missingSignals,
    canContinue: score >= 50 && evidenceRows.length > 0,
  };
}

function selectAgentNextAction(proposedActions, readiness) {
  if (proposedActions.length === 0) {
    return {
      kind: "none",
      priority: "low",
      requiresApproval: false,
      reason: "No proposed next action is available.",
    };
  }
  if (!readiness.canContinue) {
    return proposedActions.find((action) => action.kind === "observeScreen" || action.kind === "controlBrowser") || proposedActions[0];
  }
  return proposedActions.find((action) => !action.requiresApproval && action.kind !== "none") || proposedActions[0];
}

function makeAgentRiskTags({
  readiness,
  decisionChecklist,
  proposedActions,
  safetyGates,
  approvalRequiredFor,
  stopBeforeDestructiveAction,
}) {
  const tags = new Set();
  if (!readiness.canContinue) {
    tags.add("insufficient-evidence");
  }
  for (const item of decisionChecklist) {
    if (item.status === "missing") {
      tags.add(`missing-${kebabCase(item.signal)}`);
    }
  }
  if (safetyGates.length > 0) {
    tags.add("approval-required");
  }
  for (const action of proposedActions) {
    if (action.requiresApproval) {
      tags.add("approval-required");
    }
    if (action.kind === "controlBrowser" && approvalRequiredFor.includes("externalNetwork")) {
      tags.add("external-network-gate");
    }
    if (action.kind === "manageFiles" && stopBeforeDestructiveAction && approvalRequiredFor.includes("destructiveFileChange")) {
      tags.add("destructive-action-gate");
    }
    if (action.kind === "runShellCommand") {
      tags.add("shell-command-gate");
    }
    if (action.kind === "operateDesktopApp") {
      tags.add("desktop-control-gate");
      if (approvalRequiredFor.includes("operateDesktopAppFinalSubmit")) {
        tags.add("final-submit-gate");
      }
    }
    if (action.kind === "composeMessage" || action.kind === "composeEmail") {
      tags.add("final-submit-gate");
    }
  }
  return [...tags];
}

function makeAgentStopReason({
  readiness,
  selectedNextAction,
  riskTags,
  stopBeforeDestructiveAction,
}) {
  if (!readiness.canContinue) {
    return "insufficient-evidence";
  }
  if (riskTags.includes("final-submit-gate")) {
    return "final-submit";
  }
  if (stopBeforeDestructiveAction && riskTags.includes("destructive-action-gate")) {
    return "destructive";
  }
  if (riskTags.includes("external-network-gate")) {
    return "external";
  }
  if (selectedNextAction?.requiresApproval || riskTags.includes("approval-required")) {
    return "approval-required";
  }
  if (selectedNextAction?.kind === "none") {
    return "complete";
  }
  return "none";
}

function makeAgentHandoffSummary(readiness, selectedNextAction, stopReason) {
  const satisfied = readiness.satisfiedSignals.length > 0 ? readiness.satisfiedSignals.join(", ") : "none";
  const missing = readiness.missingSignals.length > 0 ? `; missing ${readiness.missingSignals.join(", ")}` : "";
  return `Evidence score ${readiness.score}/100 from ${satisfied}${missing}. Selected next action: ${selectedNextAction.kind}. Stop reason: ${stopReason}.`;
}

function sourceEvidenceCount(summary, source) {
  switch (source) {
    case "screenObservation":
      return summary.screenObservationCount;
    case "accessibilityTree":
      return summary.accessibilityTreeCount;
    case "browserTrace":
      return summary.browserTraceCount;
    case "fileDiff":
      return summary.fileDiffCount;
    case "commandOutput":
      return summary.commandOutputCount;
    case "messageDraft":
      return summary.messageDraftCount;
    case "agentTrace":
      return summary.agentTraceCount;
    default:
      return 0;
  }
}

function kebabCase(value) {
  return String(value || "")
    .replace(/([a-z0-9])([A-Z])/g, "$1-$2")
    .replace(/[^a-zA-Z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .toLowerCase();
}

async function messageDraftAction(action, index, config) {
  const artifacts = [
    await writeArtifact(
      "messageDraft",
      `message-draft-${index + 1}.txt`,
      [
        `Target: ${action.target}`,
        `Instruction: ${action.instruction}`,
        "",
        "Draft requires user confirmation before send.",
      ].join("\n"),
      true,
      config,
    ),
  ];
  return {
    status: "waitingForApproval",
    summary: `${action.title} produced a draft and is waiting for user confirmation`,
    artifacts,
    isRetryable: false,
  };
}

async function genericAuditAction(action, index, config) {
  const artifacts = [
    await writeArtifact(
      "auditLog",
      `audit-${index + 1}.json`,
      {
        actionID: action.id,
        actionKind: action.kind,
        title: action.title,
        target: action.target,
        instruction: action.instruction,
        inputPreview: action.inputPreview,
        toolArguments: action.toolArguments || {},
      },
      Boolean(action.handlesSensitiveData),
      config,
    ),
  ];
  return {
    status: "succeeded",
    summary: `${action.title} recorded by Gateway audit handler`,
    artifacts,
    isRetryable: false,
  };
}

function eventKindForStatus(status) {
  switch (status) {
    case "succeeded":
      return "actionCompleted";
    case "failed":
      return "actionFailed";
    case "waitingForApproval":
      return "approvalRequested";
    case "skipped":
      return "actionSkipped";
    default:
      return "actionStarted";
  }
}

async function writeArtifact(kind, title, payload, redacted, config, metadata = undefined) {
  await fs.mkdir(config.sessionWorkspace, { recursive: true });
  const safeTitle = sanitizeTitle(title);
  const filePath = path.join(config.sessionWorkspace, safeTitle);
  const data = typeof payload === "string" ? payload : JSON.stringify(payload, null, 2);
  await fs.writeFile(filePath, data, "utf8");
  const artifact = {
    id: crypto.randomUUID(),
    kind,
    title: safeTitle,
    reference: `file://${filePath}`,
    isRedacted: redacted,
  };
  if (metadata && Object.keys(metadata).length > 0) {
    artifact.metadata = metadata;
  }
  config.sessionContext?.artifacts?.push({ ...artifact, payload });
  rememberArtifact(kind, payload, config.sessionContext);
  return artifact;
}

function rememberExistingArtifact(kind, title, filePath, redacted, payload, config) {
  const artifact = {
    id: crypto.randomUUID(),
    kind,
    title: sanitizeTitle(title),
    reference: `file://${filePath}`,
    isRedacted: redacted,
  };
  config.sessionContext?.artifacts?.push({ ...artifact, payload });
  rememberArtifact(kind, payload, config.sessionContext);
  return artifact;
}

function rememberArtifact(kind, payload, context) {
  if (!context) {
    return;
  }
  switch (kind) {
    case "browserTrace":
      if (payload && typeof payload === "object") {
        if (payload.mode === "artifact-grounded-extraction" || payload.mode === "dry-run-extraction") {
          return;
        }
        context.browserTraces.push(payload);
      }
      break;
    case "screenshot":
      if (payload && typeof payload === "object") {
        context.screenObservations.push(payload);
      }
      break;
    case "accessibilityTree":
      if (payload && typeof payload === "object") {
        context.accessibilityTrees.push(payload);
      }
      break;
    case "fileDiff":
      if (payload && typeof payload === "object") {
        context.fileDiffs.push(payload);
      }
      break;
    case "commandOutput":
      context.commandOutputs.push(String(payload).slice(0, 1200));
      break;
    case "messageDraft":
      context.messageDrafts.push(String(payload).slice(0, 1200));
      break;
    case "agentTrace":
      if (payload && typeof payload === "object") {
        context.agentTraces.push(payload);
      }
      break;
    default:
      break;
  }
}

function summarizeArtifactContext(context) {
  return {
    browserTraceCount: context?.browserTraces?.length || 0,
    screenObservationCount: context?.screenObservations?.length || 0,
    accessibilityTreeCount: context?.accessibilityTrees?.length || 0,
    fileDiffCount: context?.fileDiffs?.length || 0,
    commandOutputCount: context?.commandOutputs?.length || 0,
    messageDraftCount: context?.messageDrafts?.length || 0,
    agentTraceCount: context?.agentTraces?.length || 0,
  };
}

function buildExtractionRows(context, sourcePriority, action) {
  const rows = [];
  const priority = sourcePriority.length > 0 ? sourcePriority : ["browserTrace", "accessibilityTree", "commandOutput"];
  for (const source of priority) {
    switch (source) {
      case "browserTrace":
        rows.push(...browserTraceRows(context?.browserTraces || []));
        break;
      case "fileDiff":
        rows.push(...fileDiffRows(context?.fileDiffs || []));
        break;
      case "commandOutput":
        rows.push(...commandOutputRows(context?.commandOutputs || []));
        break;
      case "accessibilityTree":
        rows.push(...accessibilityRows(context?.accessibilityTrees || []));
        break;
      case "screenObservation":
        rows.push(...screenRows(context?.screenObservations || []));
        break;
      default:
        break;
    }
  }
  return rows.slice(0, 40);
}

function browserTraceRows(traces) {
  const rows = [];
  for (const trace of traces) {
    if (trace.title || trace.textPreview) {
      rows.push({
        title: trace.title || "Browser page",
        source: trace.source || trace.target || "browserTrace",
        summary: trace.textPreview || "Browser trace captured.",
        confidence: trace.mode === "network-fetch" || trace.mode === "local-html" ? 0.82 : 0.62,
      });
    }
    for (const heading of trace.headings || []) {
      rows.push({
        title: heading.text || `Heading ${heading.level}`,
        source: trace.source || "browserHeading",
        summary: `H${heading.level} section discovered in browser content.`,
        confidence: 0.74,
      });
    }
    for (const link of trace.links || []) {
      rows.push({
        title: link.text || link.href,
        source: link.href || trace.source || "browserLink",
        summary: "Navigation link extracted from browser content.",
        confidence: 0.72,
      });
    }
    for (const table of trace.tables || []) {
      rows.push({
        title: table.headers?.join(" / ") || `Table ${table.index + 1}`,
        source: trace.source || "browserTable",
        summary: JSON.stringify({ headers: table.headers || [], rows: table.rows || [] }).slice(0, 500),
        confidence: 0.78,
      });
    }
  }
  return rows;
}

function fileDiffRows(fileDiffs) {
  return fileDiffs.flatMap((diff) =>
    (diff.created || []).map((createdPath) => ({
      title: path.basename(createdPath),
      source: createdPath,
      summary: `Workspace file created for requested path ${diff.requestedPath || createdPath}.`,
      confidence: 0.76,
    })),
  );
}

function commandOutputRows(outputs) {
  return outputs.map((output, index) => ({
    title: `Command output ${index + 1}`,
    source: "commandOutput",
    summary: normalizeText(output).slice(0, 500),
    confidence: output.includes("exitCode=0") ? 0.8 : 0.55,
  }));
}

function accessibilityRows(trees) {
  return trees.flatMap((tree, treeIndex) =>
    (tree.nodes || []).map((node, nodeIndex) => ({
      title: node.title || node.label || `Accessibility node ${treeIndex + 1}.${nodeIndex + 1}`,
      source: "accessibilityTree",
      summary: JSON.stringify(node).slice(0, 400),
      confidence: 0.66,
    })),
  );
}

function screenRows(observations) {
  return observations.map((observation, index) => ({
    title: observation.observationGoal || `Screen observation ${index + 1}`,
    source: "screenObservation",
    summary: JSON.stringify({
      platform: observation.platform,
      target: observation.target,
      windows: observation.windows || [],
    }).slice(0, 400),
    confidence: 0.6,
  }));
}

function structuredShellCommand(action) {
  return typeof action.toolArguments?.shellCommand === "string"
    ? action.toolArguments.shellCommand.trim()
    : typeof action.shellCommand === "string"
    ? action.shellCommand.trim()
    : typeof action.commandLine === "string"
      ? action.commandLine.trim()
      : "";
}

function parseCommandLine(commandLine) {
  const args = [];
  let current = "";
  let quote = null;
  for (let index = 0; index < commandLine.length; index += 1) {
    const char = commandLine[index];
    if (quote) {
      if (char === quote) {
        quote = null;
      } else {
        current += char;
      }
      continue;
    }
    if (char === "'" || char === '"') {
      quote = char;
      continue;
    }
    if (/\s/.test(char)) {
      if (current) {
        args.push(current);
        current = "";
      }
      continue;
    }
    current += char;
  }
  if (quote) {
    return null;
  }
  if (current) {
    args.push(current);
  }
  if (args.length === 0) {
    return null;
  }
  return { command: args[0], args: args.slice(1) };
}

function runProcess(command, args, cwd, timeoutMs = 15000) {
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd,
      shell: false,
      env: {
        PATH: process.env.PATH || "/usr/bin:/bin:/usr/sbin:/sbin",
        HOME: os.homedir(),
      },
    });
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    let killTimer = null;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGTERM");
      stderr += "\nterminated: timeout";
      killTimer = setTimeout(() => {
        if (child.exitCode === null) {
          child.kill("SIGKILL");
        }
      }, 1200);
    }, timeoutMs);
    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString("utf8");
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString("utf8");
    });
    child.on("error", (error) => {
      clearTimeout(timer);
      if (killTimer) {
        clearTimeout(killTimer);
      }
      resolve({ exitCode: 127, stdout, stderr: `${stderr}${error.message}`, timedOut });
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      if (killTimer) {
        clearTimeout(killTimer);
      }
      resolve({ exitCode: timedOut && code === null ? 124 : code ?? 1, stdout, stderr, timedOut });
    });
  });
}

function sanitizeTitle(title) {
  return String(title).replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 120);
}

function safeWorkspacePath(workspace, requestedPath) {
  const relative = String(requestedPath || "").replace(/^[/\\]+/, "");
  const resolved = path.resolve(workspace, relative);
  const root = path.resolve(workspace);
  if (resolved !== root && resolved.startsWith(`${root}${path.sep}`)) {
    return resolved;
  }
  throw new GatewayError(400, "workspace_path_escape_blocked");
}

function resolveWorkspace(value) {
  const raw = value && value.trim() ? value.trim() : ".build/claw-gateway-workspace";
  if (raw === "~") {
    return os.homedir();
  }
  if (raw.startsWith("~/")) {
    return path.join(os.homedir(), raw.slice(2));
  }
  return path.resolve(raw);
}

function parseAllowlist(value) {
  return new Set(
    String(value || "")
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean),
  );
}

function sortedAllowlist(value) {
  return sortedStrings([...(value || [])]);
}

function sortedStrings(value) {
  return [...new Set(Array.isArray(value) ? value : [...value])]
    .map((item) => String(item).trim())
    .filter(Boolean)
    .sort((a, b) => a.localeCompare(b));
}

function allowlistContains(allowlist, value) {
  if (!allowlist || allowlist.size === 0) {
    return false;
  }
  const normalized = String(value || "").trim().toLowerCase();
  for (const item of allowlist) {
    if (String(item).trim().toLowerCase() === normalized) {
      return true;
    }
  }
  return false;
}

function tokenFingerprint(token) {
  const digest = crypto.createHash("sha256").update(token.trim()).digest("hex");
  return `sha256:${digest.slice(0, 12)}`;
}

function isoNow() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

function statusText(status) {
  return status === 400 ? "Bad Request" : status === 401 ? "Unauthorized" : "Internal Server Error";
}

function errorEvent(error) {
  const code = error instanceof GatewayError ? error.code : "internal_error";
  return {
    id: crypto.randomUUID(),
    sessionID: crypto.randomUUID(),
    taskID: crypto.randomUUID(),
    sequence: 0,
    kind: "actionFailed",
    summary: `gateway error: ${code}`,
    artifacts: [],
    isRetryable: true,
    retryCount: 0,
    createdAt: isoNow(),
  };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

class GatewayError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}
