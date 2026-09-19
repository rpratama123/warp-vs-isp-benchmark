import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const html = await readFile(path.join(root, "viewer", "index.html"), "utf8");
const scriptMatch = html.match(/<script>([\s\S]*?)<\/script>/);

assert.ok(scriptMatch, "viewer must contain embedded JavaScript");
assert.doesNotMatch(html, /<(?:script|link)[^>]+(?:src|href)=["']https?:/i, "viewer must not load remote scripts or styles");
assert.doesNotMatch(html, /innerHTML\s*=/, "viewer must not inject imported values through innerHTML");
assert.match(html, /type="file"/, "viewer must provide a file picker");
assert.match(html, /addEventListener\("drop"/, "viewer must support drag-and-drop import");

const Viewer = new Function(`${scriptMatch[1]}; return Viewer;`)();

async function fixture(name) {
  return JSON.parse(await readFile(path.join(root, "tests", "fixtures", name), "utf8"));
}

const complete = await fixture("results-complete.json");
const completeModel = Viewer.buildModel(complete);
assert.equal(completeModel.cleared, true, "complete verified fixture should be comparison-cleared");
assert.ok(completeModel.targets.length > 0, "viewer should model fixture targets");
assert.ok(completeModel.completedPairs > 0, "viewer should derive compatible completed pairs");
assert.equal(completeModel.headline, "Comparison cleared for inspection", "viewer must not produce an aggregate route winner");

const interruptedModel = Viewer.buildModel(await fixture("results-interrupted.json"));
assert.equal(interruptedModel.cleared, false, "interrupted fixture must not receive a qualified verdict");
assert.ok(interruptedModel.warnings.some((warning) => warning.includes("not comparison-valid")), "invalid comparison warning should be explicit");

const partialModel = Viewer.buildModel(await fixture("results-partial.json"));
assert.ok(partialModel.warnings.some((warning) => warning.includes("partial")), "partial fixture should disclose its run status");

const mismatched = structuredClone(complete);
const warpMeasurement = mismatched.measurements.find((measurement) => measurement.phase_id === "warp" && measurement.kind === "idle_ping");
warpMeasurement.endpoint.iperf_port += 1;
const mismatchedPairs = Viewer.pairMeasurements(mismatched, warpMeasurement.target_id, "idle_ping");
assert.ok(mismatchedPairs.some((pair) => !pair.compatible), "port changes must leave idle measurements unpaired");
assert.throws(() => Viewer.buildModel(mismatched), /differs from its pinned endpoint/, "semantically invalid endpoint drift must be rejected");

const unverified = structuredClone(complete);
unverified.phases.find((phase) => phase.id === "warp").verification_disposition = "unverified_continued";
unverified.run.comparison_valid = false;
const unverifiedModel = Viewer.buildModel(unverified);
assert.equal(unverifiedModel.cleared, false, "unverified phases must restrict the comparison");
assert.equal(unverifiedModel.headline, "No qualified route comparison", "unverified evidence must not receive winner language");

const failedParent = structuredClone(complete);
const transfer = failedParent.measurements.find((measurement) => measurement.kind === "tcp_transfer" && measurement.status === "completed");
transfer.status = "failed";
assert.throws(() => Viewer.validate(failedParent), /selects an attempt without completing/, "a failed parent may not expose a selected completed attempt");

assert.throws(() => Viewer.validate({ schema_version: "1.0.0" }), /Schema v1 validation failed/);
assert.throws(() => Viewer.validate({ ...complete, schema_version: "2.0.0" }), /Schema v1 validation failed/);
assert.throws(() => Viewer.validate({ ...complete, sessions: [null] }), /Schema v1 validation failed/, "malformed nested records must be rejected");
assert.throws(() => Viewer.validate({ ...complete, targets: Array.from({ length: 101 }, () => structuredClone(complete.targets[0])) }), /safe display limits/, "oversized schema-valid collections must be rejected separately");

const invalidConditional = structuredClone(complete);
invalidConditional.measurements.find((measurement) => measurement.kind === "idle_ping").samples[0].rtt_us = null;
assert.throws(() => Viewer.validate(invalidConditional), /Schema v1 validation failed/, "conditional ping-sample constraints must be enforced");

const forgedVerification = structuredClone(complete);
const baselineCheck = forgedVerification.phases.find((phase) => phase.id === "baseline").verification_checks[0];
baselineCheck.expected_warp_states = ["on"];
assert.throws(() => Viewer.validate(forgedVerification), /inconsistent route-verification evidence/, "phase verification must be derived from its underlying checks");

const forgedSummary = structuredClone(complete);
forgedSummary.measurements.find((measurement) => measurement.kind === "idle_ping").summary.rtt_median_ms += 1;
assert.throws(() => Viewer.validate(forgedSummary), /non-reproducible summary/, "displayed ping summaries must be reproducible from samples");

const alteredProfile = structuredClone(complete);
alteredProfile.configuration.timing.route_settle_seconds += 1;
assert.throws(() => Viewer.validate(alteredProfile), /differs from the normative profile/, "profile labels must match normative settings");

const lateVerification = structuredClone(complete);
const baselinePhase = lateVerification.phases.find((phase) => phase.id === "baseline");
baselinePhase.verification_checks.find((check) => check.position === "before_phase").checked_at = baselinePhase.ended_at;
assert.throws(() => Viewer.validate(lateVerification), /occurred after its phase started/, "verification checks must occur on the declared side of a phase");

const reversedAttempt = structuredClone(complete);
const completedAttempt = reversedAttempt.measurements.find((measurement) => measurement.kind === "tcp_transfer").attempts[0];
[completedAttempt.started_at, completedAttempt.ended_at] = [completedAttempt.ended_at, completedAttempt.started_at];
assert.throws(() => Viewer.validate(reversedAttempt), /attempt timestamps are reversed/, "transfer attempt chronology must be enforced");

assert.match(html, /repetition range/, "viewer should present repetition ranges for multi-repetition profiles");
assert.doesNotMatch(html, /Evidence leans toward/, "viewer must not render an opaque aggregate route verdict");
assert.match(html, /el\("table", "timeline-table"\)/, "timeline charts must include a textual data equivalent");
assert.match(html, /stroke-dasharray/, "timeline routes must differ by more than color");
assert.match(html, /prefers-reduced-motion: reduce/, "viewer must honor reduced-motion preferences");
assert.match(html, /tab\.tabIndex = selected \? 0 : -1/, "metric tabs must use roving keyboard focus");

console.log("Viewer tests passed.");
