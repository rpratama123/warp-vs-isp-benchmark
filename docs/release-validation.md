# Release Validation Matrix

"Automated" means mocked/controlled CI coverage, not a physical-network
acceptance result. Phase 6 hosted evidence predates the release-readiness tool;
it must not be represented as hosted release-tool success. The current known
Phase 6 workflow records are [Linux](https://github.com/rpratama123/warp-vs-isp-benchmark/actions/runs/35446382335),
[macOS](https://github.com/rpratama123/warp-vs-isp-benchmark/actions/runs/35446382333),
and [Windows](https://github.com/rpratama123/warp-vs-isp-benchmark/actions/runs/35446382338).

| System / end-to-end case | Required evidence | Current status |
| --- | --- | --- |
| Hosted Linux x86-64 Phase 6: Bash, contracts, viewer, installed/missing dependency paths | Linux run above; controlled automated tests | Complete for Phase 6 automated coverage |
| Hosted macOS ARM64 Phase 6: platform adapters and installed/missing dependency paths | macOS run above (`macos-14` matrix entry); controlled automated tests | Complete for Phase 6 automated coverage |
| Hosted macOS Intel Phase 6: platform adapters and installed/missing dependency paths | macOS run above (`macos-15-intel` matrix entry); controlled automated tests | Complete for Phase 6 automated coverage |
| Hosted Windows PowerShell 5.1 Phase 6: runner behavior and pinned download checks | Windows run above (`powershell-51`); controlled automated tests | Complete for Phase 6 automated coverage |
| Hosted Windows PowerShell 7 Phase 6: runner behavior and pinned download checks | Windows run above (`powershell-7`); controlled automated tests | Complete for Phase 6 automated coverage |
| Local release metadata/version/schema/snapshot and evidence-gate checks | `node scripts/package-release.mjs --check` and `docs/release-evidence.json` | Complete locally; not yet hosted by readiness workflow |
| Pre-publication eligibility | `node scripts/package-release.mjs --stable` checks dependency approvals and complete pre-build gates without writing `dist/` | Current repository intentionally blocked; automated temporary-copy success coverage exists |
| Local readiness packaging/checksum generation and rejection of version or embedded-target tampering | `npm run test:release` temporary-directory tests | Complete locally; mocked metadata coverage |
| Hosted readiness workflow | A post-change workflow run completing `npm ci`, `npm test`, audit, check, bundle, and artifact upload | Pending; changes are not pushed |
| Installed and missing jq/iperf dependency behavior on each supported OS | Hosted test plus physical log where provisioning differs | Automated coverage only; physical pending |
| Checksum rejection | Controlled bad-hash test and independently downloaded artifact rejection | Controlled test complete; independent artifact pending |
| Route mismatch and unavailable endpoint | Runner result showing explicit disposition, not a route claim | Automated mocked coverage; physical pending |
| Interrupted, baseline-only, and resume handling | Validated result fixtures and runner execution | Automated coverage complete; physical pending |
| Unwritable or nonpersistent output location | Actionable runner failure/save behavior on each OS | Automated coverage only; physical pending |
| Offline or malformed viewer import | Viewer tests showing local-only safe rejection | Automated coverage complete; physical pending |
| Physical Windows x64 | Redacted field result, version/checksum, and operator notes | Pending |
| Physical Unraid/Linux x86-64 | Redacted field result, persistent-output proof, and operator notes | Pending |
| Physical macOS Intel and Apple Silicon | Separate redacted field results | Pending |
| Indosat peak and off-peak paired runs | Comparable redacted result sets with route dispositions | Pending |
| Final release-asset verification | Independent artifact download, extraction, complete checksum check, and inspected launch | Pending |
| Stable dependency provenance and redistribution approval | Reviewed manifest, reproducible provenance, and notices | Pending |

## Field evidence handling

Keep original results in controlled storage. Before attaching evidence, remove
local paths, host names, identities, public client addresses, tokens, and any
unnecessary route details; preserve timestamps, selected destination address,
manifest version, runner version, checksums, phase verification disposition,
and failures needed to reproduce the conclusion. Do not replace failed runs
with synthetic successes.

The six physical and Indosat gates are `pre-build` in
`docs/release-evidence.json`; they and dependency approval are checked by the
nonwriting `node scripts/package-release.mjs --stable` eligibility preflight.
The final asset gate is `post-build`: it verifies the generated candidate bytes
and does not create a circular pre-build blocker. Before publication, it needs
a dated review record, the candidate checksum manifest/artifact hash, and an
independent verification. Promote the exact verified candidate bytes unchanged;
do not rebuild after verification. Until then bundles are readiness candidates,
not stable releases.
