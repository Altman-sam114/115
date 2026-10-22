import http from "node:http";
import net from "node:net";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import { spawn } from "node:child_process";
import { handleModelPlanning } from "./claw-model-planner.mjs";

const plane = "claw.gateway.planning.v1";
const token = `planning-token-${crypto.randomUUID()}`;
const marker = `private-planning-text-${crypto.randomUUID()}`;
const workspace = `.build/planning-no-effects-${crypto.randomUUID()}`;
const proposal = { summary: "Reviewable model plan", actions: [
  { kind: "observeScreen", goal: "Observe the authorized desktop", inputs: {} },
  { kind: "controlBrowser", goal: "Find public documentation", inputs: { mode: "url", app: "Safari", target: "https://example.test/docs" } },
  { kind: "manageFiles", goal: "Write a reviewed note", inputs: { path: "notes/model.txt", text: "Explicit note" } },
  { kind: "runShellCommand", goal: "Inspect the workspace", inputs: { command: "pwd" } },
  { kind: "operateDesktopApp", goal: "Prepare a desktop draft", inputs: { app: "TextEdit", text: "Reviewed draft", keys: "" } },
  { kind: "extractData", goal: "Extract source evidence", inputs: { path: "reports/model.json" } },
  { kind: "composeMessage", goal: "Prepare a message draft", inputs: { recipient: "reviewed-person", text: "Reviewed message" } },
  { kind: "composeEmail", goal: "Prepare an email draft", inputs: { recipient: "reviewed@example.test", text: "Reviewed email" } },
] };
let mode = "valid";
let changedProposal;
let hits = 0;
let aborted = 0;
const requests = [];
const held = [];
const provider = http.createServer(async (request, response) => {
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  hits += 1;
  requests.push({ path: request.url, headers: request.headers, body: JSON.parse(Buffer.concat(chunks)) });
  response.once("close", () => { if (!response.writableEnded) aborted += 1; });
  if (mode === "hold") { held.push(response); return; }
  if (mode === "redirect") { response.writeHead(302, { Location: `http://127.0.0.1:${provider.address().port}/forbidden` }); response.end(); return; }
  response.writeHead(mode === "error" ? 500 : 200, { "Content-Type": "application/json" });
  if (mode === "large") { response.end("x".repeat(131073)); return; }
  if (mode === "malformed") { response.end(`{${marker}`); return; }
  const content = mode === "duplicate" ? '{"summary":"a","summary":"b","actions":[]}' : JSON.stringify(changedProposal ?? proposal);
  response.end(JSON.stringify({ done: mode !== "not-done", done_reason: mode === "truncated" ? "length" : "stop",
    message: { role: "assistant", content, ...(mode === "tool-call" ? { tool_calls: [{ name: marker }] } : {}),
      ...(mode === "tool-call-object" ? { tool_calls: { length: 0, name: marker } } : {}) },
    prompt_eval_count: 33, eval_count: 55 }));
});
await new Promise((resolve) => provider.listen(0, "127.0.0.1", resolve));
const portFinder = net.createServer();
await new Promise((resolve) => portFinder.listen(0, "127.0.0.1", resolve));
const gatewayPort = portFinder.address().port;
await new Promise((resolve) => portFinder.close(resolve));
let output = "";
const gateway = spawn(process.execPath, ["Tools/claw-gateway-server.mjs"], { env: { ...process.env,
  CLAW_GATEWAY_HOST: "127.0.0.1", CLAW_GATEWAY_PORT: String(gatewayPort), CLAW_GATEWAY_TOKEN: token,
  CLAW_WORKSPACE: workspace, CLAW_PLANNER_ENDPOINT: `http://127.0.0.1:${provider.address().port}/api/chat`,
  CLAW_PLANNER_MODEL: "fixture-only:no-weights", CLAW_PLANNER_TIMEOUT_MS: "800",
}, stdio: ["ignore", "pipe", "pipe"] });
gateway.stdout.on("data", (chunk) => { output += chunk; });
gateway.stderr.on("data", (chunk) => { output += chunk; });
const expect = (condition, message) => { if (!condition) throw new Error(`Planning smoke: ${message}`); };
const waitFor = async (condition) => {
  const deadline = Date.now() + 5000;
  while (!condition() && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 10));
  expect(condition(), "bounded fixture coordination did not finish");
};
const body = () => ({ controlPlane: plane, kind: "planningRequest", requestNonce: crypto.randomBytes(16).toString("hex"), command: marker });
async function send(value = body(), overrides = {}) {
  const response = await fetch(`http://127.0.0.1:${gatewayPort}/claw/planning`, {
    method: "POST", headers: { "Content-Type": "application/json", "X-Claw-Control-Plane": plane, Authorization: `Bearer ${token}`, ...overrides },
    body: typeof value === "string" ? value : JSON.stringify(value), signal: AbortSignal.timeout(5000),
  });
  const result = await response.json();
  return { status: response.status, result };
}
function rejected(response) {
  expect(response.status !== 200 && response.result.kind === "planningError", "unsafe planning input must fail closed");
  expect(Object.keys(response.result).sort().join(",") === "controlPlane,errorCode,kind", "failure must have only fixed diagnostics");
  expect(!JSON.stringify(response).includes(marker) && !JSON.stringify(response).includes(token), "failure leaked private input or token");
}

try {
  await waitFor(() => output.includes("Claw Gateway listening"));
  const request = body();
  const success = await send(request);
  expect(success.status === 200 && success.result.requestNonce === request.requestNonce, "successful response must bind this request");
  expect(JSON.stringify(success.result.proposal) === JSON.stringify(proposal), "the validated model plan must survive exactly");
  expect(success.result.usage.inputTokens === 33 && success.result.usage.outputTokens === 55, "actual provider usage must be preserved");
  expect(Object.values(success.result.effects).every((value) => value === false), "planning cannot claim execution effects");
  expect(hits === 1 && requests[0].path === "/api/chat", "planning must make one explicit provider request");
  const sent = requests[0];
  expect(!sent.headers.authorization && !JSON.stringify(sent).includes(token), "Gateway credential must never reach the model");
  expect(sent.body.stream === false && sent.body.options.num_predict === 2048 && sent.body.format.additionalProperties === false, "schema and output budget are required");
  expect(sent.body.messages.length === 2 && sent.body.messages[0].role === "system" && sent.body.messages[1].role === "user"
    && sent.body.messages[1].content === marker && !sent.body.messages[0].content.includes(marker), "task data must not alter the fixed system contract");

  const swiftClient = await new Promise((resolve) => {
    const child = spawn(".build/claw-logic-smoke", ["--planning-http-smoke"], { env: { ...process.env,
      CLAW_PLANNING_SMOKE_ENDPOINT: `ws://127.0.0.1:${gatewayPort}`, CLAW_PLANNING_SMOKE_TOKEN: token,
    }, stdio: ["ignore", "pipe", "pipe"] });
    let log = "";
    child.stdout.on("data", (chunk) => { log += chunk; });
    child.stderr.on("data", (chunk) => { log += chunk; });
    const timer = setTimeout(() => child.kill(), 10000);
    child.once("error", () => { clearTimeout(timer); resolve({ code: -1, log: "Swift HTTP fixture unavailable" }); });
    child.once("exit", (code) => { clearTimeout(timer); resolve({ code, log }); });
  });
  expect(swiftClient.code === 0 && swiftClient.log.includes("production HTTP client smoke passed"), "the production Swift HTTP client must complete Gateway/model/approval flow");
  expect(!swiftClient.log.includes(token) && !swiftClient.log.includes(marker), "Swift HTTP client must not print private payloads");
  console.log("Claw model planning production HTTP client smoke passed");

  const before = hits;
  for (const [value, headers] of [
    [body(), { Authorization: "Bearer wrong" }], [{ ...body(), receipt: marker }, {}],
    [{ ...body(), command: "x".repeat(4097) }, {}], [{ ...body(), requestNonce: 123456789 }, {}],
    [body(), { "X-Claw-Schema": "claw.computer.control.v1" }],
    ['{"controlPlane":"claw.gateway.planning.v1","kind":"planningRequest","requestNonce":"a_nonce_123","command":"a","command":"b"}', {}],
  ]) rejected(await send(value, headers));
  expect(hits === before, "invalid request must not contact the model");

  let invalidConfig = {};
  const configServer = http.createServer((request, response) => handleModelPlanning(request, response, {
    authorize: () => {}, parseJSON: JSON.parse, env: invalidConfig,
  }));
  await new Promise((resolve) => configServer.listen(0, "127.0.0.1", resolve));
  try {
    for (const endpoint of [undefined, "https://example.test/api/chat", "http://127.0.0.1/api/chat?token=secret", "http://user:secret@127.0.0.1/api/chat", "http://127.0.0.1/other"]) {
      invalidConfig = { CLAW_PLANNER_ENDPOINT: endpoint, CLAW_PLANNER_MODEL: "fixture-model" };
      const response = await fetch(`http://127.0.0.1:${configServer.address().port}/claw/planning`, {
        method: "POST", headers: { "Content-Type": "application/json", "X-Claw-Control-Plane": plane }, body: JSON.stringify(body()),
      });
      expect(response.status === 503 && (await response.json()).errorCode === "planning_not_configured", "invalid model configuration must fail before inference");
    }
    invalidConfig = { CLAW_PLANNER_ENDPOINT: `http://127.0.0.1:${provider.address().port}/api/chat`, CLAW_PLANNER_MODEL: "" };
    const noModel = await fetch(`http://127.0.0.1:${configServer.address().port}/claw/planning`, {
      method: "POST", headers: { "Content-Type": "application/json", "X-Claw-Control-Plane": plane }, body: JSON.stringify(body()),
    });
    expect(noModel.status === 503 && (await noModel.json()).errorCode === "planning_not_configured", "missing model name must not trigger any implicit selection or download");
    expect(hits === before, "invalid configuration must not reach any provider");
  } finally { await new Promise((resolve) => configServer.close(resolve)); }

  const mutations = [
    (p) => { p.actions[0].approval = "automatic"; },
    (p) => { p.actions[0].kind = "runAgentLoop"; },
    (p) => { p.actions[2].inputs.path = "../escape.txt"; },
    (p) => { p.actions[1].inputs.target = "https://user:secret@example.test"; },
    (p) => { p.actions[3].inputs.cwdPolicy = "unrestricted"; },
    (p) => { p.actions[2].inputs.text = "x".repeat(4097); },
    (p) => { p.actions.push(p.actions[0]); },
  ];
  for (const mutate of mutations) {
    changedProposal = structuredClone(proposal); mutate(changedProposal);
    const prior = hits; rejected(await send()); expect(hits === prior + 1, "invalid output must not trigger model retries");
  }
  changedProposal = undefined;
  for (mode of ["duplicate", "redirect", "large", "malformed", "not-done", "truncated", "tool-call", "tool-call-object", "error"]) {
    const prior = hits; rejected(await send()); expect(hits === prior + 1, "provider failure must neither follow redirects nor retry");
  }
  mode = "hold";
  const firstBody = body();
  const first = send(firstBody);
  await waitFor(() => held.length === 1);
  rejected(await send(firstBody));
  rejected(await send(firstBody));
  expect(held.length === 1, "duplicate requests must not release another request's capacity slot");
  const second = send();
  await waitFor(() => held.length === 2);
  const capacity = await send();
  expect(capacity.status === 429 && capacity.result.errorCode === "planning_capacity", "capacity must be bounded");
  const timeouts = await Promise.all([first, second]);
  expect(timeouts.every((value) => value.status === 504 && value.result.errorCode === "planning_timeout"), "provider waits must time out without execution");
  await waitFor(() => aborted >= 2);
  const cancellation = new AbortController();
  const pending = fetch(`http://127.0.0.1:${gatewayPort}/claw/planning`, { method: "POST", headers: {
    "Content-Type": "application/json", "X-Claw-Control-Plane": plane, Authorization: `Bearer ${token}`,
  }, body: JSON.stringify(body()), signal: cancellation.signal }).catch(() => null);
  await waitFor(() => held.length === 3);
  cancellation.abort();
  await pending;
  await waitFor(() => aborted >= 3);
  expect(!(await fs.stat(workspace).catch(() => null)), "planning must not create any Gateway workspace, audit, session or artifact files");
  expect(!output.includes(marker) && !output.includes(token) && !output.includes(firstBody.requestNonce), "Gateway logs leaked planning input or identity");
  console.log(`Claw model planning smoke passed (${hits} bounded fixture requests; no model weights or computer actions)`);
} finally {
  gateway.kill();
  for (const response of held) response.destroy();
  provider.closeAllConnections();
  await new Promise((resolve) => provider.close(resolve));
}
