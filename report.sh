#!/usr/bin/env bash
set -euo pipefail

# 사용법:
#   report.sh [LOG_FILE] [START_TS] [END_TS]
# 예시:
#   report.sh /var/log/agent-app/monitor.log
#   report.sh /var/log/agent-app/monitor.log "2026-05-24 13:00:00" "2026-05-24 14:00:00"
LOG_FILE="${1:-/var/log/agent-app/monitor.log}"
START_TS="${2:-}"
END_TS="${3:-}"

if [ ! -f "$LOG_FILE" ]; then
  echo "[ERROR] log file not found: $LOG_FILE"
  exit 1
fi

# monitor.log 포맷에서 CPU/MEM/DISK 값을 파싱해 통계를 계산한다.
# 시간 범위를 주면 [start <= timestamp <= end] 샘플만 집계한다.
awk -v start="$START_TS" -v end="$END_TS" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function update(metric, value, ts) {
  if (!(metric in cnt)) {
    min[metric]=value; max[metric]=value
    min_t[metric]=ts; max_t[metric]=ts
  }
  if (value < min[metric]) { min[metric]=value; min_t[metric]=ts }
  if (value > max[metric]) { max[metric]=value; max_t[metric]=ts }
  sum[metric]+=value
  cnt[metric]++
}
{
  if ($0 !~ /^\[/) next
  ts = substr($0, 2, 19)
  if (start != "" && ts < start) next
  if (end != "" && ts > end) next

  cpu = mem = disk = ""
  if (match($0, /CPU:[0-9.]+%/)) {
    cpu = substr($0, RSTART+4, RLENGTH-5)+0
    update("CPU", cpu, ts)
  }
  if (match($0, /MEM:[0-9.]+%/)) {
    mem = substr($0, RSTART+4, RLENGTH-5)+0
    update("MEM", mem, ts)
  }
  if (match($0, /DISK_USED:[0-9.]+%/)) {
    disk = substr($0, RSTART+10, RLENGTH-11)+0
    update("DISK", disk, ts)
  }
}
END {
  if (!("CPU" in cnt) && !("MEM" in cnt) && !("DISK" in cnt)) {
    print "[INFO] no matching samples in range"
    exit 0
  }
  print "====== STATISTICS REPORT ======"
  # 과제 요구 형식(평균/최대/최소/샘플수)에 맞춰 출력한다.
  if ("CPU" in cnt) {
    printf "[CPU]\nAverage : %.2f%%\nMaximum : %.2f%% at %s\nMinimum : %.2f%% at %s\n", sum["CPU"]/cnt["CPU"], max["CPU"], max_t["CPU"], min["CPU"], min_t["CPU"]
  }
  if ("MEM" in cnt) {
    printf "[Memory]\nAverage : %.2f%%\nMaximum : %.2f%% at %s\nMinimum : %.2f%% at %s\n", sum["MEM"]/cnt["MEM"], max["MEM"], max_t["MEM"], min["MEM"], min_t["MEM"]
  }
  if ("DISK" in cnt) {
    printf "[Disk]\nAverage : %.2f%%\nMaximum : %.2f%% at %s\nMinimum : %.2f%% at %s\n", sum["DISK"]/cnt["DISK"], max["DISK"], max_t["DISK"], min["DISK"], min_t["DISK"]
  }
  printf "[Samples]\nData Points: %d samples\n", cnt["CPU"]
}
' "$LOG_FILE"

