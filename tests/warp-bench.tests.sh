#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export WARP_BENCH_SOURCE_ONLY=1
# shellcheck source=../scripts/warp-bench.sh
source "$root/scripts/warp-bench.sh"
WARP_BENCH_JQ=$(command -v jq)
WARP_BENCH_JQ_PROVISIONING=system
fixture=$root/tests/fixtures/normalization-parity.json
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT

assert_equal() {
  [[ $1 == "$2" ]] || { printf 'FAIL: %s (expected %s, got %s)\n' "$3" "$2" "$1" >&2; exit 1; }
  printf 'PASS: %s\n' "$3"
}

assert_true() {
  "$@" || { printf 'FAIL: %s\n' "${ASSERT_NAME:-assertion}" >&2; exit 1; }
  printf 'PASS: %s\n' "${ASSERT_NAME:-assertion}"
}

pipe_probe=$(env -u WARP_BENCH_SOURCE_ONLY WARP_BENCH_ENTRY_PROBE=1 bash < "$root/scripts/warp-bench.sh")
assert_equal "$pipe_probe" pipe-entry-reached 'pipe-to-shell reaches the interactive entry point'
assert_equal "$(wb_seconds_to_ms 3000000)" 3000000000 'monotonic milliseconds exceed 32-bit uptime'

cadence_dir=$temporary/cadence
mkdir -p "$cadence_dir/bin"
printf '0\n' > "$cadence_dir/clock"
printf '0\n' > "$cadence_dir/count"
cat > "$cadence_dir/bin/ping" <<'EOF'
#!/usr/bin/env bash
count=$(<"$WARP_BENCH_FAKE_COUNT"); count=$((count + 1)); printf '%s\n' "$count" > "$WARP_BENCH_FAKE_COUNT"
now=$(<"$WARP_BENCH_FAKE_CLOCK")
if (( count == 1 )); then
  printf '%s\n' "$((now + 1000))" > "$WARP_BENCH_FAKE_CLOCK"
  printf '100%% packet loss\n'
  exit 1
fi
printf '%s\n' "$((now + 20))" > "$WARP_BENCH_FAKE_CLOCK"
printf '64 bytes: time=1.0 ms\n'
EOF
chmod 700 "$cadence_dir/bin/ping"
cadence_samples=$(
  export PATH="$cadence_dir/bin:$PATH" WARP_BENCH_FAKE_CLOCK="$cadence_dir/clock" WARP_BENCH_FAKE_COUNT="$cadence_dir/count"
  wb_uptime_ms() { local now; read -r now < "$WARP_BENCH_FAKE_CLOCK"; printf '%s' "$now"; }
  sleep() {
    local now increment
    now=$(<"$WARP_BENCH_FAKE_CLOCK")
    increment=$(awk -v value="$1" 'BEGIN { printf "%.0f", value * 1000 }')
    printf '%s\n' "$((now + increment))" > "$WARP_BENCH_FAKE_CLOCK"
  }
  wb_ping_adapter 192.0.2.1 3 500 1000 32 | jq -sc '[.[].elapsed_ms]|join(",")'
)
assert_equal "$cadence_samples" '"0,1000,1500"' 'timeout recovery does not burst catch-up probes'

summary=$(jq -c '.ping_samples' "$fixture" | wb_ping_summary)
assert_equal "$(jq -c . <<<"$summary")" "$(jq -c '.ping_summary' "$fixture")" 'Bash ping normalization parity'

normalized=$(jq -c '.iperf' "$fixture" | wb_normalize_iperf upload)
assert_equal "$(jq -r '.receiver|[.bytes,.duration_ms,.bits_per_second]|@csv' <<<"$normalized")" '2000,2000,8000' 'receiver-authoritative aggregate normalization'
assert_equal "$(jq -r '.intervals[0]|[.index,.start_ms,.end_ms,.receiver_bytes]|@csv' <<<"$normalized")" '0,0,2000,2000' 'aggregate interval covers receiver total'

stream='{"event":"start","data":{"test_start":{"duration":2}}}
{"event":"interval","data":{"sum":{"start":0,"end":1,"bytes":1050,"omitted":false}}}
{"event":"interval","data":{"sum":{"start":1,"end":2,"bytes":1050,"omitted":false}}}
{"event":"server_output_json","data":{"intervals":[{"sum":{"start":0,"end":1,"bytes":1000,"omitted":false}},{"sum":{"start":1,"end":2,"bytes":1000,"omitted":false}}]}}
{"event":"end","data":{"sum_sent":{"seconds":2,"bytes":2100,"retransmits":1},"sum_received":{"seconds":2,"bytes":2000}}}'
stream_normalized=$(printf '%s\n' "$stream" | wb_normalize_iperf upload)
assert_equal "$(jq -r '[.intervals[].index]|join(",")' <<<"$stream_normalized")" '0,1' 'stream interval indexes are contiguous'
assert_equal "$(jq -r '[.intervals[].receiver_bytes]|add' <<<"$stream_normalized")" '2000' 'server receiver intervals are authoritative'
assert_equal "$(jq -r '.intervals[0].end_ms == .intervals[1].start_ms and .intervals[1].end_ms == .receiver.duration_ms' <<<"$stream_normalized")" true 'normalized intervals have complete contiguous timing'

if printf '%s\n' '{"intervals":[{"sum":{"start":0,"end":1,"bytes":999}}],"end":{"sum_sent":{"seconds":1,"bytes":999},"sum_received":{"seconds":1,"bytes":1000}}}' | wb_normalize_iperf download >/dev/null 2>&1; then
  printf 'FAIL: mismatched receiver intervals were accepted\n' >&2; exit 1
fi
printf 'PASS: parser rejects intervals inconsistent with receiver totals\n'

if printf '%s\n' '{"error":"server is busy"}' | wb_normalize_iperf download >/dev/null 2>&1; then
  printf 'FAIL: iperf error was accepted\n' >&2; exit 1
fi
printf 'PASS: parser rejects iperf failures\n'

trace=$(printf 'ip=203.0.113.4\nwarp=plus\ncolo=CGK\n' | wb_trace_parse '["on","plus"]' trace-id before_phase)
assert_equal "$(jq -r .observed_warp_state <<<"$trace")" plus 'trace state parser'
assert_equal "$(jq -r .colo <<<"$trace")" CGK 'trace colo parser'
assert_equal "$(jq -r .match <<<"$trace")" matched 'trace expected-state match'
[[ $trace != *203.0.113.4* ]] || { printf 'FAIL: trace retained client address\n' >&2; exit 1; }
printf 'PASS: trace omits client address\n'

redacted=$(wb_redact 'Failure 203.0.113.7 2001:db8::1234 /home/alice/result.json alice@example.test DESKTOP-SECRET')
[[ $redacted == *'[local-path]'* && $redacted == *'[address]'* && $redacted == *'[identity]'* && $redacted == *'[host]'* ]]
[[ $redacted != *'203.0.113.7'* && $redacted != *'2001:db8'* && $redacted != *'alice@example.test'* ]]
printf 'PASS: diagnostic IPv4, IPv6, identity, host, and path redaction\n'

checkpoint=$temporary/checkpoint.json
wb_checkpoint "$checkpoint" '{"long":"value that must not survive replacement","run":{"updated_at":"old","ended_at":null}}'
wb_checkpoint "$checkpoint" '{"run":{"updated_at":"new","ended_at":null}}'
assert_equal "$(jq -r 'has("long")' "$checkpoint")" false 'atomic checkpoint replaces rather than appends'
wb_state_apply "$checkpoint" '.marker="mutated"'
assert_equal "$(jq -r .marker "$checkpoint")" mutated 'jq checkpoint mutation helper'

target='[{"id":"test-target","manifest_target_id":"test-target","label":"Test","country_code":"US","city":null,"location_confidence":"unverified","hostname":"example.test","endpoint":{"ipv4":"192.0.2.1","iperf_port":5201}}]'
state=$(wb_new_state quick "$target" 3.21.0 system test-run 2026-09-16T10:00:00Z)
assert_equal "$(jq '.measurements|length' <<<"$state")" 6 'complete two-phase measurement plan'
assert_equal "$(jq '[.measurements[]|select(.kind=="idle_ping")]|length' <<<"$state")" 2 'one idle test per phase and target'
assert_equal "$(jq '[.measurements[]|select(.kind=="tcp_transfer")]|length' <<<"$state")" 4 'all direction and phase transfer tests planned'
assert_equal "$(jq -r '.environment.runner.implementation' <<<"$state")" bash 'Linux Bash environment snapshot'
assert_equal "$(jq -r '.configuration.idle_ping.requested_probes' <<<"$state")" 30 'exact quick profile snapshot'

finalization_result=$temporary/finalization-result.json
cp "$root/tests/fixtures/results-complete.json" "$finalization_result"
wb_finalize_state "$finalization_result" auto
assert_equal "$(jq -r '.run.status' "$finalization_result")" completed 'completed plans finalize without jq scope errors'
assert_equal "$(jq -r '.run.comparison_valid' "$finalization_result")" true 'compatible verified phases finalize as comparable'

result=$temporary/linux-result.json
wb_checkpoint "$result" "$state"
fake_iperf=$temporary/fake-iperf3
cat > "$fake_iperf" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"event":"start","data":{"test_start":{"duration":1}}}'
sleep 0.15
printf '%s\n' '{"event":"interval","data":{"sum":{"start":0,"end":0.1,"bytes":1000,"omitted":false}}}'
printf '%s\n' '{"event":"end","data":{"sum_sent":{"seconds":0.1,"bytes":1000,"retransmits":0},"sum_received":{"seconds":0.1,"bytes":1000}}}'
EOF
chmod 700 "$fake_iperf"
WARP_BENCH_WORK_DIR=$temporary
wb_ping_adapter() {
  printf '%s\n' '{"sequence":1,"elapsed_ms":0,"outcome":"reply","rtt_us":1000,"error_code":null}'
}
wb_phase_start "$result" baseline
wb_run_transfer "$result" baseline-test-target-download-1 "$fake_iperf"
assert_equal "$(jq -r '.measurements[]|select(.id=="baseline-test-target-download-1")|.status' "$result")" completed 'background JSON-stream transfer completes'
assert_equal "$(jq -r '.measurements[]|select(.id=="baseline-test-target-download-1")|.selected_attempt' "$result")" 1 'completed transfer selects successful attempt'
assert_equal "$(jq -r '.measurements[]|select(.id=="baseline-test-target-download-1")|.attempts[0].loaded_ping.status' "$result")" completed 'loaded ping is attached to transfer attempt'

malformed_iperf=$temporary/malformed-iperf3
cat > "$malformed_iperf" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"event":"start","data":{"test_start":{"duration":1}}}'
sleep 0.15
printf '%s\n' '{"event":"end","data":{}}'
EOF
chmod 700 "$malformed_iperf"
wb_state_apply "$result" '.configuration.timing.server_busy_retries=0'
parser_stderr=$temporary/parser-stderr
wb_run_transfer "$result" baseline-test-target-upload-1 "$malformed_iperf" 2> "$parser_stderr"
assert_equal "$(jq -r '.measurements[]|select(.id=="baseline-test-target-upload-1")|.status' "$result")" failed 'malformed iperf output fails the transfer cleanly'
assert_equal "$(wc -c < "$parser_stderr")" 0 'expected parser rejection does not leak jq diagnostics'

wb_state_apply "$result" '(.measurements[]|select(.id=="baseline-test-target-idle")) |= (.status="running"|.started_at=$checkpoint_now)'
wb_finalize_state "$result" interrupted
assert_equal "$(jq -r '.run.status' "$result")" interrupted 'run finalizes as interrupted'
assert_equal "$(jq -r '.sessions[0].status' "$result")" interrupted 'session finalizes as interrupted'
assert_equal "$(jq -r '.phases[]|select(.id=="baseline")|.status' "$result")" interrupted 'running phase finalizes as interrupted'
assert_equal "$(jq -r '.measurements[]|select(.id=="baseline-test-target-idle")|.status' "$result")" interrupted 'running measurement finalizes as interrupted'
assert_equal "$(jq -r '.run.ended_at == .run.updated_at' "$result")" true 'terminal checkpoint timestamps agree'

if [[ -n ${WARP_BENCH_TEST_OUTPUT:-} ]]; then
  cp "$result" "$WARP_BENCH_TEST_OUTPUT"
fi

printf 'All Bash runner tests passed.\n'
