# WARP vs ISP Benchmark

**Status: release-readiness prerelease bundle only. A stable release is blocked.**
The benchmark compares paired direct-ISP and WARP-routed measurements; it does
not diagnose an ISP or predict all destinations. See the [methodology](docs/methodology.md),
[endpoint evidence](docs/endpoints.md), and [binary provenance](docs/binary-provenance.md).

## Supported platforms

- Windows x64 (Windows PowerShell 5.1 or PowerShell 7)
- Linux x86-64, including Unraid
- macOS 14+ on Intel and Apple Silicon

Linux and macOS iperf3 dependencies are pinned candidates, not approved stable
dependencies. Field validation is also incomplete; details are in
[release validation](docs/release-validation.md).

`node scripts/package-release.mjs --stable` is a nonwriting pre-publication
eligibility check for dependency approvals and pre-build field evidence. It
does not create stable assets. The normal packaging command creates a readiness
candidate. Independently verify that candidate's exact bytes and checksum
manifest, record the post-build gate in `docs/release-evidence.json`, then
promote those unchanged bytes without rebuilding.

## Acquire and inspect safely

No published release is claimed here. A readiness workflow artifact contains a
versioned directory and its checksum file in the same extracted parent:
`warp-vs-isp-benchmark-<VERSION>-readiness/` and
`warp-vs-isp-benchmark-<VERSION>-readiness-SHA256SUMS`. Download the workflow
artifact from GitHub, extract it, and set `<ARTIFACT_ROOT>` to that parent (the
directory containing both entries). Replace `<VERSION>` with `0.3.0` or the
exact reviewed version. Verify every packaged/listed file before inspection.
Checksum paths are relative to the extracted artifact root, so run the checksum
tool from that directory; `sha256sum -c path/to/SHA256SUMS` from another cwd is
incorrect.

```bash
artifact_root="<ARTIFACT_ROOT>"
bundle="warp-vs-isp-benchmark-<VERSION>-readiness"
sums="${bundle}-SHA256SUMS"
if command -v sha256sum >/dev/null; then
  (cd "$artifact_root" && sha256sum -c "$sums")
else
  (cd "$artifact_root" && shasum -a 256 -c "$sums")
fi
less "$artifact_root/$bundle/scripts/warp-bench.sh"
bash "$artifact_root/$bundle/scripts/warp-bench.sh"
```

```powershell
$artifactRoot = '<ARTIFACT_ROOT>'
$bundle = 'warp-vs-isp-benchmark-<VERSION>-readiness'
$sums = Join-Path $artifactRoot "$bundle-SHA256SUMS"
Get-Content $sums | ForEach-Object {
  if ($_ -notmatch '^(?<hash>[0-9a-f]{64})  (?<file>.+)$') { throw "Invalid checksum entry: $_" }
  $actual = (Get-FileHash (Join-Path $artifactRoot $Matches.file) -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $Matches.hash) { throw "Checksum mismatch: $($Matches.file)" }
}
Get-Content (Join-Path $artifactRoot "$bundle/scripts/warp-bench.ps1") -Raw | more
& (Join-Path $artifactRoot "$bundle/scripts/warp-bench.ps1")
```

The PowerShell command fails on malformed or mismatched entries. Inspect the
included manifests before running. **Do not use pipe-to-shell
commands** (`curl | bash` or `iwr | iex`) for an unreviewed network response:
they execute changed or compromised content before inspection and verification.

## Results viewer and privacy

Open `viewer/index.html` locally and import a result JSON by file picker or
drag-and-drop. It is self-contained and does not upload results. Results omit
the public client IP and local host identity by default, but retain destination
addresses and timing/network evidence; redact before sharing if needed.

WARP trace verification applies only to the checked HTTPS connection. Public
endpoints can be unavailable, geographically uncertain, rate-limited, or have
different ICMP behavior. Follow [endpoint maintenance](docs/endpoint-maintenance.md)
before relying on a target set.
