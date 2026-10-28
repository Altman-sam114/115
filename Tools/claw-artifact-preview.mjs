export const ARTIFACT_PREVIEW_PLANE = "claw.gateway.artifact-preview.v1";
const supported = new Set(["fileDiff", "commandOutput", "browserTrace", "messageDraft"]);
const uuid = (value) => typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
const fail = (code, status) => Object.assign(new Error(code), { code, status });

// Store only immutable bytes produced by our writer, never a client-supplied file reference.
export class ArtifactPreviewRegistry {
  #records = new Map();
  #clock;
  constructor(clock = Date.now) { this.#clock = clock; }
  #prune() {
    for (const [id, record] of this.#records) {
      if (this.#clock() - record.created >= 600_000) this.#records.delete(id);
    }
  }
  register(taskID, artifact, content) {
    this.#prune();
    if (!uuid(taskID) || !uuid(artifact.id) || !supported.has(artifact.kind) || typeof content !== "string"
        || Buffer.byteLength(content, "utf8") > 32768 || content.includes("\0")) return;
    if (this.#records.has(artifact.id.toLowerCase())) return;
    while (this.#records.size >= 64) this.#records.delete(this.#records.keys().next().value);
    this.#records.set(artifact.id.toLowerCase(), Object.freeze({ taskID: taskID.toLowerCase(), artifactID: artifact.id.toLowerCase(),
      artifactKind: artifact.kind, content, byteCount: Buffer.byteLength(content, "utf8"), created: this.#clock() }));
  }
  find(taskID, artifactID) {
    this.#prune();
    const record = this.#records.get(artifactID.toLowerCase());
    return record?.taskID === taskID.toLowerCase() ? record : null;
  }
}

function send(response, status, body) {
  if (response.destroyed || response.writableEnded) return;
  response.writeHead(status, { "Content-Type": "application/json", "Cache-Control": "no-store", Connection: "close",
    "X-Content-Type-Options": "nosniff" });
  response.end(JSON.stringify(body));
}

export async function handleArtifactPreview(request, response, { authorize, parseJSON, registry }) {
  let timer;
  try {
    try { authorize(); } catch { throw fail("preview_unauthorized", 401); }
    if (request.method !== "POST" || request.headers["x-claw-control-plane"] !== ARTIFACT_PREVIEW_PLANE
        || request.headers["x-claw-schema"] || request.headers["content-type"]?.split(";")[0].trim() !== "application/json") {
      throw fail("preview_invalid_request", 400);
    }
    if (Number(request.headers["content-length"] || 0) > 1024) throw fail("preview_payload_too_large", 413);
    timer = setTimeout(() => request.destroy(), 3000);
    timer.unref();
    let size = 0;
    const chunks = [];
    for await (const chunk of request) {
      size += chunk.length;
      if (size > 1024) throw fail("preview_payload_too_large", 413);
      chunks.push(Buffer.from(chunk));
    }
    const body = parseJSON(new TextDecoder("utf-8", { fatal: true }).decode(Buffer.concat(chunks)));
    if (!body || Object.keys(body).sort().join(",") !== "artifactID,controlPlane,kind,requestNonce,taskID"
        || body.controlPlane !== ARTIFACT_PREVIEW_PLANE || body.kind !== "previewRequest"
        || typeof body.requestNonce !== "string" || !/^[A-Za-z0-9_-]{8,128}$/.test(body.requestNonce)
        || !uuid(body.taskID) || !uuid(body.artifactID)) throw fail("preview_invalid_request", 400);
    const record = registry.find(body.taskID, body.artifactID);
    if (!record) throw fail("preview_not_available", 404);
    send(response, 200, { controlPlane: ARTIFACT_PREVIEW_PLANE, kind: "previewResponse", requestNonce: body.requestNonce,
      taskID: record.taskID, artifactID: record.artifactID, artifactKind: record.artifactKind,
      mediaType: "text/plain; charset=utf-8", content: record.content, byteCount: record.byteCount,
      effects: { computerActions: false, taskDispatched: false } });
  } catch (error) {
    const codes = new Set(["preview_unauthorized", "preview_invalid_request", "preview_payload_too_large", "preview_not_available"]);
    const known = codes.has(error?.code);
    send(response, known ? error.status : 400, { controlPlane: ARTIFACT_PREVIEW_PLANE, kind: "previewError",
      errorCode: known ? error.code : "preview_invalid_request" });
  } finally {
    if (timer) clearTimeout(timer);
  }
}
