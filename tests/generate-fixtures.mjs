import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const fixtureDirectory = resolve(root, "tests/fixtures");

function roundHalfUp(value, digits) {
  const scale = 10 ** digits;
  return Math.floor(value * scale + 0.5) / scale;
}

function pingSummary(samples) {
  const replies = samples.filter((sample) => sample.outcome === "reply");
  const timeouts = samples.filter((sample) => sample.outcome === "timeout").length;
  const localFailures = samples.filter((sample) => sample.outcome === "local_error").length;
  const sent = replies.length + timeouts;
  const values = replies.map((sample) => sample.rtt_us).sort((a, b) => a - b);
  const meanUs = values.length === 0 ? null : values.reduce((sum, value) => sum + value, 0) / values.length;
  const middle = Math.floor(values.length / 2);
  const medianUs = values.length === 0
    ? null
    : values.length % 2 === 1
      ? values[middle]
      : (values[middle - 1] + values[middle]) / 2;
  const stddevUs = values.length === 0
    ? null
    : Math.sqrt(values.reduce((sum, value) => sum + (value - meanUs) ** 2, 0) / values.length);
  const adjacentDifferences = [];
  for (let index = 1; index < samples.length; index += 1) {
    if (
      samples[index - 1].outcome === "reply"
      && samples[index].outcome === "reply"
      && samples[index].sequence === samples[index - 1].sequence + 1
    ) {
      adjacentDifferences.push(Math.abs(samples[index].rtt_us - samples[index - 1].rtt_us));
    }
  }
  const adjacentMeanUs = adjacentDifferences.length === 0
    ? null
    : adjacentDifferences.reduce((sum, value) => sum + value, 0) / adjacentDifferences.length;
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

function samples(count, baseRttUs, timeoutSequence = null) {
  return Array.from({ length: count }, (_, index) => {
    const sequence = index + 1;
    if (sequence === timeoutSequence) {
      return {
        sequence,
        elapsed_ms: index * 1000,
        outcome: "timeout",
        rtt_us: null,
        error_code: null
      };
    }
    return {
      sequence,
      elapsed_ms: index * 1000,
      outcome: "reply",
      rtt_us: baseRttUs + (index % 5) * 250,
      error_code: null
    };
  });
}

function verification(phase, position, minute) {
  const baseline = phase === "baseline";
  return {
    id: `${phase}-${position}`,
    session_id: "session-1",
    position,
    checked_at: `2026-09-16T10:${String(minute).padStart(2, "0")}:00Z`,
    request_status: "completed",
    expected_warp_states: baseline ? ["off"] : ["on", "plus"],
    observed_warp_state: baseline ? "off" : "on",
    colo: "CGK",
    match: "matched",
    evidence_scope: "cloudflare_https_trace",
    error: null
  };
}

const endpoint = { ipv4: "192.0.2.10", iperf_port: 5201 };

function idleMeasurement(phase, minute, baseRttUs) {
  const values = samples(30, baseRttUs, 7);
  return {
    id: `${phase}-singapore-idle`,
    phase_id: phase,
    target_id: "singapore",
    session_id: "session-1",
    kind: "idle_ping",
    status: "completed",
    started_at: `2026-09-16T10:${String(minute).padStart(2, "0")}:00Z`,
    ended_at: `2026-09-16T10:${String(minute).padStart(2, "0")}:30Z`,
    endpoint,
    settings: {
      requested_probes: 30,
      interval_ms: 1000,
      timeout_ms: 2000,
      payload_bytes: 32
    },
    samples: values,
    summary: pingSummary(values),
    error: null
  };
}

function loadedPing(baseRttUs) {
  const values = Array.from({ length: 20 }, (_, index) => ({
    sequence: index + 1,
    elapsed_ms: index * 500,
    outcome: "reply",
    rtt_us: baseRttUs + index * 1000,
    error_code: null
  }));
  return {
    status: "completed",
    samples: values,
    summary: pingSummary(values),
    error: null
  };
}

function transferMeasurement(phase, direction, minute, bytes, loadedRttUs) {
  const id = `${phase}-singapore-${direction}-1`;
  const bitsPerSecond = Math.floor(bytes * 8000 / 10000 + 0.5);
  return {
    id,
    phase_id: phase,
    target_id: "singapore",
    kind: "tcp_transfer",
    status: "completed",
    started_at: `2026-09-16T10:${String(minute).padStart(2, "0")}:00Z`,
    ended_at: `2026-09-16T10:${String(minute).padStart(2, "0")}:10Z`,
    endpoint,
    settings: {
      protocol: "tcp",
      direction,
      repetition: 1,
      duration_seconds: 10,
      streams: 1
    },
    selected_attempt: 1,
    attempts: [
      {
        number: 1,
        session_id: "session-1",
        status: "completed",
        started_at: `2026-09-16T10:${String(minute).padStart(2, "0")}:00Z`,
        ended_at: `2026-09-16T10:${String(minute).padStart(2, "0")}:10Z`,
        sender: {
          bytes: bytes + 100000,
          duration_ms: 10000,
          bits_per_second: Math.floor((bytes + 100000) * 8000 / 10000 + 0.5),
          retransmits: direction === "upload" ? 2 : null
        },
        receiver: {
          bytes,
          duration_ms: 10000,
          bits_per_second: bitsPerSecond,
          retransmits: null
        },
        intervals: [
          {
            index: 0,
            start_ms: 0,
            end_ms: 5000,
            receiver_bytes: Math.floor(bytes / 2),
            receiver_bits_per_second: Math.floor(Math.floor(bytes / 2) * 8000 / 5000 + 0.5),
            sender_bits_per_second: null,
            retransmits: null,
            omitted: false
          },
          {
            index: 1,
            start_ms: 5000,
            end_ms: 10000,
            receiver_bytes: bytes - Math.floor(bytes / 2),
            receiver_bits_per_second: Math.floor((bytes - Math.floor(bytes / 2)) * 8000 / 5000 + 0.5),
            sender_bits_per_second: null,
            retransmits: null,
            omitted: false
          }
        ],
        loaded_ping: loadedPing(loadedRttUs),
        error: null
      }
    ],
    error: null
  };
}

function pendingMeasurement(measurement) {
  const pending = {
    ...structuredClone(measurement),
    status: "pending",
    started_at: null,
    ended_at: null,
    error: null
  };
  if (pending.kind === "idle_ping") {
    pending.samples = [];
    pending.summary = null;
  } else {
    pending.selected_attempt = null;
    pending.attempts = [];
  }
  return pending;
}

function baseResult() {
  return {
    schema_version: "1.0.0",
    run: {
      id: "run-complete",
      runner_version: "0.1.0",
      target_manifest_version: "1.0.0",
      profile_complete: true,
      comparison_valid: true,
      started_at: "2026-09-16T10:00:00Z",
      updated_at: "2026-09-16T11:00:00Z",
      ended_at: "2026-09-16T11:00:00Z",
      status: "completed"
    },
    environment: {
      os: { family: "windows", name: "Windows", version: "11" },
      architecture: "x86_64",
      runner: { implementation: "powershell", version: "0.1.0" },
      tools: [
        { name: "ping", version: ".NET 4.8", provisioning: "system", capabilities: ["ipv4", "rtt_microseconds"] },
        { name: "iperf3", version: "3.19.1", provisioning: "temporary_download", capabilities: ["json", "reverse", "intervals"] }
      ]
    },
    configuration: {
      profile: "quick",
      ip_version: 4,
      idle_ping: { requested_probes: 30, interval_ms: 1000, timeout_ms: 2000, payload_bytes: 32 },
      loaded_ping: { interval_ms: 500, timeout_ms: 1000, payload_bytes: 32 },
      tcp: { duration_seconds: 10, repetitions_per_direction: 1, streams: 1, directions: ["download", "upload"] },
      timing: {
        route_settle_seconds: 5,
        between_transfers_seconds: 2,
        between_targets_seconds: 3,
        server_busy_retries: 2,
        retry_backoff_seconds: [5, 10]
      }
    },
    privacy: {
      policy_version: "1.0.0",
      sanitization_applied: true,
      destination_ipv4_retained: true,
      client_address_retained: false,
      local_identity_retained: false,
      raw_tool_output_retained: false
    },
    targets: [
      {
        id: "singapore",
        manifest_target_id: "sg-singapore-example",
        label: "Singapore",
        country_code: "SG",
        city: "Singapore",
        location_confidence: "directory_listed",
        hostname: "iperf.example.test",
        endpoint
      }
    ],
    sessions: [
      {
        id: "session-1",
        reason: "initial",
        previous_session_id: null,
        gap_seconds: null,
        route_reverified: true,
        started_at: "2026-09-16T10:00:00Z",
        ended_at: "2026-09-16T11:00:00Z",
        status: "completed"
      }
    ],
    phases: [
      {
        id: "baseline",
        ordinal: 1,
        requested_route: "direct",
        status: "completed",
        started_at: "2026-09-16T10:01:00Z",
        ended_at: "2026-09-16T10:20:00Z",
        verification_disposition: "verified",
        verification_checks: [verification("baseline", "before_phase", 1), verification("baseline", "after_phase", 20)]
      },
      {
        id: "warp",
        ordinal: 2,
        requested_route: "warp",
        status: "completed",
        started_at: "2026-09-16T10:31:00Z",
        ended_at: "2026-09-16T10:50:00Z",
        verification_disposition: "verified",
        verification_checks: [verification("warp", "before_phase", 31), verification("warp", "after_phase", 50)]
      }
    ],
    measurements: [
      idleMeasurement("baseline", 2, 15000),
      transferMeasurement("baseline", "download", 4, 350000000, 40000),
      transferMeasurement("baseline", "upload", 6, 340000000, 42000),
      idleMeasurement("warp", 32, 17000),
      transferMeasurement("warp", "download", 34, 370000000, 45000),
      transferMeasurement("warp", "upload", 36, 360000000, 47000)
    ],
    diagnostics: []
  };
}

const complete = baseResult();

const partial = structuredClone(complete);
partial.run.id = "run-partial";
partial.run.status = "partial";
partial.run.profile_complete = false;
const failedTransfer = partial.measurements.find((measurement) => measurement.id === "warp-singapore-upload-1");
failedTransfer.status = "failed";
failedTransfer.ended_at = "2026-09-16T10:36:18Z";
failedTransfer.selected_attempt = null;
const retryTimes = [[0, 1], [6, 7], [17, 18]];
failedTransfer.attempts = [1, 2, 3].map((number) => ({
  number,
  session_id: "session-1",
  status: "failed",
  started_at: `2026-09-16T10:36:${String(retryTimes[number - 1][0]).padStart(2, "0")}Z`,
  ended_at: `2026-09-16T10:36:${String(retryTimes[number - 1][1]).padStart(2, "0")}Z`,
  sender: null,
  receiver: null,
  intervals: [],
  loaded_ping: null,
  error: {
    code: "IPERF_SERVER_BUSY",
    category: "remote_server",
    retryable: true,
    message: "The public server rejected the transfer because it was busy."
  }
}));
failedTransfer.error = {
  code: "IPERF_SERVER_BUSY",
  category: "remote_server",
  retryable: true,
  message: "The public server remained busy after bounded retries."
};
partial.diagnostics.push({
  timestamp: "2026-09-16T10:36:18Z",
  severity: "warning",
  code: "IPERF_SERVER_BUSY",
  message: "Upload result is unavailable after bounded retries.",
  phase_id: "warp",
  target_id: "singapore",
  measurement_id: failedTransfer.id
});

const failed = baseResult();
failed.run = {
  ...failed.run,
  id: "run-failed",
  profile_complete: false,
  comparison_valid: false,
  updated_at: "2026-09-16T10:01:00Z",
  ended_at: "2026-09-16T10:01:00Z",
  status: "failed"
};
failed.sessions[0] = { ...failed.sessions[0], ended_at: "2026-09-16T10:01:00Z", status: "completed" };
failed.phases = [
  {
    id: "baseline",
    ordinal: 1,
    requested_route: "direct",
    status: "failed",
    started_at: "2026-09-16T10:01:00Z",
    ended_at: "2026-09-16T10:01:00Z",
    verification_disposition: "verification_failed",
    verification_checks: [
      {
        id: "baseline-before-failed",
        session_id: "session-1",
        position: "before_phase",
        checked_at: "2026-09-16T10:01:00Z",
        request_status: "failed",
        expected_warp_states: ["off"],
        observed_warp_state: "unknown",
        colo: null,
        match: "indeterminate",
        evidence_scope: "cloudflare_https_trace",
        error: {
          code: "TRACE_UNREACHABLE",
          category: "route_verification",
          retryable: true,
          message: "Cloudflare trace could not be reached."
        }
      }
    ]
  },
  {
    id: "warp",
    ordinal: 2,
    requested_route: "warp",
    status: "pending",
    started_at: null,
    ended_at: null,
    verification_disposition: "not_performed",
    verification_checks: []
  }
];
failed.measurements = complete.measurements.map(pendingMeasurement);
failed.diagnostics = [
  {
    timestamp: "2026-09-16T10:01:00Z",
    severity: "error",
    code: "BASELINE_NOT_VERIFIED",
    message: "The benchmark stopped before measurements began.",
    phase_id: "baseline",
    target_id: null,
    measurement_id: null
  }
];

const interrupted = baseResult();
interrupted.run = {
  ...interrupted.run,
  id: "run-interrupted",
  profile_complete: false,
  comparison_valid: false,
  updated_at: "2026-09-16T10:02:02Z",
  ended_at: "2026-09-16T10:02:02Z",
  status: "interrupted"
};
interrupted.sessions[0] = { ...interrupted.sessions[0], ended_at: "2026-09-16T10:02:02Z", status: "interrupted" };
interrupted.phases = [
  {
    id: "baseline",
    ordinal: 1,
    requested_route: "direct",
    status: "interrupted",
    started_at: "2026-09-16T10:01:00Z",
    ended_at: "2026-09-16T10:02:02Z",
    verification_disposition: "unverified_continued",
    verification_checks: [verification("baseline", "before_phase", 1)]
  },
  {
    id: "warp",
    ordinal: 2,
    requested_route: "warp",
    status: "pending",
    started_at: null,
    ended_at: null,
    verification_disposition: "not_performed",
    verification_checks: []
  }
];
const interruptedSamples = samples(2, 15000);
interrupted.measurements = [
  {
    ...idleMeasurement("baseline", 2, 15000),
    status: "interrupted",
    ended_at: "2026-09-16T10:02:02Z",
    samples: interruptedSamples,
    summary: pingSummary(interruptedSamples),
    error: {
      code: "USER_CANCELLED",
      category: "user",
      retryable: true,
      message: "The benchmark was cancelled during idle ping."
    }
  },
  ...complete.measurements.slice(1).map(pendingMeasurement)
];
interrupted.diagnostics = [
  {
    timestamp: "2026-09-16T10:02:02Z",
    severity: "warning",
    code: "USER_CANCELLED",
    message: "Progress was checkpointed for a later resume.",
    phase_id: "baseline",
    target_id: "singapore",
    measurement_id: "baseline-singapore-idle"
  }
];

const checkOnly = process.argv.includes("--check");
let stale = false;
await mkdir(fixtureDirectory, { recursive: true });
for (const [name, fixture] of Object.entries({ complete, partial, failed, interrupted })) {
  const path = resolve(fixtureDirectory, `results-${name}.json`);
  const content = `${JSON.stringify(fixture, null, 2)}\n`;
  if (checkOnly) {
    const existing = await readFile(path, "utf8").catch(() => null);
    if (existing?.replace(/\r\n/g, "\n") !== content) {
      stale = true;
      console.error(`Generated fixture is stale: results-${name}.json`);
    }
  } else {
    await writeFile(path, content);
  }
}

if (stale) process.exit(1);
