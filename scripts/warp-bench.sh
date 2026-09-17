#!/usr/bin/env bash
# Self-contained Linux x86_64 and macOS 14+ WARP versus ISP benchmark runner.
set -o pipefail

WARP_BENCH_VERSION=0.3.0
WARP_BENCH_SOURCE_ONLY=${WARP_BENCH_SOURCE_ONLY:-0}
WARP_BENCH_JQ=${WARP_BENCH_JQ:-}
WARP_BENCH_JQ_PROVISIONING=${WARP_BENCH_JQ_PROVISIONING:-system}
WARP_BENCH_PREFLIGHT_TIMEOUT_SECONDS=${WARP_BENCH_PREFLIGHT_TIMEOUT_SECONDS:-2}
WARP_BENCH_TIMEOUT_GRACE_SECONDS=${WARP_BENCH_TIMEOUT_GRACE_SECONDS:-5}
WARP_BENCH_TEMP_ROOT=
WARP_BENCH_WORK_DIR=
WARP_BENCH_STATE_PATH=
WARP_BENCH_ACTIVE_PID=
WARP_BENCH_FINALIZED=0

# Release-time snapshots. Runtime never depends on repository manifests.
WARP_BENCH_TARGETS_JSON='{"schema_version":"1.0.0","manifest_version":"1.0.0","targets":[{"id":"id-indonesia-myrepublic","order":1,"enabled":true,"label":"Indonesia","country_code":"ID","city":null,"location_confidence":"unverified","endpoints":[{"id":"myrepublic-tangerang2","priority":1,"hostname":"speedtest.tangerang2.myrepublic.net.id","ports":[9201,9202,9203,9204,9205,9206,9207,9208,9209,9210,9211,9212,9213,9214,9215,9216,9217,9218,9219,9220,9221,9222,9223,9224,9225,9226,9227,9228,9229,9230,9231,9232,9233,9234,9235,9236,9237,9238,9239,9240],"verification_status":"partially_verified"},{"id":"biznet-indonesia","priority":2,"hostname":"iperf.biznetnetworks.com","ports":[5201,5202,5203],"verification_status":"unavailable"}]},{"id":"sg-singapore-ovh","order":2,"enabled":true,"label":"Singapore","country_code":"SG","city":"Singapore","location_confidence":"operator_documented","endpoints":[{"id":"ovh-singapore","priority":1,"hostname":"sgp.proof.ovh.net","ports":[5201,5202,5203,5204,5205,5206,5207,5208,5209,5210],"verification_status":"verified"},{"id":"leaseweb-singapore-1","priority":2,"hostname":"speedtest.sin1.sg.leaseweb.net","ports":[5201,5202,5203,5204,5205,5206,5207,5208,5209,5210],"verification_status":"unverified"}]},{"id":"jp-tokyo-leaseweb","order":3,"enabled":true,"label":"Tokyo","country_code":"JP","city":"Tokyo","location_confidence":"directory_listed","endpoints":[{"id":"leaseweb-tokyo-11","priority":1,"hostname":"speedtest.tyo11.jp.leaseweb.net","ports":[5201,5202,5203,5204,5205,5206,5207,5208,5209,5210],"verification_status":"verified"},{"id":"datacamp-tokyo","priority":2,"hostname":"89.187.160.1","ports":[5201],"verification_status":"unverified"}]},{"id":"nl-amsterdam-clouvider","order":4,"enabled":true,"label":"Amsterdam","country_code":"NL","city":"Amsterdam","location_confidence":"operator_documented","endpoints":[{"id":"clouvider-amsterdam","priority":1,"hostname":"ams.speedtest.clouvider.net","ports":[5200,5201,5202,5203,5204,5205,5206,5207,5208,5209],"verification_status":"verified"},{"id":"leaseweb-amsterdam-1","priority":2,"hostname":"speedtest.ams1.nl.leaseweb.net","ports":[5201,5202,5203,5204,5205,5206,5207,5208,5209,5210],"verification_status":"unverified"}]},{"id":"gb-london-clouvider","order":5,"enabled":true,"label":"London","country_code":"GB","city":"London","location_confidence":"operator_documented","endpoints":[{"id":"clouvider-london","priority":1,"hostname":"lon.speedtest.clouvider.net","ports":[5200,5201,5202,5203,5204,5205,5206,5207,5208,5209],"verification_status":"verified"},{"id":"leaseweb-london-12","priority":2,"hostname":"speedtest.lon12.uk.leaseweb.net","ports":[5201,5202,5203,5204,5205,5206,5207,5208,5209,5210],"verification_status":"unverified"}]},{"id":"us-los-angeles-clouvider","order":6,"enabled":true,"label":"Los Angeles","country_code":"US","city":"Los Angeles","location_confidence":"operator_documented","endpoints":[{"id":"clouvider-los-angeles","priority":1,"hostname":"la.speedtest.clouvider.net","ports":[5200,5201,5202,5203,5204,5205,5206,5207,5208,5209],"verification_status":"verified"},{"id":"leaseweb-los-angeles-12","priority":2,"hostname":"speedtest.lax12.us.leaseweb.net","ports":[5201,5202,5203,5204,5205,5206,5207,5208,5209,5210],"verification_status":"unverified"}]},{"id":"us-new-york-clouvider","order":7,"enabled":true,"label":"New York City","country_code":"US","city":"New York City","location_confidence":"operator_documented","endpoints":[{"id":"clouvider-new-york","priority":1,"hostname":"nyc.speedtest.clouvider.net","ports":[5200,5201,5202,5203,5204,5205,5206,5207,5208,5209],"verification_status":"verified"},{"id":"leaseweb-new-york-1","priority":2,"hostname":"speedtest.nyc1.us.leaseweb.net","ports":[5201,5202,5203,5204,5205,5206,5207,5208,5209,5210],"verification_status":"unverified"}]}]}'
WARP_BENCH_JQ_ARTIFACT_LINUX_X86_64='{"id":"jq-1.8.2-linux-x86_64","tool":"jq","version":"1.8.2","os":"linux","architecture":"x86_64","url":"https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-linux-amd64","sha256":"b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f","archive_format":"raw","executable_path":"jq","required_files":["jq"],"upstream_source":"https://github.com/jqlang/jq/tree/jq-1.8.2","provenance_urls":["https://github.com/jqlang/jq/releases/tag/jq-1.8.2","https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-attestation.json"],"build_provenance":"Official jq release; static Linux executable built and tested by the tagged GitHub Actions workflow.","license":"MIT AND BSD-2-Clause AND ICU","license_notice_urls":["https://github.com/jqlang/jq/blob/jq-1.8.2/COPYING"],"distribution_mode":"upstream_download","use_status":"approved","redistribution_status":"approved"}'
WARP_BENCH_JQ_ARTIFACT_MACOS_X86_64='{"id":"jq-1.8.2-macos-x86_64","tool":"jq","version":"1.8.2","os":"macos","architecture":"x86_64","url":"https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-macos-amd64","sha256":"e94b266e3c26690550006abe63152b782280f4e14374accdf04cbde844f00bc0","archive_format":"raw","executable_path":"jq","required_files":["jq"],"upstream_source":"https://github.com/jqlang/jq/tree/jq-1.8.2","provenance_urls":["https://github.com/jqlang/jq/releases/tag/jq-1.8.2","https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-attestation.json"],"build_provenance":"Official jq release built on macos-14; requires macOS 14 or newer and links only to Apple system libraries.","license":"MIT AND BSD-2-Clause AND ICU","license_notice_urls":["https://github.com/jqlang/jq/blob/jq-1.8.2/COPYING"],"distribution_mode":"upstream_download","use_status":"approved","redistribution_status":"approved"}'
WARP_BENCH_JQ_ARTIFACT_MACOS_AARCH64='{"id":"jq-1.8.2-macos-aarch64","tool":"jq","version":"1.8.2","os":"macos","architecture":"aarch64","url":"https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-macos-arm64","sha256":"2d75340ba57a4b4b4c8708a21c2dc8e958a48aaa8bba13b27f77f6e4c0eca07e","archive_format":"raw","executable_path":"jq","required_files":["jq"],"upstream_source":"https://github.com/jqlang/jq/tree/jq-1.8.2","provenance_urls":["https://github.com/jqlang/jq/releases/tag/jq-1.8.2","https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-attestation.json"],"build_provenance":"Official jq release built on macos-14; requires macOS 14 or newer and links only to Apple system libraries.","license":"MIT AND BSD-2-Clause AND ICU","license_notice_urls":["https://github.com/jqlang/jq/blob/jq-1.8.2/COPYING"],"distribution_mode":"upstream_download","use_status":"approved","redistribution_status":"approved"}'
WARP_BENCH_JQ_ARTIFACT=
WARP_BENCH_IPERF_ARTIFACT='{"id":"iperf3-3.21-linux-x86_64-userdocs","tool":"iperf3","version":"3.21.0","os":"linux","architecture":"x86_64","url":"https://github.com/userdocs/iperf3-static/releases/download/3.21/iperf3-amd64","sha256":"201cbaed73d4e4da72c44c9aee895a2d58c75f1d1a4d721137f4888f6b7f5016","archive_format":"raw","executable_path":"iperf3","required_files":["iperf3"],"upstream_source":"https://github.com/esnet/iperf/tree/3.21","provenance_urls":["https://github.com/userdocs/iperf3-static/releases/tag/3.21","https://github.com/userdocs/iperf3-static/attestations"],"build_provenance":"Community static musl build with GitHub attestation, but mutable release assets and moving toolchain/OpenSSL inputs.","license":"BSD-3-Clause AND Apache-2.0 AND MIT","license_notice_urls":["https://github.com/esnet/iperf/blob/3.21/LICENSE","https://github.com/userdocs/iperf3-static/blob/master/LICENSE.txt"],"distribution_mode":"upstream_download","use_status":"candidate","redistribution_status":"review_required"}'

wb_read() { local value; IFS= read -r value < /dev/tty || return 1; printf '%s' "$value"; }
wb_prompt() { printf '%s' "$1" > /dev/tty; wb_read; }
wb_jq() { "$WARP_BENCH_JQ" "$@"; }
wb_platform() {
  WARP_BENCH_OS=${WARP_BENCH_OS:-$(uname -s)}; WARP_BENCH_ARCH=${WARP_BENCH_ARCH:-$(uname -m)}
  case "$WARP_BENCH_OS/$WARP_BENCH_ARCH" in
    Linux/x86_64) WARP_BENCH_OS_FAMILY=linux; WARP_BENCH_ARCHITECTURE=x86_64 ;;
    Darwin/x86_64) WARP_BENCH_OS_FAMILY=macos; WARP_BENCH_ARCHITECTURE=x86_64 ;;
    Darwin/arm64|Darwin/aarch64) WARP_BENCH_OS_FAMILY=macos; WARP_BENCH_ARCHITECTURE=aarch64 ;;
    *) return 1 ;;
  esac
  if [[ $WARP_BENCH_OS_FAMILY == macos ]]; then
    WARP_BENCH_OS_VERSION=${WARP_BENCH_OS_VERSION:-$(sw_vers -productVersion 2>/dev/null || true)}
    [[ ${WARP_BENCH_OS_VERSION%%.*} -ge 14 ]] || return 1
  else WARP_BENCH_OS_VERSION=${WARP_BENCH_OS_VERSION:-$(uname -r)}; fi
}
wb_utc() { if [[ ${WARP_BENCH_OS_FAMILY:-linux} == macos ]]; then perl -MTime::HiRes=time -MPOSIX=strftime -e '$t=time; printf "%s.%06dZ\n",strftime("%Y-%m-%dT%H:%M:%S",gmtime($t)),($t-int($t))*1000000'; else date -u +%Y-%m-%dT%H:%M:%S.%6NZ; fi; }
wb_seconds_to_ms() { awk -v value="$1" 'BEGIN { printf "%.0f", value * 1000 }'; }
wb_uptime_ms() { local seconds; if [[ ${WARP_BENCH_OS_FAMILY:-linux} == macos ]]; then perl -MTime::HiRes=clock_gettime,CLOCK_MONOTONIC -e 'printf "%.0f",clock_gettime(CLOCK_MONOTONIC)*1000' 2>/dev/null; else read -r seconds _ < /proc/uptime; wb_seconds_to_ms "$seconds"; fi; }
wb_sha256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
wb_timeout() {
  local seconds=$1 grace=$WARP_BENCH_TIMEOUT_GRACE_SECONDS
  shift
  if [[ $WARP_BENCH_OS_FAMILY == linux ]]; then timeout --signal=TERM --kill-after="${grace}s" "$seconds" "$@"
  else
    # System Perl is capability-checked at startup. It stays as the active PID,
    # forwards TERM/INT to its child, and gives a TERM-resistant child a bounded grace.
    perl -MPOSIX=:sys_wait_h -e '
      $seconds=shift @ARGV; $grace=shift @ARGV; @command=@ARGV; $timed=0; $stopped=0;
      $child=fork; defined $child or exit 127;
      if (!$child) { exec @command or exit 127 }
      $SIG{ALRM}=sub { $timed=1 }; $SIG{TERM}=sub { $stopped=1 }; $SIG{INT}=sub { $stopped=1 };
      alarm $seconds; $result=0;
      while (!$timed && !$stopped) { $result=waitpid($child, WNOHANG); last if $result == $child; select undef, undef, undef, 0.05 }
      alarm 0;
      if ($result != $child && ($timed || $stopped)) {
        kill "TERM", $child; select undef, undef, undef, $grace;
        if (waitpid($child, WNOHANG) != $child) { kill "KILL", $child; waitpid($child, 0) }
      }
      exit 124 if $timed; exit 143 if $stopped;
      exit 127 if $result != $child; exit (($? & 127) ? 128 + ($? & 127) : $? >> 8);
    ' "$seconds" "$grace" "$@"
  fi
}
wb_select_jq_artifact() { case "$WARP_BENCH_OS_FAMILY/$WARP_BENCH_ARCHITECTURE" in linux/x86_64) WARP_BENCH_JQ_ARTIFACT=$WARP_BENCH_JQ_ARTIFACT_LINUX_X86_64; WARP_BENCH_JQ_URL=https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-linux-amd64; WARP_BENCH_JQ_SHA256=b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f ;; macos/x86_64) WARP_BENCH_JQ_ARTIFACT=$WARP_BENCH_JQ_ARTIFACT_MACOS_X86_64; WARP_BENCH_JQ_URL=https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-macos-amd64; WARP_BENCH_JQ_SHA256=e94b266e3c26690550006abe63152b782280f4e14374accdf04cbde844f00bc0 ;; macos/aarch64) WARP_BENCH_JQ_ARTIFACT=$WARP_BENCH_JQ_ARTIFACT_MACOS_AARCH64; WARP_BENCH_JQ_URL=https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-macos-arm64; WARP_BENCH_JQ_SHA256=2d75340ba57a4b4b4c8708a21c2dc8e958a48aaa8bba13b27f77f6e4c0eca07e ;; *) return 1 ;; esac; }

wb_redact() {
  local value=${1:-}
  value=${value//$'\n'/ }
  value=$(printf '%s' "$value" | sed -E \
    -e 's#([A-Za-z]:\\|\\\\|//)[^ ,;]+#[local-path]#g' \
    -e 's#(^|[[:space:]])/(tmp|var|home|Users|users|config|mnt)/[^ ,;]+#\1[local-path]#g' \
    -e 's#(^|[^0-9.])((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])([^0-9.]|$)#\1[address]\5#g' \
    -e 's#([[:xdigit:]]{0,4}:){2,7}[[:xdigit:]]{0,4}#[address]#g' \
    -e 's#[[:alnum:]._%+-]+@[[:alnum:].-]+\.[A-Za-z]{2,}#[identity]#g' \
    -e 's#DESKTOP-[A-Za-z0-9-]+#[host]#Ig')
  printf '%.300s' "$value"
}

wb_error() {
  wb_jq -cn --arg code "$1" --arg category "$2" --argjson retryable "$3" --arg message "$(wb_redact "$4")" \
    '{code:$code,category:$category,retryable:$retryable,message:$message}'
}

wb_profile() {
  local name=${1:-quick}
  if [[ $name == extended ]]; then
    wb_jq -cn '{profile:"extended",ip_version:4,idle_ping:{requested_probes:120,interval_ms:1000,timeout_ms:2000,payload_bytes:32},loaded_ping:{interval_ms:500,timeout_ms:1000,payload_bytes:32},tcp:{duration_seconds:15,repetitions_per_direction:3,streams:1,directions:["download","upload"]},timing:{route_settle_seconds:10,between_transfers_seconds:5,between_targets_seconds:10,server_busy_retries:2,retry_backoff_seconds:[5,10]}}'
  else
    wb_jq -cn '{profile:"quick",ip_version:4,idle_ping:{requested_probes:30,interval_ms:1000,timeout_ms:2000,payload_bytes:32},loaded_ping:{interval_ms:500,timeout_ms:1000,payload_bytes:32},tcp:{duration_seconds:10,repetitions_per_direction:1,streams:1,directions:["download","upload"]},timing:{route_settle_seconds:5,between_transfers_seconds:2,between_targets_seconds:3,server_busy_retries:2,retry_backoff_seconds:[5,10]}}'
  fi
}

wb_ping_summary() {
  wb_jq -c '
    def rr($x): if $x == null then null else (($x / 1000 * 1000 + 0.5 | floor) / 1000) end;
    . as $samples | [.[] | select(.outcome == "reply") | .rtt_us] | sort as $values
    | [$samples[] | select(.outcome == "reply")] | length as $replies
    | [$samples[] | select(.outcome == "timeout")] | length as $timeouts
    | [$samples[] | select(.outcome == "local_error")] | length as $local
    | ($values | length) as $count
    | (if $count == 0 then null else ($values | add) / $count end) as $mean
    | [range(1; $samples | length) as $i
        | select($samples[$i - 1].outcome == "reply" and $samples[$i].outcome == "reply" and $samples[$i].sequence == $samples[$i - 1].sequence + 1)
        | ($samples[$i].rtt_us - $samples[$i - 1].rtt_us) | fabs] as $adjacent
    | {probes_recorded:($samples|length),probes_sent:($replies+$timeouts),replies_received:$replies,timed_out:$timeouts,local_failures:$local,
       reply_loss_percent:(if ($replies+$timeouts)==0 then null else ((100*$timeouts/($replies+$timeouts)*1000000+0.5|floor)/1000000) end),
       rtt_min_ms:rr(if $count==0 then null else $values[0] end),rtt_mean_ms:rr($mean),
       rtt_median_ms:rr(if $count==0 then null elif $count%2==1 then $values[($count/2|floor)] else ($values[$count/2-1]+$values[$count/2])/2 end),
       rtt_p95_ms:rr(if $count==0 then null else $values[((0.95*$count)|ceil)-1] end),rtt_max_ms:rr(if $count==0 then null else $values[-1] end),
       rtt_stddev_ms:rr(if $count==0 then null else ([$values[] | (. - $mean) * (. - $mean)] | add / $count | sqrt) end),
       rtt_adjacent_mean_abs_diff_ms:rr(if ($adjacent|length)==0 then null else ($adjacent|add)/($adjacent|length) end)}'
}

wb_trace_parse() {
  local expected=$1 id=$2 position=$3 key value warp=unknown colo=null match=indeterminate
  while IFS='=' read -r key value; do
    case "$key" in
      warp) [[ $value == off || $value == on || $value == plus ]] && warp=$value ;;
      colo) [[ $value =~ ^[A-Z]{3}$ ]] && colo="\"$value\"" ;;
    esac
  done
  if [[ $warp != unknown ]]; then
    wb_jq -e --arg state "$warp" 'index($state) != null' <<<"$expected" >/dev/null && match=matched || match=mismatched
  fi
  wb_jq -cn --arg id "$id" --arg position "$position" --arg warp "$warp" --arg match "$match" --argjson colo "$colo" --argjson expected "$expected" --arg now "$(wb_utc)" \
    '{id:$id,session_id:"session-1",position:$position,checked_at:$now,request_status:"completed",expected_warp_states:$expected,observed_warp_state:$warp,colo:$colo,match:$match,evidence_scope:"cloudflare_https_trace",error:null}'
}

wb_trace() {
  local expected=$1 id=$2 position=$3 raw
  if raw=$(curl --fail --silent --show-error --ipv4 --connect-timeout 10 --max-time 15 --proto '=https' https://www.cloudflare.com/cdn-cgi/trace); then
    printf '%s\n' "$raw" | wb_trace_parse "$expected" "$id" "$position"
  else
    wb_jq -cn --arg id "$id" --arg position "$position" --argjson expected "$expected" --arg now "$(wb_utc)" \
      '{id:$id,session_id:"session-1",position:$position,checked_at:$now,request_status:"failed",expected_warp_states:$expected,observed_warp_state:"unknown",colo:null,match:"indeterminate",evidence_scope:"cloudflare_https_trace",error:{code:"TRACE_UNREACHABLE",category:"route_verification",retryable:true,message:"Cloudflare trace could not be reached over IPv4."}}'
  fi
}

wb_ping_adapter() {
  local address=$1 count=$2 interval=$3 timeout_ms=$4 payload=$5 process_id=${6:-}
  local sequence=1 series_start probe_start elapsed result rtt next minimum_next now sleep_ms
  command -v ping >/dev/null 2>&1 || return 2
  series_start=$(wb_uptime_ms)
  while (( sequence <= count )); do
    [[ -n $process_id ]] && ! kill -0 "$process_id" 2>/dev/null && break
    probe_start=$(wb_uptime_ms); elapsed=$((probe_start - series_start))
    if [[ $WARP_BENCH_OS_FAMILY == macos ]]; then result=$(LC_ALL=C ping -n -c 1 -W "$timeout_ms" -s "$payload" "$address" 2>&1)
    else result=$(LC_ALL=C ping -4 -n -c 1 -W "$(( (timeout_ms + 999) / 1000 ))" -s "$payload" "$address" 2>&1); fi
    if [[ $result =~ time[=\<]([0-9.]+) ]]; then
      rtt=$(awk -v value="${BASH_REMATCH[1]}" 'BEGIN { printf "%d", value * 1000 + 0.5 }')
      printf '{"sequence":%d,"elapsed_ms":%d,"outcome":"reply","rtt_us":%d,"error_code":null}\n' "$sequence" "$elapsed" "$rtt"
    elif [[ $result =~ [Rr]equest[[:space:]]timeout[[:space:]]for[[:space:]]icmp_seq || $result =~ [0-9]+(\.[0-9]+)?%[[:space:]]packet[[:space:]]loss || $result =~ timed[[:space:]]out || $result =~ no[[:space:]]answer ]]; then
      printf '{"sequence":%d,"elapsed_ms":%d,"outcome":"timeout","rtt_us":null,"error_code":null}\n' "$sequence" "$elapsed"
    else
      printf '{"sequence":%d,"elapsed_ms":%d,"outcome":"local_error","rtt_us":null,"error_code":"PING_LOCAL_ERROR"}\n' "$sequence" "$elapsed"
    fi
    ((sequence++)); (( sequence > count )) && break
    next=$((series_start + (sequence - 1) * interval)); minimum_next=$((probe_start + interval))
    (( next < minimum_next )) && next=$minimum_next
    while :; do
      now=$(wb_uptime_ms); sleep_ms=$((next - now)); (( sleep_ms <= 0 )) && break
      sleep "$(awk -v value="$sleep_ms" 'BEGIN { printf "%.3f", value / 1000 }')"
    done
  done
}

wb_normalize_iperf() {
  local direction=$1
  wb_jq -sc --arg direction "$direction" '
    def side($value):
      if $value == null or $value.bytes == null or ($value.seconds // 0) <= 0 then null
      else ([1,(($value.seconds * 1000 + 0.5) | floor)] | max) as $duration
        | ($value.bytes | floor) as $bytes
        | {bytes:$bytes,duration_ms:$duration,bits_per_second:(($bytes*8000/$duration+0.5)|floor),retransmits:($value.retransmits // null)} end;
    def document:
      if length == 1 and .[0].event == null then .[0]
      else ([.[]|select(.event=="end")]|if length==1 then .[0].data else error("iperf3 JSON stream lacks exactly one end event") end) as $end
        | {end:$end,intervals:[.[]|select(.event=="interval")|.data],server_output_json:([.[]|select(.event=="server_output_json")|.data]|last // null)} end;
    document as $doc
    | if $doc.error then error($doc.error) else . end
    | side($doc.end.sum_received) as $receiver
    | side($doc.end.sum_sent) as $sender
    | if $receiver == null then error("receiver statistics unavailable") else . end
    | (if $direction == "upload" and $doc.server_output_json != null
       then ($doc.server_output_json | if type=="string" then fromjson else . end).intervals
       elif $direction == "upload" then null else $doc.intervals end) as $source
    | if $source == null then {sender:$sender,receiver:$receiver,intervals:[{index:0,start_ms:0,end_ms:$receiver.duration_ms,receiver_bytes:$receiver.bytes,receiver_bits_per_second:$receiver.bits_per_second,sender_bits_per_second:null,retransmits:null,omitted:false}]}
      else reduce range(0; $source|length) as $raw_index
        ({items:[],end:0,bytes:0};
          ($source[$raw_index].sum // $source[$raw_index].streams[0]) as $sum
          | if $sum == null or $sum.bytes == null then error("receiver interval omitted its byte count") else . end
          | (.end) as $start
          | (if $raw_index == ($source|length)-1 then $receiver.duration_ms else ([0,(($sum.end*1000+0.5)|floor)]|max|[.,$receiver.duration_ms]|min) end) as $end
          | if $end <= $start then error("receiver interval has non-positive duration") else . end
          | ($sum.bytes|floor) as $bytes
          | .items += [{index:(.items|length),start_ms:$start,end_ms:$end,receiver_bytes:$bytes,receiver_bits_per_second:(($bytes*8000/($end-$start)+0.5)|floor),sender_bits_per_second:null,retransmits:($sum.retransmits//null),omitted:($sum.omitted//false)}]
          | .end=$end | if ($sum.omitted//false) then . else .bytes += $bytes end)
        | if (.items|length)==0 or .end != $receiver.duration_ms or .bytes != $receiver.bytes then error("receiver intervals do not cover receiver totals") else {sender:$sender,receiver:$receiver,intervals:.items} end
      end'
}

wb_checkpoint() {
  local path=$1 json=$2 temporary
  temporary="${path}.tmp"
  printf '%s\n' "$json" > "$temporary" || return 1
  wb_jq -e . "$temporary" >/dev/null || { rm -f "$temporary"; return 1; }
  mv -f "$temporary" "$path"
}

wb_state_apply() {
  local path=$1 filter=$2 now temporary
  shift 2; now=$(wb_utc); temporary="${path}.tmp"
  wb_jq "$@" --arg checkpoint_now "$now" "$filter | .run.updated_at = (.run.ended_at // \$checkpoint_now)" "$path" > "$temporary" || { rm -f "$temporary"; return 1; }
  wb_jq -e . "$temporary" >/dev/null || { rm -f "$temporary"; return 1; }
  mv -f "$temporary" "$path"
}

wb_new_state() {
  local profile=$1 targets=$2 iperf_version=$3 iperf_provisioning=$4 run_id=$5 started_at=$6
  local configuration jq_version ping_version os_name os_version
  configuration=$(wb_profile "$profile") || return 1
  jq_version=$(wb_jq --version | sed 's/^jq-//')
  if command -v ping >/dev/null 2>&1; then
    if [[ ${WARP_BENCH_OS_FAMILY:-linux} == macos ]]; then ping_version='BSD system ping'
    else ping_version=$(LC_ALL=C ping -V 2>&1 | sed -n '1p' || true); fi
  else ping_version=unavailable; fi
  ping_version=${ping_version:-unavailable}; ping_version=${ping_version:0:80}
  os_name=${WARP_BENCH_OS:-$(uname -s)}; os_version=${WARP_BENCH_OS_VERSION:-$(uname -r)}
  wb_jq -cn --arg version "$WARP_BENCH_VERSION" --arg run_id "$run_id" --arg started "$started_at" \
    --arg iperf_version "$iperf_version" --arg iperf_provisioning "$iperf_provisioning" --arg jq_version "$jq_version" --arg jq_provisioning "$WARP_BENCH_JQ_PROVISIONING" \
    --arg ping_version "$ping_version" --arg os_name "$os_name" --arg os_version "$os_version" --arg os_family "${WARP_BENCH_OS_FAMILY:-linux}" --arg architecture "${WARP_BENCH_ARCHITECTURE:-x86_64}" --argjson configuration "$configuration" --argjson targets "$targets" '
    ["baseline","warp"] as $phases
    | [$phases[] as $phase | $targets[] as $target |
       {id:([$phase,$target.id,"idle"]|join("-")),phase_id:$phase,target_id:$target.id,session_id:"session-1",kind:"idle_ping",status:"pending",started_at:null,ended_at:null,endpoint:$target.endpoint,settings:$configuration.idle_ping,samples:[],summary:null,error:null},
       ($configuration.tcp.directions[] as $direction | range(1;$configuration.tcp.repetitions_per_direction+1) as $repetition |
        {id:([$phase,$target.id,$direction,($repetition|tostring)]|join("-")),phase_id:$phase,target_id:$target.id,kind:"tcp_transfer",status:"pending",started_at:null,ended_at:null,endpoint:$target.endpoint,settings:{protocol:"tcp",direction:$direction,repetition:$repetition,duration_seconds:$configuration.tcp.duration_seconds,streams:1},selected_attempt:null,attempts:[],error:null})] as $measurements
    | {schema_version:"1.0.0",run:{id:$run_id,runner_version:$version,target_manifest_version:"1.0.0",profile_complete:false,comparison_valid:false,started_at:$started,updated_at:$started,ended_at:null,status:"in_progress"},
        environment:{os:{family:$os_family,name:$os_name,version:$os_version},architecture:$architecture,runner:{implementation:"bash",version:$version},tools:[
         {name:"ping",version:$ping_version,provisioning:"system",capabilities:["ipv4","rtt_microseconds"]},
         {name:"iperf3",version:$iperf_version,provisioning:$iperf_provisioning,capabilities:["json","reverse","intervals"]},
         {name:"jq",version:$jq_version,provisioning:$jq_provisioning,capabilities:["json"]}]},
       configuration:$configuration,privacy:{policy_version:"1.0.0",sanitization_applied:true,destination_ipv4_retained:true,client_address_retained:false,local_identity_retained:false,raw_tool_output_retained:false},targets:$targets,
       sessions:[{id:"session-1",reason:"initial",previous_session_id:null,gap_seconds:null,route_reverified:false,started_at:$started,ended_at:null,status:"running"}],
       phases:[{id:"baseline",ordinal:1,requested_route:"direct",status:"pending",started_at:null,ended_at:null,verification_disposition:"not_performed",verification_checks:[]},{id:"warp",ordinal:2,requested_route:"warp",status:"pending",started_at:null,ended_at:null,verification_disposition:"not_performed",verification_checks:[]}],measurements:$measurements,diagnostics:[]}'
}

wb_add_diagnostic() {
  local path=$1 severity=$2 code=$3 message=$4 phase=${5:-} target=${6:-} measurement=${7:-}
  wb_state_apply "$path" '.diagnostics += [{timestamp:$checkpoint_now,severity:$severity,code:$code,message:$message,phase_id:(if $phase=="" then null else $phase end),target_id:(if $target=="" then null else $target end),measurement_id:(if $measurement=="" then null else $measurement end)}]' \
    --arg severity "$severity" --arg code "$code" --arg message "$(wb_redact "$message")" --arg phase "$phase" --arg target "$target" --arg measurement "$measurement"
}

wb_finalize_state() {
  local path=$1 status=$2
  wb_state_apply "$path" '
    def interrupted_error: {code:"USER_CANCELLED",category:"user",retryable:true,message:"The benchmark was interrupted."};
    .measurements |= map(if .status=="running" then .status="interrupted" | .ended_at=$checkpoint_now | .error=interrupted_error
      | if .kind=="tcp_transfer" then .attempts |= map(if .status=="running" then .status="interrupted" | .ended_at=$checkpoint_now | .error=interrupted_error else . end) else . end else . end)
    | .phases |= map(if .status=="running" then .status="interrupted" | .ended_at=$checkpoint_now | if .verification_disposition=="not_performed" then .verification_disposition="unverified_continued" else . end
      elif .status=="completed" and .verification_disposition=="not_performed" then .verification_disposition="unverified_continued" else . end)
    | .sessions[0].status=(if $status=="interrupted" then "interrupted" else "completed" end) | .sessions[0].ended_at=$checkpoint_now
    | .run.profile_complete=([.measurements[] | (.status=="completed" and (if .kind=="idle_ping" then true else (.selected_attempt as $selected | any(.attempts[]; .number==$selected and .status=="completed" and .loaded_ping.status=="completed" and (.intervals|length)>0)) end))] | all)
    | . as $state | .run.comparison_valid=(
        ([.phases[]|select(.status=="completed" and .verification_disposition=="verified")|.id]|sort)==["baseline","warp"] and
        any(.measurements[];
          .phase_id=="baseline" and .status=="completed" and
          (. as $baseline | any($state.measurements[];
            .phase_id=="warp" and .status=="completed" and .target_id==$baseline.target_id and .kind==$baseline.kind and .endpoint==$baseline.endpoint and .settings==$baseline.settings))))
    | .run.status=(if $status=="auto" then (if .run.profile_complete then "completed" else "partial" end) else $status end)
    | .run.ended_at=$checkpoint_now' --arg status "$status"
}

wb_phase_start() {
  wb_state_apply "$1" '(.phases[]|select(.id==$phase)) |= (.status="running"|.started_at=$checkpoint_now)' --arg phase "$2"
}

wb_phase_end() {
  wb_state_apply "$1" '(.phases[]|select(.id==$phase)) |= (.status="completed"|.ended_at=$checkpoint_now)' --arg phase "$2"
}

wb_complete_verification() {
  wb_state_apply "$1" '(.phases[]|select(.id==$phase)) |= (.verification_disposition=(if ([.verification_checks[]|select(.match=="matched")|.position]|(index("before_phase")!=null and index("after_phase")!=null)) then "verified" else "unverified_continued" end))' --arg phase "$2"
}

wb_confirm_route() {
  local path=$1 phase=$2 position=$3 expected check id answer match observed
  [[ $phase == baseline ]] && expected='["off"]' || expected='["on","plus"]'
  while :; do
    id="$phase-$position-$(($(wb_jq --arg phase "$phase" '[.phases[]|select(.id==$phase)|.verification_checks|length][0]' "$path") + 1))"
    check=$(wb_trace "$expected" "$id" "$position") || return 1
    wb_state_apply "$path" '(.phases[]|select(.id==$phase).verification_checks) += [$check]' --arg phase "$phase" --argjson check "$check" || return 1
    match=$(wb_jq -r '.match' <<<"$check"); observed=$(wb_jq -r '.observed_warp_state' <<<"$check")
    [[ $match == matched ]] && { printf 'verified\n'; return; }
    printf 'Route check was %s (observed WARP: %s). Check policy routing, connection tracking, and FastTrack.\n' "$match" "$observed" > /dev/tty
    answer=$(wb_prompt '[R]etry, [S]ave and exit, or [C]ontinue unverified: ') || return 1
    case "$answer" in [Ss]*) printf 'save\n'; return;; [Cc]*) printf 'continued\n'; return;; esac
  done
}

wb_run_idle() {
  local path=$1 phase=$2 target=$3 id settings address samples summary started ended status error
  id="$phase-$target-idle"; settings=$(wb_jq -c --arg id "$id" '.measurements[]|select(.id==$id)|.settings' "$path")
  address=$(wb_jq -r --arg id "$id" '.measurements[]|select(.id==$id)|.endpoint.ipv4' "$path")
  wb_state_apply "$path" '(.measurements[]|select(.id==$id)) |= (.status="running"|.started_at=$checkpoint_now)' --arg id "$id" || return 1
  samples=$(wb_ping_adapter "$address" "$(wb_jq -r '.requested_probes' <<<"$settings")" "$(wb_jq -r '.interval_ms' <<<"$settings")" "$(wb_jq -r '.timeout_ms' <<<"$settings")" "$(wb_jq -r '.payload_bytes' <<<"$settings")" | wb_jq -sc '.')
  summary=$(wb_ping_summary <<<"$samples"); started=$(wb_jq -r --arg id "$id" '.measurements[]|select(.id==$id)|.started_at' "$path"); ended=$(wb_utc)
  if [[ $(wb_jq -r '.probes_sent' <<<"$summary") == 0 ]]; then
    status=failed; error=$(wb_error PING_UNAVAILABLE local_system false 'The client could not send ICMP probes.')
    wb_add_diagnostic "$path" warning PING_UNAVAILABLE 'Idle latency is unavailable because ICMP probes could not be sent.' "$phase" "$target" "$id"
  else status=completed; error=null; fi
  wb_state_apply "$path" '(.measurements[]|select(.id==$id)) |= (.status=$status|.ended_at=$ended|.samples=$samples|.summary=$summary|.error=$error)' \
    --arg id "$id" --arg status "$status" --arg ended "$ended" --argjson samples "$samples" --argjson summary "$summary" --argjson error "$error"
}

wb_wait_for_iperf_start() {
  local pid=$1 output=$2 count=0
  while kill -0 "$pid" 2>/dev/null && (( count < 200 )); do
    grep -q '"event"[[:space:]]*:[[:space:]]*"start"' "$output" 2>/dev/null && return 0
    sleep 0.05; ((count++))
  done
  return 1
}

wb_run_transfer() {
  local path=$1 id=$2 iperf=$3 max_attempts number direction duration address port attempt_started output errors pid exit_code
  local loaded_samples loaded_summary loaded status error parsed ended backoff
  wb_state_apply "$path" '(.measurements[]|select(.id==$id)) |= (.status="running"|.started_at=$checkpoint_now)' --arg id "$id" || return 1
  max_attempts=$((1 + $(wb_jq -r '.configuration.timing.server_busy_retries' "$path")))
  direction=$(wb_jq -r --arg id "$id" '.measurements[]|select(.id==$id)|.settings.direction' "$path")
  duration=$(wb_jq -r --arg id "$id" '.measurements[]|select(.id==$id)|.settings.duration_seconds' "$path")
  address=$(wb_jq -r --arg id "$id" '.measurements[]|select(.id==$id)|.endpoint.ipv4' "$path")
  port=$(wb_jq -r --arg id "$id" '.measurements[]|select(.id==$id)|.endpoint.iperf_port' "$path")
  for ((number=1; number<=max_attempts; number++)); do
    if (( number > 1 )); then
      backoff=$(wb_jq -r --argjson index "$((number-2))" '.configuration.timing.retry_backoff_seconds[[$index, (.configuration.timing.retry_backoff_seconds|length)-1]|min]' "$path"); sleep "$backoff"
    fi
    attempt_started=$(wb_utc); output="$WARP_BENCH_WORK_DIR/iperf-$id-$number.json"; errors="$WARP_BENCH_WORK_DIR/iperf-$id-$number.err"
    wb_state_apply "$path" '(.measurements[]|select(.id==$id).attempts) += [{number:$number,session_id:"session-1",status:"running",started_at:$started,ended_at:null,sender:null,receiver:null,intervals:[],loaded_ping:null,error:null}]' \
      --arg id "$id" --argjson number "$number" --arg started "$attempt_started" || return 1
    local args=(-4 -c "$address" -p "$port" -t "$duration" -P 1 --json-stream --forceflush --get-server-output)
    [[ $direction == download ]] && args+=(-R)
    wb_timeout "$((duration + 30))" "$iperf" "${args[@]}" >"$output" 2>"$errors" & pid=$!; WARP_BENCH_ACTIVE_PID=$pid
    loaded=null
    if wb_wait_for_iperf_start "$pid" "$output"; then
      loaded_samples=$(wb_ping_adapter "$address" 10000 "$(wb_jq -r '.configuration.loaded_ping.interval_ms' "$path")" "$(wb_jq -r '.configuration.loaded_ping.timeout_ms' "$path")" "$(wb_jq -r '.configuration.loaded_ping.payload_bytes' "$path")" "$pid" | wb_jq -sc '.')
      wait "$pid"; exit_code=$?; WARP_BENCH_ACTIVE_PID=
      if (( exit_code == 0 )) && parsed=$(wb_normalize_iperf "$direction" < "$output" 2>/dev/null); then
        loaded_samples=$(wb_jq -c --argjson duration "$(wb_jq -r '.receiver.duration_ms' <<<"$parsed")" '[.[]|select(.elapsed_ms < $duration)]' <<<"$loaded_samples")
        loaded_summary=$(wb_ping_summary <<<"$loaded_samples")
        if [[ $(wb_jq -r '.probes_sent' <<<"$loaded_summary") == 0 ]]; then
          error=$(wb_error PING_UNAVAILABLE local_system false 'The client could not send loaded-latency probes.')
          loaded=$(wb_jq -cn --argjson samples "$loaded_samples" --argjson summary "$loaded_summary" --argjson error "$error" '{status:"unavailable",samples:$samples,summary:$summary,error:$error}')
          wb_add_diagnostic "$path" warning PING_UNAVAILABLE 'Loaded latency is unavailable because ICMP probes could not be sent.' "${id%%-*}" '' "$id"
        else loaded=$(wb_jq -cn --argjson samples "$loaded_samples" --argjson summary "$loaded_summary" '{status:"completed",samples:$samples,summary:$summary,error:null}'); fi
        ended=$(wb_utc)
        wb_state_apply "$path" '(.measurements[]|select(.id==$id)) |= (.status="completed"|.ended_at=$ended|.selected_attempt=$number|.error=null|(.attempts[]|select(.number==$number)) |= (.status="completed"|.ended_at=$ended|.sender=$parsed.sender|.receiver=$parsed.receiver|.intervals=$parsed.intervals|.loaded_ping=$loaded|.error=null))' \
          --arg id "$id" --argjson number "$number" --arg ended "$ended" --argjson parsed "$parsed" --argjson loaded "$loaded" || { rm -f "$output" "$errors"; return 1; }
        rm -f "$output" "$errors"; return 0
      fi
    else
      kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; WARP_BENCH_ACTIVE_PID=
    fi
    ended=$(wb_utc); error=$(wb_error IPERF_TRANSFER_FAILED remote_server true 'The public iperf3 server did not produce a usable transfer result.')
    wb_state_apply "$path" '(.measurements[]|select(.id==$id)) |= ((.attempts[]|select(.number==$number)) |= (.status="failed"|.ended_at=$ended|.loaded_ping=$loaded|.error=$error) | if $number==$maximum then .status="failed"|.ended_at=$ended|.selected_attempt=null|.error=$error else . end)' \
      --arg id "$id" --argjson number "$number" --argjson maximum "$max_attempts" --arg ended "$ended" --argjson loaded "$loaded" --argjson error "$error" || return 1
    rm -f "$output" "$errors"
  done
  wb_add_diagnostic "$path" warning IPERF_TRANSFER_FAILED 'Transfer result is unavailable after bounded retries.' '' '' "$id"
  return 0
}

wb_run_phase() {
  local path=$1 phase=$2 iperf=$3 target_id label target_index=0 total direction repetition id
  wb_phase_start "$path" "$phase" || return 1; total=$(wb_jq '.targets|length' "$path")
  while IFS= read -r target_id; do
    ((target_index++)); label=$(wb_jq -r --arg id "$target_id" '.targets[]|select(.id==$id)|.label' "$path")
    printf '[%s | %d/%d | %s] Idle ping\n' "$phase" "$target_index" "$total" "$label"
    wb_run_idle "$path" "$phase" "$target_id" || return 1
    for direction in download upload; do
      for ((repetition=1; repetition<=$(wb_jq -r '.configuration.tcp.repetitions_per_direction' "$path"); repetition++)); do
        printf '[%s | %d/%d | %s] %s repetition %d\n' "$phase" "$target_index" "$total" "$label" "$direction" "$repetition"
        id="$phase-$target_id-$direction-$repetition"; wb_run_transfer "$path" "$id" "$iperf" || return 1
        sleep "$(wb_jq -r '.configuration.timing.between_transfers_seconds' "$path")"
      done
    done
    (( target_index < total )) && sleep "$(wb_jq -r '.configuration.timing.between_targets_seconds' "$path")"
  done < <(wb_jq -r '.targets[].id' "$path")
  wb_phase_end "$path" "$phase"
}

wb_valid_ipv4() {
  local address=$1 octet rest=$1 count=0
  [[ $address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  while [[ $rest == *.* ]]; do octet=${rest%%.*}; ((10#$octet <= 255)) || return 1; rest=${rest#*.}; ((count++)); done
  ((10#$rest <= 255 && count == 3))
}

wb_resolve_ipv4() {
  local host=$1 address
  if wb_valid_ipv4 "$host"; then printf '%s\n' "$host"; return; fi
  if [[ $WARP_BENCH_OS_FAMILY == macos ]] && command -v dscacheutil >/dev/null 2>&1; then
    dscacheutil -q host -a name "$host" 2>/dev/null | awk '/^ip_address: /{print $2}' | while IFS= read -r address; do wb_valid_ipv4 "$address" && printf '%s\n' "$address"; done | sort -u
  elif command -v getent >/dev/null 2>&1; then
    getent ahostsv4 "$host" 2>/dev/null | awk '{print $1}' | while IFS= read -r address; do wb_valid_ipv4 "$address" && printf '%s\n' "$address"; done | sort -u
  elif command -v nslookup >/dev/null 2>&1; then
    nslookup "$host" 2>/dev/null | awk '/^Address: /{print $2}' | while IFS= read -r address; do wb_valid_ipv4 "$address" && printf '%s\n' "$address"; done | sort -u
  else return 1; fi
}

wb_tcp_preflight() {
  wb_timeout "$WARP_BENCH_PREFLIGHT_TIMEOUT_SECONDS" bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$1" "$2" 2>/dev/null
}

wb_select_target() {
  local target=$1 endpoint hostname address port
  while IFS= read -r endpoint; do
    [[ $(wb_jq -r '.verification_status' <<<"$endpoint") == unavailable ]] && continue
    hostname=$(wb_jq -r '.hostname' <<<"$endpoint")
    while IFS= read -r address; do
      while IFS= read -r port; do
        if wb_tcp_preflight "$address" "$port"; then
          wb_jq -cn --argjson target "$target" --arg hostname "$hostname" --arg address "$address" --argjson port "$port" \
            '{id:$target.id,manifest_target_id:$target.id,label:$target.label,country_code:$target.country_code,city:$target.city,location_confidence:$target.location_confidence,hostname:$hostname,endpoint:{ipv4:$address,iperf_port:$port}}'
          return 0
        fi
      done < <(wb_jq -r '.ports[]' <<<"$endpoint")
    done < <(wb_resolve_ipv4 "$hostname")
  done < <(wb_jq -c '.endpoints|sort_by(.priority)[]' <<<"$target")
  return 1
}

wb_resolve_targets() {
  local selected='[]' target choice label
  while IFS= read -r target; do
    label=$(wb_jq -r '.label' <<<"$target"); printf 'Resolving and pinning %s...\n' "$label" >&2
    if choice=$(wb_select_target "$target"); then selected=$(wb_jq -cn --argjson selected "$selected" --argjson choice "$choice" '$selected+[$choice]')
    else printf 'Warning: no documented endpoint was reachable for %s; it will be omitted.\n' "$label" >&2; fi
  done < <(wb_jq -c '.targets|sort_by(.order)[]|select(.enabled)' <<<"$WARP_BENCH_TARGETS_JSON")
  [[ $(wb_jq 'length' <<<"$selected") -gt 0 ]] || return 1
  printf '%s\n' "$selected"
}

wb_resolve_tools() {
  local candidate version directory temporary hash
  if [[ -n $WARP_BENCH_JQ && -x $WARP_BENCH_JQ ]] && "$WARP_BENCH_JQ" --version >/dev/null 2>&1; then return 0; fi
  candidate=$(command -v jq 2>/dev/null || true)
  if [[ -n $candidate ]]; then
    version=$($candidate --version 2>/dev/null)
    [[ $version =~ ^jq-1\.[5-9] || $version =~ ^jq-[2-9]\. ]] && { WARP_BENCH_JQ=$candidate; WARP_BENCH_JQ_PROVISIONING=system; return 0; }
  fi
  command -v curl >/dev/null 2>&1 && { command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1; } || return 1
  wb_select_jq_artifact || return 1
  directory=$(mktemp -d "${TMPDIR:-/tmp}/warp-bench-jq.XXXXXX") || return 1; chmod 700 "$directory"; WARP_BENCH_TEMP_ROOT=$directory
  temporary="$directory/jq.tmp"; WARP_BENCH_JQ="$directory/jq"
  curl --fail --location --proto '=https' --tlsv1.2 "$WARP_BENCH_JQ_URL" -o "$temporary" || return 1
  hash=$(wb_sha256 "$temporary"); [[ $hash == "$WARP_BENCH_JQ_SHA256" ]] || return 1
  mv "$temporary" "$WARP_BENCH_JQ"; chmod 700 "$WARP_BENCH_JQ"; "$WARP_BENCH_JQ" --version >/dev/null 2>&1 || return 1
  WARP_BENCH_JQ_PROVISIONING=temporary_download
}

wb_get_iperf() {
  local system version version_text help directory file hash consent
  system=$(command -v iperf3 2>/dev/null || true)
  if [[ -n $system ]]; then
    version_text=$($system --version 2>&1); help=$($system --help 2>&1)
    if [[ $version_text =~ iperf[[:space:]]+(3\.[0-9]+(\.[0-9]+)?) ]]; then version=${BASH_REMATCH[1]}; else version=; fi
    if [[ -n $version && $help == *--json-stream* && $help == *--get-server-output* && $help =~ (^|[[:space:]])-R([,[:space:]]|$) ]]; then
      printf '%s system %s\n' "$system" "$version"; return 0
    fi
    printf 'Installed iperf3 lacks required JSON-stream, server-output, or reverse capability.\n' >&2
  fi
  if [[ $WARP_BENCH_OS_FAMILY == macos ]]; then
    printf 'macOS requires a compatible system iperf3 (with --json-stream, --get-server-output, and -R); no macOS artifact will be downloaded. Install a compatible iperf3 using your normal system administration process.\n' >&2
    return 1
  fi
  consent=$(wb_prompt 'The pinned Linux iperf3 artifact is a candidate, not approved. Download and execute it temporarily? [y/N] ') || return 1
  [[ $consent == [Yy]* ]] || return 1
  command -v curl >/dev/null 2>&1 && { command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1; } || return 1
  [[ -n $WARP_BENCH_TEMP_ROOT ]] || { WARP_BENCH_TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/warp-bench.XXXXXX") || return 1; chmod 700 "$WARP_BENCH_TEMP_ROOT"; }
  directory="$WARP_BENCH_TEMP_ROOT/iperf"; mkdir -m 700 "$directory" || return 1; file="$directory/iperf3"
  curl --fail --location --proto '=https' --tlsv1.2 "$(wb_jq -r '.url' <<<"$WARP_BENCH_IPERF_ARTIFACT")" -o "$file.tmp" || return 1
  hash=$(wb_sha256 "$file.tmp"); [[ $hash == $(wb_jq -r '.sha256' <<<"$WARP_BENCH_IPERF_ARTIFACT") ]] || return 1
  mv "$file.tmp" "$file"; chmod 700 "$file"
  version=$($file --version 2>&1); help=$($file --help 2>&1)
  [[ $version =~ iperf[[:space:]]+3\.21 && $help == *--json-stream* && $help == *--get-server-output* && $help =~ (^|[[:space:]])-R([,[:space:]]|$) ]] || return 1
  printf '%s temporary_download 3.21.0\n' "$file"
}

wb_persistent_output() {
  local root=${1:-} answer probe fs_type
  if [[ -z $root ]]; then
    [[ -d /mnt/user ]] && root=/mnt/user/warp-benchmark-results || root=${HOME:-$PWD}/warp-benchmark-results
    answer=$(wb_prompt "Results directory [$root]: ") || return 1; [[ -n $answer ]] && root=$answer
  fi
  mkdir -p -- "$root" || return 1; probe="$root/.warp-bench-write.$$"
  printf 'persistence-probe\n' > "$probe.tmp" || return 1
  command -v sync >/dev/null 2>&1 && sync "$probe.tmp" 2>/dev/null || true
  mv -f "$probe.tmp" "$probe" && rm -f "$probe" || return 1
  if [[ $WARP_BENCH_OS_FAMILY == macos ]]; then fs_type=$(stat -f %T "$root" 2>/dev/null || true); else fs_type=$(findmnt -n -o FSTYPE -T "$root" 2>/dev/null || true); fi
  if [[ $root == /tmp/* || $root == /run/* || -z $fs_type || $fs_type == tmpfs || $fs_type == ramfs || $fs_type == overlay || $fs_type == "devfs" ]]; then
    answer=$(wb_prompt "Output filesystem '$fs_type' may be volatile. Confirm this path is persistent? [y/N] ") || return 1
    [[ $answer == [Yy]* ]] || return 1
  fi
  (cd "$root" 2>/dev/null && pwd -P)
}

wb_show_summary() {
  local path=$1
  wb_jq -r '
    "\nBenchmark status: \(.run.status)",
    (.targets[] as $target | [$target.label, (["baseline","warp"][] as $phase |
      ([.measurements[]|select(.phase_id==$phase and .target_id==$target.id and .kind=="idle_ping" and .status=="completed")][0].summary.rtt_median_ms // null) as $rtt |
      ([.measurements[]|select(.phase_id==$phase and .target_id==$target.id and .kind=="tcp_transfer" and .settings.direction=="download" and .status=="completed") | . as $measurement | [.attempts[]|select(.number==$measurement.selected_attempt)][0].receiver.bits_per_second/1000000] | if length==0 then null else add/length end) as $rate |
      "\($phase) median RTT \(if $rtt==null then "n/a" else "\($rtt) ms" end), download \(if $rate==null then "n/a" else "\(($rate*10|round)/10) Mbps" end)")] | join(" | "))' "$path"
  printf 'Results: %s\n' "$path"
}

wb_stop_active() {
  local count=0 pid=$WARP_BENCH_ACTIVE_PID
  [[ -n $pid ]] || return 0
  kill "$pid" 2>/dev/null || true
  # Let the macOS timeout wrapper forward TERM and complete its grace period.
  while kill -0 "$pid" 2>/dev/null && (( count < 55 )); do sleep 0.1; ((count++)); done
  kill -KILL "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  WARP_BENCH_ACTIVE_PID=
}

wb_cleanup() {
  wb_stop_active
  [[ -n $WARP_BENCH_WORK_DIR ]] && rm -rf "$WARP_BENCH_WORK_DIR"
  [[ -n $WARP_BENCH_TEMP_ROOT ]] && rm -rf "$WARP_BENCH_TEMP_ROOT"
}

wb_signal() {
  trap - INT TERM
  wb_stop_active
  if [[ -n $WARP_BENCH_STATE_PATH && -f $WARP_BENCH_STATE_PATH && $WARP_BENCH_FINALIZED == 0 ]]; then
    wb_add_diagnostic "$WARP_BENCH_STATE_PATH" error RUN_INTERRUPTED 'The benchmark was interrupted; completed measurements remain checkpointed.' || true
    wb_finalize_state "$WARP_BENCH_STATE_PATH" interrupted || true; WARP_BENCH_FINALIZED=1
    printf 'Benchmark interrupted. Checkpoint: %s\n' "$WARP_BENCH_STATE_PATH" >&2
  fi
  wb_cleanup; exit 130
}

wb_main() {
  local answer profile=quick root iperf_path iperf_provisioning iperf_version targets started run_id run_directory route_result now
  [[ ${WARP_BENCH_ENTRY_PROBE:-0} == 1 ]] && { printf 'pipe-entry-reached\n'; return; }
  [[ $# -eq 0 ]] || { printf 'This runner does not support resume or command-line state input.\n' >&2; return 2; }
  wb_platform || { printf 'This runner supports Linux x86_64 and macOS 14+ x86_64/arm64 only.\n' >&2; return 1; }
  [[ -r /dev/tty && -w /dev/tty ]] || { printf 'An interactive terminal is required.\n' >&2; return 1; }
  umask 077
  local utility
  for utility in awk bash chmod curl date grep mkdir mktemp mv rm sed sleep sort tr uname; do
    command -v "$utility" >/dev/null 2>&1 || { printf 'Required utility is unavailable: %s\n' "$utility" >&2; return 1; }
  done
  if [[ $WARP_BENCH_OS_FAMILY == linux ]]; then timeout --help 2>&1 | grep -q -- '--kill-after' || { printf 'The installed timeout utility lacks required process-control support.\n' >&2; return 1; }
  else perl -MTime::HiRes=clock_gettime,CLOCK_MONOTONIC -e 'clock_gettime(CLOCK_MONOTONIC)' >/dev/null 2>&1 || { printf 'macOS requires its system Perl Time::HiRes monotonic-clock capability.\n' >&2; return 1; }; fi
  if [[ $WARP_BENCH_OS_FAMILY == macos ]]; then
    command -v dscacheutil >/dev/null 2>&1 || command -v nslookup >/dev/null 2>&1 || { printf 'IPv4 target resolution requires dscacheutil or nslookup.\n' >&2; return 1; }
  elif ! command -v getent >/dev/null 2>&1 && ! command -v nslookup >/dev/null 2>&1; then
    printf 'IPv4 target resolution requires getent or nslookup.\n' >&2; return 1
  fi
  trap wb_signal HUP INT TERM
  printf 'WARP vs ISP Benchmark %s\nThis test can saturate the connection. Pause downloads and use wired Ethernet when possible.\n' "$WARP_BENCH_VERSION"
  answer=$(wb_prompt 'Select [Q]uick (~10.5 GB) or [E]xtended (~47.3 GB): ') || return 1
  [[ $answer == [Ee]* ]] && profile=extended
  root=$(wb_persistent_output "${WARP_BENCH_OUTPUT:-}") || { printf 'A writable persistent output path is required.\n' >&2; return 1; }
  wb_resolve_tools || { printf 'jq 1.5 or newer is required and bootstrap failed.\n' >&2; return 1; }
  read -r iperf_path iperf_provisioning iperf_version < <(wb_get_iperf) || return 1
  [[ -n $iperf_path ]] || return 1
  targets=$(wb_resolve_targets) || { printf 'No public iperf3 endpoint could be pinned.\n' >&2; return 1; }
  [[ -n $WARP_BENCH_TEMP_ROOT ]] || { WARP_BENCH_TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/warp-bench.XXXXXX") || return 1; chmod 700 "$WARP_BENCH_TEMP_ROOT"; }
  WARP_BENCH_WORK_DIR="$WARP_BENCH_TEMP_ROOT/work"; mkdir -m 700 "$WARP_BENCH_WORK_DIR" || return 1
  started=$(wb_utc); run_id=$(printf '%s-%s-%s' "$(date -u +%Y%m%d%H%M%S)" "$$" "$RANDOM" | tr '[:upper:]' '[:lower:]')
  run_directory="$root/warp-benchmark-$(date -u +%Y%m%dT%H%M%SZ)-${run_id: -5}"; mkdir -m 700 "$run_directory" || return 1
  WARP_BENCH_STATE_PATH="$run_directory/results.json"
  wb_checkpoint "$WARP_BENCH_STATE_PATH" "$(wb_new_state "$profile" "$targets" "$iperf_version" "$iperf_provisioning" "$run_id" "$started")" || return 1
  printf 'Pinned %s target(s). Results are checkpointed to %s\n' "$(wb_jq '.targets|length' "$WARP_BENCH_STATE_PATH")" "$WARP_BENCH_STATE_PATH"
  wb_prompt 'Confirm normal direct ISP routing, then press Enter: ' >/dev/null || return 1
  route_result=$(wb_confirm_route "$WARP_BENCH_STATE_PATH" baseline before_phase) || return 1
  [[ $route_result == save ]] && { wb_finalize_state "$WARP_BENCH_STATE_PATH" failed || return 1; WARP_BENCH_FINALIZED=1; wb_show_summary "$WARP_BENCH_STATE_PATH"; wb_cleanup; return; }
  [[ $route_result == verified ]] && wb_state_apply "$WARP_BENCH_STATE_PATH" '.sessions[0].route_reverified=true'
  wb_run_phase "$WARP_BENCH_STATE_PATH" baseline "$iperf_path" || return 1
  route_result=$(wb_confirm_route "$WARP_BENCH_STATE_PATH" baseline after_phase) || return 1
  wb_complete_verification "$WARP_BENCH_STATE_PATH" baseline || return 1
  if [[ $route_result == save ]]; then wb_finalize_state "$WARP_BENCH_STATE_PATH" baseline_only || return 1; WARP_BENCH_FINALIZED=1; wb_show_summary "$WARP_BENCH_STATE_PATH"; wb_cleanup; return; fi
  answer=$(wb_prompt 'Continue with WARP phase? [Y/n] ') || return 1
  if [[ $answer == [Nn]* ]]; then wb_finalize_state "$WARP_BENCH_STATE_PATH" baseline_only || return 1; WARP_BENCH_FINALIZED=1; wb_show_summary "$WARP_BENCH_STATE_PATH"; wb_cleanup; return; fi
  wb_prompt 'Enable WARP policy routing for this client, then press Enter: ' >/dev/null || return 1
  sleep "$(wb_jq -r '.configuration.timing.route_settle_seconds' "$WARP_BENCH_STATE_PATH")"
  route_result=$(wb_confirm_route "$WARP_BENCH_STATE_PATH" warp before_phase) || return 1
  [[ $route_result == save ]] && { wb_finalize_state "$WARP_BENCH_STATE_PATH" baseline_only || return 1; WARP_BENCH_FINALIZED=1; wb_show_summary "$WARP_BENCH_STATE_PATH"; wb_cleanup; return; }
  wb_run_phase "$WARP_BENCH_STATE_PATH" warp "$iperf_path" || return 1
  wb_confirm_route "$WARP_BENCH_STATE_PATH" warp after_phase >/dev/null || return 1
  wb_complete_verification "$WARP_BENCH_STATE_PATH" warp || return 1
  wb_finalize_state "$WARP_BENCH_STATE_PATH" auto || return 1; WARP_BENCH_FINALIZED=1
  wb_show_summary "$WARP_BENCH_STATE_PATH"; wb_cleanup
}

if [[ $WARP_BENCH_SOURCE_ONLY != 1 && ( -z ${BASH_SOURCE[0]} || ${BASH_SOURCE[0]} == "$0" ) ]]; then
  wb_main "$@"
  status=$?
  if (( status != 0 )); then
    if [[ -n $WARP_BENCH_STATE_PATH && -f $WARP_BENCH_STATE_PATH && $WARP_BENCH_FINALIZED == 0 ]]; then
      wb_add_diagnostic "$WARP_BENCH_STATE_PATH" error RUN_INTERRUPTED 'The benchmark stopped unexpectedly; completed measurements remain checkpointed.' || true
      wb_finalize_state "$WARP_BENCH_STATE_PATH" interrupted || true
    fi
    wb_cleanup; exit "$status"
  fi
fi
