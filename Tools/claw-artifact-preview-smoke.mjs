import http from "node:http";
import net from "node:net";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { spawn } from "node:child_process";
import { ArtifactPreviewRegistry, ARTIFACT_PREVIEW_PLANE as plane } from "./claw-artifact-preview.mjs";

const expect = (condition, message) => { if (!condition) throw new Error(`Artifact preview smoke: ${message}`); };
const token = `preview-${crypto.randomUUID()}`;
const marker = `private-preview-${crypto.randomUUID()}`;
const workspace = path.resolve(`.build/preview-smoke-${crypto.randomUUID()}`);
let clock = 1000;
const registry = new ArtifactPreviewRegistry(() => clock);
const taskID = crypto.randomUUID();
const artifact = { id: crypto.randomUUID(), kind: "commandOutput" };
registry.register(taskID, artifact, marker);
registry.register(taskID, artifact, "replacement");
expect(registry.find(taskID, artifact.id)?.content === marker, "snapshot must be immutable");
expect(!registry.find(crypto.randomUUID(), artifact.id), "another task must not find this record");
clock += 600_000;
expect(!registry.find(taskID, artifact.id), "TTL must expire exactly at ten minutes");
for (const kind of ["auditLog", "agentTrace", "screenshot", "accessibilityTree", "unknown"]) {
  const blocked = { id: crypto.randomUUID(), kind };
  registry.register(taskID, blocked, marker);
  expect(!registry.find(taskID, blocked.id), "protected kinds must not register");
}
for (const content of ["x".repeat(32769), "中".repeat(10923), "bad\0text"]) {
  const blocked = { id: crypto.randomUUID(), kind: "commandOutput" };
  registry.register(taskID, blocked, content);
  expect(!registry.find(taskID, blocked.id), "oversized/invalid content must not be truncated or registered");
}
const first = { id: crypto.randomUUID(), kind: "commandOutput" };
registry.register(taskID, first, "first");
for (let i = 0; i < 64; i++) registry.register(taskID, { id: crypto.randomUUID(), kind: "fileDiff" }, "bounded");
expect(!registry.find(taskID, first.id), "registry must evict oldest after 64 entries");
const boundary = { id: crypto.randomUUID(), kind: "commandOutput" };
registry.register(taskID, boundary, "x".repeat(32768));
expect(registry.find(taskID, boundary.id)?.byteCount === 32768, "maximum complete snapshot must be retained");

const finder = net.createServer();
await new Promise((resolve) => finder.listen(0, "127.0.0.1", resolve));
const port = finder.address().port;
await new Promise((resolve) => finder.close(resolve));
let output = "";
const gateway = spawn(process.execPath, ["Tools/claw-gateway-server.mjs"], { env: { ...process.env,
  CLAW_GATEWAY_HOST: "127.0.0.1", CLAW_GATEWAY_PORT: String(port), CLAW_GATEWAY_TOKEN: token, CLAW_REQUIRE_TOKEN: "1",
  CLAW_WORKSPACE: workspace, CLAW_ALLOW_SHELL: "1", CLAW_SHELL_ALLOWLIST: "pwd", CLAW_ALLOW_BROWSER_NETWORK: "0",
  CLAW_ALLOW_BROWSER_CONTROL: "0", CLAW_ALLOW_SCREEN_CAPTURE: "0", CLAW_ALLOW_DESKTOP_CONTROL: "0",
  CLAW_ALLOW_WINDOW_METADATA: "0", CLAW_ALLOW_ACCESSIBILITY_OBSERVE: "0",
}, stdio: ["ignore", "pipe", "pipe"] });
gateway.stdout.on("data", (data) => { output += data; });
gateway.stderr.on("data", (data) => { output += data; });

function body(id = artifact.id, task = taskID) {
  return { controlPlane: plane, kind: "previewRequest", requestNonce: crypto.randomBytes(16).toString("base64url"), taskID: task, artifactID: id };
}
async function send(payload, headers = {}, method = "POST", raw = false) {
  const response = await fetch(`http://127.0.0.1:${port}/claw/artifacts/preview`, { method, headers: {
    "Content-Type": "application/json", "X-Claw-Control-Plane": plane, Authorization: `Bearer ${token}`, ...headers,
  }, ...(method === "GET" ? {} : { body: raw ? payload : JSON.stringify(payload) }), signal: AbortSignal.timeout(5000), redirect: "manual" });
  return { status: response.status, headers: response.headers, result: await response.json() };
}
async function tree(directory) {
  const entries = await fs.readdir(directory, { withFileTypes: true }).catch(() => []);
  const files = [];
  for (const entry of entries) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await tree(file));
    else files.push([file, crypto.createHash("sha256").update(await fs.readFile(file)).digest("hex")]);
  }
  return files.sort((a, b) => a[0].localeCompare(b[0]));
}
try {
  const deadline = Date.now() + 5000;
  while (!output.includes("Claw Gateway listening") && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 20));
  expect(output.includes("Claw Gateway listening"), "Gateway did not start");
  const missing = await send(body());
  expect(missing.status === 404 && missing.result.errorCode === "preview_not_available", "unknown IDs must not create tasks or files");
  expect((await tree(workspace)).length === 0, "preview-only calls must not create a workspace");
  const envelope = { schemaVersion: "claw.computer.control.v1", sourceApp: "Cloud preview fixture", auditRequired: true,
    gateway: { allowedActionKinds: ["runShellCommand"], requiresApprovalForSensitiveData: true, auditEnabled: true },
    task: { id: taskID, status: "sent", command: marker, actions: [{ id: crypto.randomUUID(), kind: "runShellCommand", title: "Inspect workspace",
      target: "workspace", instruction: marker, inputPreview: marker, sourceSurface: "clawGateway", handlesSensitiveData: true,
      approval: "gatewayApproval", toolArguments: { shellCommand: "pwd", cwdPolicy: "workspaceOnly" } }] } };
  const events = await dispatch(envelope);
  expect(events.some((event) => event.kind === "sessionCompleted"), "approved cloud fixture must complete");
  const stored = events.flatMap((event) => event.artifacts || []).find((item) => item.kind === "commandOutput");
  expect(stored, "real writer must produce command output");
  const initial = await fs.readFile(new URL(stored.reference), "utf8");
  expect(initial.includes(`stdout:\n${workspace}`) && initial.includes("exitCode=0"), "fixture must inspect only its isolated workspace");
  const successBody = body(stored.id);
  const success = await send(successBody);
  expect(success.status === 200 && success.result.content === initial && success.result.byteCount === Buffer.byteLength(initial), "HTTP must return exact writer bytes");
  expect(success.result.requestNonce === successBody.requestNonce && success.result.effects.computerActions === false
    && success.result.effects.taskDispatched === false && success.headers.get("cache-control") === "no-store", "identity/effects/cache contract failed");
  await fs.writeFile(new URL(stored.reference), "changed-on-disk: never follow this file reference");
  expect((await send(body(stored.id))).result.content === initial, "preview must not re-read a changed file");
  const before = JSON.stringify(await tree(workspace));
  const invalid = [
    [body(stored.id, crypto.randomUUID()), {}, 404],
    [{ ...body(stored.id), path: "/etc/passwd" }, {}, 400],
    [{ ...body(stored.id), reference: stored.reference }, {}, 400],
    [{ ...body(stored.id), artifactID: "../../etc/passwd" }, {}, 400],
    [{ ...body(stored.id), requestNonce: "bad\nnonce" }, {}, 400],
    [body(stored.id), { Authorization: "Bearer wrong" }, 401],
    [body(stored.id), { Authorization: "" }, 401],
    [body(stored.id), { "X-Claw-Control-Plane": "wrong" }, 400],
    [body(stored.id), { "X-Claw-Schema": envelope.schemaVersion }, 400],
    [body(stored.id), { "Content-Type": "text/plain" }, 400],
  ];
  for (const [payload, headers, status] of invalid) {
    const result = await send(payload, headers);
    expect(result.status === status && Object.keys(result.result).sort().join(",") === "controlPlane,errorCode,kind", "rejection must be fixed and payload-free");
    expect(!JSON.stringify(result.result).includes(marker) && !JSON.stringify(result.result).includes(token), "rejection leaked content or token");
  }
  expect((await send(body(stored.id), {}, "GET")).status === 400, "GET must never retrieve content");
  const duplicate = JSON.stringify(body(stored.id)).slice(0, -1) + ',"artifact\\u0049D":"foreign"}';
  expect((await send(duplicate, {}, "POST", true)).status === 400, "escaped duplicate key must fail");
  expect((await send("x".repeat(1025), {}, "POST", true)).status === 413, "request size must be bounded");
  const protectedArtifact = events.flatMap((event) => event.artifacts || []).find((item) => item.kind === "auditLog");
  expect((await send(body(protectedArtifact.id))).status === 404, "audit payload must not be previewable");
  const client = spawn(".build/claw-logic-smoke", ["--artifact-preview-http-smoke"], { env: { ...process.env,
    CLAW_PREVIEW_SMOKE_ENDPOINT: `ws://127.0.0.1:${port}`, CLAW_PREVIEW_SMOKE_TOKEN: token,
    CLAW_PREVIEW_SMOKE_TASK: taskID, CLAW_PREVIEW_SMOKE_ARTIFACT: stored.id,
  }, stdio: ["ignore", "pipe", "pipe"] });
  let clientOutput = "";
  client.stdout.on("data", (chunk) => { clientOutput += chunk; });
  client.stderr.on("data", (chunk) => { clientOutput += chunk; });
  const clientTimer = setTimeout(() => client.kill(), 15000);
  const code = await new Promise((resolve, reject) => { client.once("error", reject); client.once("close", resolve); });
  clearTimeout(clientTimer);
  expect(code === 0 && clientOutput.includes("Claw artifact preview production HTTP client smoke passed"), "production Swift HTTP transport must read the writer snapshot");
  expect(JSON.stringify(await tree(workspace)) === before, "all preview calls must leave every workspace byte unchanged");
  expect(!output.includes(token) && !output.includes(marker) && !output.includes(stored.id) && !clientOutput.includes(token), "logs must not leak identity/content/credentials");
  console.log("Claw artifact preview smoke passed (bounded registry, authenticated writer snapshot, immutable/no file reads, production Swift HTTP client, no preview execution effects)");
} finally {
  gateway.kill();
}

function dispatch(envelope) {
  return new Promise((resolve, reject) => {
    const request = http.request({ host: "127.0.0.1", port, path: "/v1/tasks", headers: { Connection: "Upgrade", Upgrade: "websocket",
      "Sec-WebSocket-Version": "13", "Sec-WebSocket-Key": crypto.randomBytes(16).toString("base64"), Authorization: `Bearer ${token}` } });
    const timer = setTimeout(() => { request.destroy(); reject(new Error("Preview dispatch fixture timeout")); }, 5000);
    request.on("error", (error) => { clearTimeout(timer); reject(error); });
    request.on("response", () => { clearTimeout(timer); reject(new Error("Preview dispatch fixture rejected")); });
    request.on("upgrade", (_response, socket, head) => {
      const payload = Buffer.from(JSON.stringify(envelope));
      const mask = crypto.randomBytes(4);
      const header = payload.length < 126 ? Buffer.from([0x81, 0x80 | payload.length]) : Buffer.from([0x81, 0xfe, payload.length >> 8, payload.length & 255]);
      socket.write(Buffer.concat([header, mask, Buffer.from(payload.map((byte, index) => byte ^ mask[index % 4]))]));
      let pending = head;
      const events = [];
      socket.on("error", (error) => { clearTimeout(timer); reject(error); });
      socket.on("close", () => { clearTimeout(timer); resolve(events); });
      socket.on("data", (data) => {
        pending = Buffer.concat([pending, data]);
        while (pending.length >= 2) {
          const opcode = pending[0] & 15;
          let length = pending[1] & 127;
          let offset = 2;
          if (length === 126) { if (pending.length < 4) return; length = pending.readUInt16BE(2); offset = 4; }
          if (length === 127) { if (pending.length < 10) return; length = Number(pending.readBigUInt64BE(2)); offset = 10; }
          if (length > 262144) { socket.destroy(); reject(new Error("Preview fixture frame oversized")); return; }
          if (pending.length < offset + length) return;
          if (opcode === 1) events.push(JSON.parse(pending.subarray(offset, offset + length).toString("utf8")));
          pending = pending.subarray(offset + length);
          if (opcode === 8) socket.end();
        }
      });
    });
    request.end();
  });
}
