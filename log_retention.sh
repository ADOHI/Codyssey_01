#!/usr/bin/env bash
set -u

# ---------------------------------------------------------------------------
# log_retention.sh
# ---------------------------------------------------------------------------
# 목적:
#   시간 기반 로그 보존 정책 수행
#
# 정책:
#   1) /var/log/agent-app/*.log 중 7일 경과 파일을 gzip 압축
#   2) 압축 파일(.gz)을 /var/log/monitor/agent-app/archive 로 이동
#   3) archive/*.gz 중 30일 경과 파일 삭제
#
# 설계 원칙:
#   - 예외 상황(권한 부족, 대상 없음, 디렉토리 없음)에서 즉시 크래시보다
#     경고 메시지와 안전 종료를 우선한다.
# ---------------------------------------------------------------------------

# 시간 기반 로그 보존 정책:
# 1) /var/log/agent-app/*.log 중 7일 지난 파일 압축(gzip)
# 2) 압축 파일을 /var/log/monitor/agent-app/archive/ 로 이동
# 3) archive/*.gz 중 30일 지난 파일 삭제
# 실패 시 전체 중단보다 "경고 후 안전 종료"를 우선한다.
LOG_DIR="/var/log/agent-app"
ARCHIVE_DIR="/var/log/monitor/agent-app/archive"
WARN=0

# 대상 디렉토리 유무/권한 확인 (예외 처리)
if [ ! -d "$LOG_DIR" ]; then
  echo "[WARNING] log directory not found: $LOG_DIR"
  exit 0
fi

# 쓰기 권한이 없으면 압축/이동 작업이 불가능하므로 안전 종료
if [ ! -w "$LOG_DIR" ]; then
  echo "[WARNING] insufficient permission on $LOG_DIR"
  exit 0
fi

# 아카이브 디렉토리가 없으면 생성 시도, 실패하면 경고 후 종료
mkdir -p "$ARCHIVE_DIR" 2>/dev/null || {
  echo "[WARNING] cannot create archive directory: $ARCHIVE_DIR"
  exit 0
}

# 압축 대상 유무를 먼저 검사해 "대상 없음"을 명시한다.
if ! find "$LOG_DIR" -maxdepth 1 -type f -name "*.log" -mtime +7 -print -quit | grep -q .; then
  echo "[INFO] no log files older than 7 days to compress"
else
  # 공백/특수문자 파일명 안전 처리를 위해 -print0 + read -d '' 사용
  find "$LOG_DIR" -maxdepth 1 -type f -name "*.log" -mtime +7 -print0 | while IFS= read -r -d '' f; do
    # gzip -f: 기존 .gz가 있어도 강제로 덮어쓰기
    if gzip -f "$f"; then
      base="$(basename "$f").gz"
      # 아카이브 이동 실패는 경고만 남기고 다음 파일 처리 계속
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

# 30일 지난 아카이브 삭제(없으면 정보 로그만 출력)
if ! find "$ARCHIVE_DIR" -maxdepth 1 -type f -name "*.gz" -mtime +30 -print -quit | grep -q .; then
  echo "[INFO] no archived files older than 30 days to delete"
else
  find "$ARCHIVE_DIR" -maxdepth 1 -type f -name "*.gz" -mtime +30 -delete || {
    echo "[WARNING] failed deleting old archives"
    WARN=1
  }
fi

# 최종 상태 보고:
# WARN==0 -> 전체 성공
# WARN==1 -> 일부 경고 발생(치명 실패 아님)
if [ "$WARN" -eq 0 ]; then
  echo "[INFO] log retention completed safely"
else
  echo "[WARNING] log retention completed with warnings"
fi

