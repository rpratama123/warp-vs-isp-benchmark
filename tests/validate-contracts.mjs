import { readFile, readdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { isIP } from "node:net";
import Ajv2020 from "ajv/dist/2020.js";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const loadJson = async (path) => JSON.parse(await readFile(resolve(root, path), "utf8"));

const ajv = new Ajv2020({ allErrors: true, strict: true });
const contracts = [
  ["schema/results-v1.schema.json", /^results-.*\.json$/],
  ["schema/targets-v1.schema.json", /^targets-.*\.json$/],
  ["schema/binaries-v1.schema.json", /^binaries-.*\.json$/]
];

let failures = 0;

for (const [schemaPath, fixturePattern] of contracts) {
  const validate = ajv.compile(await loadJson(schemaPath));
  const fixtures = (await readdir(resolve(root, "tests/fixtures"))).filter((name) => fixturePattern.test(name)).sort();
  for (const fixture of fixtures) {
    const data = await loadJson(`tests/fixtures/${fixture}`);
    if (!validate(data)) {
      failures += 1;
      console.error(`Schema validation failed: ${fixture}`);
      console.error(ajv.errorsText(validate.errors, { separator: "\n" }));
    } else {
      console.log(`Schema valid: ${fixture}`);
    }
  }
}

function roundHalfUp(value, digits) {
  const scale = 10 ** digits;
  return Math.floor(value * scale + 0.5) / scale;
}

function summariesEqual(actual, expected) {
  return Object.keys(expected).every((key) => Object.is(actual[key], expected[key]));
}

function calculatePingSummary(samples) {
  const replies = samples.filter((sample) => sample.outcome === "reply");
  const timeouts = samples.filter((sample) => sample.outcome === "timeout").length;
  const localFailures = samples.filter((sample) => sample.outcome === "local_error").length;
  const sent = replies.length + timeouts;
  const values = replies.map((sample) => sample.rtt_us).sort((a, b) => a - b);
  const meanUs = values.length === 0 ? null : values.reduce((sum, value) => sum + value, 0) / values.length;
  const middle = Math.floor(values.length / 2);
  const medianUs = values.length === 0 ? null : values.length % 2 === 1
    ? values[middle]
    : (values[middle - 1] + values[middle]) / 2;
  const stddevUs = values.length === 0 ? null
    : Math.sqrt(values.reduce((sum, value) => sum + (value - meanUs) ** 2, 0) / values.length);
  const adjacent = [];
  for (let index = 1; index < samples.length; index += 1) {
    if (
      samples[index - 1].outcome === "reply"
      && samples[index].outcome === "reply"
      && samples[index].sequence === samples[index - 1].sequence + 1
    ) {
      adjacent.push(Math.abs(samples[index].rtt_us - samples[index - 1].rtt_us));
    }
  }
  const adjacentMeanUs = adjacent.length === 0 ? null : adjacent.reduce((sum, value) => sum + value, 0) / adjacent.length;
  const milliseconds = (value) => value === null ? null : roundHalfUp(value / 1000, 3);
  return {
    probes_recorded: samples.length,
    probes_sent: sent,
    replies_received: replies.length,
    timed_out: timeouts,
    local_failures: localFailures,
    reply_loss_percent: sent === 0 ? null : roundHalfUp(100 * timeouts / sent, 6),
    rtt_min_ms: milliseconds(values.length === 0 ? null : values[0]),
    rtt_mean_ms: milliseconds(meanUs),
    rtt_median_ms: milliseconds(medianUs),
    rtt_p95_ms: milliseconds(values.length === 0 ? null : values[Math.ceil(0.95 * values.length) - 1]),
    rtt_max_ms: milliseconds(values.length === 0 ? null : values.at(-1)),
    rtt_stddev_ms: milliseconds(stddevUs),
    rtt_adjacent_mean_abs_diff_ms: milliseconds(adjacentMeanUs)
  };
}

function unique(values) {
  return new Set(values).size === values.length;
}

const exactProfiles = {
  quick: {
    idle_ping: { requested_probes: 30, interval_ms: 1000, timeout_ms: 2000, payload_bytes: 32 },
    loaded_ping: { interval_ms: 500, timeout_ms: 1000, payload_bytes: 32 },
    tcp: { duration_seconds: 10, repetitions_per_direction: 1, streams: 1, directions: ["download", "upload"] },
    timing: { route_settle_seconds: 5, between_transfers_seconds: 2, between_targets_seconds: 3, server_busy_retries: 2, retry_backoff_seconds: [5, 10] }
  },
  extended: {
    idle_ping: { requested_probes: 120, interval_ms: 1000, timeout_ms: 2000, payload_bytes: 32 },
    loaded_ping: { interval_ms: 500, timeout_ms: 1000, payload_bytes: 32 },
    tcp: { duration_seconds: 15, repetitions_per_direction: 3, streams: 1, directions: ["download", "upload"] },
    timing: { route_settle_seconds: 10, between_transfers_seconds: 5, between_targets_seconds: 10, server_busy_retries: 2, retry_backoff_seconds: [5, 10] }
  }
};

function isDeepEqual(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function hasSensitiveKey(value) {
  const banned = new Set(["client_ip", "local_ip", "public_ip", "username", "user_name", "computer_name", "raw_trace", "raw_output", "environment_variables"]);
  if (Array.isArray(value)) return value.some(hasSensitiveKey);
  if (value && typeof value === "object") {
    return Object.entries(value).some(([key, child]) => banned.has(key.toLowerCase()) || hasSensitiveKey(child));
  }
  return false;
}

function sensitiveText(value) {
  if (Array.isArray(value)) return value.some(sensitiveText);
  if (!value || typeof value !== "object") return false;
  return Object.entries(value).some(([key, child]) => {
    if ((key === "message" || key === "build_provenance") && typeof child === "string") {
      const addressTokens = child.match(/[0-9A-Fa-f:.]+/g) ?? [];
      return addressTokens.some((token) => isIP(token.replace(/^[[(]|[\]),.;]$/g, "")) !== 0)
        || /(?:[A-Za-z]:\\|\\\\[^\\\s]+\\|(?:^|\s)\/(?:tmp|var|home|Users|config|mnt)\/)/.test(child)
        || /\bDESKTOP-[A-Z0-9-]+\b/i.test(child)
        || /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i.test(child);
    }
    return sensitiveText(child);
  });
}

function parseTimestamp(value) {
  return value === null ? null : Date.parse(value);
}

function validTimestamp(value) {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?Z$/.exec(value);
  if (!match) return false;
  const [, year, month, day, hour, minute, second] = match.map(Number);
  if (month < 1 || month > 12 || hour > 23 || minute > 59 || second > 59) return false;
  const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
  return day >= 1 && day <= daysInMonth && Number.isFinite(Date.parse(value));
}

function invalidTimestampPath(value, path = "$") {
  if (Array.isArray(value)) {
    for (let index = 0; index < value.length; index += 1) {
      const invalid = invalidTimestampPath(value[index], `${path}[${index}]`);
      if (invalid) return invalid;
    }
  } else if (value && typeof value === "object") {
    for (const [key, child] of Object.entries(value)) {
      if ((key.endsWith("_at") || key === "timestamp") && child !== null && !validTimestamp(child)) return `${path}.${key}`;
      const invalid = invalidTimestampPath(child, `${path}.${key}`);
      if (invalid) return invalid;
    }
  }
  return null;
}

function semanticErrors(result) {
  const errors = [];
  const check = (condition, message) => {
    if (!condition) errors.push(message);
  };
  const targetIds = result.targets.map((target) => target.id);
  const sessionIds = result.sessions.map((session) => session.id);
  const phaseIds = result.phases.map((phase) => phase.id);
  const measurementIds = result.measurements.map((measurement) => measurement.id);

  check(unique(targetIds), "target IDs must be unique");
  check(unique(sessionIds), "session IDs must be unique");
  check(unique(phaseIds), "phase IDs must be unique");
  check(unique(measurementIds), "measurement IDs must be unique");
  check(!hasSensitiveKey(result), "sensitive or unrestricted raw-data key found");
  check(!sensitiveText(result), "diagnostic text contains an address, email, or local user path");
  check(invalidTimestampPath(result) === null, `invalid timestamp at ${invalidTimestampPath(result)}`);
  check(parseTimestamp(result.run.started_at) <= parseTimestamp(result.run.updated_at), "run updated_at precedes started_at");
  if (result.run.ended_at) check(parseTimestamp(result.run.updated_at) <= parseTimestamp(result.run.ended_at), "run ended_at precedes updated_at");
  check(isDeepEqual({
    idle_ping: result.configuration.idle_ping,
    loaded_ping: result.configuration.loaded_ping,
    tcp: result.configuration.tcp,
    timing: result.configuration.timing
  }, exactProfiles[result.configuration.profile]), "profile snapshot does not match the normative profile");

  for (const phase of result.phases) {
    const expectedStates = phase.id === "baseline" ? ["off"] : ["on", "plus"];
    check(phase.requested_route === (phase.id === "baseline" ? "direct" : "warp"), `${phase.id} requested route is inconsistent`);
    for (const verification of phase.verification_checks) {
      check(sessionIds.includes(verification.session_id), `${verification.id} references an unknown session`);
      check(isDeepEqual(verification.expected_warp_states, expectedStates), `${verification.id} has incorrect expected WARP states`);
      const expectedMatch = verification.request_status === "completed" && expectedStates.includes(verification.observed_warp_state)
        ? "matched"
        : verification.request_status === "completed" && verification.observed_warp_state !== "unknown"
          ? "mismatched"
          : "indeterminate";
      check(verification.match === expectedMatch, `${verification.id} match disposition is inconsistent`);
      if (phase.started_at && verification.position === "before_phase") {
        check(parseTimestamp(verification.checked_at) <= parseTimestamp(phase.started_at), `${verification.id} occurred after its phase started`);
      }
      if (phase.ended_at && verification.position === "after_phase") {
        check(parseTimestamp(verification.checked_at) >= parseTimestamp(phase.ended_at), `${verification.id} occurred before its phase ended`);
      }
    }
    if (phase.verification_disposition === "verified") {
      const positions = phase.verification_checks.filter((verification) => verification.match === "matched").map((verification) => verification.position);
      check(positions.includes("before_phase") && positions.includes("after_phase"), `${phase.id} is verified without matching before/after checks`);
    }
    if (phase.status === "pending") {
      check(phase.started_at === null && phase.ended_at === null && phase.verification_disposition === "not_performed", `${phase.id} pending lifecycle is inconsistent`);
    } else if (phase.status === "running") {
      check(phase.started_at !== null && phase.ended_at === null, `${phase.id} running lifecycle is inconsistent`);
    } else {
      check(phase.started_at !== null && phase.ended_at !== null, `${phase.id} terminal lifecycle is inconsistent`);
    }
  }

  for (const session of result.sessions) {
    if (session.reason === "initial") check(session.previous_session_id === null && session.gap_seconds === null, `${session.id} initial linkage is inconsistent`);
    if (session.reason === "resume") check(session.previous_session_id !== null && sessionIds.includes(session.previous_session_id) && session.gap_seconds !== null, `${session.id} resume linkage is inconsistent`);
    if (session.status === "running") check(session.ended_at === null, `${session.id} running session has an end time`);
    else check(session.ended_at !== null, `${session.id} terminal session lacks an end time`);
    if (session.ended_at) check(parseTimestamp(session.started_at) <= parseTimestamp(session.ended_at), `${session.id} has reversed timestamps`);
  }

  const expectedMeasurementKeys = [];
  for (const phaseId of ["baseline", "warp"]) {
    for (const targetId of targetIds) {
      expectedMeasurementKeys.push(`${phaseId}|${targetId}|idle_ping`);
      for (const direction of result.configuration.tcp.directions) {
        for (let repetition = 1; repetition <= result.configuration.tcp.repetitions_per_direction; repetition += 1) {
          expectedMeasurementKeys.push(`${phaseId}|${targetId}|tcp_transfer|${direction}|${repetition}`);
        }
      }
    }
  }
  const actualMeasurementKeys = result.measurements.map((measurement) => measurement.kind === "idle_ping"
    ? `${measurement.phase_id}|${measurement.target_id}|idle_ping`
    : `${measurement.phase_id}|${measurement.target_id}|tcp_transfer|${measurement.settings.direction}|${measurement.settings.repetition}`);
  check(unique(actualMeasurementKeys), "measurement plan contains duplicate logical tests");
  check(isDeepEqual([...actualMeasurementKeys].sort(), [...expectedMeasurementKeys].sort()), "measurement plan does not match targets, phases, directions, and repetitions");

  for (const measurement of result.measurements) {
    check(targetIds.includes(measurement.target_id), `${measurement.id} references an unknown target`);
    check(phaseIds.includes(measurement.phase_id), `${measurement.id} references an unknown phase`);
    const target = result.targets.find((candidate) => candidate.id === measurement.target_id);
    const phase = result.phases.find((candidate) => candidate.id === measurement.phase_id);
    check(target && isDeepEqual(measurement.endpoint, target.endpoint), `${measurement.id} endpoint differs from its pinned target`);
    if (measurement.started_at && phase?.started_at) {
      check(parseTimestamp(measurement.started_at) >= parseTimestamp(phase.started_at), `${measurement.id} started before its phase`);
    }
    if (measurement.ended_at && phase?.ended_at) {
      check(parseTimestamp(measurement.ended_at) <= parseTimestamp(phase.ended_at), `${measurement.id} ended after its phase`);
    }
    if (measurement.started_at && measurement.ended_at) {
      check(parseTimestamp(measurement.started_at) <= parseTimestamp(measurement.ended_at), `${measurement.id} has reversed timestamps`);
    }

    if (measurement.status === "pending") {
      check(measurement.started_at === null && measurement.ended_at === null && measurement.error === null, `${measurement.id} pending state contains execution evidence`);
    } else if (measurement.status === "running") {
      check(measurement.started_at !== null && measurement.ended_at === null && measurement.error === null, `${measurement.id} running lifecycle is inconsistent`);
    } else if (measurement.status === "completed") {
      check(measurement.started_at !== null && measurement.ended_at !== null && measurement.error === null, `${measurement.id} completed lifecycle is inconsistent`);
    } else {
      check(measurement.error !== null, `${measurement.id} terminal non-success state requires an error or reason`);
    }

    if (measurement.kind === "idle_ping") {
      check(sessionIds.includes(measurement.session_id), `${measurement.id} references an unknown session`);
      check(measurement.settings.requested_probes === result.configuration.idle_ping.requested_probes, `${measurement.id} probe count differs from the profile`);
      check(isDeepEqual(measurement.settings, result.configuration.idle_ping), `${measurement.id} ping settings differ from the profile`);
      validatePingResult(measurement, measurement.id, check);
      if (measurement.status === "completed") {
        check(measurement.samples.length === measurement.settings.requested_probes, `${measurement.id} completed with an incomplete probe set`);
      }
      if (measurement.status === "pending") {
        check(measurement.samples.length === 0 && measurement.summary === null, `${measurement.id} pending ping contains samples or summary`);
      }
    } else {
      check(measurement.settings.duration_seconds === result.configuration.tcp.duration_seconds, `${measurement.id} duration differs from the profile`);
      check(measurement.settings.streams === result.configuration.tcp.streams, `${measurement.id} stream count differs from the profile`);
      check(measurement.settings.repetition <= result.configuration.tcp.repetitions_per_direction, `${measurement.id} repetition exceeds the profile`);
      check(unique(measurement.attempts.map((attempt) => attempt.number)), `${measurement.id} attempt numbers must be unique`);
      const successful = measurement.attempts.find((attempt) => attempt.number === measurement.selected_attempt);
      if (measurement.status === "completed") {
        check(successful?.status === "completed", `${measurement.id} does not select a completed attempt`);
        check(successful?.receiver !== null, `${measurement.id} completed without receiver data`);
      } else {
        check(measurement.selected_attempt === null, `${measurement.id} selects an attempt without completing`);
      }
      if (measurement.status === "pending") {
        check(measurement.attempts.length === 0, `${measurement.id} pending transfer contains attempts`);
      }
      for (const attempt of measurement.attempts) {
        check(sessionIds.includes(attempt.session_id), `${measurement.id} attempt references an unknown session`);
        if (attempt.status === "completed") {
          check(attempt.ended_at !== null && attempt.receiver !== null && attempt.error === null, `${measurement.id} completed attempt lifecycle is inconsistent`);
        } else if (attempt.status === "running") {
          check(attempt.ended_at === null && attempt.error === null, `${measurement.id} running attempt lifecycle is inconsistent`);
        } else {
          check(attempt.ended_at !== null && attempt.error !== null, `${measurement.id} unsuccessful attempt requires an end time and error`);
        }
        if (attempt.ended_at) {
          check(parseTimestamp(attempt.started_at) <= parseTimestamp(attempt.ended_at), `${measurement.id} attempt has reversed timestamps`);
          if (measurement.started_at) check(parseTimestamp(attempt.started_at) >= parseTimestamp(measurement.started_at), `${measurement.id} attempt starts before measurement`);
          if (measurement.ended_at) check(parseTimestamp(attempt.ended_at) <= parseTimestamp(measurement.ended_at), `${measurement.id} attempt ends after measurement`);
        }
        if (attempt.number > 1) {
          const previous = measurement.attempts.find((candidate) => candidate.number === attempt.number - 1);
          if (previous?.ended_at) {
            const expectedBackoff = result.configuration.timing.retry_backoff_seconds[Math.min(attempt.number - 2, result.configuration.timing.retry_backoff_seconds.length - 1)];
            check((parseTimestamp(attempt.started_at) - parseTimestamp(previous.ended_at)) / 1000 >= expectedBackoff, `${measurement.id} retry starts before configured backoff`);
          }
        }
        for (const sideName of ["sender", "receiver"]) {
          const side = attempt[sideName];
          if (side) {
            const expectedBps = Math.floor(side.bytes * 8000 / side.duration_ms + 0.5);
            check(side.bits_per_second === expectedBps, `${measurement.id} ${sideName} throughput is not reproducible`);
          }
        }
        let lastEnd = 0;
        let intervalBytes = 0;
        for (const [index, interval] of attempt.intervals.entries()) {
          check(interval.index === index, `${measurement.id} interval indexes are not contiguous`);
          check(interval.start_ms === lastEnd, `${measurement.id} intervals overlap or contain a gap`);
          check(interval.end_ms > interval.start_ms, `${measurement.id} interval has a non-positive duration`);
          lastEnd = interval.end_ms;
          if (interval.receiver_bytes !== null && interval.receiver_bits_per_second !== null) {
            const intervalBps = Math.floor(interval.receiver_bytes * 8000 / (interval.end_ms - interval.start_ms) + 0.5);
            check(interval.receiver_bits_per_second === intervalBps, `${measurement.id} interval throughput is not reproducible`);
            if (!interval.omitted) intervalBytes += interval.receiver_bytes;
          }
        }
        if (attempt.receiver && attempt.intervals.length > 0) {
          check(lastEnd === attempt.receiver.duration_ms, `${measurement.id} intervals do not cover receiver duration`);
          check(intervalBytes === attempt.receiver.bytes, `${measurement.id} interval bytes do not equal receiver bytes`);
        }
        if (attempt.status === "completed") check(attempt.intervals.length > 0, `${measurement.id} completed attempt lacks interval data`);
        if (attempt.loaded_ping) {
          validatePingResult(attempt.loaded_ping, `${measurement.id} loaded ping`, check);
          if (attempt.loaded_ping.status === "completed" && attempt.receiver) {
            const loadedSamples = attempt.loaded_ping.samples;
            check(loadedSamples.length > 0, `${measurement.id} completed loaded ping has no samples`);
            if (loadedSamples.length > 0) {
              check(loadedSamples[0].elapsed_ms < result.configuration.loaded_ping.interval_ms, `${measurement.id} loaded ping starts too late`);
              check(loadedSamples.at(-1).elapsed_ms >= attempt.receiver.duration_ms - result.configuration.loaded_ping.timeout_ms, `${measurement.id} loaded ping ends too early`);
              check(loadedSamples.at(-1).elapsed_ms < attempt.receiver.duration_ms, `${measurement.id} loaded ping extends beyond transfer duration`);
              for (let index = 1; index < loadedSamples.length; index += 1) {
                check(loadedSamples[index].elapsed_ms - loadedSamples[index - 1].elapsed_ms >= result.configuration.loaded_ping.interval_ms, `${measurement.id} loaded probes overlap or exceed cadence`);
              }
            }
          }
        }
      }
    }
  }

  const allMeasurementsCompleted = result.measurements.length === expectedMeasurementKeys.length
    && result.measurements.every((measurement) => {
      if (measurement.status !== "completed") return false;
      if (measurement.kind === "idle_ping") return true;
      const selected = measurement.attempts.find((attempt) => attempt.number === measurement.selected_attempt);
      return selected?.loaded_ping?.status === "completed" && selected.intervals.length > 0;
    });
  check(result.run.profile_complete === allMeasurementsCompleted, "profile_complete does not match the measurement plan");
  if (result.run.status === "completed") check(result.run.profile_complete, "completed run must have a complete profile");
  if (result.run.status === "partial") check(!result.run.profile_complete, "partial run cannot have a complete profile");
  const completedPhases = result.phases.filter((phase) => phase.status === "completed").map((phase) => phase.id);
  if (result.run.status === "completed" || result.run.status === "partial") {
    check(result.run.ended_at !== null, `${result.run.status} run requires ended_at`);
    check(completedPhases.includes("baseline") && completedPhases.includes("warp"), `${result.run.status} run requires both completed phases`);
  } else if (result.run.status === "baseline_only") {
    check(result.run.ended_at !== null && completedPhases.includes("baseline") && !completedPhases.includes("warp"), "baseline_only lifecycle is inconsistent");
  } else if (result.run.status === "failed") {
    check(result.run.ended_at !== null && completedPhases.length === 0 && !result.run.comparison_valid, "failed run lifecycle is inconsistent");
  } else if (result.run.status === "interrupted") {
    check(result.run.ended_at !== null && !result.run.profile_complete, "interrupted run lifecycle is inconsistent");
  } else if (result.run.status === "in_progress") {
    check(result.run.ended_at === null && result.sessions.some((session) => session.status === "running"), "in_progress lifecycle is inconsistent");
  }

  const verifiedPhases = result.phases.filter((phase) => phase.status === "completed" && phase.verification_disposition === "verified").map((phase) => phase.id);
  let comparablePairExists = false;
  if (verifiedPhases.includes("baseline") && verifiedPhases.includes("warp")) {
    for (const baseline of result.measurements.filter((measurement) => measurement.phase_id === "baseline" && measurement.status === "completed")) {
      comparablePairExists ||= result.measurements.some((warp) => warp.phase_id === "warp"
        && warp.status === "completed"
        && warp.target_id === baseline.target_id
        && warp.kind === baseline.kind
        && isDeepEqual(warp.endpoint, baseline.endpoint)
        && isDeepEqual(warp.settings, baseline.settings));
    }
  }
  check(result.run.comparison_valid === comparablePairExists, "comparison_valid does not match eligible paired measurements");
  return errors;
}

function validatePingResult(ping, label, check) {
  check(unique(ping.samples.map((sample) => sample.sequence)), `${label} sample sequences must be unique`);
  for (let index = 0; index < ping.samples.length; index += 1) {
    const sample = ping.samples[index];
    check(sample.sequence === index + 1, `${label} sample sequences must be contiguous and ordered`);
    if (index > 0) check(sample.elapsed_ms >= ping.samples[index - 1].elapsed_ms, `${label} elapsed times must be monotonic`);
  }
  if (ping.summary !== null) {
    check(summariesEqual(ping.summary, calculatePingSummary(ping.samples)), `${label} summary is not reproducible`);
  }
  if (ping.status === "completed") check(ping.summary !== null && ping.error === null, `${label} completed state requires a summary and no error`);
  if (ping.status === "unavailable" || ping.status === "failed" || ping.status === "interrupted") check(ping.error !== null, `${label} unsuccessful state requires an error`);
}

const resultFixtures = (await readdir(resolve(root, "tests/fixtures"))).filter((name) => /^results-.*\.json$/.test(name)).sort();
for (const fixture of resultFixtures) {
  const result = await loadJson(`tests/fixtures/${fixture}`);
  const errors = semanticErrors(result);
  for (const error of errors) {
    failures += 1;
    console.error(`Semantic validation failed: ${fixture}: ${error}`);
  }
  if (errors.length === 0) console.log(`Semantic valid: ${fixture}`);
}

const targetManifest = await loadJson("tests/fixtures/targets-valid.json");
if (invalidTimestampPath(targetManifest) !== null) failures += 1;
if (!unique(targetManifest.targets.map((target) => target.id))) failures += 1;
if (!unique(targetManifest.targets.map((target) => target.order))) failures += 1;
if (!isDeepEqual(targetManifest.targets.map((target) => target.order), [...targetManifest.targets.map((target) => target.order)].sort((a, b) => a - b))) failures += 1;
for (const target of targetManifest.targets) {
  if (!unique(target.endpoints.map((endpoint) => endpoint.id))) failures += 1;
  if (!unique(target.endpoints.map((endpoint) => endpoint.priority))) failures += 1;
}

const binaryManifest = await loadJson("tests/fixtures/binaries-valid.json");
if (invalidTimestampPath(binaryManifest) !== null) failures += 1;
if (!unique(binaryManifest.artifacts.map((artifact) => artifact.id))) failures += 1;

const completeFixture = await loadJson("tests/fixtures/results-complete.json");
const negativeCases = [
  ["wrong route expectation", (data) => { data.phases[0].verification_checks[0].expected_warp_states = ["on"]; }],
  ["incomplete measurement plan", (data) => { data.measurements.pop(); }],
  ["sensitive diagnostic text", (data) => { data.diagnostics.push({ timestamp: "2026-09-16T11:00:00Z", severity: "warning", code: "LEAK", message: "Client 203.0.113.8 failed.", phase_id: null, target_id: null, measurement_id: null }); }],
  ["sensitive local path", (data) => { data.diagnostics.push({ timestamp: "2026-09-16T11:00:00Z", severity: "warning", code: "LEAK", message: "Read C:\\Temp\\output.json failed.", phase_id: null, target_id: null, measurement_id: null }); }],
  ["noncontiguous ping sequence", (data) => { data.measurements[0].samples[1].sequence = 3; }],
  ["malformed interval", (data) => { data.measurements[1].attempts[0].intervals[0].end_ms = 0; }],
  ["completed ping without summary", (data) => { data.measurements[0].summary = null; }],
  ["completed transfer without intervals", (data) => { data.measurements[1].attempts[0].intervals = []; }],
  ["truncated interval timeline", (data) => {
    const attempt = data.measurements[1].attempts[0];
    attempt.intervals[1].end_ms = 9000;
    attempt.intervals[1].receiver_bits_per_second = Math.floor(attempt.intervals[1].receiver_bytes * 8000 / 4000 + 0.5);
  }],
  ["invalid calendar timestamp", (data) => { data.run.updated_at = "2026-99-99T10:00:00Z"; }],
  ["inconsistent run lifecycle", (data) => { data.run.status = "failed"; }]
];
for (const [name, mutate] of negativeCases) {
  const invalid = structuredClone(completeFixture);
  mutate(invalid);
  if (semanticErrors(invalid).length === 0) {
    failures += 1;
    console.error(`Negative semantic test was not rejected: ${name}`);
  } else {
    console.log(`Negative semantic test rejected: ${name}`);
  }
}

if (failures > 0) {
  console.error(`\n${failures} contract validation failure(s).`);
  process.exit(1);
}

console.log("\nAll schemas and semantic contract checks passed.");
