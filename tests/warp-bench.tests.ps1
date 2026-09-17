$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\warp-bench.ps1'
. $scriptPath
$sharedFixture = Get-Content (Join-Path $PSScriptRoot 'fixtures/normalization-parity.json') -Raw | ConvertFrom-Json

$failures = 0
function Assert-Equal($Expected, $Actual, [string]$Name) {
    if ($Expected -ne $Actual) { Write-Error "$Name expected '$Expected', got '$Actual'"; $script:failures++ }
    else { Write-Host "PASS: $Name" }
}
function Assert-True([bool]$Value, [string]$Name) { Assert-Equal $true $Value $Name }

$samples = @(
    [pscustomobject]@{ sequence = 1; outcome = 'reply'; rtt_us = 1000 },
    [pscustomobject]@{ sequence = 2; outcome = 'reply'; rtt_us = 3000 },
    [pscustomobject]@{ sequence = 3; outcome = 'timeout'; rtt_us = $null },
    [pscustomobject]@{ sequence = 4; outcome = 'reply'; rtt_us = 5000 },
    [pscustomobject]@{ sequence = 5; outcome = 'local_error'; rtt_us = $null }
)
$summary = Get-WarpBenchPingSummary $samples
Assert-Equal 4 $summary.probes_sent 'ping sent excludes local errors'
Assert-Equal 25 $summary.reply_loss_percent 'ping loss calculation'
Assert-Equal 3 $summary.rtt_median_ms 'median calculation'
Assert-Equal 5 $summary.rtt_p95_ms 'nearest-rank p95 calculation'
Assert-Equal 2 $summary.rtt_adjacent_mean_abs_diff_ms 'missing probe breaks adjacency'
$sharedSummary = Get-WarpBenchPingSummary @($sharedFixture.ping_samples)
Assert-Equal $sharedFixture.ping_summary.rtt_stddev_ms $sharedSummary.rtt_stddev_ms 'shared ping fixture parity'

$trace = ConvertFrom-WarpBenchTrace "ip=203.0.113.4`nwarp=plus`ncolo=CGK" @('on', 'plus') 'test-trace'
Assert-Equal 'plus' $trace.observed_warp_state 'trace WARP parser'
Assert-Equal 'CGK' $trace.colo 'trace colo parser'
Assert-Equal 'matched' $trace.match 'trace match disposition'
Assert-True (-not (($trace | ConvertTo-Json -Depth 5) -match '203\.0\.113\.4')) 'trace omits client IP'

$redacted = Protect-WarpBenchText 'Failure for 203.0.113.7 in C:\Users\alice\result.json from alice@example.test'
Assert-True (-not ($redacted -match '203\.0\.113\.7|alice|C:\\')) 'diagnostic redaction'
$redactedV6 = Protect-WarpBenchText 'Failure for 2001:db8::1234'
Assert-True (-not ($redactedV6 -match '2001:db8')) 'IPv6 diagnostic redaction'

$iperfJson = '{"intervals":[{"sum":{"start":0,"end":1,"bytes":1050,"bits_per_second":8400,"omitted":false}},{"sum":{"start":1,"end":2,"bytes":1050,"bits_per_second":8400,"omitted":false}}],"end":{"sum_sent":{"seconds":2,"bytes":2100,"retransmits":2},"sum_received":{"seconds":2,"bytes":2000}},"server_output_json":{"intervals":[{"sum":{"start":0,"end":1,"bytes":1000,"bits_per_second":8000,"omitted":false}},{"sum":{"start":1,"end":2,"bytes":1000,"bits_per_second":8000,"omitted":false}}]}}'
$parsed = ConvertFrom-WarpBenchIperfJson $iperfJson 'upload'
Assert-Equal 8000 $parsed.receiver.bits_per_second 'receiver goodput normalization'
$intervalBytes = [int64]0
foreach ($interval in $parsed.intervals) { $intervalBytes += $interval.receiver_bytes }
Assert-Equal 2000 $intervalBytes 'interval bytes cover receiver total'
Assert-Equal 2000 $parsed.intervals[1].end_ms 'interval duration coverage'
$parserRejectedFailure = $false
try { ConvertFrom-WarpBenchIperfJson '{"error":"server is busy"}' 'download' | Out-Null } catch { $parserRejectedFailure = $true }
Assert-True $parserRejectedFailure 'iperf failure is not converted to zero throughput'
$sharedIperf = ConvertFrom-WarpBenchIperfJson ($sharedFixture.iperf | ConvertTo-Json -Compress -Depth 10) 'upload'
Assert-Equal $sharedFixture.iperf_normalized.receiver_bits_per_second $sharedIperf.receiver.bits_per_second 'shared iperf fixture parity'

$streamJson = @'
{"event":"start","data":{"test_start":{"duration":2}}}
{"event":"interval","data":{"sum":{"start":0,"end":1,"seconds":1,"bytes":1050,"bits_per_second":8400,"omitted":false}}}
{"event":"interval","data":{"sum":{"start":1,"end":2,"seconds":1,"bytes":1050,"bits_per_second":8400,"omitted":false}}}
{"event":"server_output_text","data":"ordinary public server text"}
{"event":"end","data":{"sum_sent":{"seconds":2,"bytes":2100,"retransmits":1},"sum_received":{"seconds":2,"bytes":2000}}}
'@
$streamParsed = ConvertFrom-WarpBenchIperfJson $streamJson 'upload'
Assert-Equal 1 $streamParsed.intervals.Count 'upload without server JSON uses receiver aggregate interval'
Assert-Equal 2000 $streamParsed.intervals[0].receiver_bytes 'aggregate interval keeps authoritative receiver bytes'

$target = [ordered]@{ id = 'test-target'; manifest_target_id = 'test-target'; label = 'Test'; country_code = 'US'; city = $null; location_confidence = 'unverified'; hostname = 'example.test'; endpoint = [ordered]@{ ipv4 = '192.0.2.1'; iperf_port = 5201 } }
$state = New-WarpBenchState 'quick' @($target) '3.21.0' 'system' 'test-run' '2026-09-16T10:00:00Z'
Assert-Equal 6 $state.measurements.Count 'complete two-phase measurement plan'
Assert-Equal 'pending' $state.measurements[5].status 'initial measurement state'
Assert-Equal 30 $state.configuration.idle_ping.requested_probes 'quick profile snapshot'
$checkpoint = [IO.Path]::GetTempFileName()
try {
    Write-WarpBenchCheckpoint $state $checkpoint
    $roundTrip = [IO.File]::ReadAllText($checkpoint) | ConvertFrom-Json
    Assert-Equal '1.0.0' $roundTrip.schema_version 'checkpoint serialization'
    Assert-Equal 6 $roundTrip.measurements.Count 'checkpoint preserves measurement plan'
} finally { Remove-Item -LiteralPath $checkpoint, "$checkpoint.tmp", "$checkpoint.bak" -Force -ErrorAction SilentlyContinue }

$terminalPath = [IO.Path]::GetTempFileName()
try {
    Stop-WarpBenchState $state 'interrupted' $terminalPath
    $terminal = [IO.File]::ReadAllText($terminalPath) | ConvertFrom-Json
    Assert-Equal $terminal.run.ended_at $terminal.run.updated_at 'terminal checkpoint timestamp ordering'
    Assert-Equal 'interrupted' $terminal.run.status 'interrupted terminal lifecycle'
    if ($env:WARP_BENCH_TEST_OUTPUT) {
        [IO.File]::Copy($terminalPath, $env:WARP_BENCH_TEST_OUTPUT, $true)
    }
} finally { Remove-Item -LiteralPath $terminalPath, "$terminalPath.tmp", "$terminalPath.bak" -Force -ErrorAction SilentlyContinue }

if ($failures -gt 0) { throw "$failures PowerShell test(s) failed." }
Write-Host 'All PowerShell runner tests passed.'
