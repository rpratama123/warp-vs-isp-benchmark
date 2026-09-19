# Endpoint Maintenance

## Cadence and evidence

Review each enabled endpoint at least monthly and before every bundle. Record
the date, source URL, operator usage policy, IPv4 resolution, forward/reverse
iperf3 result, documented port, and ICMP observation in `docs/endpoints.md` or
the review record. Do not treat a DNS answer or one successful transfer as
location or long-term capacity evidence.

## Replacement and DNS changes

Deprecate an endpoint after operator withdrawal, a policy conflict, repeated
bounded failures, location ambiguity that affects its label, or an unremedied
DNS/ownership change. Verify a replacement's permission, geography, IPv4,
ports, forward and reverse support before enabling it. A DNS change during a
paired run is evidence: retain the selected address in the result, do not
silently substitute it, and exclude incompatible pairs.

## Manifest and release procedure

Update `manifests/targets.json` with sources, verification status and timestamps.
Make a manifest-version change for a substantive target, endpoint, port, or
dependency decision; regenerate embedded runner snapshots and run the contract
and release checks. For a release bundle: review evidence, run `npm test`,
`npm audit --omit=optional`, and `node scripts/package-release.mjs --check`,
then create the readiness candidate bundle. Record completed physical evidence
in the `pre-build` gates of `docs/release-evidence.json`. `--stable` is a
nonwriting eligibility check for those gates and dependency approvals. After
candidate generation, independently verify its exact bytes and checksum
manifest, record the `post-build` final-asset gate, and promote those unchanged
bytes without rebuilding.
