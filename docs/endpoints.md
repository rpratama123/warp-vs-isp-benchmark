# Public Endpoint Research

## Status

Research and technical checks were performed on 2026-09-16. The curated
machine-readable list is `manifests/targets.json`.

Public servers are external dependencies. A server being published and working
on one date does not guarantee availability, capacity, ICMP behavior, or
continued permission. Runtime failures are expected and must produce partial
results rather than synthetic zeroes.

## Verification Method

Research prioritized operator-owned documentation. Where no operator page was
available, the target relies on the actively maintained
`R0GGER/public-iperf3-servers` directory.

Technical checks used:

- IPv4 DNS resolution.
- iperf3 3.21.
- One-second TCP transfers limited to 1 Mbps.
- One forward and one reverse attempt on a documented port.
- A different documented port for a bounded retry when necessary.

These checks establish basic protocol compatibility only. They are not capacity
benchmarks and were not run from the user's Indosat connection. ICMP was not
tested because the validation environment had no ping utility, so every
endpoint retains `supports_icmp: "unknown"` until checked on a supported runner.

The temporary Linux iperf3 candidate used for these checks matched SHA-256
`201cbaed73d4e4da72c44c9aee895a2d58c75f1d1a4d721137f4888f6b7f5016`.
It is not an approved runtime dependency.

## Results

| Order | Region | Hostname | Resolved IPv4 at check time | Publication | Forward | Reverse | Manifest status |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | Indonesia | `speedtest.tangerang2.myrepublic.net.id` | `157.66.210.199` | Public directory | Failed | Passed on port 9203 | Partially verified |
| 2 | Singapore | `sgp.proof.ovh.net` | `15.235.182.181` | Operator documented | Passed | Passed | Verified |
| 3 | Tokyo | `speedtest.tyo11.jp.leaseweb.net` | `23.106.226.75` | Public directory | Passed | Passed | Verified |
| 4 | Amsterdam | `ams.speedtest.clouvider.net` | `194.127.172.176` | Operator documented | Passed on port 5201 | Passed on port 5201 | Verified |
| 5 | London | `lon.speedtest.clouvider.net` | `5.180.211.133` | Operator documented | Passed | Passed | Verified |
| 6 | Los Angeles | `la.speedtest.clouvider.net` | `77.247.126.223` | Operator documented | Passed | Passed | Verified |
| 7 | New York City | `nyc.speedtest.clouvider.net` | `194.33.45.192` | Operator documented | Passed | Passed | Verified |

Resolved addresses are observations, not manifest pins. A runner resolves each
hostname at the start of a benchmark, pins the selected IPv4 address in the
result, and uses it for both phases.

### Indonesia Caveats

The Indonesian entry is intentionally labeled with no city:

- Its hostname implies Tangerang.
- The public directory labels it Kediri.
- MyRepublic does not publish accessible endpoint-specific iperf3 instructions.
- Reverse mode succeeded, but three bounded forward attempts ended without a
  valid receiver throughput result.

It remains enabled because an Indonesian reference point is a core project
requirement and it is explicitly maintained in a public iperf3 directory. The
runner must display its reduced confidence and tolerate upload failure. It must
not present this endpoint as a verified city-specific result.

### Singapore

OVH directly states that `sgp.proof.ovh.net` accepts iperf3 on ports 5201-5210.
The current public directory additionally documents reverse mode. This is the
strongest Asian endpoint in the list.

### Tokyo

The Leaseweb hostname is operator-owned, resolves to IPv4, and passed both test
directions. Public iperf3 ports and reverse capability are documented by the
public directory rather than an accessible Leaseweb instruction page.

### Clouvider Regions

Clouvider directly publishes the Amsterdam, London, Los Angeles, and New York
City hostnames, ports 5200-5209, and a best-effort 10 Gbps description. All four
passed forward and reverse tests. Amsterdam's first reverse attempt lacked a
valid receiver result; both directions were then confirmed on port 5201.

Each region also has a lower-priority public-directory fallback where one is
listed. These fallbacks are marked unverified and must not replace a selected
primary between phases. Indonesia's only known alternate is explicitly marked
unavailable based on its latest published status, so it is research evidence,
not a usable runtime fallback.

The speed-test page's browser application has a telemetry policy. The separate
iperf3 command-line service does not document equivalent result telemetry, so
the project makes no claim about server-side connection logging. Users should
assume public server operators can observe source addresses and connection
metadata even though the local result file omits the client address.

## Selection Policy

- Target order is Indonesia, Singapore, Tokyo, Amsterdam, London, Los Angeles,
  and New York City.
- Ports are attempted individually in listed order with bounded retries.
- Runtime selection does not search for the fastest endpoint.
- The selected hostname, resolved IPv4 address, and port are frozen before the
  baseline phase.
- If an endpoint cannot support both phases on the same pinned address and port,
  its measurements remain unpaired.
- A busy or unavailable endpoint is reported as unavailable, not as zero
  throughput.
- The manifest should be reviewed before each release and periodically after
  release. Technical verification dates are evidence snapshots, not uptime
  promises.

## Sources

- [OVH Singapore proof server](https://sgp.proof.ovh.net/)
- [Clouvider/AS62240 speed-test servers](https://as62240.net/speedtest)
- [Public iperf3 server directory](https://github.com/R0GGER/public-iperf3-servers)
- [Public directory testing process](https://github.com/R0GGER/public-iperf3-servers/blob/main/testing_process.md)
- [MyRepublic speed-test page](https://www.myrepublic.co.id/speed-test)
