# Codyssey_01 - 시스템 관제 자동화 스크립트 개발 수행 내역서

이번 과제 진행하면서 실제로 작업한 내용과 확인 결과를 순서대로 정리했습니다.  
환경 구성 -> 보안 설정 -> 계정/권한 -> 앱 실행 -> 관제 스크립트 -> cron 자동화 -> 보너스 구현 순으로 진행했습니다.

---

## 1) 작업 환경

- 호스트: Windows (NT 커널 `10.0.26200.8457`, 일반적으로 Windows 11 계열 빌드) + WSL2
- 리눅스 환경: Ubuntu `24.04.1 LTS` (Noble Numbat, systemd 활성)
- WSL 커널: `6.6.114.1-microsoft-standard-WSL2`
- 제공 앱 위치: `C:\Users\adohi\Downloads\agent-app.zip`
- 리눅스 실행 파일: `agent-app-linux-x86` (Python 소스가 아닌 바이너리 제공)
- 최종 AGENT_HOME: `/home/agent-admin/agent-app`

---

## 2) 요구사항 해석 및 문서 공백 보정(중요)

과제 문서와 실제 제공 앱 사이에 불일치가 있어, 실행 로그를 근거로 다음을 보정했습니다.

- 문서: `AGENT_KEY_PATH=/home/.../api_keys/t_secret.key` (파일 경로)
- 실제 앱 검증 로직: `AGENT_KEY_PATH=/home/.../api_keys` (디렉토리 경로) 기대
- 문서: 키 파일명 `t_secret.key`
- 실제 앱 검증 로직: `secret.key` 파일을 검사

따라서 실제 동작 기준으로 다음을 적용했습니다.

- `AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys`
- `/home/agent-admin/agent-app/api_keys/secret.key` 파일 생성
- 파일 내용: `agent_api_key_test`

---

## 3) 단위별 수행 내역

### 단위 A. 기본 보안 및 네트워크

#### A-1. SSH 설정

- `/etc/ssh/sshd_config` 변경
  - `Port 20022`
  - `PermitRootLogin no`
- SSH 소켓 모드로 인해 22 포트가 남아 있던 이슈를 확인하고 수정
  - `ssh.socket` 비활성화
  - `ssh.service` 재시작 후 20022 리슨 확인

실행 명령어:

```bash
# root에서 실행
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak_codyssey
sed -i -E 's/^#?Port .*/Port 20022/' /etc/ssh/sshd_config
sed -i -E 's/^#?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl disable --now ssh.socket
systemctl enable --now ssh

# 검증
awk '/^Port / || /^PermitRootLogin / {print}' /etc/ssh/sshd_config
ss -tulnp | awk '/:20022/ {print}'
```

검증 결과:

```text
Port 20022
PermitRootLogin no
tcp LISTEN ... 0.0.0.0:20022 ... ("sshd"...)
```

#### A-2. 방화벽(UFW)

- `ufw` 설치 및 활성화
- 기본 정책
  - `deny incoming`
  - `allow outgoing`
- 허용 포트
  - `20022/tcp`
  - `15034/tcp`

실행 명령어:

```bash
# root에서 실행
apt-get update
apt-get install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 20022/tcp
ufw allow 15034/tcp
ufw --force enable

# 검증
ufw status
```

검증 결과:

```text
Status: active
20022/tcp ALLOW
15034/tcp ALLOW
```

---

### 단위 B. 계정/그룹/권한(협업 + 최소권한)

#### B-1. 계정/그룹 생성

- 사용자
  - `agent-admin`
  - `agent-dev`
  - `agent-test`
- 그룹
  - `agent-common`: admin, dev, test
  - `agent-core`: admin, dev

실행 명령어:

```bash
# root에서 실행
groupadd -f agent-common
groupadd -f agent-core

id -u agent-admin >/dev/null 2>&1 || useradd -m -s /bin/bash agent-admin
id -u agent-dev   >/dev/null 2>&1 || useradd -m -s /bin/bash agent-dev
id -u agent-test  >/dev/null 2>&1 || useradd -m -s /bin/bash agent-test

usermod -aG agent-common agent-admin
usermod -aG agent-common agent-dev
usermod -aG agent-common agent-test
usermod -aG agent-core agent-admin
usermod -aG agent-core agent-dev

# 검증
id agent-admin
id agent-dev
id agent-test
```

검증 결과:

```text
uid=1001(agent-admin) gid=1003(agent-admin) groups=1003(agent-admin),1001(agent-common),1002(agent-core)
uid=1002(agent-dev) gid=1004(agent-dev) groups=1004(agent-dev),1001(agent-common),1002(agent-core)
uid=1003(agent-test) gid=1005(agent-test) groups=1005(agent-test),1001(agent-common)
```

검증 요약:

- `agent-admin`: `agent-common`, `agent-core` 포함
- `agent-dev`: `agent-common`, `agent-core` 포함
- `agent-test`: `agent-common` 포함

#### B-2. 디렉토리/권한/ACL

- 생성 디렉토리
  - `/home/agent-admin/agent-app`
  - `/home/agent-admin/agent-app/upload_files`
  - `/home/agent-admin/agent-app/api_keys`
  - `/var/log/agent-app`
- 정책 반영
  - `upload_files`: group=`agent-common`, rwx
  - `api_keys`, `/var/log/agent-app`: group=`agent-core`, rwx
- ACL 적용 확인(`getfacl`)

실행 명령어:

```bash
# root에서 실행
apt-get install -y acl
install -d -m 750  -o agent-admin -g agent-core   /home/agent-admin/agent-app
install -d -m 2770 -o agent-admin -g agent-common /home/agent-admin/agent-app/upload_files
install -d -m 2770 -o agent-admin -g agent-core   /home/agent-admin/agent-app/api_keys
install -d -m 2770 -o agent-admin -g agent-core   /var/log/agent-app

setfacl -m g:agent-common:rwx /home/agent-admin/agent-app/upload_files
setfacl -m g:agent-core:rwx   /home/agent-admin/agent-app/api_keys
setfacl -m g:agent-core:rwx   /var/log/agent-app

# 검증
ls -ld /home/agent-admin/agent-app /home/agent-admin/agent-app/upload_files /home/agent-admin/agent-app/api_keys /var/log/agent-app
getfacl -p /home/agent-admin/agent-app/upload_files
getfacl -p /home/agent-admin/agent-app/api_keys
getfacl -p /var/log/agent-app
```

검증 결과(실제 출력):

```text
drwxr-x---  5 agent-admin agent-core   4096 ... /home/agent-admin/agent-app
drwxrws---+ 2 agent-admin agent-core   4096 ... /home/agent-admin/agent-app/api_keys
drwxrws---+ 2 agent-admin agent-common 4096 ... /home/agent-admin/agent-app/upload_files
drwxrws---+ 2 agent-admin agent-core   4096 ... /var/log/agent-app

# file: /home/agent-admin/agent-app/upload_files
# owner: agent-admin
# group: agent-common
user::rwx
group::rwx
group:agent-common:rwx
mask::rwx
other::---

# file: /home/agent-admin/agent-app/api_keys
# owner: agent-admin
# group: agent-core
user::rwx
group::rwx
group:agent-core:rwx
mask::rwx
other::---

# file: /var/log/agent-app
# owner: agent-admin
# group: agent-core
user::rwx
group::rwx
group:agent-core:rwx
mask::rwx
other::---
```

검증 포인트 정리:

- `upload_files`는 `agent-common` 그룹 쓰기 가능 (협업 영역)
- `api_keys`, `/var/log/agent-app`는 `agent-core` 그룹 전용 (민감 영역)

---

### 단위 C. 앱 실행 환경 구성

#### C-1. 환경 변수

`/etc/profile.d/agent-app.sh`에 고정:

- `AGENT_HOME=/home/agent-admin/agent-app`
- `AGENT_PORT=15034`
- `AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files`
- `AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys`  (실앱 기준 보정)
- `AGENT_LOG_DIR=/var/log/agent-app`

실행 명령어:

```bash
# root에서 실행
cat > /etc/profile.d/agent-app.sh <<'EOF'
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files
export AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys
export AGENT_LOG_DIR=/var/log/agent-app
EOF
chmod 644 /etc/profile.d/agent-app.sh
```

검증 명령어:

```bash
# 일반 계정 세션에서 확인
runuser -u agent-admin -- bash -lc 'source /etc/profile.d/agent-app.sh; env | sort | grep "^AGENT_"'
```

검증 결과:

```text
AGENT_HOME=/home/agent-admin/agent-app
AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys
AGENT_LOG_DIR=/var/log/agent-app
AGENT_PORT=15034
AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files
```

#### C-2. 키 파일

- `/home/agent-admin/agent-app/api_keys/secret.key`
- 내용: `agent_api_key_test`

실행 명령어:

```bash
# root에서 실행
printf '%s\n' 'agent_api_key_test' > /home/agent-admin/agent-app/api_keys/secret.key
chown agent-admin:agent-core /home/agent-admin/agent-app/api_keys/secret.key
chmod 640 /home/agent-admin/agent-app/api_keys/secret.key
```

#### C-3. 앱 실행 검증

- 일반 계정(`agent-admin`)으로 실행
- Boot Sequence 5단계 모두 `[OK]`
- 마지막에 `Agent READY` 출력
- `0.0.0.0:15034` LISTEN 확인

실행 명령어:

```bash
# root에서 실행
cp /mnt/c/Users/adohi/Desktop/Codyssey_01/agent-app-src/agent-app-linux-x86 /home/agent-admin/agent-app/agent_app
chown agent-admin:agent-core /home/agent-admin/agent-app/agent_app
chmod 750 /home/agent-admin/agent-app/agent_app

# 앱 실행(일반 계정)
runuser -u agent-admin -- bash -lc 'source /etc/profile.d/agent-app.sh; /home/agent-admin/agent-app/agent_app'

# 백그라운드 실행 시
runuser -u agent-admin -- bash -lc 'source /etc/profile.d/agent-app.sh; nohup /home/agent-admin/agent-app/agent_app >/home/agent-admin/agent-app/agent-app.out 2>&1 &'

# 검증
ss -tulnp | awk '/:15034/ {print}'
```

검증 결과(실제 출력):

```text
tcp LISTEN 0 1 0.0.0.0:15034 0.0.0.0:* users:(("agent_app",pid=6116,fd=4))
```

실행 로그 발췌:

```text
>>> Starting Agent Boot Sequence...
[1/5] Checking User Account               [OK]
[2/5] Verifying Environment Variables     [OK]
[3/5] Checking Required Files             [OK]
[4/5] Checking Port Availability          [OK]
[5/5] Verifying Log Permission            [OK]
All Boot Checks Passed!
Agent READY
```

---

### 단위 D. monitor.sh 구현

파일:

- 소스: `./monitor.sh` (제출용)
- 배포: `/home/agent-admin/agent-app/bin/monitor.sh`

권한 정책:

- owner: `agent-dev`
- group: `agent-core`
- mode: `750`

구현된 기능:

- Health Check(실패 시 `exit 1`)
  - 프로세스: `agent_app` 또는 `agent_app.py` 패턴 검사
  - 포트: `15034/tcp` LISTEN 검사
- 방화벽 상태 점검(경고만)
  - UFW 사용 시 `/etc/ufw/ufw.conf`의 `ENABLED=yes` 판별
  - 비활성/미탐지 시 `[WARNING]`
- 리소스 수집
  - CPU(%): `/proc/stat` 1초 샘플링
  - MEM(%): `free`
  - DISK_USED(%): `df -P /`
- 임계값 경고(종료 없음)
  - CPU > 20
  - MEM > 10
  - DISK > 80
- 로그 기록
  - `/var/log/agent-app/monitor.log`
  - 형식: `[YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..%`
- 로그 용량 관리
  - `monitor.log` 10MB 초과 시 로테이션
  - 최대 `monitor.log.10`까지 유지

수동 실행 예시:

```text
====== SYSTEM MONITOR RESULT ======
[HEALTH CHECK]
Checking process 'agent_app.py'... [OK] (PID: 6114)
Checking port 15034... [OK]
[RESOURCE MONITORING]
CPU Usage : 1.0%
MEM Usage : 6.1%
DISK Used : 1%
[INFO] Log appended: /var/log/agent-app/monitor.log
```

배포/실행 명령어:

```bash
# root에서 실행
install -d -m 750 -o agent-dev -g agent-core /home/agent-admin/agent-app/bin
cp /mnt/c/Users/adohi/Desktop/Codyssey_01/monitor.sh /home/agent-admin/agent-app/bin/monitor.sh
sed -i 's/\r$//' /home/agent-admin/agent-app/bin/monitor.sh
chown agent-dev:agent-core /home/agent-admin/agent-app/bin/monitor.sh
chmod 750 /home/agent-admin/agent-app/bin/monitor.sh

# 수동 실행(일반 계정)
runuser -u agent-admin -- bash -lc '/home/agent-admin/agent-app/bin/monitor.sh'

# 로그 확인
tail -n 5 /var/log/agent-app/monitor.log
```

---

### 단위 E. cron 자동 실행

- 실행 계정: `agent-admin`
- 등록 내용:

```text
* * * * * /home/agent-admin/agent-app/bin/monitor.sh
```

검증:

- 등록 전후 확인
- 1분 이상 대기 후 `monitor.log` 라인 수 증가 확인
  - 예: `8 -> 9` 증가

실행 명령어:

```bash
# root에서 실행
systemctl enable --now cron
crontab -u agent-admin -l 2>/dev/null | sed '/monitor.sh/d' > /tmp/agent_admin_cron_new
printf '%s\n' '* * * * * /home/agent-admin/agent-app/bin/monitor.sh' >> /tmp/agent_admin_cron_new
crontab -u agent-admin /tmp/agent_admin_cron_new

# 검증
crontab -u agent-admin -l
wc -l /var/log/agent-app/monitor.log
sleep 70
wc -l /var/log/agent-app/monitor.log
```

검증 결과(실제 출력):

```text
CRON:
* * * * * /home/agent-admin/agent-app/bin/monitor.sh
BEFORE:
128 /var/log/agent-app/monitor.log
AFTER:
129 /var/log/agent-app/monitor.log
```

---

### 단위 F. 보너스 구현

#### F-1. report.sh (요약 리포트 자동 생성)

- 파일: `./report.sh`
- 배포: `/home/agent-admin/agent-app/bin/report.sh`
- 기능:
  - `monitor.log`의 CPU/MEM/DISK 평균/최대/최소/샘플 수 출력
  - 인자:
    - 1번째: 로그 파일 경로(기본 `/var/log/agent-app/monitor.log`)
    - 2번째: 시작 시각(선택, `YYYY-MM-DD HH:MM:SS`)
    - 3번째: 종료 시각(선택, `YYYY-MM-DD HH:MM:SS`)

실행 예시:

```bash
/home/agent-admin/agent-app/bin/report.sh /var/log/agent-app/monitor.log
```

실행 결과(실제 출력):

```text
====== STATISTICS REPORT ======
[CPU]
Average : 0.65%
Maximum : 1.40% at 2026-05-24 13:07:02
Minimum : 0.00% at 2026-05-24 13:55:02
[Memory]
Average : 6.99%
Maximum : 7.10% at 2026-05-24 13:18:02
Minimum : 5.40% at 2026-05-24 13:12:02
[Disk]
Average : 1.00%
Maximum : 1.00% at 2026-05-24 13:04:31
Minimum : 1.00% at 2026-05-24 13:04:31
[Samples]
Data Points: 138 samples
```

배포 명령어:

```bash
# root에서 실행
cp /mnt/c/Users/adohi/Desktop/Codyssey_01/report.sh /home/agent-admin/agent-app/bin/report.sh
sed -i 's/\r$//' /home/agent-admin/agent-app/bin/report.sh
chown agent-dev:agent-core /home/agent-admin/agent-app/bin/report.sh
chmod 750 /home/agent-admin/agent-app/bin/report.sh
```

#### F-2. log_retention.sh (시간 기반 보존 정책)

- 파일: `./log_retention.sh`
- 배포: `/home/agent-admin/agent-app/bin/log_retention.sh`
- 기능:
  - 7일 지난 `*.log` 압축(`gzip`) 후 아카이브 이동
  - 아카이브 경로: `/var/log/monitor/agent-app/archive/`
  - 30일 지난 `*.gz` 아카이브 삭제
- 안전 종료/경고 처리:
  - 디렉토리 미존재
  - 권한 부족
  - 대상 파일 없음

실행 예시:

```bash
/home/agent-admin/agent-app/bin/log_retention.sh
```

실행 결과(실제 출력):

```text
[INFO] log retention completed safely
```

아카이브 이동/삭제 검증(테스트 파일 기반):

```text
=== BEFORE ===
-rw-r--r-- 1 agent-admin agent-core   9052 ... monitor.log
-rw-r--r-- 1 root        agent-core     27 ... retention_test_case2.log
-rw-r--r-- 1 root        agent-core     51 ... retention_test_case2_archive.log.gz

=== SCRIPT OUTPUT ===
[INFO] log retention completed safely

=== AFTER ===
-rw-r--r-- 1 agent-admin agent-core   9052 ... monitor.log
-rw-r--r-- 1 agent-admin agent-core     72 ... retention_test_case2.log.gz
```

해석:

- `retention_test_case2.log`(7일+ 경과) -> 압축되어 `retention_test_case2.log.gz`로 archive에 이동됨
- `retention_test_case2_archive.log.gz`(30일+ 경과) -> 삭제됨
- 상세 원문은 `artifacts/log_retention.evidence.txt` 파일에 보관

배포/사전 준비 명령어:

```bash
# root에서 실행
cp /mnt/c/Users/adohi/Desktop/Codyssey_01/log_retention.sh /home/agent-admin/agent-app/bin/log_retention.sh
sed -i 's/\r$//' /home/agent-admin/agent-app/bin/log_retention.sh
chown agent-dev:agent-core /home/agent-admin/agent-app/bin/log_retention.sh
chmod 750 /home/agent-admin/agent-app/bin/log_retention.sh

# 아카이브 경로 권한 준비
install -d -m 2770 -o agent-admin -g agent-core /var/log/monitor/agent-app/archive
```

---

## 4) 필수 증거 체크리스트

- SSH 20022 변경 + Root 원격 접속 차단: 확인 완료
- 방화벽 활성화 + 20022/15034만 허용: 확인 완료
- 계정/그룹(agent-admin/dev/test, agent-common/core): 확인 완료
- 디렉토리/권한/ACL: 확인 완료
- Boot Sequence 5단계 + Agent READY: 확인 완료
- monitor.sh 실행(프로세스/포트/리소스/경고): 확인 완료
- `/var/log/agent-app/monitor.log` 누적 기록: 확인 완료
- `agent-admin` crontab 매분 등록 + 1분 후 로그 증가: 확인 완료
- `report.sh` 리포트 출력: 확인 완료
- `log_retention.sh` 안전 종료/정책 동작: 확인 완료

---

## 5) 재현 절차(처음부터 다시 할 때)

1. `agent-app.zip` 압축 해제 후 실행 파일 준비
2. SSH/UFW/ACL 설치 및 보안 정책 적용
3. 계정/그룹/디렉토리/ACL 생성
4. 환경 변수와 `secret.key` 생성
5. `agent-admin`으로 앱 기동해 `Agent READY` 확인
6. `monitor.sh` 배포(소유자/권한 맞춤)
7. 수동 실행 후 `monitor.log` 생성 확인
8. `agent-admin` crontab 매분 등록
9. 1~2분 후 로그 자동 증가 확인
10. (보너스) `report.sh`로 요약 통계 출력 확인
11. (보너스) `log_retention.sh`로 보존 정책 동작 확인

---

## 6) 제출 파일

- 수행 내역서: `README.md`
- 자동화 스크립트: `monitor.sh`
- 보너스 스크립트(리포트): `report.sh`
- 보너스 스크립트(보존 정책): `log_retention.sh`

---

## 7) 과제 목표 설명(내가 이해한 내용)

### 1. SSH 포트 변경 + Root 원격 접속 차단이 기본 보안인 이유

- 기본 포트와 기본 계정은 자동화 공격의 1차 표적이 되기 쉽습니다.
- SSH 포트 변경은 보안을 완성하는 조치는 아니지만, 단순 스캔/무차별 시도 노출을 줄이는 1차 완화책입니다.
- root 직접 원격 접속 허용은 계정 탈취 시 피해 범위를 시스템 전체로 즉시 확장시킵니다.
- 따라서 원격 접속은 일반 계정으로 받고, 권한 상승은 필요 시점에만 수행하는 방식이 운영 표준에 가깝습니다.

### 2. 방화벽에서 “필요 포트만 허용”이 중요한 이유

- 방화벽 운영의 기본 원칙은 “기본 거부(Default Deny) + 필요한 포트만 허용”입니다.
- 이 방식은 서비스 노출 면적을 최소화하고, 의도하지 않은 데몬/테스트 포트 공개를 예방합니다.
- 정책은 단순해야 검증과 감사가 쉬워집니다(허용 목록이 곧 운영 문서 역할 수행).
- 실제 적용은 상태 명령(UFW/firewalld)으로 주기적으로 확인해야 정책과 현실의 불일치를 줄일 수 있습니다.

### 3. 계정/그룹/ACL로 공유 디렉토리와 보안 디렉토리를 분리하는 이유

- 운영 환경은 역할이 다른 사용자가 동시에 접근하므로, 권한을 동일하게 주면 사고 확률이 급격히 높아집니다.
- 공유 영역과 민감 영역을 분리하면 협업 효율과 보안 통제가 동시에 좋아집니다.
- 그룹 기반 권한은 운영 정책을 단순하게 유지하고, 인원 변경 시 유지보수 비용을 낮춥니다.
- ACL은 기본 퍼미션만으로 어려운 세밀 제어(특정 그룹 추가 권한 등)를 보완하는 실무 도구입니다.

### 4. 환경 변수로 실행 환경을 고정하는 이유와 검증 방법

- 실행 경로/포트/키 위치를 환경 변수로 분리하면 배포 대상(개발/스테이징/운영)이 바뀌어도 코드 수정 없이 설정만 교체할 수 있습니다.
- 하드코딩을 줄이면 “로컬에서는 동작하지만 서버에서는 실패” 같은 환경 의존 오류를 크게 줄일 수 있습니다.
- 핵심 변수는 시작 시점에 반드시 검증되어야 하며, 실패 시 즉시 원인(누락/오타/권한/경로 오류)을 식별할 수 있어야 합니다.
- 실무 검증은 보통 아래 순서로 진행합니다.
  - 1) **변수 값 자체 확인**: 실행 계정 컨텍스트에서 `env | grep '^AGENT_'`로 실제 주입값 확인
  - 2) **부트 단계 검증 확인**: 애플리케이션 부트 로그에서 환경 변수 체크 단계([2/5] 등) 성공 여부 확인
  - 3) **의존 파일 검증 확인**: 키 파일/디렉토리 단계([3/5] 등) 성공 여부 확인
  - 4) **런타임 상태 검증**: `ss -tulnp`로 기대 포트 LISTEN, 필요 시 `access/open` 로그(strace 등)로 실제 경로 접근 확인
- 즉, “설정값 확인 -> 앱 내부 검증 -> OS 레벨 상태 검증” 3중 확인을 해야 환경 고정이 제대로 되었다고 볼 수 있습니다.

### 5. 관제 스크립트 + 로그 기록으로 장애 추적이 쉬워지는 이유

- 관제의 핵심은 “현재 생존 여부 확인”과 “시간축 데이터 축적”을 동시에 수행하는 것입니다.
- 로그가 있으면 장애를 **언제/무엇이/어떻게**의 관점으로 분해할 수 있어 추적 난이도가 크게 내려갑니다.
  - **언제**: 타임스탬프로 장애 시작 시점과 지속 시간을 특정
  - **무엇이**: 프로세스/포트/리소스 중 어떤 지표가 먼저 비정상화됐는지 식별
  - **어떻게**: CPU 급등 -> 포트 미응답 같은 선후관계를 확인
- 주기 로그가 없으면 특정 순간 상태를 복원할 수 없어 원인 분석이 추정(감)에 의존하게 됩니다.
- 반대로 누적 로그가 있으면
  - 장애 직전 패턴(메모리 점진 증가, 디스크 급증 등) 탐지
  - 동일 패턴 재발 여부 비교
  - 대응 조치 전/후 효과(튜닝, 배포, 정책 변경) 검증
  이 가능해집니다.
- 결국 관제 로그는 단순 기록이 아니라, 장애 복구 속도(MTTR) 단축과 재발 방지 품질을 높이는 운영 데이터입니다.

### 6. crontab 주기 실행 + 로그 보존 정책이 필요한 이유

- 수동 점검은 공백 시간이 생기기 때문에, 운영 신뢰성을 위해 주기 실행 자동화가 필요합니다.
- 주기 데이터가 있어야 특정 시간대 이슈를 재구성하고, 성능 추세를 비교할 수 있습니다.
- 로그는 자산이지만 무제한 저장하면 장애 원인이 되므로 보존 정책(용량/기간 기준)이 필수입니다.
- 실무에서는 로테이션, 압축, 보존기간, 삭제 기준을 함께 설계해 운영 비용과 분석 가치를 균형화합니다.

---

## 8) 트러블슈팅 (문서-실행 불일치 분석 포함)

### 이슈 1. `AGENT_KEY_PATH` 문서값 그대로 적용 시 부트 실패

- 증상:
  - 문서처럼 `AGENT_KEY_PATH=/home/.../api_keys/t_secret.key`로 설정하면 Boot Sequence [2/5]에서 실패
  - 메시지: `Key Path Mismatch. Expected: /home/agent-admin/agent-app/api_keys`
- 원인:
  - 제공 문서는 `AGENT_KEY_PATH`를 파일 경로처럼 안내하지만, 실제 앱은 디렉토리 경로를 기대
- 조치:
  - `AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys`로 보정

### 이슈 2. 파일명 불일치 (`t_secret.key` vs `secret.key`)

- 증상:
  - `AGENT_KEY_PATH`를 디렉토리로 수정한 뒤 Boot Sequence [3/5]에서 실패
  - 메시지: `Missing File: secret.key`
- 원인:
  - 앱 내부 검증 로직이 `secret.key` 파일명으로 고정돼 있음
- 조치:
  - `/home/agent-admin/agent-app/api_keys/secret.key` 생성
  - 파일 내용 `agent_api_key_test` 입력

### 정적 분석 시도 결과

- `file /home/agent-admin/agent-app/agent_app` 결과:
  - `ELF 64-bit ... stripped`
- `strings`로 핵심 문자열을 추출하려 했지만 정보가 제한적이었음
- 해석:
  - stripped 바이너리라 정적 문자열 기반 역분석만으로는 한계

### 동적 분석(`strace`)으로 최종 확인

- 실행 명령어:

```bash
# root에서 실행 (필요 시)
apt-get install -y strace

# 일반 계정 컨텍스트에서 앱 실행 + 파일 접근 추적
runuser -u agent-admin -- bash -lc 'source /etc/profile.d/agent-app.sh; timeout 6s strace -f -e trace=openat,access /home/agent-admin/agent-app/agent_app'
```

- 핵심 근거(실제 추적):

```text
access("/home/agent-admin/agent-app/api_keys/secret.key", R_OK) = 0
openat(AT_FDCWD, "/home/agent-admin/agent-app/api_keys/secret.key", O_RDONLY|O_CLOEXEC) = 3
...
[2/5] Verifying Environment Variables     [OK]
[3/5] Checking Required Files             [OK]
... Verified 'secret.key' with correct key string.
```

### 결론

- `AGENT_KEY_PATH`는 **키 파일 경로가 아니라 키 디렉토리 경로**를 넣어야 한다.
- 앱은 해당 디렉토리에서 **`secret.key`** 파일을 찾는다.
- 따라서 본 과제 최종 적용값은 아래가 정답 동작 조합이다.
  - `AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys`
  - `/home/agent-admin/agent-app/api_keys/secret.key`
  - 파일 내용: `agent_api_key_test`

---

## 9) WSL(Ubuntu)에서 클론 후 재현 절차

아래 순서대로 하면 동일 환경에서 재현할 수 있습니다.

### 1. WSL 진입 및 레포 클론

```bash
wsl -d Ubuntu
cd ~
git clone https://github.com/ADOHI/Codyssey_01.git
cd Codyssey_01
chmod +x monitor.sh report.sh log_retention.sh
```

### 2. 제공 앱 준비

이 레포에는 제공 앱 바이너리가 포함되어 있지 않습니다.  
제공된 `agent-app.zip`을 별도로 준비하여 `agent_app` 실행 파일을 배치해야 합니다.

```bash
# 예시: 이미 /mnt/c/Users/... 경로에 압축을 풀어둔 경우
sudo cp /mnt/c/Users/adohi/Desktop/Codyssey_01/agent-app-src/agent-app-linux-x86 /home/agent-admin/agent-app/agent_app
sudo chown agent-admin:agent-core /home/agent-admin/agent-app/agent_app
sudo chmod 750 /home/agent-admin/agent-app/agent_app
```

### 3. 스크립트 배포

```bash
sudo install -d -m 750 -o agent-dev -g agent-core /home/agent-admin/agent-app/bin
sudo cp monitor.sh /home/agent-admin/agent-app/bin/monitor.sh
sudo cp report.sh /home/agent-admin/agent-app/bin/report.sh
sudo cp log_retention.sh /home/agent-admin/agent-app/bin/log_retention.sh
sudo chown agent-dev:agent-core /home/agent-admin/agent-app/bin/*.sh
sudo chmod 750 /home/agent-admin/agent-app/bin/*.sh
```

### 4. 앱 실행 및 리슨 확인

```bash
sudo runuser -u agent-admin -- bash -lc 'source /etc/profile.d/agent-app.sh; /home/agent-admin/agent-app/agent_app'
ss -tulnp | awk '/:15034/ {print}'
```

### 5. 모니터링/로그/크론 확인

```bash
sudo runuser -u agent-admin -- bash -lc '/home/agent-admin/agent-app/bin/monitor.sh'
sudo tail -n 5 /var/log/agent-app/monitor.log
sudo crontab -u agent-admin -l
```

### 참고: WSL에서 git 커밋할 때

WSL 내부에서 직접 커밋하려면 사용자 정보를 1회 설정합니다.

```bash
git config --global user.name "YOUR_NAME"
git config --global user.email "YOUR_EMAIL"
```

---

## 10) 보완 설명

아래 항목은 최종평가에서 Fail로 지적된 포인트를 보완하기 위한 설명입니다.

### A. 로그 용량 관리(10MB/10개)를 어떻게 구현했는가? (기준 8, 12)

- 구현 방식은 `logrotate`가 아니라 **`monitor.sh` 내부 로직**입니다.
- `rotate_logs()` 함수에서 `stat -c '%s' "$LOG_FILE"`로 현재 로그 크기를 확인합니다.
- 크기가 `MAX_BYTES(10MB)` 이상이면 회전:
  - 가장 오래된 `monitor.log.10` 삭제
  - `monitor.log.9 -> .10`, `monitor.log.8 -> .9` ... 식으로 뒤로 밀기
  - 현재 `monitor.log`를 `monitor.log.1`로 이동
  - 새 `monitor.log` 파일 생성
- 즉, 파일 개수는 최대 10개(`.1`~`.10`)로 제한되고, 용량 초과 시 자동 순환합니다.

### B. 프로세스/포트 확인에 어떤 명령을 썼고 왜 선택했는가? (기준 9)

- 프로세스 확인: `pgrep -f "$APP_PATTERN"`
  - `ps`와 차이: `ps`는 "목록 조회" 중심이라 결과를 다시 `grep/awk`로 후처리해야 하는 경우가 많음
  - `pgrep`은 "찾기 전용"이라 조건에 맞는 PID만 바로 반환해 조건문 처리(`if`, `exit`)가 단순함
  - 이유: 전체 커맨드라인 기준(-f)으로 패턴 매칭이 가능해 `agent_app`/`agent_app.py` 모두 대응 가능
  - 이유: PID를 바로 얻어 로그 포맷(`PID:...`)과 헬스체크 성공/실패 판단에 즉시 재사용 가능
- 포트 확인: `ss -tuln | awk ...`
  - `netstat`와 차이: `netstat`는 `net-tools` 패키지 의존이 많고, 최신 환경에서는 기본 미설치인 경우가 잦음
  - `ss`는 `iproute2` 계열 도구로 최신 리눅스 표준에 가깝고 대량 소켓 조회 성능이 일반적으로 더 좋음
  - 이유: `tcp + LISTEN + :15034` 조건을 정확히 필터링해 Health Check 실패 여부를 명확히 결정 가능
  - 이유: 스크립트 자동화에서 출력 포맷이 비교적 일관적이라 `awk` 파싱 안정성이 높음

### C. CPU/MEM/DISK 추출/파싱 방식과 로그 포맷 이유 (기준 10)

- CPU:
  - `/proc/stat`를 1초 간격으로 2번 읽고, 총 틱/유휴 틱 증분으로 사용률 계산
  - 순간 스냅샷보다 증분 방식이 실제 점유율에 가깝습니다.
- MEM:
  - `free`의 `Mem:` 행에서 `used/total * 100`으로 계산
- DISK:
  - `df -P /`의 루트 파티션(`NR==2`) 사용률(`%`) 파싱
- 로그 포맷 고정 이유:
  - `[timestamp] PID CPU MEM DISK_USED` 순서로 남기면 사람이 읽기 쉽고, 후처리(awk/grep/report.sh)도 단순해집니다.
  - 포맷을 고정해야 자동 리포트(`report.sh`) 파싱 안정성이 유지됩니다.

### D. 소유자/권한(agent-dev, 750)이 정책을 어떻게 만족하는가? (기준 11)

- 파일: `/home/agent-admin/agent-app/bin/monitor.sh`
- 권한: `750 (rwxr-x---)`
  - 소유자(`agent-dev`)는 읽기/쓰기/실행 가능 -> 스크립트 작성/수정 담당
  - 그룹(`agent-core`)은 읽기/실행 가능 -> `agent-admin`이 그룹 소속으로 실행 가능
  - 기타 사용자 권한 없음 -> 최소 권한 원칙 충족
- 즉, “개발자가 수정, 운영 계정이 실행, 그 외 차단” 구조를 권한 한 줄로 보장합니다.

### E. `>` 와 `>>` 차이 (로그 누적 관점) (기준 16)

- `>` : 파일 **덮어쓰기(초기화)** 후 기록
  - 매번 이전 로그가 사라져 추적성이 깨짐
- `>>` : 파일 **뒤에 이어쓰기(누적)**
  - 시계열 기록이 유지되어 장애 전후 분석 가능
- 본 과제에서 `monitor.log`는 운영 추적 목적이므로 `>>`를 사용했습니다.

### F. 모니터링 대상을 웹 서버로 바꾸면 무엇을 변경해야 하는가? (기준 17)

- 바꿔야 할 핵심 파라미터:
  - 프로세스 패턴: `APP_PATTERN` (예: `nginx|apache2`)
  - 포트: `AGENT_PORT` (예: 80, 443, 8080)
- 나머지 로직(CPU/MEM/DISK 수집, 임계치 경고, 로그 기록, 로테이션)은 재사용 가능
- 즉, **대상 서비스 식별자(프로세스명/포트)만 교체**하면 같은 틀로 웹 서버 관제가 가능합니다.

### G. “프로세스는 살아있는데 포트가 안 열림” 트러블슈팅 순서 (기준 18)

- 1단계: 프로세스 상태 확인
  - `pgrep -af <프로세스패턴>`
- 2단계: 실제 리슨 포트 확인
  - `ss -tulnp | grep <포트>`
- 3단계: 앱 로그 확인
  - 바인드 실패(`Address already in use`), 권한 오류, 설정/환경 변수 오류 탐색
- 4단계: 포트 충돌 확인
  - 다른 프로세스가 해당 포트를 선점했는지 확인
- 5단계: 방화벽/보안 정책 확인
  - 로컬 리슨은 됐는데 외부 접근만 안 되면 방화벽/UFW 규칙 점검
- 주요 원인 후보:
  - 잘못된 바인드 주소(127.0.0.1만 바인드)
  - 포트 중복 점유
  - 시작 직후 크래시(프로세스 잔존처럼 보여도 워커 실패)
  - 환경 변수 오설정으로 앱이 다른 포트로 기동

---

## 11) 리눅스 명령어/옵션 정리 (과제 사용 기준)

리눅스가 익숙하지 않아서, 이번 과제에서 실제로 사용한 명령어를 목적별로 정리했습니다.

### A. 서비스/시스템 관리

- `systemctl enable --now <service>`
  - **의미**: 부팅 시 자동 시작 등록 + 지금 즉시 시작
  - **옵션**
    - `enable`: 부팅 자동 시작
    - `--now`: 현재 세션에서도 즉시 start 수행
- `systemctl disable --now <service>`
  - **의미**: 자동 시작 해제 + 즉시 중지
- `systemctl is-active --quiet <service>`
  - **의미**: 서비스 활성 여부 확인(출력 최소)
  - **옵션**
    - `--quiet`: 텍스트 출력 대신 종료코드로 판단

### B. 계정/그룹/권한

- `useradd -m -s /bin/bash <user>`
  - **의미**: 사용자 생성 + 홈 디렉토리 생성 + 기본 셸 지정
  - **옵션**
    - `-m`: 홈 디렉토리 생성
    - `-s`: 로그인 셸 지정
- `groupadd -f <group>`
  - **의미**: 그룹 생성(이미 있으면 오류 없이 통과)
  - **옵션**
    - `-f`: 존재 시 실패하지 않음
- `usermod -aG <group> <user>`
  - **의미**: 사용자를 보조 그룹에 추가
  - **옵션**
    - `-a`: 기존 그룹 유지(append)
    - `-G`: 보조 그룹 설정
- `id <user>`
  - **의미**: UID/GID/소속 그룹 확인
- `chown <owner>:<group> <path>`
  - **의미**: 파일/디렉토리 소유자/그룹 변경
- `chmod 750 <path>`
  - **의미**: 소유자 `rwx`, 그룹 `r-x`, 기타 `---`

### C. 디렉토리/ACL

- `install -d -m 2770 -o <owner> -g <group> <dir>`
  - **의미**: 디렉토리 생성 + 권한/소유자/그룹을 한 번에 설정
  - **옵션**
    - `-d`: 디렉토리 생성
    - `-m`: 권한(mode) 지정
    - `-o`: owner 지정
    - `-g`: group 지정
- `setfacl -m g:<group>:rwx <path>`
  - **의미**: ACL로 특정 그룹 권한 추가/수정
  - **옵션**
    - `-m`: ACL 엔트리 modify
- `getfacl -p <path>`
  - **의미**: ACL 상세 조회
  - **옵션**
    - `-p`: 절대경로 형태로 표시

### D. 파일 편집/치환

- `sed -i -E 's/old/new/' <file>`
  - **의미**: 정규식 치환을 파일에 직접 반영
  - **옵션**
    - `-i`: 파일 직접 수정(in-place)
    - `-E`: 확장 정규식 사용
- `cat > <file> <<'EOF' ... EOF`
  - **의미**: 여러 줄 내용을 파일로 저장(설정파일 작성 시 유용)
- `printf '%s\n' 'text' > file`
  - **의미**: 파일 생성/덮어쓰기
- `printf '%s\n' 'text' >> file`
  - **의미**: 파일 뒤에 이어쓰기(누적 로그)

### E. 프로세스/포트/리소스 확인

- `pgrep -f <pattern>`
  - **의미**: 명령행 전체에서 프로세스 패턴 검색
  - **왜 사용**: `ps | grep`보다 조건문에 바로 쓰기 쉬운 PID 반환형
  - **`ps`와 차이**
    - `pgrep`: "찾기/판정" 중심 (매칭 PID만 반환)
    - `ps`: "조회/진단" 중심 (전체 목록을 사람이 읽기 좋게 출력)
  - **옵션**
    - `-f`: 실행 파일명뿐 아니라 전체 커맨드라인 매칭
- `pkill -f <pattern>`
  - **의미**: 패턴 매칭 프로세스 종료
- `ps -ef`
  - **의미**: 전체 프로세스 상세 보기
  - **언제 사용**: 장애 분석 시 부모/자식 관계(PPID), 실행 경로(CMD)까지 확인할 때
  - **옵션**
    - `-e`: 모든 프로세스
    - `-f`: 풀 포맷(UID, PID, PPID, CMD 등)
- `ss -tulnp`
  - **의미**: 소켓/포트 LISTEN 상태 확인
  - **왜 사용**: 최신 리눅스 표준 도구이며 `netstat` 대비 기본 가용성과 성능이 유리한 경우가 많음
  - **`netstat`와 차이**
    - `ss`: iproute2 기반, 최신 환경 친화적
    - `netstat`: net-tools 기반, 일부 배포판에서 기본 미설치
  - **옵션**
    - `-t`: TCP
    - `-u`: UDP
    - `-l`: LISTEN 소켓
    - `-n`: 숫자 포맷(포트/주소)
    - `-p`: 프로세스 정보 표시
- `free`
  - **의미**: 메모리 사용량 확인
- `df -P /`
  - **의미**: 루트 파티션 디스크 사용량 확인
  - **옵션**
    - `-P`: POSIX 형식(파싱 안정성)

### F. 로그/파일 처리

- `stat -c '%s' <file>`
  - **의미**: 파일 크기(바이트) 확인
- `mv old new`
  - **의미**: 파일 이동/이름변경(로그 로테이션에 활용)
- `tac <file> | sed -n '1,20p' | tac`
  - **의미**: 파일의 마지막 20줄 추출(순서 보존)
- `tail -n 5 <file>`
  - **의미**: 마지막 N줄 확인
  - **옵션**
    - `-n`: 줄 수 지정

### G. Cron/스케줄링

- `crontab -u <user> -l`
  - **의미**: 특정 사용자 cron 목록 조회
  - **옵션**
    - `-u`: 대상 사용자 지정
    - `-l`: 목록 출력(list)
- `crontab -u <user> <file>`
  - **의미**: 파일 내용을 해당 사용자 cron으로 등록
- `* * * * * <command>`
  - **의미**: 매분 실행
  - **형식**: 분 시 일 월 요일 명령

### H. 방화벽/네트워크

- `ufw default deny incoming`
  - **의미**: 인바운드 기본 거부
- `ufw default allow outgoing`
  - **의미**: 아웃바운드 기본 허용
- `ufw allow 20022/tcp`
  - **의미**: 특정 포트/프로토콜 허용
- `ufw status`
  - **의미**: 현재 규칙 상태 확인

### I. 실행 사용자 전환

- `runuser -u <user> -- bash -lc '<cmd>'`
  - **의미**: 지정 사용자 컨텍스트에서 명령 실행
  - **옵션**
    - `-u`: 실행 사용자 지정
    - `--`: runuser 옵션 종료
    - `bash -lc`: 로그인 셸 환경으로 명령 실행

### J. awk (텍스트 파싱 핵심)

- `awk`는 “열(컬럼) 기반 필터링 + 조건 분기 + 출력 포맷팅”에 강한 도구입니다.
- 이 과제에서는 주로 `ss`, `df`, `free`, 로그 라인 파싱에 사용했습니다.
- 기본 패턴:
  - `awk '조건 {동작}'`
  - 조건이 참인 줄에서만 동작을 수행

- 예시 1: SSH/앱 포트 라인만 출력
  - `ss -tulnp | awk '/:20022|:15034/ {print}'`
  - `/regex/`는 해당 패턴이 포함된 줄만 통과

- 예시 2: 루트 파티션 사용률만 추출
  - `df -P / | awk 'NR==2 {gsub("%","",$5); print $5}'`
  - `NR==2`: 두 번째 줄만 처리
  - `gsub("%","",$5)`: `%` 문자 제거
  - `print $5`: 5번째 컬럼(사용률) 출력

- 예시 3: 포트 LISTEN 여부 판정(종료코드 활용)
  - `ss -tuln | awk -v p=":15034" '$1=="tcp" && $2=="LISTEN" && index($5,p)>0 {found=1} END{exit !found}'`
  - `-v p=":15034"`: 쉘 변수를 awk 변수로 전달
  - `index($5,p)>0`: 5번째 컬럼에 포트 문자열 포함 여부
  - `END{exit !found}`: 찾으면 0, 못 찾으면 1로 종료하여 if 조건에 사용 가능

- 예시 4: 실수 비교(`a > b`)를 쉘에서 사용
  - `awk -v a="$CPU_USAGE" -v b="$CPU_WARN" 'BEGIN {exit !(a>b)}'`
  - bash의 문자열 비교 대신 awk 숫자 비교를 사용해 임계치 판단 정확도를 높임

- 자주 쓰는 awk 내장 변수
  - `NR`: 현재까지 읽은 전체 줄 번호
  - `$1`, `$2` ...: 공백 기준 컬럼
  - `$0`: 현재 줄 전체
