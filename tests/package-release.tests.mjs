import assert from "node:assert/strict";
import { cp, mkdtemp, readFile, rm, writeFile, access } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const temporary = await mkdtemp(path.join(tmpdir(), "warp-bench-release-"));
const copy = async (name) => cp(path.join(root, name), path.join(temporary, name), { recursive: true });
for (const name of ["scripts", "viewer", "schema", "manifests", "docs", "LICENSE", "VERSION", "README.md", "package.json", "package-lock.json"]) await copy(name);
const run = (...args) => spawnSync(process.execPath, [path.join(root, "scripts/package-release.mjs"), ...args], {
  env: { ...process.env, WARP_BENCH_RELEASE_ROOT: temporary }, encoding: "utf8"
});
async function verifyChecksums(bundleName) {
  const sums = await readFile(path.join(temporary, "dist", `${bundleName}-SHA256SUMS`), "utf8");
  for (const line of sums.trim().split("\n")) {
    const match = line.match(/^([a-f0-9]{64})  (.+)$/);
    assert.ok(match, `valid checksum line: ${line}`);
    const actual = createHash("sha256").update(await readFile(path.join(temporary, "dist", match[2]))).digest("hex");
    assert.equal(actual, match[1], `checksum for ${match[2]}`);
  }
}

try {
  let result = run("--check");
  assert.equal(result.status, 0, result.stderr);
  await assert.rejects(access(path.join(temporary, "dist")), "--check must not write dist");

  const packagePath = path.join(temporary, "package.json");
  await writeFile(packagePath, (await readFile(packagePath, "utf8")).replace('"version": "0.3.0"', '"version": "9.9.9"'));
  result = run("--check");
  assert.notEqual(result.status, 0, "version tampering must fail");
  assert.match(result.stderr, /does not match VERSION/);
  await copy("package.json");

  const powershellPath = path.join(temporary, "scripts", "warp-bench.ps1");
  await writeFile(powershellPath, (await readFile(powershellPath, "utf8")).replace('"verification_status":"verified"', '"verification_status":"tampered"'));
  result = run("--check");
  assert.notEqual(result.status, 0, "embedded target metadata tampering must fail");
  assert.match(result.stderr, /target snapshot differs/);
  await copy("scripts");

  const bashPath = path.join(temporary, "scripts", "warp-bench.sh");
  await writeFile(bashPath, (await readFile(bashPath, "utf8")).replace('"id":"jq-1.8.2-linux-x86_64"', '"id":"jq-1.8.2-macos-x86_64"'));
  result = run("--check");
  assert.notEqual(result.status, 0, "swapped jq platform artifact must fail");
  assert.match(result.stderr, /dependency metadata differs/);
  await copy("scripts");

  await writeFile(bashPath, (await readFile(bashPath, "utf8")).replace("WARP_BENCH_JQ_URL=https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-linux-amd64", "WARP_BENCH_JQ_URL=https://invalid.example/jq"));
  result = run("--check");
  assert.notEqual(result.status, 0, "runtime jq URL tampering must fail");
  assert.match(result.stderr, /runtime jq URL\/SHA-256 differs/);
  await copy("scripts");

  result = run("--stable");
  assert.notEqual(result.status, 0, "stable packaging must fail while documented blockers remain");
  assert.match(result.stderr, /Stable release is blocked/);

  const binariesPath = path.join(temporary, "manifests", "binaries.json");
  const promoted = JSON.parse(await readFile(binariesPath, "utf8"));
  for (const artifact of promoted.artifacts) { artifact.use_status = "approved"; artifact.redistribution_status = "approved"; }
  await writeFile(binariesPath, `${JSON.stringify(promoted, null, 2)}\n`);
  await writeFile(bashPath, (await readFile(bashPath, "utf8")).replace('"use_status":"candidate"', '"use_status":"approved"'));
  const evidencePath = path.join(temporary, "docs", "release-evidence.json");
  const completedEvidence = JSON.parse(await readFile(evidencePath, "utf8"));
  for (const gate of completedEvidence.gates.filter((gate) => gate.stage === "pre-build")) {
    gate.complete = true; gate.version = "0.3.0"; gate.reviewed_at = "2026-09-19T12:00:00Z"; gate.reviewer = "release reviewer"; gate.evidence_references = [`https://example.invalid/${gate.id}`];
  }
  completedEvidence.gates[0].reviewer = "";
  await writeFile(evidencePath, `${JSON.stringify(completedEvidence, null, 2)}\n`);
  result = run("--stable");
  assert.notEqual(result.status, 0, "weak completed evidence must fail");
  assert.match(result.stderr, /completed evidence gate/);
  completedEvidence.gates[0].reviewer = "release reviewer";
  await writeFile(evidencePath, `${JSON.stringify(completedEvidence, null, 2)}\n`);
  result = run("--stable");
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /preflight eligible/);
  await assert.rejects(access(path.join(temporary, "dist")), "strict preflight must not write dist");

  result = run();
  assert.equal(result.status, 0, result.stderr);
  const readiness = "warp-vs-isp-benchmark-0.3.0-readiness";
  await access(path.join(temporary, "dist", readiness, "VERSION"));
  await access(path.join(temporary, "dist", `${readiness}-SHA256SUMS`));
  await verifyChecksums(readiness);
  await writeFile(path.join(temporary, "dist", readiness, "VERSION"), "corrupted\n");
  await assert.rejects(verifyChecksums(readiness), /checksum for/);
  console.log("Release packaging tests passed.");
} finally {
  await rm(temporary, { recursive: true, force: true });
}
