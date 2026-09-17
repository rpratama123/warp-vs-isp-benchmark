# Binary Provenance And Distribution

## Decision Summary

The benchmark must never download an unpinned `latest` artifact. Every artifact
is identified by an exact URL and SHA-256 in `manifests/binaries.json`.

Artifact status has explicit meaning:

- `approved`: suitable for a released runner after required notices are bundled.
- `candidate`: researched and checksum-pinned, but not permitted as an automatic
  production dependency.
- `blocked`: retained for evidence but must not be downloaded by a runner.

Current decision:

- Official jq 1.8.2 binaries are approved.
- The pinned Windows x64 community package is approved only for direct download
  from its upstream release during the Windows MVP.
- Linux and macOS community iperf3 binaries remain candidates.
- Project-owned reproducible iperf3 builds are required before a stable release.
- Phase 3 may not silently promote another candidate; promotion requires updated
  provenance, notices, validation, and a manifest version change.

## jq 1.8.2

jq publishes first-party executables, checksums, detached signatures, and a
GitHub attestation bundle. The selected artifacts are:

| Platform | Asset | SHA-256 | Runtime note |
| --- | --- | --- | --- |
| Windows x64 | `jq-windows-amd64.exe` | `a6fc67fedaf9128a3309a1e2ebb8b986aeccf70122ee46d2cb4849e423f0c627` | Standalone |
| Linux x86-64 | `jq-linux-amd64` | `b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f` | Static ELF |
| macOS x86-64 | `jq-macos-amd64` | `e94b266e3c26690550006abe63152b782280f4e14374accdf04cbde844f00bc0` | macOS 14+ |
| macOS ARM64 | `jq-macos-arm64` | `2d75340ba57a4b4c8708a21c2dc8e958a48aaa8bba13b27f77f6e4c0eca07e` | macOS 14+ |

The tagged workflow builds Linux statically and macOS against Apple system
libraries. The source tag resolves to commit
`34f7186b86743a083a589741b6cea95293524108`.

Redistribution requires the complete jq `COPYING` notices, which include MIT,
ICU, BSD-style, Lucent, and NetBSD-derived terms. The project should place those
notices beside any mirrored assets. The current macOS decision implies a minimum
supported version of macOS 14 unless a project-owned jq build is introduced.

Sources:

- [jq 1.8.2 release](https://github.com/jqlang/jq/releases/tag/jq-1.8.2)
- [Official checksums](https://github.com/jqlang/jq/blob/master/sig/v1.8.2/sha256sum.txt)
- [Tagged build workflow](https://github.com/jqlang/jq/blob/jq-1.8.2/.github/workflows/ci.yml)
- [jq license notices](https://github.com/jqlang/jq/blob/jq-1.8.2/COPYING)

## iperf3 3.21 Source

ESnet publishes source but no official binaries. Its documentation says binary
packages are third-party products and Windows is not an officially supported
iperf3 platform.

The authoritative build input is:

| Input | Value |
| --- | --- |
| Source archive | `https://downloads.es.net/pub/iperf/iperf-3.21.tar.gz` |
| SHA-256 | `656e4405ebd620121de7ceca3eaf43a88f79ea1b857d041a6a0b1314801acdd8` |
| License | BSD-3-Clause-style with bundled component notices |

Use the ESnet distribution archive rather than GitHub-generated source archives
because the official checksum applies to the ESnet archive.

Sources:

- [ESnet obtaining documentation](https://software.es.net/iperf/obtaining.html)
- [ESnet platform FAQ](https://software.es.net/iperf/faq.html)
- [iperf3 3.21 source](https://downloads.es.net/pub/iperf/iperf-3.21.tar.gz)
- [iperf3 3.21 checksum](https://downloads.es.net/pub/iperf/iperf-3.21.tar.gz.sha256)
- [iperf3 license](https://github.com/esnet/iperf/blob/3.21/LICENSE)

## Windows x64 MVP Artifact

The selected direct-download artifact is the non-OpenSSL Windows build from
`userdocs/iperf3-static`:

| Field | Value |
| --- | --- |
| Asset | `iperf3-amd64-win.zip` |
| SHA-256 | `913d9aac883f53c2f8c63ab3adcd7c8b00ceceae768e8d03a5a93c75d09c42b4` |
| GitHub asset ID | `547045173` |
| Required files | `iperf3.exe`, `cygwin1.dll` |
| Observed Cygwin runtime | Cygwin 3.6.10-1 x86-64 |
| Attestation | GitHub artifact attestation `45552215` |
| Builder commit | `5a2402906c66da3def52b2fe95b3680a624d39e3` |

The current ZIP hash was independently verified. Its two members are attested
individually as well as in the ZIP, and the public workflow and Cygwin build
script are tied to the builder commit. This is materially stronger provenance
than the previously considered ar51an package.

The provenance still has explicit limitations:

- The GitHub release is mutable.
- The workflow accepts an external source repository/ref and the attestation
  does not record those dispatch inputs, so the exact ESnet commit is not
  cryptographically established.
- `windows-latest`, the Cygwin installer, mirror packages, and toolchain are
  rolling inputs, so the build is not reproducible.
- ESnet does not support this Windows build.
- Redistribution of `cygwin1.dll` requires LGPLv3+ compliance, the Cygwin
  linking-exception notice, and corresponding-source handling.
- The ZIP itself contains no license files.

It is approved for direct upstream download in the Windows MVP, with mandatory
SHA-256 verification. This approval does not authorize the project to mirror or
repackage it: `redistribution_status` remains `review_required`. Before a stable
release or project-hosted mirror, choose one of these paths:

1. Produce and validate a project-owned reproducible Windows build.
2. Retain the exact community ZIP as the temporary trust anchor, create a
   compliant distribution bundle with notices and Cygwin source handling, and
   record that exception explicitly.

Sources:

- [Windows artifact attestation](https://github.com/userdocs/iperf3-static/attestations/45552215)
- [Attested workflow run](https://github.com/userdocs/iperf3-static/actions/runs/34026123896)
- [Historical Windows workflow](https://github.com/userdocs/iperf3-static/blob/5a2402906c66da3def52b2fe95b3680a624d39e3/.github/workflows/ci-windows.yml)
- [Cygwin licensing](https://cygwin.com/licensing.html)

## Linux And macOS Candidates

`userdocs/iperf3-static` provides functional, attested community binaries. The
Linux x86-64 candidate was downloaded temporarily, its hash matched the manifest,
and it ran on the current Unraid x86-64 environment as iperf 3.21.

They remain candidates because:

- Release assets are uploaded with replacement enabled.
- Linux builds use moving Alpine/toolchain and `latest` OpenSSL inputs.
- macOS builds update Homebrew and use its current OpenSSL package.
- Authentication/OpenSSL is included but unnecessary for this benchmark.
- The x86-64 macOS candidate requires macOS 15.

GitHub attestations prove which workflow produced an asset but do not make all
build inputs pinned or the output reproducible.

Source: [userdocs iperf3-static](https://github.com/userdocs/iperf3-static).

## Required Project Builds

Build iperf3 3.21 from the official archive for:

- Windows x64.
- Linux x86-64, suitable for Unraid.
- macOS x86-64 and ARM64, targeting macOS 14 or newer.

Desired build properties:

- Disable OpenSSL authentication and SCTP unless a tested server requirement
  emerges.
- Linux uses a static musl build.
- macOS links only to Apple system libraries and uses an explicit deployment
  target.
- Pin container images by digest, compilers, SDKs, actions, and downloaded
  inputs.
- Publish SHA-256, SBOM, build logs, test results, and GitHub/Sigstore
  attestations.
- Include the complete upstream license and bundled-component notices.
- Validate version output, JSON output, forward/reverse TCP, interval reporting,
  cancellation, and live-progress behavior.

The final project-hosted artifact URLs and hashes do not exist yet and are
therefore deliberately absent from the manifest. Candidate entries are research
records, not placeholders that a runner may trust.

## macOS Runner Limitation

macOS 14+ runs may use only a compatible system `iperf3`; the runner never
downloads either macOS candidate. This is deliberate: the Intel candidate needs
macOS 15 and neither candidate has sufficient stable provenance. There is no
accepted user-owned physical-Mac field run. Hosted CI uses the public
`macos-14` ARM64 and `macos-15-intel` images. These checks cover both
architectures but do not prove user-owned physical Mac compatibility or
field-network acceptance.
