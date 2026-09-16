# Benchmark Methodology

## Scope

This benchmark compares two routes from one client at nearby points in time:

- `baseline`: the client's normal direct ISP route.
- `warp`: the route selected by the user's MikroTik policy for Cloudflare WARP.

It measures the behavior of those routes to a fixed set of public endpoints. It
does not prove why a route behaves differently, identify a congested carrier,
or predict performance to destinations that were not measured.

The first schema version supports IPv4 only.

## Fair Comparison Rules

A baseline/WARP measurement pair is comparable only when all of these match:

- Logical target ID.
- Pinned destination IPv4 address.
- TCP destination port, when applicable.
- Measurement kind and normalized backend semantics.
- Protocol and client-perspective direction.
- Requested duration, stream count, repetition number, and profile settings.

The target hostname is resolved before baseline testing. The selected IPv4
address and port remain fixed for both phases. A fallback, DNS re-resolution,
or port change produces unpaired data rather than a valid comparison.

Both phases must be route-verified for a pair to contribute to a valid overall
comparison. Unverified measurements remain visible, but the viewer must not
present them as conclusive baseline-versus-WARP pairs.

Tests use one TCP stream. Throughput tests run sequentially so they do not
compete with each other. Idle ping tests may run concurrently because their
traffic is negligible, but every phase must use the same scheduling strategy.

## Profiles

All durations use decimal SI units. The following values are normative for
Schema v1 runners.

| Setting | Quick | Extended |
| --- | ---: | ---: |
| Idle probes per target | 30 | 120 |
| Idle probe interval | 1000 ms | 1000 ms |
| Idle probe timeout | 2000 ms | 2000 ms |
| ICMP payload | 32 bytes | 32 bytes |
| Loaded probe interval | 500 ms | 500 ms |
| Loaded probe timeout | 1000 ms | 1000 ms |
| TCP duration | 10 seconds | 15 seconds |
| TCP repetitions per direction | 1 | 3 |
| TCP streams | 1 | 1 |
| Route-settle delay | 5 seconds | 10 seconds |
| Delay between transfers | 2 seconds | 5 seconds |
| Delay between targets | 3 seconds | 10 seconds |
| Busy-server retries | 2 | 2 |
| Retry backoff | 5, then 10 seconds | 5, then 10 seconds |

Directions always run in the order download, then upload. Targets run in
manifest order. Repetitions run in ascending order. A failed transfer completes
its retry policy before the runner advances.

Probe scheduling uses a monotonic clock and a target cadence measured from the
first probe. Probes do not overlap. If an earlier probe completes after the next
target time, the next probe starts promptly and the actual elapsed time is
recorded; the runner does not issue multiple catch-up probes at once. Loaded
ping continues until the transfer ends, so its sample count can be lower than
`ceil(transfer duration / interval)` when replies are slow or probes time out.
A completed loaded-ping series starts within one interval of transfer start. Its
final probe starts no earlier than one probe timeout plus one scheduling interval
before transfer end, allowing for a non-overlapping timeout that crosses the
final cadence slot.

At a sustained 300 Mbps for all transfers across seven targets and both phases,
the nominal application payload is approximately 10.5 GB for Quick and 47.3 GB
for Extended. These estimates exclude retries, retransmissions, protocol
overhead, verification requests, and implementation overrun. Actual wire usage
can be higher.

## Route Verification

Before and after each phase, the runner requests this endpoint over IPv4 using
a fresh connection:

```text
https://www.cloudflare.com/cdn-cgi/trace
```

Expected observations are:

- Baseline: `warp=off`.
- WARP: `warp=on` or `warp=plus`.

A failed or unrecognized response is `unknown`, never `off`. The persisted
record contains the observed WARP state, Cloudflare `colo`, timestamp, expected
states, and match disposition. It excludes the client address and raw response.

This check proves only how the HTTPS verification request reached Cloudflare.
It cannot independently prove the route taken by ICMP or iperf3 traffic. The
test therefore requires source-based policy routing for all Internet traffic
from the client. Connection tracking and MikroTik FastTrack can delay or bypass
policy changes and should be checked when observations do not change as
expected.

## Ping Accounting

Each scheduled probe has one outcome:

- `reply`: a valid echo reply with an RTT.
- `timeout`: no valid reply before the deadline.
- `local_error`: the client could not send or evaluate the probe.

The counters are defined as:

```text
probes_recorded = replies_received + timed_out + local_failures
probes_sent = replies_received + timed_out
reply_loss_percent = 100 * timed_out / probes_sent
```

`reply_loss_percent` is `null` when `probes_sent` is zero. Local failures do not
count as network loss. ICMP reply loss is not equivalent to TCP or application
packet loss because hosts can block or deprioritize ICMP.

Raw RTT is normalized once to integer microseconds. Implementations calculate
summaries from those integers without intermediate rounding:

- Minimum and maximum are the smallest and largest successful RTTs.
- Mean is the arithmetic mean.
- Median is the middle sorted value, or the mean of the two middle values.
- p95 uses nearest rank: sorted one-based element `ceil(0.95 * n)`.
- Standard deviation is the population standard deviation, dividing by `n`.
- Mean absolute successive difference includes a pair only when both adjacent
  scheduled sequence numbers have replies. Missing probes break adjacency.

With one reply, standard deviation is zero and successive difference is
`null`. With no replies, every RTT summary is `null`.

Result files store raw RTT in integer microseconds and summary RTT in
milliseconds rounded to three decimals. Percentages are rounded to six decimal
places. Rounding is round-half-up for nonnegative values:

```text
rounded = floor(value * scale + 0.5) / scale
```

## TCP Throughput

Direction is always from the client perspective:

- Download uses iperf3 reverse mode; the client is receiver.
- Upload uses normal mode; the server is receiver.

Receiver goodput is authoritative:

```text
bits_per_second = round_half_up(receiver_bytes * 8000 / duration_ms)
```

Bytes, measured duration, and integer bits per second are stored. Sender values
are retained separately when available. Sender throughput must not replace a
missing receiver result. Retransmissions are nullable because not every side or
build reports them; zero means the tool explicitly reported zero.

Intervals store actual boundaries. A completed transfer requires interval data
covering the receiver measurement duration so the viewer can render a truthful
timeline. Omitted warm-up intervals remain marked and must not be treated as
measured throughput. No zero-throughput value is created for an unavailable,
busy, failed, or interrupted transfer.

When multiple repetitions exist, presentation summaries use completed receiver
goodput values with the same min, mean, median, p95, and max definitions as RTT.
Repetitions have equal weight and upload/download remain separate. The raw
repetitions remain authoritative.

## Loaded Latency

Loaded probes target the same pinned destination IPv4 while each TCP transfer
runs. Only probes sent at or after the actual transfer start and before its end
belong to that transfer. Loaded ping is attached to the transfer attempt so its
timing and endpoint cannot drift from the throughput result.

Loaded ping uses the same accounting and statistics as idle ping. It has an
independent status: TCP can complete when ICMP is unavailable.

For a given phase, target, direction, and repetition:

```text
loaded increase = loaded statistic - idle statistic
```

Median and p95 increases are the primary display values. They are `null` if
either input is unavailable. Samples and successive-difference pairs are never
joined across transfers or repetitions.

## Status And Error Semantics

Run statuses:

- `in_progress`: a valid checkpoint with work remaining.
- `completed`: all planned work reached a terminal state and no required test
  failed or was skipped.
- `baseline_only`: the user intentionally saved a usable baseline and stopped.
- `partial`: the workflow was finalized, but one or more planned tests failed,
  were skipped, or were unavailable.
- `interrupted`: execution ended unexpectedly or was cancelled before orderly
  finalization.
- `failed`: no usable benchmark phase completed.

A run can be schema-valid without being comparison-valid. `profile_complete`
means every configured measurement completed, every selected TCP attempt has a
completed loaded-ping result, and required interval data is present.
`comparison_valid` means both phases completed, both were verified, and at
least one compatible completed measurement pair exists.

Measurement statuses:

- `pending`: planned but not started.
- `running`: active at checkpoint time.
- `completed`: produced its required primary result.
- `failed`: attempted but produced no valid primary result.
- `skipped`: deliberately not attempted.
- `interrupted`: started but did not finish.

Retries are preserved as attempts. A successful retry does not erase earlier
failures. Errors use stable codes, categories, retryability, and sanitized
messages. Unavailable values are `null`, never fabricated zeroes. JSON cannot
contain NaN or infinity; implementations normalize those values to `null` and
record a diagnostic.

## Checkpoints And Resume

The complete measurement plan is written before tests start. Atomic checkpoint
updates preserve pending, running, failed, and completed work.

Resume retains the original run ID, configuration, selected targets, pinned
endpoints, and measurement IDs. It creates a new session and new attempts rather
than overwriting prior evidence. Stale `running` work is first marked
`interrupted`. The session records the interruption gap and route re-verification.

A long time gap weakens the comparison because network conditions may have
changed. The viewer must disclose the gap rather than hide it.

## Privacy

The result contract intentionally has no fields for:

- Public or local client IP addresses.
- Hostname, user name, or account name.
- Environment variables, executable paths, or temporary paths.
- Raw Cloudflare trace or iperf3 output.
- Arbitrary metadata or unrestricted diagnostic objects.

Destination IPv4 addresses are retained because endpoint identity is required
for pairing. Diagnostics use bounded codes and sanitized messages. Runners must
remove client addresses, host identity, and local paths from messages before
persistence. The schema restricts shape and length but cannot prove that free
text has been sanitized, so semantic validation also rejects known sensitive
field names and obvious local identity keys.

Results remain local unless the user explicitly handles them. The runner and
viewer perform no telemetry or automatic uploads.

## Windows Runner Acceptance

Run this checklist on clean Windows x64 systems under both Windows PowerShell
5.1 and PowerShell 7. Administrator rights and Python must not be present or
required.

- Run `powershell.exe -NoProfile -File tests/warp-bench.tests.ps1` and
  `pwsh -NoProfile -File tests/warp-bench.tests.ps1` from a checkout.
- Dot-source `scripts/warp-bench.ps1` and confirm that no benchmark starts.
- Test `iwr -useb <release URL>/warp-bench.ps1 | iex`; embedded target and
  binary metadata must work without repository files beside the script.
- Test once with compatible iperf3 3.x on `PATH`, then without it. The latter
  must download the pinned ZIP, verify SHA-256, safely extract it under the
  temporary directory, self-check it, and remove it after exit.
- Complete Quick and Extended runs. Confirm the same pinned IPv4 addresses and
  ports appear in both phases and `npm test` validates each resulting JSON
  after it is added temporarily as a `results-*.json` fixture.
- Exercise a busy server, blocked ICMP, failed trace, route mismatch, explicit
  unverified continuation, baseline-only exit, and Ctrl+C. Confirm unavailable
  throughput is never zero and each checkpoint remains parseable.
- Inspect `results.json` for client addresses, local paths, host/user identity,
  raw trace text, and raw iperf output. None may be retained.
- Confirm direct routing reports `warp=off`, WARP routing reports `warp=on` or
  `warp=plus`, and explain that this HTTPS check does not prove the ICMP or
  iperf route.

## Interpretation Limitations

Public iperf3 servers can be busy, rate-limited, geographically mislabeled, or
loaded differently between phases. ICMP behavior can differ from application
traffic. Baseline-first ordering is exposed to time drift, especially in long
Extended runs. Tunnel encryption, MTU/MSS behavior, router CPU, policy routing,
and FastTrack can affect WARP independently of ISP international routing.

Use wired Ethernet, pause other heavy traffic, keep router configuration stable,
and repeat measurements during relevant peak and off-peak periods before making
deployment decisions.
