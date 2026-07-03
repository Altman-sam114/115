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

const events = await connectAndCollectEvents({
  host,
  port,
  token,
  envelope: makeEnvelope(token),
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

for (const artifact of events.flatMap((event) => event.artifacts || [])) {
  if (artifact.reference?.startsWith("file://")) {
    await fs.access(new URL(artifact.reference));
  }
}

const browserTraces = await readArtifacts(events, "browserTrace");
const pageTrace = browserTraces.find((trace) => trace.mode === "local-html");
expect(pageTrace?.title === "Gateway Smoke Page", "missing websocket browser title extraction");
expect(pageTrace?.tables?.some((table) => table.rows?.some((row) => row.includes("Gateway"))), "missing websocket browser table extraction");
expect(pageTrace?.forms?.some((form) => form.fields?.some((field) => field.name === "query")), "missing websocket browser form extraction");
const extractedTrace = browserTraces.find((trace) => trace.mode === "artifact-grounded-extraction");
expect(Boolean(extractedTrace), "missing websocket artifact-grounded extraction");
expect(extractedTrace?.sourceArtifacts?.browserTraceCount >= 1, "websocket extraction did not consume browser trace");
expect(extractedTrace?.sourceArtifacts?.fileDiffCount >= 1, "websocket extraction did not consume file diff");
expect(extractedTrace?.sourceArtifacts?.commandOutputCount >= 1, "websocket extraction did not consume command output");
expect(extractedTrace?.rows?.some((row) => row.title === "Gateway Smoke Page"), "websocket extraction missing page row");
const agentTraces = await readArtifacts(events, "agentTrace");
const agentTrace = agentTraces.find((trace) => trace.mode === "agent-loop-trace");
expect(Boolean(agentTrace), "missing websocket agent loop trace");
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

console.log(`Claw Gateway smoke passed (${events.length} events)`);

function makeEnvelope(rawToken) {
  const taskID = crypto.randomUUID();
  return {
    schemaVersion: "claw.computer.control.v1",
    sourceApp: "Claw Controller",
    gateway: {
      endpoint: `ws://${host}:${port}`,
      deviceName: "smoke",
      securityMode: "mutualApproval",
      tokenFingerprint: tokenFingerprint(rawToken),
      allowedActionKinds: ["controlBrowser", "manageFiles", "runShellCommand", "extractData", "runAgentLoop"],
      requiresApprovalForSensitiveData: true,
      auditEnabled: true,
    },
    task: {
      id: taskID,
      command: "open browser and collect data",
      summary: "smoke",
      sourceDevice: "smoke",
      destinationGateway: `ws://${host}:${port}`,
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

function isoNow() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

function expect(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function waitFor(predicate, timeoutMs) {
  const started = Date.now();
  while (!predicate()) {
    if (Date.now() - started > timeoutMs) {
      throw new Error(`timeout waiting for gateway. Output:\n${serverOutput}`);
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
}
