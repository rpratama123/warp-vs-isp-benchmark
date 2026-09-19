# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Static, self-contained HTML with embedded CSS and JavaScript. It must open from the local filesystem without a web server, Internet connection, upload, package installation, or privileged access.

## Users

The primary user is the benchmark operator who has run the WARP versus ISP benchmark and needs to decide whether WARP improves the tested routes. Network specialists and report readers are secondary audiences; the primary flow must remain understandable without specialist interpretation.

## Product Purpose

Import a local Schema v1 benchmark result, establish whether its baseline/WARP comparison is trustworthy, and show where WARP improves, regresses, or lacks usable evidence across latency, loss, RTT variation, throughput, loaded latency, and measurement timelines.

Success means the operator can quickly answer whether WARP helps for the tested destinations without the viewer overstating causation, treating unavailable data as zero, or presenting incompatible measurements as valid pairs.

## Positioning

The viewer derives every comparison from the benchmark's pinned endpoint and measurement semantics, and places evidence quality ahead of a verdict. It keeps unverified and partial evidence visible while refusing to summarize it as conclusive.

## Operating Context

The operator opens `viewer/index.html` locally after a benchmark, then imports a JSON result through a file picker or drag-and-drop. Results can originate from supported Windows, Linux/Unraid, or macOS runners. Runs may be complete, partial, baseline-only, interrupted, resumed after a long gap, or contain unavailable public endpoints.

## Capabilities and Constraints

- Support Schema v1 result files and handle malformed or untrusted JSON without executing imported content.
- Provide paired views for idle latency, ICMP reply loss, RTT variation, TCP download/upload throughput, loaded latency, and transfer timelines.
- Pair only measurements with matching target, pinned IPv4 address, port where applicable, kind, protocol, client-perspective direction, duration, stream count, repetition, and profile semantics.
- Require both phases to be route-verified before presenting a pair as conclusive.
- Clearly warn about unverified routing, endpoint mismatch, missing data, interrupted or incomplete runs, and long phase or resume gaps.
- Preserve nullable values as unavailable; never convert failure or absence to zero.
- Keep all result processing local with no telemetry or automatic uploads.
- Work accessibly on desktop and mobile from one self-contained HTML file.

## Evidence on Hand

- Normative Schema v1: `schema/results-v1.schema.json`.
- Methodology and comparison rules: `docs/methodology.md`.
- Real Linux/Unraid outputs, including partial and recovered runs: `test_results/`.
- Generated contract fixtures: `tests/fixtures/`.
- Endpoint provenance and confidence notes: `docs/endpoints.md`.
- No testimonials, customer claims, universal performance claims, or causal congestion evidence may be fabricated.

## Product Principles

- Trust before verdict: disclose validity and caveats before summarizing route performance.
- Compare like with like: incompatible evidence remains visible but unpaired.
- Missing is not zero: preserve the distinction among failure, interruption, unavailability, and measured zero.
- Show the destination story: an overall summary never hides meaningful endpoint-level regressions.
- Local by construction: imported result data never leaves the browser.

## Accessibility & Inclusion

The viewer must provide an accessible desktop and mobile layout, keyboard-operable import and controls, visible focus, semantic data structures, non-color-only comparison cues, and reduced-motion behavior.
