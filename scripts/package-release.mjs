import { cp, mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const args = new Set(process.argv.slice(2));
const root = path.resolve(process.env.WARP_BENCH_RELEASE_ROOT || scriptRoot);
if (![...args].every((arg) => ["--check", "--stable"].includes(arg))) {
  throw new Error("Usage: node scripts/package-release.mjs [--check] [--stable]");
}

const text = (file) => readFile(path.join(root, file), "utf8");
const json = async (file) => JSON.parse(await text(file));
const semver = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/;
const errors = [];
const addError = (message) => errors.push(`RELEASE CHECK: ${message}`);

const version = (await text("VERSION")).trim();
if (!semver.test(version)) addError(`VERSION must be strict semver; got ${JSON.stringify(version)}.`);
const packageJson = await json("package.json");
const lock = await json("package-lock.json");
for (const [name, actual] of [
  ["package.json", packageJson.version],
  ["package-lock.json", lock.version],
  ["package-lock.json packages['']", lock.packages?.[""]?.version]
]) if (actual !== version) addError(`${name} version ${JSON.stringify(actual)} does not match VERSION ${version}.`);

const bash = await text("scripts/warp-bench.sh");
const powershell = await text("scripts/warp-bench.ps1");
const bashVersion = bash.match(/^WARP_BENCH_VERSION=(.+)$/m)?.[1];
const psVersion = powershell.match(/^\$script:WarpBenchVersion = '([^']+)'/m)?.[1];
if (bashVersion !== version) addError(`Bash runner version ${JSON.stringify(bashVersion)} does not match VERSION ${version}.`);
if (psVersion !== version) addError(`PowerShell runner version ${JSON.stringify(psVersion)} does not match VERSION ${version}.`);

const viewer = await text("viewer/index.html");
const schema = JSON.stringify(JSON.parse(await text("schema/results-v1.schema.json")));
const embeddedSchema = viewer.match(/\/\* embedded-schema:start \*\/([\s\S]*?)\/\* embedded-schema:end \*\//)?.[1];
if (embeddedSchema !== schema) addError("viewer embedded schema is stale; run npm run build:viewer.");

const targets = await json("manifests/targets.json");
const binaries = await json("manifests/binaries.json");
const evidence = await json("docs/release-evidence.json");
const requiredEvidenceGates = [["physical-windows-x64", "pre-build"], ["physical-unraid-linux-x86_64", "pre-build"], ["physical-macos-intel", "pre-build"], ["physical-macos-apple-silicon", "pre-build"], ["indosat-peak", "pre-build"], ["indosat-off-peak", "pre-build"], ["independent-final-release-asset-verification", "post-build"]];
const isUtc = (value) => typeof value === "string" && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/.test(value) && !Number.isNaN(Date.parse(value));
const isSafeEvidenceReference = (value) => {
  if (typeof value !== "string" || !value.trim()) return false;
  if (value.startsWith("https://")) { try { return new URL(value).protocol === "https:"; } catch { return false; } }
  return /^[A-Za-z0-9][A-Za-z0-9._/-]*$/.test(value) && !value.split("/").includes("..");
};
if (evidence.schema_version !== "1.0.0" || !Array.isArray(evidence.gates) || JSON.stringify(evidence.gates.map((gate) => [gate?.id, gate?.stage])) !== JSON.stringify(requiredEvidenceGates)) {
  addError("docs/release-evidence.json must contain the required evidence gate IDs and stages in order.");
} else for (const gate of evidence.gates) {
  if (typeof gate.complete !== "boolean" || !Array.isArray(gate.evidence_references) || !Object.hasOwn(gate, "version") || !Object.hasOwn(gate, "reviewed_at") || !Object.hasOwn(gate, "reviewer") || !Object.hasOwn(gate, "artifact_sha256")) addError(`evidence gate ${gate.id} has an invalid shape.`);
  if (gate.complete && (gate.version !== version || !isUtc(gate.reviewed_at) || typeof gate.reviewer !== "string" || !gate.reviewer.trim() || gate.evidence_references.length === 0 || gate.evidence_references.some((reference) => !isSafeEvidenceReference(reference)))) addError(`completed evidence gate ${gate.id} needs matching version, UTC review metadata, reviewer, and safe evidence references.`);
  if (gate.id === "independent-final-release-asset-verification" && gate.complete && (typeof gate.artifact_sha256 !== "string" || !/^[a-f0-9]{64}$/.test(gate.artifact_sha256))) addError("completed final asset evidence needs a 64-hex artifact_sha256.");
}
const parsePs = (name) => JSON.parse(powershell.match(new RegExp(`\\$script:${name} = @'\\r?\\n([\\s\\S]*?)\\r?\\n'@`))?.[1] || "null");
const parseBash = (name) => JSON.parse(bash.match(new RegExp(`${name}='([^']+)'`))?.[1] || "null");
const checkTargets = (embedded, runner, endpointPolicy) => {
  if (!embedded || embedded.manifest_version !== targets.manifest_version) return addError(`${runner} target snapshot manifest version is inconsistent.`);
  const expectedIds = targets.targets.filter((item) => item.enabled).map((item) => item.id);
  if (JSON.stringify((embedded.targets || []).map((item) => item.id)) !== JSON.stringify(expectedIds)) return addError(`${runner} target snapshot IDs or order are inconsistent.`);
  for (const target of embedded.targets || []) {
    const tracked = targets.targets.find((item) => item.id === target.id && item.enabled);
    if (!tracked) return addError(`${runner} target snapshot contains an untracked or disabled target.`);
    const expectedEndpoints = endpointPolicy(tracked.endpoints);
    if (JSON.stringify((target.endpoints || []).map((item) => item.id)) !== JSON.stringify(expectedEndpoints.map((item) => item.id))) return addError(`${runner} target snapshot endpoint IDs or order are inconsistent for ${target.id}.`);
    for (const endpoint of target.endpoints || []) {
      const expected = tracked.endpoints.find((item) => item.id === endpoint.id);
      if (!expected || ["priority", "hostname", "verification_status"].some((key) => endpoint[key] !== expected[key]) || JSON.stringify(endpoint.ports) !== JSON.stringify(expected.ports)) return addError(`${runner} target snapshot differs for ${target.id}/${endpoint.id}.`);
    }
  }
};
const checkArtifact = (embedded, id, runner) => {
  const tracked = binaries.artifacts.find((item) => item.id === id);
  for (const key of ["id", "version", "url", "sha256", "archive_format", "executable_path", "use_status", "distribution_mode"]) {
    if (!tracked || embedded?.[key] !== tracked[key]) return addError(`${runner} dependency metadata differs for ${id} (${key}).`);
  }
  if (JSON.stringify(embedded?.required_files) !== JSON.stringify(tracked.required_files)) addError(`${runner} dependency metadata differs for ${id} (required_files).`);
};
// Bash is a complete release snapshot. PowerShell filters unavailable endpoints
// before embedding because its runtime cannot use them; no other omission is valid.
checkTargets(parsePs("TargetManifestJson"), "PowerShell", (endpoints) => endpoints.filter((item) => item.verification_status !== "unavailable"));
checkArtifact(parsePs("IperfArtifactJson"), "iperf3-3.21-windows-x86_64-userdocs", "PowerShell");
checkTargets(parseBash("WARP_BENCH_TARGETS_JSON"), "Bash", (endpoints) => endpoints);
const jqPlatforms = [
  ["LINUX_X86_64", "linux/x86_64", "jq-1.8.2-linux-x86_64"],
  ["MACOS_X86_64", "macos/x86_64", "jq-1.8.2-macos-x86_64"],
  ["MACOS_AARCH64", "macos/aarch64", "jq-1.8.2-macos-aarch64"]
];
for (const [suffix, platform, artifactId] of jqPlatforms) {
  const artifact = parseBash(`WARP_BENCH_JQ_ARTIFACT_${suffix}`); checkArtifact(artifact, artifactId, "Bash");
  const tracked = binaries.artifacts.find((item) => item.id === artifactId);
  const branch = bash.match(new RegExp(`${platform.replace("/", "\\/")}\\)\\s*WARP_BENCH_JQ_ARTIFACT=.*?;\\s*WARP_BENCH_JQ_URL=([^;\\s]+);\\s*WARP_BENCH_JQ_SHA256=([a-f0-9]{64})`));
  if (!branch || branch[1] !== tracked?.url || branch[2] !== tracked?.sha256) addError(`Bash runtime jq URL/SHA-256 differs for ${platform}.`);
}
checkArtifact(parseBash("WARP_BENCH_IPERF_ARTIFACT"), "iperf3-3.21-linux-x86_64-userdocs", "Bash");

const blockers = [];
for (const artifact of binaries.artifacts) {
  if (artifact.use_status !== "approved" || artifact.redistribution_status !== "approved") blockers.push(`dependency ${artifact.id} is ${artifact.use_status}/${artifact.redistribution_status}`);
}
if (!errors.length) for (const gate of evidence.gates) if (gate.stage === "pre-build" && !gate.complete) blockers.push(`pre-build evidence gate ${gate.id} is incomplete (docs/release-evidence.json)`);
if (errors.length) throw new Error(errors.join("\n"));
console.log(`Release metadata check passed for ${version}.`);
console.log(blockers.length ? `Stable-release blockers:\n${blockers.map((item) => `- ${item}`).join("\n")}` : "Stable-release blockers: none.");
if (args.has("--stable")) {
  if (blockers.length) throw new Error("Stable release is blocked; resolve every blocker above.");
  console.log("Stable publication preflight eligible. Generate a readiness candidate, verify its exact bytes independently, then record the post-build evidence gate before publication.");
  process.exit(0);
}
if (args.has("--check")) process.exit(0);

const bundleName = `warp-vs-isp-benchmark-${version}-readiness`;
const dist = path.join(root, "dist");
const bundle = path.join(dist, bundleName);
await rm(dist, { recursive: true, force: true });
await mkdir(bundle, { recursive: true });
const assets = ["scripts", "viewer", "schema", "manifests", "docs", "LICENSE", "VERSION", "README.md", "package.json", "package-lock.json"];
for (const asset of assets) await cp(path.join(root, asset), path.join(bundle, asset), { recursive: true, force: false, errorOnExist: true });
const files = [];
async function collect(directory, prefix = "") {
  for (const entry of (await readdir(directory, { withFileTypes: true })).sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0))) {
    const relative = path.posix.join(prefix, entry.name); const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) await collect(absolute, relative); else if (entry.isFile()) files.push([relative, absolute]);
  }
}
await collect(bundle);
const sums = await Promise.all(files.map(async ([relative, absolute]) => `${createHash("sha256").update(await readFile(absolute)).digest("hex")}  ${bundleName}/${relative}`));
await writeFile(path.join(dist, `${bundleName}-SHA256SUMS`), `${sums.join("\n")}\n`);
console.log(`Created readiness candidate bundle ${path.relative(root, bundle)}. It is not publishable until its unchanged bytes are independently verified and the post-build evidence gate is recorded.`);
