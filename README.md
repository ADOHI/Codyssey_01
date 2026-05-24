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

검증 결과(요약):

- `upload_files` -> group `agent-common`, ACL `group:agent-common:rwx`
- `api_keys` -> group `agent-core`, ACL `group:agent-core:rwx`
- `/var/log/agent-app` -> group `agent-core`, ACL `group:agent-core:rwx`

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
