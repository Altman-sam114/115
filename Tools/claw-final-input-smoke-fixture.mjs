import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";

export function makeFinalInputEnvelope(base, marker) {
  const result = JSON.parse(JSON.stringify(base));
  const file = result.task.actions.find((action) => action.kind === "manageFiles");
  const desktop = result.task.actions.find((action) => action.kind === "operateDesktopApp");
  const clone = (action, args) => ({
    ...action, id: crypto.randomUUID(), title: "Final input provenance fixture",
    instruction: marker, inputPreview: marker, toolArguments: args,
  });
  const missingFileInputs = [
    {}, { writePath: "notes/missing.txt" }, { writeText: "Explicit text without a path" },
    { writePath: 23, writeText: "Explicit text with a wrong path type" },
    { writePath: "notes/wrong-type.txt", writeText: 23 },
    { writePath: "notes/empty.txt", writeText: "  " },
  ].map((args) => clone(file, args));
  const missingDesktop = clone(desktop, { targetApp: "TextEdit" });
  const keysOnly = clone(desktop, {
    targetApp: "TextEdit", keySequence: "command+k", finalSubmitRequiresApproval: "true", captureBeforeAfter: "false",
  });
  keysOnly.instruction = "Explicit keys-only input; no inferred paste text";
  const validFile = clone(file, {
    workspaceOnly: "true", writePath: "notes/approved-final.txt", writeText: "Explicitly reviewed final fixture text",
  });
  validFile.instruction = "Explicit final write";
  validFile.inputPreview = "omitted";
  result.task.id = crypto.randomUUID();
  result.task.command = "Verify explicit execution input and no natural-language fallback";
  result.task.actions = [...missingFileInputs, missingDesktop, keysOnly, validFile];
  result.gateway.allowedActionKinds = ["manageFiles", "operateDesktopApp"];
  return result;
}

export async function assertFinalInputEvidence(events, envelope, marker, label) {
  const expect = (condition, message) => { if (!condition) throw new Error(`${label}: ${message}`); };
  const invalid = envelope.task.actions.slice(0, -2);
  for (const action of invalid) {
    const scoped = events.filter((event) => event.actionID === action.id);
    const failed = scoped.filter((event) => event.kind === "actionFailed");
    expect(failed.length === 1 && failed[0].isRetryable === false, "missing input must fail once without automatic retry");
    const artifacts = scoped.flatMap((event) => event.artifacts || []);
    expect(artifacts.length === 1 && artifacts[0].kind === "auditLog" && artifacts[0].isRedacted, "missing input must produce only a redacted audit");
    expect(artifacts[0].metadata?.mode === "structured-input-required", "fixed missing-input mode is required");
    expect(artifacts[0].metadata?.executionAttempted === "false", "missing input must not attempt execution");
    const audit = JSON.parse(await fs.readFile(new URL(artifacts[0].reference), "utf8"));
    expect(audit.safety?.businessFileWritten === false, "missing input cannot write a business file");
    expect(!JSON.stringify({ scoped, audit }).includes(marker), "missing-input diagnostics leaked natural-language input");
  }
  const keysOnly = envelope.task.actions.at(-2);
  const desktopArtifact = events.filter((event) => event.actionID === keysOnly.id)
    .flatMap((event) => event.artifacts || []).find((artifact) => artifact.kind === "screenshot");
  expect(Boolean(desktopArtifact), "explicit keys-only input must preserve the dry-run review path");
  const desktop = JSON.parse(await fs.readFile(new URL(desktopArtifact.reference), "utf8"));
  expect(desktop.pasteTextPreview === "", "inputPreview must never become paste text");
  expect(!JSON.stringify(desktop).includes(marker), "desktop fallback retained the raw preview");
  const valid = envelope.task.actions.at(-1);
  const diffArtifact = events.filter((event) => event.actionID === valid.id)
    .flatMap((event) => event.artifacts || []).find((artifact) => artifact.kind === "fileDiff");
  expect(Boolean(diffArtifact), "a valid action after rejected inputs must still run");
  const diff = JSON.parse(await fs.readFile(new URL(diffArtifact.reference), "utf8"));
  expect(await fs.readFile(diff.created[0], "utf8") === valid.toolArguments.writeText, "explicit final file content must match exactly");
  expect((await fs.readdir(path.join(diff.workspace, "notes"))).sort().join(",") === "approved-final.txt", "missing inputs created an unexpected file");
  expect(!(await fs.readdir(diff.workspace)).some((name) => name.startsWith("managed-file-")), "missing path used a generated filename fallback");
  expect(events.some((event) => event.kind === "sessionCompleted"), "the rejection matrix must finish the session");
}
