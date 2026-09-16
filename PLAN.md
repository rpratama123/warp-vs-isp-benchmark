# WARP vs ISP Benchmark Plan

## Objective

Build an interactive benchmark that compares a direct ISP connection against
Cloudflare WARP routed through MikroTik WireGuard.

The user manually switches policy-based routing between phases. Both phases run
on the same client against the same selected endpoints with identical test
parameters.

The benchmark measures whether WARP improves performance to the tested
destinations. It must not claim to prove ISP gateway congestion or predict
performance to every destination.

## Confirmed Requirements

| Item | Decision |
| --- | --- |
| Initial test device | x86-64 Unraid NAS without Python |
| Platform priority | Windows x64, Linux x86-64, then macOS Intel and Apple Silicon |
| ISP reference connection | Indosat HiFi fiber, 300 Mbps upload/download, no FUP |
| IP version | IPv4 only |
| Routing | All Internet traffic from the test device follows the selected MikroTik policy |
| Switching | Manual, with interactive confirmation |
| Profiles | Quick and Extended, selected at startup |
| Hosting | Scripts, dependency binaries if needed, and HTML viewer |
| Measurement endpoints | Public third-party servers only |
| Output | Versioned JSON with a stable, documented schema |
| Privacy | Retain destination IPs; omit public client IP and local host identity by default |
| Visualization | Self-contained HTML, local file import, no uploads |
| Installation | No permanent installation or administrator privileges by default |

## Architecture

### Windows Runner

Implement `scripts/warp-bench.ps1` for Windows x64, supporting Windows
PowerShell 5.1 and PowerShell 7.

Use:

- .NET ping APIs to avoid parsing localized `ping.exe` output.
- iperf3 for throughput measurements.
- Built-in PowerShell JSON serialization.
- Temporary, checksum-verified dependency downloads when required.

iperf3 is not officially supported on Windows by ESnet. Select and validate a
community build; do not substitute iperf2.

### Unix Runner

Implement `scripts/warp-bench.sh` using Bash.

Use:

- Native ping with platform-specific adapters.
- iperf3 for throughput measurements.
- `jq` for JSON processing, downloaded temporarily if unavailable.
- Explicit support for Linux x86-64/Unraid first, then macOS architectures.

Do not require Python. Detect available utilities instead of assuming a
complete GNU/Linux userland.

Handle restricted ICMP permissions, incompatible binaries, and non-executable
temporary directories with actionable errors rather than system modifications.

### Release Distribution

Store scripts, schemas, and manifests in Git. Prefer GitHub Release assets for
compiled binaries.

Each release must use matching, pinned versions of its scripts, manifests, and
downloadable dependencies.

Provide one-line launchers and a download-and-inspect alternative.

Illustrative launch commands:

```bash
curl -fsSL https://<host>/warp-bench.sh | bash
```

```powershell
iwr -useb https://<host>/warp-bench.ps1 | iex
```

The Bash runner must read interactive answers from `/dev/tty` when its standard
input contains the downloaded script.

## User Workflow

1. Detect platform, architecture, terminal capabilities, and dependencies.
2. Ask the user to select Quick or Extended.
3. Confirm a writable, persistent results directory.
4. Explain expected duration, estimated traffic, and temporary connection
   saturation.
5. Ask the user to pause downloads, backups, and other heavy traffic.
6. Load the pinned target manifest and resolve IPv4 destinations.
7. Confirm direct routing and verify baseline WARP state.
8. Run baseline measurements and save checkpoints.
9. Ask the user to enable WARP policy routing.
10. Wait for confirmation and briefly allow routing to settle.
11. Verify WARP using fresh connections.
12. Run identical measurements against the selected endpoints.
13. Save final results and print a comparison summary and absolute output path.

Allow the user to finish after baseline without losing results.

If route verification fails, offer retry, save-and-exit, or explicit
continuation as unverified. Never silently label an unverified phase as
verified.

The runner must not modify MikroTik configuration.

## WARP Verification

Request the following over IPv4 before and after each phase:

```text
https://www.cloudflare.com/cdn-cgi/trace
```

Expected states:

- Baseline: `warp=off`.
- WARP: `warp=on` or `warp=plus`.
- Failed request or unrecognized response: unknown.

Record the observed state, Cloudflare `colo`, and verification timestamps.
Discard the trace's client IP field.

A successful trace check verifies only that HTTPS request. It does not
independently prove that ICMP and iperf3 traffic followed the same policy.
Document this limitation and require source-based routing of all Internet
traffic from the client.

Warn about connection tracking and FastTrack if policy changes do not appear to
take effect.

## Measurement Profiles

| Setting | Quick | Extended |
| --- | ---: | ---: |
| Idle probes per target | 30 | 120 |
| Approximate probe interval | 1 second | 1 second |
| TCP transfer duration | 10 seconds | 15 seconds |
| Repetitions per direction | 1 | 3 |
| TCP streams | 1 | 1 |
| Download and upload | Yes | Yes |
| Ping during throughput | Yes | Yes |
| Cooldowns | Short | Longer |
| Approximate total duration | 7-10 minutes | 30-40 minutes |

Duration excludes the manual switching pause and may increase with failures or
retries.

For seven destinations and two phases, estimated payload at a sustained 300
Mbps throughout all transfers is:

- Quick: approximately 10.5 GB.
- Extended: approximately 47.3 GB.

These are estimates, not enforced traffic caps.

Run low-rate idle ping tests concurrently across destinations where practical.
Run throughput tests sequentially.

Keep UDP and multi-stream testing outside the initial default profiles.

### Metrics

Collect:

- ICMP probes sent, received, timed out, and failed locally.
- ICMP reply-loss percentage.
- Minimum, mean, median, p95, and maximum successful RTT.
- RTT standard deviation.
- Mean absolute RTT difference between adjacent successful probes, excluding
  pairs separated by missing replies.
- TCP receiver throughput for download and upload.
- Per-interval throughput.
- TCP retransmission statistics when available.
- RTT and ICMP loss during each throughput transfer.

Document percentile and statistical definitions so both runners produce
equivalent results.

Do not equate ICMP loss with application packet loss. Do not label RTT
variation as UDP jitter or one-way latency.

## Public Endpoint Strategy

Use geographically identified public measurement servers, not anycast DNS
services or arbitrary CDN-fronted websites.

Initial candidates:

| Region | Primary candidate | Listed iperf3 ports | Alternate |
| --- | --- | --- | --- |
| Indonesia | `speedtest.tangerang2.myrepublic.net.id` | `9201-9240` | To be verified |
| Singapore | `speedtest.sin1.sg.leaseweb.net` | `5201-5210` | `sgp.proof.ovh.net`, `5201-5210` |
| Tokyo | `speedtest.tyo11.jp.leaseweb.net` | `5201-5210` | `89.187.160.1`, `5201` |
| Netherlands | `speedtest.ams1.nl.leaseweb.net` | `5201-5210` | `speedtest.serverius.net`, `5002` |
| UK/London | `lon.speedtest.clouvider.net` | `5200-5209` | `speedtest.lon12.uk.leaseweb.net`, `5201-5210` |
| US West/Los Angeles | `la.speedtest.clouvider.net` | `5200-5209` | `speedtest.lax12.us.leaseweb.net`, `5201-5210` |
| US East/New York | `speedtest.nyc1.us.leaseweb.net` | `5201-5210` | To be verified |

These are publicly listed candidates, not verified-live endpoints. Validate
availability, advertised location, permitted usage, and protocol support before
release.

The Indonesian candidate has conflicting city information in the source
listing. Label it Indonesia with city unverified until confirmed.

Use the selected throughput destination as its initial ping target, but validate
ICMP support independently.

### Selection Rules

- Embed a curated, versioned target manifest.
- Record sources and verification dates.
- Resolve and pin IPv4 addresses for paired measurements.
- Attempt only documented ports, with bounded retries and backoff.
- Preserve the selected IP and port across phases where possible.
- Record changes rather than silently substituting endpoints.
- Never choose the fastest server independently in each phase.
- Exclude mismatched endpoints from direct paired comparisons.
- Accept missing regional results when public servers are unavailable.
- Do not convert unavailable or busy servers into zero-throughput measurements.
- Respect operator limits and avoid unnecessary capacity-heavy preflight tests.

Geographic order is a presentation choice, not an assumption about latency
order.

## Interactive Progress

Display:

- Current phase and destination.
- Measurement type and repetition.
- Probe or transfer progress.
- Elapsed time and approximate remaining time.
- Live measurements where supported.
- Retry reasons and cooldowns.
- Checkpoint confirmation and output location.

Example:

```text
[Baseline | 3/7 | Tokyo]
Download: repetition 2/3, 9/15 seconds
Current throughput: 247 Mbps
Results checkpoint saved.
```

Provide a plain-text fallback when terminal capabilities are limited.

Validate live-output handling against the selected iperf3 versions. Do not
assume all platforms support the newest JSON streaming features. Final
structured results must remain reliable even when only a countdown can be shown
during a transfer.

## Dependency Management

Check installed tools for required capabilities before using them.

If a compatible tool is unavailable:

1. Select the pinned artifact for the platform.
2. Download it into a private temporary directory.
3. Verify its SHA-256 before extraction and execution.
4. Extract safely and perform an executable self-check.
5. Use the same tool throughout both phases.
6. Clean up temporary dependencies without deleting results.

The binary manifest must contain:

- Tool version.
- OS and architecture.
- Exact artifact URL.
- SHA-256 digest.
- Archive format and executable path.
- Upstream provenance.
- Required runtime libraries.
- License and redistribution notices.

Do not automatically install packages, change `PATH` permanently, alter
PowerShell execution policy, or invoke `sudo`.

If suitable portable binaries are unavailable, use a documented build process
rather than an unverified download.

## Result Format

Use a unique run directory with a stable filename:

```text
warp-benchmark-<UTC-start-time>-<run-id>/results.json
```

Confirm persistent storage explicitly on Unraid.

The JSON document must include:

| Section | Contents |
| --- | --- |
| Identity | Schema version, script version, run ID, completion status |
| Environment | OS, architecture, measurement backend, tool versions |
| Configuration | Profile, durations, probe settings, repetitions, streams, IPv4 |
| Targets | Stable IDs, hostnames, destination IPs, ports, advertised regions, manifest version |
| Phases | Requested routing mode, observed verification state, timestamps |
| Measurements | Raw samples, summaries, transfer intervals, normalized metrics |
| Diagnostics | Failures, retries, unsupported features, sanitized tool details |

Serialization rules:

- UTF-8 JSON.
- Numeric measurements with explicit units in field names.
- UTC timestamps.
- `null` for unavailable values.
- Stable ordering for target and measurement arrays.
- Explicit distinction between failed, skipped, interrupted, and completed
  tests.
- Atomic checkpoint updates after each completed measurement.
- No automatic uploads.

"Deterministic" means a stable data contract and consistent calculations, not
identical measurements or byte-identical files between runs.

### Privacy

Retain destination IPs because endpoint identity is necessary for meaningful
comparisons.

Omit by default:

- Public client IP.
- Local client IP.
- Hostname and user account name.
- Unsanitized Cloudflare trace responses.
- Unsanitized iperf3 output containing client addressing.

Apply sanitization to persisted diagnostics as well as normalized results.

### Interruption And Resume

Preserve completed measurements after cancellation or failure.

An explicit resume mode must:

- Load the original configuration and target selection.
- Recheck expected routing state.
- Record the interruption and time gap.
- Avoid mixing results from incompatible configurations.
- Warn that a long gap weakens the paired comparison.

## HTML Viewer

Build `viewer/index.html` as a self-contained file with embedded JavaScript,
CSS, and charting code.

Support file-picker and drag-and-drop import of `results.json`.

Show:

- Baseline versus WARP median and p95 RTT.
- ICMP loss and RTT variation.
- Upload and download throughput.
- Repetition ranges.
- Idle versus loaded latency.
- Per-interval timelines.
- Clear explanations of missing or unverified data.

Validate the schema and treat imported content as untrusted data.

Compare only compatible measurements. Avoid an opaque overall score or
unjustified statistical-confidence claims.

Do not use runtime CDN requests, telemetry, or uploads.

## Planned Repository Layout

```text
scripts/
    warp-bench.ps1
    warp-bench.sh
manifests/
    targets.json
    binaries.json
schema/
    results-v1.schema.json
viewer/
    index.html
tests/
    fixtures/
docs/
    methodology.md
    binary-provenance.md
PLAN.md
```

## Delivery Phases

Each phase should be reviewed and accepted before beginning the next one. A
phase may refine later details, but must not silently break an accepted schema
or methodology.

### Phase 1: Contracts And Methodology

Define the behavior before implementing either runner.

Deliverables:

- Results JSON Schema v1.
- Target and binary manifest schemas.
- Exact metric, percentile, rounding, and error-state definitions.
- Quick and Extended profile definitions.
- Privacy and sanitization rules.
- Representative valid, partial, failed, and interrupted result fixtures.
- Methodology document explaining limitations and fair-comparison rules.

Completion gate:

- Example result files validate against the schema.
- Both Windows and Unix implementations can use the contract without
  platform-specific fields changing its meaning.
- The planned viewer can derive every chart from the documented fields.

### Phase 2: Endpoint And Binary Research

Establish trustworthy external inputs before wiring them into a runner.

Deliverables:

- Curated IPv4 target manifest with primary and alternate endpoints.
- Documented endpoint source, location confidence, ports, capabilities,
  usage policy, and verification date.
- Selected Windows x64 iperf3 build and `jq` strategy where needed.
- Candidate portable Linux x86-64 and macOS artifacts.
- SHA-256 hashes, provenance, licenses, and redistribution assessment.
- Decision on whether project-owned reproducible builds are required.

Completion gate:

- Every enabled endpoint has been tested or is clearly marked unverified.
- Every downloadable artifact has traceable provenance and an acceptable
  redistribution license.
- No runner depends on an unpinned `latest` URL.

### Phase 3: Windows MVP

Build the first end-to-end runner for Windows x64.

Deliverables:

- Interactive PowerShell runner for Quick and Extended profiles.
- Dependency discovery, download, hash verification, and temporary cleanup.
- IPv4 WARP verification with privacy filtering.
- Idle ICMP, TCP upload/download, and loaded-latency measurements.
- Baseline-to-WARP workflow with route-state checks.
- Atomic checkpointing, baseline-only completion, and interruption handling.
- Schema-compliant output and terminal summary.
- Automated tests for calculation, serialization, failures, and redaction.

Completion gate:

- A clean Windows x64 machine can complete a paired benchmark without Python,
  administrator rights, or permanent installation.
- Generated results validate against Schema v1.
- Common server and network failures produce partial results rather than data
  loss or misleading zero values.

### Phase 4: Linux And Unraid

Port the accepted behavior to Bash without changing metric semantics.

Deliverables:

- Linux x86-64 Bash runner tested on Unraid.
- `/dev/tty` interaction for pipe-to-shell usage.
- Linux ping adapter and equivalent statistics.
- `jq` and iperf3 dependency handling without package installation or Python.
- Persistent output-location checks appropriate for Unraid.
- Cross-platform fixture tests proving equivalent normalized output.

Completion gate:

- The target Unraid NAS can complete the same paired benchmark.
- Windows and Linux produce equivalent statistics for shared fixtures.
- Both runners generate viewer-compatible Schema v1 results.

### Phase 5: macOS Support

Extend the Bash runner rather than create a third implementation.

Deliverables:

- macOS ping and utility compatibility layer.
- Intel and Apple Silicon dependency artifacts or documented fallbacks.
- Tests on supported macOS versions and both architectures where feasible.
- Updated manifests and binary provenance.

Completion gate:

- The same Bash entry point runs on Linux and supported macOS systems.
- macOS output remains semantically equivalent and validates against Schema v1.

### Phase 6: Self-Contained Viewer

Build visualization only after real runner outputs are stable.

Deliverables:

- Offline `viewer/index.html` with embedded CSS and JavaScript.
- File picker and drag-and-drop JSON import.
- Paired latency, loss, RTT variation, throughput, loaded-latency, and timeline
  views.
- Clear warnings for unverified routing, endpoint mismatch, missing data,
  interrupted runs, and long phase gaps.
- Safe handling of malformed and untrusted imported JSON.
- Accessible desktop and mobile layout.

Completion gate:

- The viewer works with fixtures and real outputs from every supported runner.
- Opening the viewer requires no web server or Internet connection.
- The viewer never compares incompatible measurements as a valid pair.

### Phase 7: Release And Field Validation

Package and validate the complete public workflow.

Deliverables:

- Versioned GitHub Release assets and checksums.
- Stable one-line launch URLs plus inspect-before-running instructions.
- Final binary provenance, licenses, methodology, privacy, and usage docs.
- End-to-end test matrix for supported systems.
- Real Indosat HiFi baseline/WARP validation during peak and off-peak periods.
- Endpoint maintenance and deprecation process.

Completion gate:

- Fresh systems can execute the documented commands and obtain valid results.
- Release assets are immutable, pinned, and hash-verified.
- Documentation accurately describes observed limitations and failure modes.

### Possible Later Enhancements

Keep these outside the first stable release unless evidence shows they are
needed:

- UDP loss and iperf3 jitter testing at a conservative configured rate.
- Multi-stream TCP diagnostics.
- IPv6 as a separate explicit mode.
- Baseline to WARP to baseline sequencing.
- Non-interactive automation and scheduled sampling.
- Additional application-level HTTPS measurements.
- Windows ARM64.

## Verification Matrix

Test at least:

- Compatible dependencies already installed.
- Dependencies missing, incompatible, or failing checksum verification.
- Baseline/WARP trace mismatch and trace unavailability.
- ICMP blocked while throughput remains available.
- Busy, unreachable, or partially supported iperf3 servers.
- Missing upload/download receiver statistics.
- Interrupted runs, baseline-only completion, and resume.
- Unwritable or nonpersistent output locations.
- Locale differences and limited terminal capabilities.
- Equivalent statistics across Windows and Unix fixtures.
- Privacy redaction across all persisted fields.
- Offline viewer operation and malformed input handling.

For real measurements, use wired Ethernet, minimize background traffic, and
keep router configuration unchanged except for the intended policy switch.

Repeat comparisons during peak and off-peak periods before deciding whether to
enable WARP globally. A later optional baseline to WARP to baseline workflow can
help identify time-related changes.

## Research Sources

- [Public iperf3 server directory](https://github.com/R0GGER/public-iperf3-servers)
- [iperf.fr server listings and statuses](https://iperf.fr/iperf-servers.php)
- [iperf.fr binary sources](https://iperf.fr/iperf-download.php)
- [ESnet iperf3 FAQ and platform limitations](https://software.es.net/iperf/faq.html)
