#requires -Version 5.1
<#
.SYNOPSIS
Runs the Windows x64 WARP versus ISP benchmark.

.DESCRIPTION
The runner is self-contained so it can be invoked with iwr | iex. Dot-source it
to load its functions without starting the interactive workflow.
#>

Set-StrictMode -Version 2.0

$script:WarpBenchVersion = '0.2.0'
$script:TargetManifestJson = @'
{"schema_version":"1.0.0","manifest_version":"1.0.0","targets":[{"id":"id-indonesia-myrepublic","order":1,"enabled":true,"label":"Indonesia","country_code":"ID","city":null,"location_confidence":"unverified","endpoints":[{"id":"myrepublic-tangerang2","priority":1,"hostname":"speedtest.tangerang2.myrepublic.net.id","ports":[9201,9202,9203,9204,9205,9206,9207,9208,9209,9210,9211,9212,9213,9214,9215,9216,9217,9218,9219,9220,9221,9222,9223,9224,9225,9226,9227,9228,9229,9230,9231,9232,9233,9234,9235,9236,9237,9238,9239,9240],"verification_status":"partially_verified"}]},{"id":"sg-singapore-ovh","order":2,"enabled":true,"label":"Singapore","country_code":"SG","city":"Singapore","location_confidence":"operator_documented","endpoints":[{"id":"ovh-singapore","priority":1,"hostname":"sgp.proof.ovh.net","ports":[5201,5202,5203,5204,5205,5206,5207,5208,5209,5210],"verification_status":"verified"},{"id":"leaseweb-singapore-1","priority":2,"hostname":"speedtest.sin1.sg.leaseweb.net","ports":[5201,5202,5203,5204,5205,5206,5207,5208,5209,5210],"verification_status":"unverified"}]},{"id":"jp-tokyo-leaseweb","order":3,"enabled":true,"label":"Tokyo","country_code":"JP","city":"Tokyo","location_confidence":"directory_listed","endpoints":[{"id":"leaseweb-tokyo-11","priority":1,"hostname":"speedtest.tyo11.jp.leaseweb.net","ports":[5201,5202,5203,5204,5205,5206,5207,5208,5209,5210],"verification_status":"verified"},{"id":"datacamp-tokyo","priority":2,"hostname":"89.187.160.1","ports":[5201],"verification_status":"unverified"}]},{"id":"nl-amsterdam-clouvider","order":4,"enabled":true,"label":"Amsterdam","country_code":"NL","city":"Amsterdam","location_confidence":"operator_documented","endpoints":[{"id":"clouvider-amsterdam","priority":1,"hostname":"ams.speedtest.clouvider.net","ports":[5200,5201,5202,5203,5204,5205,5206,5207,5208,5209],"verification_status":"verified"},{"id":"leaseweb-amsterdam-1","priority":2,"hostname":"speedtest.ams1.nl.leaseweb.net","ports":[5201,5202,5203,5204,5205,5206,5207,5208,5209,5210],"verification_status":"unverified"}]},{"id":"gb-london-clouvider","order":5,"enabled":true,"label":"London","country_code":"GB","city":"London","location_confidence":"operator_documented","endpoints":[{"id":"clouvider-london","priority":1,"hostname":"lon.speedtest.clouvider.net","ports":[5200,5201,5202,5203,5204,5205,5206,5207,5208,5209],"verification_status":"verified"},{"id":"leaseweb-london-12","priority":2,"hostname":"speedtest.lon12.uk.leaseweb.net","ports":[5201,5202,5203,5204,5205,5206,5207,5208,5209,5210],"verification_status":"unverified"}]},{"id":"us-los-angeles-clouvider","order":6,"enabled":true,"label":"Los Angeles","country_code":"US","city":"Los Angeles","location_confidence":"operator_documented","endpoints":[{"id":"clouvider-los-angeles","priority":1,"hostname":"la.speedtest.clouvider.net","ports":[5200,5201,5202,5203,5204,5205,5206,5207,5208,5209],"verification_status":"verified"},{"id":"leaseweb-los-angeles-12","priority":2,"hostname":"speedtest.lax12.us.leaseweb.net","ports":[5201,5202,5203,5204,5205,5206,5207,5208,5209,5210],"verification_status":"unverified"}]},{"id":"us-new-york-clouvider","order":7,"enabled":true,"label":"New York City","country_code":"US","city":"New York City","location_confidence":"operator_documented","endpoints":[{"id":"clouvider-new-york","priority":1,"hostname":"nyc.speedtest.clouvider.net","ports":[5200,5201,5202,5203,5204,5205,5206,5207,5208,5209],"verification_status":"verified"},{"id":"leaseweb-new-york-1","priority":2,"hostname":"speedtest.nyc1.us.leaseweb.net","ports":[5201,5202,5203,5204,5205,5206,5207,5208,5209,5210],"verification_status":"unverified"}]}]}
'@
$script:IperfArtifactJson = @'
{"id":"iperf3-3.21-windows-x86_64-userdocs","tool":"iperf3","version":"3.21.0","os":"windows","architecture":"x86_64","url":"https://github.com/userdocs/iperf3-static/releases/download/3.21/iperf3-amd64-win.zip","sha256":"913d9aac883f53c2f8c63ab3adcd7c8b00ceceae768e8d03a5a93c75d09c42b4","archive_format":"zip","executable_path":"iperf3.exe","required_files":["iperf3.exe","cygwin1.dll"],"use_status":"approved","distribution_mode":"upstream_download"}
'@

function Get-WarpBenchUtc {
    [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.ffffffZ')
}

function New-WarpBenchError {
    param([string]$Code, [string]$Category, [bool]$Retryable, [string]$Message)
    [ordered]@{ code = $Code; category = $Category; retryable = $Retryable; message = Protect-WarpBenchText $Message }
}

function Protect-WarpBenchText {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return $null }
    $value = $Text
    $value = [regex]::Replace($value, '(?i)(?:[a-z]:\\|\\\\)[^\s,;]+', '[local-path]')
    $value = [regex]::Replace($value, '(?i)(?:^|\s)/(?:tmp|var|home|users|config|mnt)/[^\s,;]+', ' [local-path]')
    $value = [regex]::Replace($value, '(?<![\d.])(?:25[0-5]|2[0-4]\d|1?\d?\d)(?:\.(?:25[0-5]|2[0-4]\d|1?\d?\d)){3}(?![\d.])', '[address]')
    $value = [regex]::Replace($value, '(?i)(?<![0-9a-f:])(?:[0-9a-f]{0,4}:){2,7}[0-9a-f]{0,4}(?![0-9a-f:])', '[address]')
    $value = [regex]::Replace($value, '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b', '[identity]')
    $value = [regex]::Replace($value, '(?i)\bDESKTOP-[A-Z0-9-]+\b', '[host]')
    if ($value.Length -gt 300) { $value = $value.Substring(0, 300) }
    $value
}

function ConvertTo-WarpBenchInt {
    param($Value)
    if ($null -eq $Value) { return $null }
    [int64][Math]::Floor(([double]$Value) + 0.5)
}

function Round-WarpBenchHalfUp {
    param([double]$Value, [int]$Digits)
    $scale = [Math]::Pow(10, $Digits)
    [Math]::Floor($Value * $scale + 0.5) / $scale
}

function Get-WarpBenchPingSummary {
    param([Parameter(Mandatory)][object[]]$Samples)
    $replies = @($Samples | Where-Object { $_.outcome -eq 'reply' })
    $timeouts = @($Samples | Where-Object { $_.outcome -eq 'timeout' }).Count
    $localFailures = @($Samples | Where-Object { $_.outcome -eq 'local_error' }).Count
    $sent = $replies.Count + $timeouts
    $values = @($replies | ForEach-Object { [int64]$_.rtt_us } | Sort-Object)
    $mean = $null; $median = $null; $stddev = $null; $p95 = $null
    if ($values.Count -gt 0) {
        $sum = [double]0
        foreach ($value in $values) { $sum += $value }
        $mean = $sum / $values.Count
        $middle = [int][Math]::Floor($values.Count / 2)
        if (($values.Count % 2) -eq 1) { $median = [double]$values[$middle] }
        else { $median = ([double]$values[$middle - 1] + [double]$values[$middle]) / 2 }
        $squared = [double]0
        foreach ($value in $values) { $squared += [Math]::Pow($value - $mean, 2) }
        $stddev = [Math]::Sqrt($squared / $values.Count)
        $p95 = [double]$values[[int][Math]::Ceiling(0.95 * $values.Count) - 1]
    }
    $differences = @()
    for ($index = 1; $index -lt $Samples.Count; $index++) {
        $previous = $Samples[$index - 1]; $current = $Samples[$index]
        if ($previous.outcome -eq 'reply' -and $current.outcome -eq 'reply' -and $current.sequence -eq ($previous.sequence + 1)) {
            $differences += [Math]::Abs([double]$current.rtt_us - [double]$previous.rtt_us)
        }
    }
    $adjacentMean = $null
    if ($differences.Count -gt 0) {
        $differenceSum = [double]0
        foreach ($difference in $differences) { $differenceSum += $difference }
        $adjacentMean = $differenceSum / $differences.Count
    }
    function Convert-UsToMs($Value) {
        if ($null -eq $Value) { return $null }
        Round-WarpBenchHalfUp ([double]$Value / 1000) 3
    }
    [ordered]@{
        probes_recorded = $Samples.Count; probes_sent = $sent; replies_received = $replies.Count
        timed_out = $timeouts; local_failures = $localFailures
        reply_loss_percent = $(if ($sent -eq 0) { $null } else { Round-WarpBenchHalfUp (100.0 * $timeouts / $sent) 6 })
        rtt_min_ms = $(if ($values.Count) { Convert-UsToMs $values[0] } else { $null })
        rtt_mean_ms = Convert-UsToMs $mean; rtt_median_ms = Convert-UsToMs $median; rtt_p95_ms = Convert-UsToMs $p95
        rtt_max_ms = $(if ($values.Count) { Convert-UsToMs $values[$values.Count - 1] } else { $null })
        rtt_stddev_ms = Convert-UsToMs $stddev; rtt_adjacent_mean_abs_diff_ms = Convert-UsToMs $adjacentMean
    }
}

function ConvertFrom-WarpBenchTrace {
    param([AllowNull()][string]$Text, [string[]]$ExpectedStates, [string]$Id, [string]$Position = 'before_phase')
    $fields = @{}
    if ($Text) {
        foreach ($line in ($Text -split "`r?`n")) {
            if ($line -match '^([a-z]+)=([^\r\n]{0,100})$') { $fields[$matches[1]] = $matches[2] }
        }
    }
    $state = if ($fields.ContainsKey('warp') -and $fields.warp -in @('off', 'on', 'plus')) { $fields.warp } else { 'unknown' }
    $colo = if ($fields.ContainsKey('colo') -and $fields.colo -match '^[A-Z]{3}$') { $fields.colo } else { $null }
    $match = if ($state -eq 'unknown') { 'indeterminate' } elseif ($state -in $ExpectedStates) { 'matched' } else { 'mismatched' }
    [ordered]@{
        id = $Id; session_id = 'session-1'; position = $Position; checked_at = Get-WarpBenchUtc
        request_status = 'completed'; expected_warp_states = @($ExpectedStates); observed_warp_state = $state
        colo = $colo; match = $match; evidence_scope = 'cloudflare_https_trace'; error = $null
    }
}

function ConvertFrom-WarpBenchIperfJson {
    param([Parameter(Mandatory)][string]$Json, [Parameter(Mandatory)][string]$Direction)
    $trimmed = $Json.Trim()
    if ($trimmed -match '(?m)^\s*\{"event":') {
        $events = @()
        foreach ($line in ($trimmed -split "`r?`n")) {
            if (-not [string]::IsNullOrWhiteSpace($line)) { $events += ($line | ConvertFrom-Json) }
        }
        $endEvent = @($events | Where-Object event -eq 'end')
        if ($endEvent.Count -ne 1) { throw 'iperf3 JSON stream lacks one end event.' }
        $data = [pscustomobject]@{
            intervals = @($events | Where-Object event -eq 'interval' | ForEach-Object { $_.data })
            end = $endEvent[0].data
        }
        $serverJsonEvent = @($events | Where-Object event -eq 'server_output_json')
        if ($serverJsonEvent.Count -gt 0) { $data | Add-Member -NotePropertyName server_output_json -NotePropertyValue $serverJsonEvent[-1].data }
    }
    else { $data = $trimmed | ConvertFrom-Json }
    if ($data.PSObject.Properties['error'] -and $data.error) { throw (Protect-WarpBenchText ([string]$data.error)) }
    $receiverRaw = $data.end.sum_received
    $senderRaw = $data.end.sum_sent
    if ($null -eq $receiverRaw -or $null -eq $receiverRaw.bytes -or [double]$receiverRaw.seconds -le 0) {
        throw 'iperf3 did not report receiver statistics.'
    }
    function Convert-Side($Side) {
        if ($null -eq $Side -or $null -eq $Side.bytes -or [double]$Side.seconds -le 0) { return $null }
        $duration = [int][Math]::Max(1, [Math]::Floor([double]$Side.seconds * 1000 + 0.5))
        $bytes = [int64]$Side.bytes
        [ordered]@{
            bytes = $bytes; duration_ms = $duration
            bits_per_second = [int64][Math]::Floor($bytes * 8000.0 / $duration + 0.5)
            retransmits = $(if ($Side.PSObject.Properties['retransmits'] -and $null -ne $Side.retransmits) { [int64]$Side.retransmits } else { $null })
        }
    }
    $receiver = Convert-Side $receiverRaw
    $sender = Convert-Side $senderRaw
    $intervalData = $data
    if ($Direction -eq 'upload' -and $data.PSObject.Properties['server_output_json'] -and $null -ne $data.server_output_json) {
        $intervalData = $data.server_output_json
        if ($intervalData -is [string]) { $intervalData = $intervalData | ConvertFrom-Json }
    }
    elseif ($Direction -eq 'upload') {
        # Public servers commonly return only textual server output. Preserve the
        # authoritative receiver total as one full-duration receiver interval.
        return [ordered]@{
            sender = $sender; receiver = $receiver
            intervals = @([ordered]@{
                index = 0; start_ms = 0; end_ms = $receiver.duration_ms; receiver_bytes = $receiver.bytes
                receiver_bits_per_second = $receiver.bits_per_second; sender_bits_per_second = $null
                retransmits = $null; omitted = $false
            })
        }
    }
    $rawIntervals = @($intervalData.intervals)
    $intervals = @()
    $allocated = [int64]0
    for ($index = 0; $index -lt $rawIntervals.Count; $index++) {
        $sum = $rawIntervals[$index].sum
        if ($null -eq $sum) { $sum = $rawIntervals[$index].streams[0] }
        $start = [int][Math]::Max(0, [Math]::Floor([double]$sum.start * 1000 + 0.5))
        $end = [int][Math]::Min($receiver.duration_ms, [Math]::Floor([double]$sum.end * 1000 + 0.5))
        if ($index -eq 0) { $start = 0 } else { $start = $intervals[$index - 1].end_ms }
        if ($index -eq ($rawIntervals.Count - 1)) { $end = $receiver.duration_ms }
        if ($end -le $start) { continue }
        if ($null -eq $sum.bytes) { throw 'iperf3 receiver interval omitted its byte count.' }
        $bytes = [int64]$sum.bytes
        $allocated += $bytes
        $intervals += [ordered]@{
            index = $intervals.Count; start_ms = $start; end_ms = $end; receiver_bytes = $bytes
            receiver_bits_per_second = [int64][Math]::Floor($bytes * 8000.0 / ($end - $start) + 0.5)
            sender_bits_per_second = $null
            retransmits = $(if ($sum.PSObject.Properties['retransmits'] -and $null -ne $sum.retransmits) { [int64]$sum.retransmits } else { $null })
            omitted = $(if ($sum.PSObject.Properties['omitted']) { [bool]$sum.omitted } else { $false })
        }
    }
    if ($intervals.Count -eq 0) { throw 'iperf3 did not report usable transfer intervals.' }
    if ($allocated -ne $receiver.bytes) { throw 'iperf3 receiver intervals do not cover the receiver byte total.' }
    [ordered]@{ sender = $sender; receiver = $receiver; intervals = @($intervals) }
}

function Get-WarpBenchProfile {
    param([ValidateSet('quick', 'extended')][string]$Name)
    $extended = $Name -eq 'extended'
    [ordered]@{
        profile = $Name; ip_version = 4
        idle_ping = [ordered]@{ requested_probes = $(if ($extended) { 120 } else { 30 }); interval_ms = 1000; timeout_ms = 2000; payload_bytes = 32 }
        loaded_ping = [ordered]@{ interval_ms = 500; timeout_ms = 1000; payload_bytes = 32 }
        tcp = [ordered]@{ duration_seconds = $(if ($extended) { 15 } else { 10 }); repetitions_per_direction = $(if ($extended) { 3 } else { 1 }); streams = 1; directions = @('download', 'upload') }
        timing = [ordered]@{ route_settle_seconds = $(if ($extended) { 10 } else { 5 }); between_transfers_seconds = $(if ($extended) { 5 } else { 2 }); between_targets_seconds = $(if ($extended) { 10 } else { 3 }); server_busy_retries = 2; retry_backoff_seconds = @(5, 10) }
    }
}

function Test-WarpBenchTcpPort {
    param([string]$Address, [int]$Port, [int]$TimeoutMs = 1500)
    $client = New-Object System.Net.Sockets.TcpClient([System.Net.Sockets.AddressFamily]::InterNetwork)
    try {
        $async = $client.BeginConnect($Address, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) { return $false }
        $client.EndConnect($async); return $true
    } catch { return $false } finally { $client.Dispose() }
}

function Resolve-WarpBenchTargets {
    param($Manifest)
    $selected = @()
    foreach ($target in @($Manifest.targets | Where-Object enabled | Sort-Object order)) {
        Write-Host "Resolving and pinning $($target.label)..."
        $choice = $null
        foreach ($endpoint in @($target.endpoints | Where-Object { $_.verification_status -ne 'unavailable' } | Sort-Object priority)) {
            try {
                $addresses = @([System.Net.Dns]::GetHostAddresses([string]$endpoint.hostname) | Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } | ForEach-Object IPAddressToString | Sort-Object -Unique)
            } catch { $addresses = @() }
            foreach ($address in $addresses) {
                foreach ($port in @($endpoint.ports)) {
                    if (Test-WarpBenchTcpPort $address $port) {
                        $choice = [ordered]@{
                            id = [string]$target.id; manifest_target_id = [string]$target.id; label = [string]$target.label
                            country_code = [string]$target.country_code; city = $target.city; location_confidence = [string]$target.location_confidence
                            hostname = [string]$endpoint.hostname; endpoint = [ordered]@{ ipv4 = $address; iperf_port = [int]$port }
                        }
                        break
                    }
                }
                if ($choice) { break }
            }
            if ($choice) { break }
        }
        if ($choice) { $selected += $choice } else { Write-Warning "No documented endpoint was reachable for $($target.label); it will be omitted." }
    }
    if ($selected.Count -eq 0) { throw 'No public iperf3 endpoint could be pinned.' }
    @($selected)
}

function Expand-WarpBenchSafeZip {
    param([string]$Archive, [string]$Destination, [string[]]$RequiredFiles)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $root = [IO.Path]::GetFullPath($Destination).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    $seen = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    try {
        foreach ($entry in $zip.Entries) {
            if ([string]::IsNullOrEmpty($entry.Name)) { continue }
            if ($entry.FullName -match '^(?:[/\\]|[A-Za-z]:)' -or @($entry.FullName -split '[/\\]') -contains '..') { throw 'Dependency ZIP contains an unsafe path.' }
            $output = [IO.Path]::GetFullPath((Join-Path $Destination $entry.FullName))
            if (-not $output.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { throw 'Dependency ZIP contains an unsafe path.' }
            if (-not $seen.Add($output)) { throw 'Dependency ZIP contains a duplicate path.' }
            $parent = Split-Path -Parent $output
            if (-not (Test-Path -LiteralPath $parent)) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $output, $true)
        }
    } finally { $zip.Dispose() }
    foreach ($required in $RequiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $Destination $required) -PathType Leaf)) { throw "Dependency ZIP lacks required file $required." }
    }
}

function Get-WarpBenchIperf {
    param([string]$TemporaryDirectory)
    $command = Get-Command iperf3.exe -ErrorAction SilentlyContinue
    if (-not $command) { $command = Get-Command iperf3 -ErrorAction SilentlyContinue }
    if ($command) {
        $versionText = @(& $command.Source --version 2>&1) -join ' '
        $version = if ($versionText -match 'iperf\s+(3\.\d+(?:\.\d+)?)') { $matches[1] } else { $null }
        $helpText = @(& $command.Source --help 2>&1) -join ' '
        if ($LASTEXITCODE -eq 0 -and $version -and $helpText -match '--json-stream' -and $helpText -match '(?m)(?:^|\s)-R(?:,|\s)' -and $helpText -match '--get-server-output') {
            return [ordered]@{ path = $command.Source; version = $version; provisioning = 'system' }
        }
        Write-Warning 'Installed iperf3 lacks required JSON or reverse-mode capability; using the approved temporary build.'
    }
    $artifact = $script:IperfArtifactJson | ConvertFrom-Json
    if ($artifact.use_status -ne 'approved' -or $artifact.os -ne 'windows' -or $artifact.architecture -ne 'x86_64') { throw 'Embedded iperf3 artifact is not approved for Windows x64.' }
    $archive = Join-Path $TemporaryDirectory 'iperf3.zip'
    $extract = Join-Path $TemporaryDirectory 'iperf3'
    [IO.Directory]::CreateDirectory($extract) | Out-Null
    Write-Host "Downloading approved iperf3 $($artifact.version) dependency..."
    $webClient = New-Object Net.WebClient
    $previousProtocol = [Net.ServicePointManager]::SecurityProtocol
    try {
        [Net.ServicePointManager]::SecurityProtocol = $previousProtocol -bor [Net.SecurityProtocolType]::Tls12
        $webClient.DownloadFile([string]$artifact.url, $archive)
    }
    finally {
        [Net.ServicePointManager]::SecurityProtocol = $previousProtocol
        $webClient.Dispose()
    }
    $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $artifact.sha256) { throw 'Downloaded iperf3 archive failed SHA-256 verification.' }
    Expand-WarpBenchSafeZip $archive $extract @($artifact.required_files)
    $path = Join-Path $extract ([string]$artifact.executable_path)
    $versionText = @(& $path --version 2>&1) -join ' '
    if ($LASTEXITCODE -ne 0 -or $versionText -notmatch 'iperf\s+3\.21(?:\.|\s)') { throw 'Downloaded iperf3 failed its version self-check.' }
    [ordered]@{ path = $path; version = '3.21.0'; provisioning = 'temporary_download' }
}

function Invoke-WarpBenchPingSeries {
    param([string]$Address, [int]$Count, [int]$IntervalMs, [int]$TimeoutMs, [int]$PayloadBytes, [scriptblock]$ContinueWhile)
    $samples = @(); $watch = [Diagnostics.Stopwatch]::StartNew(); $ping = New-Object Net.NetworkInformation.Ping
    $buffer = New-Object byte[] $PayloadBytes
    try {
        for ($sequence = 1; $sequence -le $Count; $sequence++) {
            if ($ContinueWhile -and -not (& $ContinueWhile)) { break }
            $elapsed = [int][Math]::Floor($watch.Elapsed.TotalMilliseconds)
            try {
                $reply = $ping.Send($Address, $TimeoutMs, $buffer)
                if ($reply.Status -eq [Net.NetworkInformation.IPStatus]::Success) {
                    $samples += [ordered]@{ sequence = $sequence; elapsed_ms = $elapsed; outcome = 'reply'; rtt_us = [int64]$reply.RoundtripTime * 1000; error_code = $null }
                } elseif ($reply.Status -in @([Net.NetworkInformation.IPStatus]::TimedOut, [Net.NetworkInformation.IPStatus]::TtlExpired, [Net.NetworkInformation.IPStatus]::TtlReassemblyTimeExceeded)) {
                    $samples += [ordered]@{ sequence = $sequence; elapsed_ms = $elapsed; outcome = 'timeout'; rtt_us = $null; error_code = $null }
                } else {
                    $samples += [ordered]@{ sequence = $sequence; elapsed_ms = $elapsed; outcome = 'local_error'; rtt_us = $null; error_code = 'PING_' + ([string]$reply.Status).ToUpperInvariant() }
                }
            } catch {
                $samples += [ordered]@{ sequence = $sequence; elapsed_ms = $elapsed; outcome = 'local_error'; rtt_us = $null; error_code = 'PING_LOCAL_ERROR' }
            }
            $targetTime = $sequence * $IntervalMs
            $sleep = $targetTime - [int]$watch.ElapsedMilliseconds
            if ($sleep -gt 0 -and $sequence -lt $Count) { Start-Sleep -Milliseconds $sleep }
        }
    } finally { $ping.Dispose(); $watch.Stop() }
    @($samples)
}

function Invoke-WarpBenchTrace {
    param([string[]]$ExpectedStates, [string]$Id, [string]$Position)
    try {
        $address = @([Net.Dns]::GetHostAddresses('www.cloudflare.com') | Where-Object { $_.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork })[0]
        if ($null -eq $address) { throw 'Cloudflare has no resolvable IPv4 address.' }
        $client = New-Object Net.Sockets.TcpClient([Net.Sockets.AddressFamily]::InterNetwork)
        try {
            $connect = $client.BeginConnect($address, 443, $null, $null)
            if (-not $connect.AsyncWaitHandle.WaitOne(10000, $false)) { throw 'Cloudflare IPv4 connection timed out.' }
            $client.EndConnect($connect); $client.ReceiveTimeout = 10000; $client.SendTimeout = 10000
            $tls = New-Object Net.Security.SslStream($client.GetStream(), $false)
            try {
                $tls.AuthenticateAsClient('www.cloudflare.com')
                $requestText = "GET /cdn-cgi/trace HTTP/1.1`r`nHost: www.cloudflare.com`r`nUser-Agent: warp-bench/$script:WarpBenchVersion`r`nConnection: close`r`n`r`n"
                $requestBytes = [Text.Encoding]::ASCII.GetBytes($requestText)
                $tls.Write($requestBytes, 0, $requestBytes.Length); $tls.Flush()
                $reader = New-Object IO.StreamReader($tls, [Text.Encoding]::ASCII, $false, 4096, $true)
                try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }
            } finally { $tls.Dispose() }
        } finally { $client.Dispose() }
        ConvertFrom-WarpBenchTrace $body $ExpectedStates $Id $Position
    } catch {
        [ordered]@{
            id = $Id; session_id = 'session-1'; position = $Position; checked_at = Get-WarpBenchUtc
            request_status = 'failed'; expected_warp_states = @($ExpectedStates); observed_warp_state = 'unknown'; colo = $null
            match = 'indeterminate'; evidence_scope = 'cloudflare_https_trace'
            error = New-WarpBenchError 'TRACE_UNREACHABLE' 'route_verification' $true 'Cloudflare trace could not be reached over IPv4.'
        }
    }
}

function Write-WarpBenchCheckpoint {
    param($State, [string]$Path)
    $State.run.updated_at = if ($State.run.ended_at) { $State.run.ended_at } else { Get-WarpBenchUtc }
    $json = $State | ConvertTo-Json -Depth 20
    $temporary = "$Path.tmp"
    $backup = "$Path.bak"
    [IO.File]::WriteAllText($temporary, $json + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
        [IO.File]::Replace($temporary, $Path, $backup)
        Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
    }
    else { [IO.File]::Move($temporary, $Path) }
}

function New-WarpBenchState {
    param([string]$Profile, [object[]]$Targets, [string]$IperfVersion, [string]$IperfProvisioning, [string]$RunId, [string]$StartedAt)
    $configuration = Get-WarpBenchProfile $Profile
    $measurements = @()
    foreach ($phase in @('baseline', 'warp')) {
        foreach ($target in $Targets) {
            $measurements += [ordered]@{
                id = "$phase-$($target.id)-idle"; phase_id = $phase; target_id = $target.id; session_id = 'session-1'; kind = 'idle_ping'
                status = 'pending'; started_at = $null; ended_at = $null; endpoint = $target.endpoint; settings = $configuration.idle_ping
                samples = @(); summary = $null; error = $null
            }
            foreach ($direction in @('download', 'upload')) {
                for ($repetition = 1; $repetition -le $configuration.tcp.repetitions_per_direction; $repetition++) {
                    $measurements += [ordered]@{
                        id = "$phase-$($target.id)-$direction-$repetition"; phase_id = $phase; target_id = $target.id; kind = 'tcp_transfer'
                        status = 'pending'; started_at = $null; ended_at = $null; endpoint = $target.endpoint
                        settings = [ordered]@{ protocol = 'tcp'; direction = $direction; repetition = $repetition; duration_seconds = $configuration.tcp.duration_seconds; streams = 1 }
                        selected_attempt = $null; attempts = @(); error = $null
                    }
                }
            }
        }
    }
    [ordered]@{
        schema_version = '1.0.0'
        run = [ordered]@{ id = $RunId; runner_version = $script:WarpBenchVersion; target_manifest_version = '1.0.0'; profile_complete = $false; comparison_valid = $false; started_at = $StartedAt; updated_at = $StartedAt; ended_at = $null; status = 'in_progress' }
        environment = [ordered]@{
            os = [ordered]@{ family = 'windows'; name = 'Windows'; version = [Environment]::OSVersion.Version.ToString() }; architecture = 'x86_64'
            runner = [ordered]@{ implementation = 'powershell'; version = $script:WarpBenchVersion }
            tools = @(
                [ordered]@{ name = 'ping'; version = [Environment]::Version.ToString(); provisioning = 'system'; capabilities = @('ipv4', 'rtt_microseconds') },
                [ordered]@{ name = 'iperf3'; version = $IperfVersion; provisioning = $IperfProvisioning; capabilities = @('json', 'reverse', 'intervals') }
            )
        }
        configuration = $configuration
        privacy = [ordered]@{ policy_version = '1.0.0'; sanitization_applied = $true; destination_ipv4_retained = $true; client_address_retained = $false; local_identity_retained = $false; raw_tool_output_retained = $false }
        targets = @($Targets)
        sessions = @([ordered]@{ id = 'session-1'; reason = 'initial'; previous_session_id = $null; gap_seconds = $null; route_reverified = $false; started_at = $StartedAt; ended_at = $null; status = 'running' })
        phases = @(
            [ordered]@{ id = 'baseline'; ordinal = 1; requested_route = 'direct'; status = 'pending'; started_at = $null; ended_at = $null; verification_disposition = 'not_performed'; verification_checks = @() },
            [ordered]@{ id = 'warp'; ordinal = 2; requested_route = 'warp'; status = 'pending'; started_at = $null; ended_at = $null; verification_disposition = 'not_performed'; verification_checks = @() }
        )
        measurements = @($measurements); diagnostics = @()
    }
}

function Add-WarpBenchDiagnostic {
    param($State, [string]$Severity, [string]$Code, [string]$Message, [AllowNull()][string]$PhaseId, [AllowNull()][string]$TargetId, [AllowNull()][string]$MeasurementId)
    $State.diagnostics += [ordered]@{ timestamp = Get-WarpBenchUtc; severity = $Severity; code = $Code; message = Protect-WarpBenchText $Message; phase_id = $PhaseId; target_id = $TargetId; measurement_id = $MeasurementId }
}

function Update-WarpBenchRunFlags {
    param($State)
    $complete = $true
    foreach ($measurement in $State.measurements) {
        if ($measurement.status -ne 'completed') { $complete = $false; break }
        if ($measurement.kind -eq 'tcp_transfer') {
            $selected = @($measurement.attempts | Where-Object { $_.number -eq $measurement.selected_attempt })
            if ($selected.Count -ne 1 -or $selected[0].loaded_ping.status -ne 'completed' -or @($selected[0].intervals).Count -eq 0) { $complete = $false; break }
        }
    }
    $State.run.profile_complete = $complete
    $comparable = $false
    if (@($State.phases | Where-Object { $_.status -eq 'completed' -and $_.verification_disposition -eq 'verified' }).Count -eq 2) {
        foreach ($baseline in @($State.measurements | Where-Object { $_.phase_id -eq 'baseline' -and $_.status -eq 'completed' })) {
            if (@($State.measurements | Where-Object {
                $_.phase_id -eq 'warp' -and $_.status -eq 'completed' -and $_.target_id -eq $baseline.target_id -and
                $_.kind -eq $baseline.kind -and $_.endpoint.ipv4 -eq $baseline.endpoint.ipv4 -and
                $_.endpoint.iperf_port -eq $baseline.endpoint.iperf_port -and
                ($_.settings | ConvertTo-Json -Compress) -eq ($baseline.settings | ConvertTo-Json -Compress)
            }).Count -gt 0) { $comparable = $true; break }
        }
    }
    $State.run.comparison_valid = $comparable
}

function Invoke-WarpBenchTransfer {
    param($State, $Measurement, [string]$IperfPath, [string]$CheckpointPath, [string]$WorkingDirectory)
    $Measurement.status = 'running'; $Measurement.started_at = Get-WarpBenchUtc
    Write-WarpBenchCheckpoint $State $CheckpointPath
    $maxAttempts = 1 + $State.configuration.timing.server_busy_retries
    for ($number = 1; $number -le $maxAttempts; $number++) {
        $process = $null
        if ($number -gt 1) { Start-Sleep -Seconds $State.configuration.timing.retry_backoff_seconds[$number - 2] }
        $started = Get-WarpBenchUtc
        $stdout = Join-Path $WorkingDirectory "iperf-$([Guid]::NewGuid().ToString('N')).json"
        $stderr = Join-Path $WorkingDirectory "iperf-$([Guid]::NewGuid().ToString('N')).err"
        $arguments = @('-c', $Measurement.endpoint.ipv4, '-p', [string]$Measurement.endpoint.iperf_port, '-t', [string]$Measurement.settings.duration_seconds, '-P', '1', '-4', '--json-stream', '--forceflush', '--get-server-output')
        if ($Measurement.settings.direction -eq 'download') { $arguments += '-R' }
        $attempt = [ordered]@{ number = $number; session_id = 'session-1'; status = 'running'; started_at = $started; ended_at = $null; sender = $null; receiver = $null; intervals = @(); loaded_ping = $null; error = $null }
        $Measurement.attempts += $attempt
        Write-WarpBenchCheckpoint $State $CheckpointPath
        try {
            $process = Start-Process -FilePath $IperfPath -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
            $startDeadline = [DateTime]::UtcNow.AddSeconds(10)
            $transferStarted = $false
            while (-not $process.HasExited -and [DateTime]::UtcNow -lt $startDeadline) {
                try {
                    if ((Test-Path -LiteralPath $stdout) -and ([IO.File]::ReadAllText($stdout) -match '(?m)^\s*\{"event":"start"')) { $transferStarted = $true; break }
                } catch [IO.IOException] { }
                Start-Sleep -Milliseconds 50
            }
            if (-not $transferStarted) { throw 'iperf3 did not enter its measured transfer state.' }
            $transferDeadline = [DateTime]::UtcNow.AddSeconds($Measurement.settings.duration_seconds + 30)
            $loadedSamples = Invoke-WarpBenchPingSeries $Measurement.endpoint.ipv4 10000 $State.configuration.loaded_ping.interval_ms $State.configuration.loaded_ping.timeout_ms $State.configuration.loaded_ping.payload_bytes { -not $process.HasExited -and [DateTime]::UtcNow -lt $transferDeadline }
            if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit(); throw 'iperf3 exceeded the transfer deadline.' }
            $process.WaitForExit()
            if ($process.ExitCode -ne 0) { throw 'iperf3 transfer failed or the public server was busy.' }
            $parsed = ConvertFrom-WarpBenchIperfJson ([IO.File]::ReadAllText($stdout)) $Measurement.settings.direction
            $loadedSamples = @($loadedSamples | Where-Object { $_.elapsed_ms -lt $parsed.receiver.duration_ms })
            $loadedSummary = Get-WarpBenchPingSummary @($loadedSamples)
            if ($loadedSummary.probes_sent -eq 0) {
                $pingError = New-WarpBenchError 'PING_UNAVAILABLE' 'local_system' $false 'The client could not send loaded-latency probes.'
                $attempt.loaded_ping = [ordered]@{ status = 'unavailable'; samples = @($loadedSamples); summary = $loadedSummary; error = $pingError }
                Add-WarpBenchDiagnostic $State 'warning' 'PING_UNAVAILABLE' 'Loaded latency is unavailable because ICMP probes could not be sent.' $Measurement.phase_id $Measurement.target_id $Measurement.id
            }
            else { $attempt.loaded_ping = [ordered]@{ status = 'completed'; samples = @($loadedSamples); summary = $loadedSummary; error = $null } }
            $attempt.sender = $parsed.sender; $attempt.receiver = $parsed.receiver; $attempt.intervals = @($parsed.intervals)
            $attempt.status = 'completed'; $attempt.ended_at = Get-WarpBenchUtc
            $Measurement.selected_attempt = $number; $Measurement.status = 'completed'; $Measurement.ended_at = $attempt.ended_at; $Measurement.error = $null
            Write-WarpBenchCheckpoint $State $CheckpointPath
            return
        } catch {
            $attempt.status = 'failed'; $attempt.ended_at = Get-WarpBenchUtc
            $attempt.error = New-WarpBenchError 'IPERF_TRANSFER_FAILED' 'remote_server' $true 'The public iperf3 server did not produce a usable transfer result.'
            if ($null -eq $attempt.loaded_ping) { $attempt.loaded_ping = $null }
            if ($number -eq $maxAttempts) {
                $Measurement.status = 'failed'; $Measurement.ended_at = $attempt.ended_at; $Measurement.selected_attempt = $null; $Measurement.error = $attempt.error
                Add-WarpBenchDiagnostic $State 'warning' 'IPERF_TRANSFER_FAILED' 'Transfer result is unavailable after bounded retries.' $Measurement.phase_id $Measurement.target_id $Measurement.id
            }
            Write-WarpBenchCheckpoint $State $CheckpointPath
        } finally {
            if ($process -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
            if ($process) { $process.Dispose() }
            Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-WarpBenchPhase {
    param($State, [string]$PhaseId, [string]$IperfPath, [string]$CheckpointPath, [string]$WorkingDirectory)
    $phase = @($State.phases | Where-Object id -eq $PhaseId)[0]
    $phase.status = 'running'; $phase.started_at = Get-WarpBenchUtc
    Write-WarpBenchCheckpoint $State $CheckpointPath
    $targetNumber = 0
    foreach ($target in $State.targets) {
        $targetNumber++
        Write-Host "[$PhaseId | $targetNumber/$($State.targets.Count) | $($target.label)] Idle ping"
        $idle = @($State.measurements | Where-Object { $_.phase_id -eq $PhaseId -and $_.target_id -eq $target.id -and $_.kind -eq 'idle_ping' })[0]
        $idle.status = 'running'; $idle.started_at = Get-WarpBenchUtc; Write-WarpBenchCheckpoint $State $CheckpointPath
        $idle.samples = @(Invoke-WarpBenchPingSeries $target.endpoint.ipv4 $idle.settings.requested_probes $idle.settings.interval_ms $idle.settings.timeout_ms $idle.settings.payload_bytes)
        $idle.summary = Get-WarpBenchPingSummary @($idle.samples); $idle.ended_at = Get-WarpBenchUtc
        if ($idle.summary.probes_sent -eq 0) {
            $idle.status = 'failed'; $idle.error = New-WarpBenchError 'PING_UNAVAILABLE' 'local_system' $false 'The client could not send ICMP probes.'
            Add-WarpBenchDiagnostic $State 'warning' 'PING_UNAVAILABLE' 'Idle latency is unavailable because ICMP probes could not be sent.' $PhaseId $target.id $idle.id
        }
        else { $idle.status = 'completed'; $idle.error = $null }
        Write-WarpBenchCheckpoint $State $CheckpointPath
        foreach ($direction in @('download', 'upload')) {
            for ($repetition = 1; $repetition -le $State.configuration.tcp.repetitions_per_direction; $repetition++) {
                Write-Host "[$PhaseId | $targetNumber/$($State.targets.Count) | $($target.label)] $direction repetition $repetition/$($State.configuration.tcp.repetitions_per_direction)"
                $measurement = @($State.measurements | Where-Object { $_.phase_id -eq $PhaseId -and $_.target_id -eq $target.id -and $_.kind -eq 'tcp_transfer' -and $_.settings.direction -eq $direction -and $_.settings.repetition -eq $repetition })[0]
                Invoke-WarpBenchTransfer $State $measurement $IperfPath $CheckpointPath $WorkingDirectory
                Start-Sleep -Seconds $State.configuration.timing.between_transfers_seconds
            }
        }
        if ($targetNumber -lt $State.targets.Count) { Start-Sleep -Seconds $State.configuration.timing.between_targets_seconds }
    }
    # A phase reached its terminal plan even when individual public servers failed.
    $phase.status = 'completed'
    $phase.ended_at = Get-WarpBenchUtc
    Write-WarpBenchCheckpoint $State $CheckpointPath
}

function Confirm-WarpBenchRoute {
    param($State, [string]$PhaseId, [string]$Position, [string]$CheckpointPath)
    $phase = @($State.phases | Where-Object id -eq $PhaseId)[0]
    $expected = if ($PhaseId -eq 'baseline') { @('off') } else { @('on', 'plus') }
    while ($true) {
        $id = "$PhaseId-$Position-$($phase.verification_checks.Count + 1)"
        $check = Invoke-WarpBenchTrace $expected $id $Position
        $phase.verification_checks += $check; Write-WarpBenchCheckpoint $State $CheckpointPath
        if ($check.match -eq 'matched') { return 'verified' }
        Write-Warning "Route check was $($check.match) (observed WARP: $($check.observed_warp_state)). Check policy routing, connection tracking, and FastTrack."
        $answer = (Read-Host '[R]etry, [S]ave and exit, or [C]ontinue unverified').Trim().ToLowerInvariant()
        if ($answer -eq 's') { return 'save' }
        if ($answer -eq 'c') { return 'continued' }
    }
}

function Complete-WarpBenchVerification {
    param($State, [string]$PhaseId)
    $phase = @($State.phases | Where-Object id -eq $PhaseId)[0]
    $positions = @($phase.verification_checks | Where-Object match -eq 'matched' | ForEach-Object position)
    $phase.verification_disposition = if ('before_phase' -in $positions -and 'after_phase' -in $positions) { 'verified' } else { 'unverified_continued' }
}

function Stop-WarpBenchState {
    param($State, [string]$Status, [string]$CheckpointPath)
    $now = Get-WarpBenchUtc
    foreach ($measurement in @($State.measurements | Where-Object status -eq 'running')) {
        $measurement.status = 'interrupted'; $measurement.ended_at = $now; $measurement.error = New-WarpBenchError 'USER_CANCELLED' 'user' $true 'The benchmark was interrupted.'
        if ($measurement.kind -eq 'tcp_transfer') {
            foreach ($attempt in @($measurement.attempts | Where-Object status -eq 'running')) { $attempt.status = 'interrupted'; $attempt.ended_at = $now; $attempt.error = $measurement.error }
        }
    }
    foreach ($phase in @($State.phases | Where-Object status -eq 'running')) { $phase.status = 'interrupted'; $phase.ended_at = $now; if ($phase.verification_disposition -eq 'not_performed') { $phase.verification_disposition = 'unverified_continued' } }
    foreach ($phase in @($State.phases | Where-Object { $_.status -eq 'completed' -and $_.verification_disposition -eq 'not_performed' })) { $phase.verification_disposition = 'unverified_continued' }
    $State.sessions[0].status = if ($Status -eq 'interrupted') { 'interrupted' } else { 'completed' }; $State.sessions[0].ended_at = $now
    $State.run.status = $Status; $State.run.ended_at = $now
    Update-WarpBenchRunFlags $State
    Write-WarpBenchCheckpoint $State $CheckpointPath
}

function Show-WarpBenchSummary {
    param($State, [string]$Path)
    Write-Host "`nBenchmark status: $($State.run.status)"
    foreach ($target in $State.targets) {
        $line = @($target.label)
        foreach ($phaseId in @('baseline', 'warp')) {
            $idle = @($State.measurements | Where-Object { $_.phase_id -eq $phaseId -and $_.target_id -eq $target.id -and $_.kind -eq 'idle_ping' -and $_.status -eq 'completed' })
            $down = @($State.measurements | Where-Object { $_.phase_id -eq $phaseId -and $_.target_id -eq $target.id -and $_.kind -eq 'tcp_transfer' -and $_.settings.direction -eq 'download' -and $_.status -eq 'completed' })
            $median = if ($idle.Count) { "$($idle[0].summary.rtt_median_ms) ms" } else { 'n/a' }
            $rates = @($down | ForEach-Object {
                $measurement = $_
                $attempt = @($measurement.attempts | Where-Object { $_.number -eq $measurement.selected_attempt })[0]
                [Math]::Round($attempt.receiver.bits_per_second / 1000000.0, 1)
            })
            $rate = if ($rates.Count) { "$([Math]::Round((($rates | Measure-Object -Average).Average), 1)) Mbps" } else { 'n/a' }
            $line += "$phaseId median RTT $median, download $rate"
        }
        Write-Host ($line -join ' | ')
    }
    Write-Host "Results: $Path"
}

function Invoke-WarpBenchmark {
    [CmdletBinding()]
    param()
    $temporaryDirectory = $null; $state = $null; $checkpointPath = $null; $finalized = $false
    try {
        if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) { throw 'This runner supports Windows x64 only.' }
        if (-not [Environment]::Is64BitOperatingSystem) { throw 'This runner requires Windows x64.' }
        Write-Host "WARP vs ISP Benchmark $script:WarpBenchVersion"
        Write-Host 'This test can saturate the connection. Pause downloads and use wired Ethernet when possible.'
        do { $profileAnswer = (Read-Host 'Select [Q]uick (7-10 min, ~10.5 GB) or [E]xtended (30-40 min, ~47.3 GB)').Trim().ToLowerInvariant() } until ($profileAnswer -in @('q', 'e'))
        $profile = if ($profileAnswer -eq 'e') { 'extended' } else { 'quick' }
        $defaultResults = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'warp-benchmark-results'
        $resultsRoot = Read-Host "Results directory [$defaultResults]"
        if ([string]::IsNullOrWhiteSpace($resultsRoot)) { $resultsRoot = $defaultResults }
        [IO.Directory]::CreateDirectory($resultsRoot) | Out-Null
        $probePath = Join-Path $resultsRoot ".write-test-$([Guid]::NewGuid().ToString('N'))"
        [IO.File]::WriteAllText($probePath, 'test'); Remove-Item -LiteralPath $probePath -Force
        $temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) "warp-bench-$([Guid]::NewGuid().ToString('N'))"
        [IO.Directory]::CreateDirectory($temporaryDirectory) | Out-Null
        $iperf = Get-WarpBenchIperf $temporaryDirectory
        $manifest = $script:TargetManifestJson | ConvertFrom-Json
        $targets = @(Resolve-WarpBenchTargets $manifest)
        $started = Get-WarpBenchUtc; $runId = [Guid]::NewGuid().ToString('N')
        $directoryName = "warp-benchmark-$($started.Substring(0, 19).Replace(':', '').Replace('-', ''))Z-$($runId.Substring(0, 8))"
        $runDirectory = Join-Path $resultsRoot $directoryName; [IO.Directory]::CreateDirectory($runDirectory) | Out-Null
        $checkpointPath = Join-Path $runDirectory 'results.json'
        $state = New-WarpBenchState $profile $targets $iperf.version $iperf.provisioning $runId $started
        Write-WarpBenchCheckpoint $state $checkpointPath
        Write-Host "Pinned $($targets.Count) target(s). Results will be checkpointed to $checkpointPath"
        Read-Host 'Confirm normal direct ISP routing, then press Enter' | Out-Null
        $baselineBefore = Confirm-WarpBenchRoute $state 'baseline' 'before_phase' $checkpointPath
        if ($baselineBefore -eq 'save') { Stop-WarpBenchState $state 'failed' $checkpointPath; $finalized = $true; Show-WarpBenchSummary $state $checkpointPath; return }
        $state.sessions[0].route_reverified = $baselineBefore -eq 'verified'
        Invoke-WarpBenchPhase $state 'baseline' $iperf.path $checkpointPath $temporaryDirectory
        $baselineAfter = Confirm-WarpBenchRoute $state 'baseline' 'after_phase' $checkpointPath
        Complete-WarpBenchVerification $state 'baseline'; Write-WarpBenchCheckpoint $state $checkpointPath
        if ($baselineAfter -eq 'save' -or (Read-Host 'Continue with WARP phase? [Y/n]').Trim().ToLowerInvariant() -eq 'n') {
            Stop-WarpBenchState $state 'baseline_only' $checkpointPath; $finalized = $true; Show-WarpBenchSummary $state $checkpointPath; return
        }
        Read-Host 'Enable WARP policy routing for this client, then press Enter' | Out-Null
        Start-Sleep -Seconds $state.configuration.timing.route_settle_seconds
        $warpBefore = Confirm-WarpBenchRoute $state 'warp' 'before_phase' $checkpointPath
        if ($warpBefore -eq 'save') { Stop-WarpBenchState $state 'baseline_only' $checkpointPath; $finalized = $true; Show-WarpBenchSummary $state $checkpointPath; return }
        Invoke-WarpBenchPhase $state 'warp' $iperf.path $checkpointPath $temporaryDirectory
        [void](Confirm-WarpBenchRoute $state 'warp' 'after_phase' $checkpointPath)
        Complete-WarpBenchVerification $state 'warp'
        $now = Get-WarpBenchUtc; $state.sessions[0].status = 'completed'; $state.sessions[0].ended_at = $now
        Update-WarpBenchRunFlags $state
        $state.run.status = if ($state.run.profile_complete) { 'completed' } else { 'partial' }; $state.run.ended_at = $now
        Write-WarpBenchCheckpoint $state $checkpointPath; $finalized = $true
        Show-WarpBenchSummary $state $checkpointPath
    } catch {
        if ($state -and $checkpointPath) {
            Add-WarpBenchDiagnostic $state 'error' 'RUN_INTERRUPTED' 'The benchmark stopped unexpectedly; completed measurements remain checkpointed.' $null $null $null
            Stop-WarpBenchState $state 'interrupted' $checkpointPath; $finalized = $true
            Write-Warning "Benchmark interrupted. Checkpoint: $checkpointPath"
        } else { Write-Error (Protect-WarpBenchText $_.Exception.Message) }
    } finally {
        if ($state -and $checkpointPath -and -not $finalized) { Stop-WarpBenchState $state 'interrupted' $checkpointPath }
        if ($temporaryDirectory) { Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

if ($MyInvocation.InvocationName -ne '.') { Invoke-WarpBenchmark }
