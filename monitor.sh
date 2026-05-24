#!/usr/bin/env bash
set -u

AGENT_HOME="${AGENT_HOME:-/home/agent-admin/agent-app}"
AGENT_PORT="${AGENT_PORT:-15034}"
AGENT_LOG_DIR="${AGENT_LOG_DIR:-/var/log/agent-app}"
APP_PATTERN="${APP_PATTERN:-agent_app|agent_app.py}"
LOG_FILE="${AGENT_LOG_DIR}/monitor.log"

CPU_WARN=20
MEM_WARN=10
DISK_WARN=80
MAX_BYTES=$((10 * 1024 * 1024))
MAX_ROTATED=10

rotate_logs() {
  [ -f "$LOG_FILE" ] || return 0
  local size
  size=$(stat -c '%s' "$LOG_FILE" 2>/dev/null || echo 0)
  [ "$size" -lt "$MAX_BYTES" ] && return 0

  [ -f "${LOG_FILE}.${MAX_ROTATED}" ] && rm -f "${LOG_FILE}.${MAX_ROTATED}"
  local idx
  for ((idx=MAX_ROTATED-1; idx>=1; idx--)); do
    [ -f "${LOG_FILE}.${idx}" ] && mv "${LOG_FILE}.${idx}" "${LOG_FILE}.$((idx+1))"
  done
  mv "$LOG_FILE" "${LOG_FILE}.1"
  : > "$LOG_FILE"
}

get_cpu_usage() {
  local user1 nice1 sys1 idle1 iowait1 irq1 softirq1 steal1 t1 id1
  local user2 nice2 sys2 idle2 iowait2 irq2 softirq2 steal2 t2 id2
  read -r _ user1 nice1 sys1 idle1 iowait1 irq1 softirq1 steal1 _ < /proc/stat
  sleep 1
  read -r _ user2 nice2 sys2 idle2 iowait2 irq2 softirq2 steal2 _ < /proc/stat
  t1=$((user1 + nice1 + sys1 + idle1 + iowait1 + irq1 + softirq1 + steal1))
  t2=$((user2 + nice2 + sys2 + idle2 + iowait2 + irq2 + softirq2 + steal2))
  id1=$((idle1 + iowait1))
  id2=$((idle2 + iowait2))
  awk -v total="$((t2-t1))" -v idle="$((id2-id1))" 'BEGIN { if (total <= 0) print "0.0"; else printf "%.1f", (100*(total-idle)/total) }'
}

is_number_gt() {
  awk -v a="$1" -v b="$2" 'BEGIN {exit !(a>b)}'
}

printf '====== SYSTEM MONITOR RESULT ======\n\n'
printf '[HEALTH CHECK]\n'

PID=$(pgrep -f "$APP_PATTERN" | head -n 1 || true)
if [ -z "$PID" ]; then
  printf "Checking process 'agent_app.py'... [FAIL]\n"
  printf '[ERROR] process check failed\n'
  exit 1
fi
printf "Checking process 'agent_app.py'... [OK] (PID: %s)\n" "$PID"

if ss -tuln | awk -v p=":${AGENT_PORT}" '$1=="tcp" && $2=="LISTEN" && index($5,p)>0 {found=1} END{exit !found}'; then
  printf 'Checking port %s... [OK]\n\n' "$AGENT_PORT"
else
  printf 'Checking port %s... [FAIL]\n' "$AGENT_PORT"
  printf '[ERROR] port check failed\n'
  exit 1
fi

FW_ACTIVE=0
if command -v ufw >/dev/null 2>&1; then
  # ufw status requires root; read ufw.conf for non-root cron compatibility.
  if awk -F= '/^ENABLED=/{if($2=="yes") found=1} END{exit !found}' /etc/ufw/ufw.conf 2>/dev/null; then
    FW_ACTIVE=1
  fi
elif command -v firewall-cmd >/dev/null 2>&1; then
  if systemctl is-active --quiet firewalld; then
    FW_ACTIVE=1
  fi
fi

if [ "$FW_ACTIVE" -eq 0 ]; then
  printf '[WARNING] Firewall inactive or not detected\n'
fi

CPU_USAGE=$(get_cpu_usage)
MEM_USAGE=$(free | awk '/Mem:/ {printf "%.1f", ($3/$2)*100}')
DISK_USED=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')

printf '[RESOURCE MONITORING]\n'
printf 'CPU Usage : %s%%\n' "$CPU_USAGE"
printf 'MEM Usage : %s%%\n' "$MEM_USAGE"
printf 'DISK Used : %s%%\n' "$DISK_USED"

if is_number_gt "$CPU_USAGE" "$CPU_WARN"; then
  printf '[WARNING] CPU threshold exceeded (%s%% > %s%%)\n' "$CPU_USAGE" "$CPU_WARN"
fi
if is_number_gt "$MEM_USAGE" "$MEM_WARN"; then
  printf '[WARNING] MEM threshold exceeded (%s%% > %s%%)\n' "$MEM_USAGE" "$MEM_WARN"
fi
if is_number_gt "$DISK_USED" "$DISK_WARN"; then
  printf '[WARNING] DISK threshold exceeded (%s%% > %s%%)\n' "$DISK_USED" "$DISK_WARN"
fi

mkdir -p "$AGENT_LOG_DIR"
rotate_logs
printf '[%s] PID:%s CPU:%s%% MEM:%s%% DISK_USED:%s%%\n' "$(date '+%F %T')" "$PID" "$CPU_USAGE" "$MEM_USAGE" "$DISK_USED" >> "$LOG_FILE"
printf '\n[INFO] Log appended: %s\n' "$LOG_FILE"
