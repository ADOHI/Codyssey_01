#!/usr/bin/env bash
set -u

LOG_DIR="/var/log/agent-app"
ARCHIVE_DIR="/var/log/monitor/agent-app/archive"
WARN=0

if [ ! -d "$LOG_DIR" ]; then
  echo "[WARNING] log directory not found: $LOG_DIR"
  exit 0
fi

if [ ! -w "$LOG_DIR" ]; then
  echo "[WARNING] insufficient permission on $LOG_DIR"
  exit 0
fi

mkdir -p "$ARCHIVE_DIR" 2>/dev/null || {
  echo "[WARNING] cannot create archive directory: $ARCHIVE_DIR"
  exit 0
}

if ! find "$LOG_DIR" -maxdepth 1 -type f -name "*.log" -mtime +7 -print -quit | grep -q .; then
  echo "[INFO] no log files older than 7 days to compress"
else
  find "$LOG_DIR" -maxdepth 1 -type f -name "*.log" -mtime +7 -print0 | while IFS= read -r -d '' f; do
    if gzip -f "$f"; then
      base="$(basename "$f").gz"
      mv "${f}.gz" "$ARCHIVE_DIR/$base" 2>/dev/null || {
        echo "[WARNING] failed to move archive: ${f}.gz"
        WARN=1
      }
    else
      echo "[WARNING] failed to compress: $f"
      WARN=1
    fi
  done
fi

if ! find "$ARCHIVE_DIR" -maxdepth 1 -type f -name "*.gz" -mtime +30 -print -quit | grep -q .; then
  echo "[INFO] no archived files older than 30 days to delete"
else
  find "$ARCHIVE_DIR" -maxdepth 1 -type f -name "*.gz" -mtime +30 -delete || {
    echo "[WARNING] failed deleting old archives"
    WARN=1
  }
fi

if [ "$WARN" -eq 0 ]; then
  echo "[INFO] log retention completed safely"
else
  echo "[WARNING] log retention completed with warnings"
fi

