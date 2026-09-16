import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import assert from "node:assert/strict";

const script = await readFile(resolve("scripts/warp-bench.ps1"), "utf8");
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
