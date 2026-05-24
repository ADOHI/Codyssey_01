# Codyssey_01 - 시스템 관제 자동화 스크립트 개발 수행 내역서

이 문서는 과제 요구사항을 **초심자도 재현 가능하도록** 순서대로 기록한 수행 내역서입니다.  
환경 구성 -> 보안 설정 -> 계정/권한 -> 앱 실행 -> 관제 스크립트 -> cron 자동화 -> 보너스 구현 순으로 진행했습니다.

---

## 1) 작업 환경

- 호스트: Windows 10 + WSL2
- 리눅스 환경: Ubuntu (systemd 활성, 과제의 "Ubuntu 22.04 또는 동등 환경" 조건 충족)
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

## 7) 과제 목표 설명(학습자 관점)

### 1. SSH 포트 변경 + Root 원격 접속 차단이 기본 보안인 이유

- 기본 SSH 포트(22)는 자동 스캔 대상이 되기 쉬워 무차별 대입 공격 시도가 많습니다.
- 포트를 변경하면 공격 표면을 줄일 수 있고, 불필요한 자동화 공격 로그를 감소시킬 수 있습니다.
- Root 계정 원격 로그인 허용은 계정 탈취 시 즉시 시스템 전체 권한을 넘겨주는 구조라 위험합니다.
- 따라서 `PermitRootLogin no`로 막고, 일반 계정 로그인 후 필요한 작업만 `sudo`로 수행하는 방식이 안전합니다.

### 2. 방화벽에서 “필요 포트만 허용”이 중요한 이유

- 방화벽의 핵심은 “허용할 것만 열고 나머지는 막는 것(기본 거부)”입니다.
- 이 과제에서는 SSH(`20022/tcp`)와 앱 포트(`15034/tcp`)만 열어 외부 노출 면적을 최소화했습니다.
- 이렇게 하면 우연히 실행된 다른 서비스 포트가 외부에 노출되는 사고를 줄일 수 있습니다.
- 검증은 `ufw status`(또는 firewalld 사용 시 `firewall-cmd --list-all`)로 실제 적용 상태를 확인합니다.

### 3. 계정/그룹/ACL로 공유 디렉토리와 보안 디렉토리를 분리하는 이유

- 모든 사용자가 같은 권한을 가지면, 실수나 오남용으로 민감 파일이 쉽게 훼손될 수 있습니다.
- `upload_files`는 협업 대상이므로 `agent-common` 그룹에 읽기/쓰기를 허용했습니다.
- `api_keys`, `/var/log/agent-app`는 민감 영역이므로 `agent-core`만 접근 가능하게 분리했습니다.
- ACL(`setfacl`, `getfacl`)을 사용하면 기본 퍼미션만으로 부족한 세밀한 권한 제어가 가능합니다.

### 4. 환경 변수로 실행 환경을 고정하는 이유와 검증 방법

- 실행 경로/포트/키 경로를 코드 밖(환경 변수)에서 관리하면 재배포/이관 시 수정 포인트가 줄어듭니다.
- 운영 중 경로 하드코딩을 줄이면 사람마다 다른 실행 위치에서 생기는 오류를 예방할 수 있습니다.
- `AGENT_HOME`, `AGENT_PORT`, `AGENT_KEY_PATH` 같은 값을 고정하면 부팅 점검에서 일관성 있게 검증됩니다.
- 검증은 앱 부트 시퀀스 로그([2/5], [3/5])와 `ss -tulnp` 포트 상태로 확인할 수 있습니다.

### 5. 관제 스크립트 + 로그 기록으로 장애 추적이 쉬워지는 이유

- 관제 스크립트는 “지금 정상인지”를 빠르게 판단하는 Health Check(프로세스/포트)를 제공합니다.
- CPU/MEM/DISK를 주기적으로 남기면 장애 시점 전후의 상태 변화를 근거로 원인 분석이 가능합니다.
- 단순 콘솔 출력은 휘발되므로, `monitor.log`처럼 누적 로그를 남겨야 사후 분석이 가능합니다.
- 즉, 관제 흐름은 “수집 -> 임계치 경고 -> 기록 -> 추적/분석”의 반복 구조입니다.

### 6. crontab 주기 실행 + 로그 보존 정책이 필요한 이유

- 수동 실행만으로는 야간/부재 시간대 상태를 놓치므로, cron으로 자동 주기 실행이 필요합니다.
- 매분 실행으로 시계열 데이터가 쌓이면, 특정 시간대 문제를 정확히 재구성할 수 있습니다.
- 로그를 무한히 쌓으면 디스크를 압박하므로, 로테이션/압축/삭제 정책이 필수입니다.
- 이 과제에서는 `monitor.sh`의 용량 기반 로테이션과 `log_retention.sh`의 시간 기반 보존 정책을 함께 적용했습니다.

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
