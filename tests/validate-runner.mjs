import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import assert from "node:assert/strict";

const script = await readFile(resolve("scripts/warp-bench.ps1"), "utf8");
const bash = await readFile(resolve("scripts/warp-bench.sh"), "utf8");
const targets = JSON.parse(script.match(/\$script:TargetManifestJson = @'\r?\n([^]*?)\r?\n'@/)[1]);
const artifact = JSON.parse(script.match(/\$script:IperfArtifactJson = @'\r?\n([^]*?)\r?\n'@/)[1]);
const manifestTargets = JSON.parse(await readFile(resolve("manifests/targets.json"), "utf8"));
const binaries = JSON.parse(await readFile(resolve("manifests/binaries.json"), "utf8"));

assert.equal(targets.manifest_version, manifestTargets.manifest_version, "embedded target manifest version");
assert.deepEqual(targets.targets.map(({ id }) => id), manifestTargets.targets.filter(({ enabled }) => enabled).map(({ id }) => id), "embedded target IDs and order");
for (const target of targets.targets) {
  const source = manifestTargets.targets.find(({ id }) => id === target.id);
  for (const endpoint of target.endpoints) {
    const expected = source.endpoints.find(({ id }) => id === endpoint.id);
    assert.ok(expected, `embedded endpoint ${endpoint.id} exists`);
    assert.equal(endpoint.hostname, expected.hostname, `embedded hostname ${endpoint.id}`);
    assert.deepEqual(endpoint.ports, expected.ports, `embedded ports ${endpoint.id}`);
  }
}
const approved = binaries.artifacts.find(({ id }) => id === artifact.id);
assert.ok(approved, "embedded artifact exists in binary manifest");
for (const key of ["version", "url", "sha256", "archive_format", "executable_path", "use_status"]) {
  assert.equal(artifact[key], approved[key], `embedded artifact ${key}`);
}
assert.deepEqual(artifact.required_files, approved.required_files, "embedded required files");
assert.match(script, /if \(\$MyInvocation\.InvocationName -ne '\.'\)/, "dot-source guard");
assert.doesNotMatch(script, /(?:^|[;|])\s*(?:Invoke-Expression|iex)\s/m, "runner does not evaluate downloaded code");
assert.match(script, /Get-FileHash[^\r\n]+SHA256/, "download hash verification");
assert.match(script, /AddressFamily\]::InterNetwork/, "IPv4 enforcement");
assert.match(script, /--json-stream/, "iperf transfer start is observable for loaded ping alignment");
assert.match(script, /SecurityProtocolType\]::Tls12/, "PowerShell 5.1 dependency download enables TLS 1.2");
assert.doesNotMatch(script, /Get-Content[^\r\n]+manifests|Join-Path[^\r\n]+manifests/i, "runtime does not require repository manifests");
console.log("Runner static and embedded-metadata checks passed.");

const embedded = (name) => JSON.parse(bash.match(new RegExp(`${name}='([^']+)'`))[1]);
const bashTargets = embedded("WARP_BENCH_TARGETS_JSON");
const bashJqs = ["LINUX_X86_64", "MACOS_X86_64", "MACOS_AARCH64"].map((suffix) => embedded(`WARP_BENCH_JQ_ARTIFACT_${suffix}`));
const bashIperf = embedded("WARP_BENCH_IPERF_ARTIFACT");
assert.equal(bashTargets.manifest_version, manifestTargets.manifest_version, "Bash embedded target manifest version");
assert.deepEqual(bashTargets.targets.map(({ id }) => id), manifestTargets.targets.filter(({ enabled }) => enabled).map(({ id }) => id), "Bash embedded enabled targets");
for (const target of bashTargets.targets) {
  const source = manifestTargets.targets.find(({ id }) => id === target.id);
  assert.ok(source, `Bash target ${target.id} exists`);
  assert.deepEqual(
    target.endpoints.map(({ id }) => id),
    source.endpoints.map(({ id }) => id),
    `Bash embeds every endpoint for ${target.id}`
  );
  for (const endpoint of target.endpoints) {
    const expected = source.endpoints.find(({ id }) => id === endpoint.id);
    for (const key of ["priority", "hostname", "verification_status"]) {
      assert.equal(endpoint[key], expected[key], `Bash endpoint ${endpoint.id} ${key}`);
    }
    assert.deepEqual(endpoint.ports, expected.ports, `Bash endpoint ${endpoint.id} ports`);
  }
}
for (const [actual, id] of [...bashJqs.map((item) => [item, item.id]), [bashIperf, "iperf3-3.21-linux-x86_64-userdocs"]]) {
  const source = binaries.artifacts.find((item) => item.id === id);
  assert.ok(source, `${id} exists in binary manifest`);
  assert.deepEqual(actual, source, `${id} embeds the full artifact metadata`);
}
assert.equal(bashIperf.use_status, "candidate", "Linux iperf candidate status remains candidate");
for (const marker of ["/dev/tty", "BASH_SOURCE", "wb_sha256", "shasum -a 256", "dscacheutil", "Time::HiRes", "wb_timeout", "--json-stream", "--get-server-output", "temporary_download", "wb_select_jq_artifact", "macOS requires a compatible system iperf3", "candidate, not approved", "does not support resume"]) assert.match(bash, new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")), `Bash security/behavior marker ${marker}`);
assert.doesNotMatch(bash, /eval\s|source\s+<\(/, "Bash does not evaluate downloaded code");
assert.doesNotMatch(bash, /\$\{[^}]+,,\}/, "Bash avoids Bash 4 lowercase expansion");
console.log("Bash embedded-metadata and security/behavior checks passed.");
