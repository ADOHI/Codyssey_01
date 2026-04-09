# Codyssey Assignment 01
## 프로젝트 개요
터미널 조작법 습득

Docker 기본 활용법 습득

Git 기본 활용법 습득
## 실행 환경
- OS: macOS 15.7.4
- Shell: zsh
- Docker: 28.5.2
- Git: 2.53.0

## 수행 체크리스트
- [o] 터미널 기본 조작 및 폴더 구성
- [o] 권한 변경 실습
- [o] Docker 설치/점검
- [o] hello-world 실행
- [o] Dockerfile 빌드/실행
- [o] 포트 매핑 접속
- [o] 볼륨 영속성
- [o] Git 설정 + VSCode GitHub 연동

## 1. 터미널 조작 로그 기록
### 1. pwd
    /Users/adohi08243536/Desktop/practice01
### 2. ls -al
    drwxr-xr-x  3 adohi08243536  adohi08243536   96 Apr  9 16:13 .
    drwx------+ 5 adohi08243536  adohi08243536  160 Apr  9 16:13 ..
    drwxr-xr-x  7 adohi08243536  adohi08243536  224 Apr  9 16:13 Codyssey_01       
    권한 / 하드링크 수 / 소유자 / 소유그룹 / 파일크기 / 수정날짜 / 이름
### 3. touch test.txt
### 4. mv test.txt ../testdir2/
    adohi08243536@c4r2s7 Codyssey_01 % cd testdir2
    adohi08243536@c4r2s7 testdir2 % ls
    test.txt
### 5. cp test.txt testcp.txt
    adohi08243536@c4r2s7 testdir2 % ls
    test.txt	testcp.txt
### 6. mv testcp.txt ../testdir1/test.txt
    adohi08243536@c4r2s7 testdir2 % cd ..
    adohi08243536@c4r2s7 Codyssey_01 % cd testdir1
    adohi08243536@c4r2s7 testdir1 % ls
    test.txt
### 7. rm test.txt
    adohi08243536@c4r2s7 testdir1 % ls
    adohi08243536@c4r2s7 testdir1 %
### 8. touch test.txt
### 9. cat test.txt
    This is dummy file
## 2. 권한 실습 및 증거 기록
    adohi08243536@c4r2s7 testdir1 % chmod 000 test.txt 
    ----------  1 adohi08243536  adohi08243536   20 Apr  9 16:42 test.txt

    adohi08243536@c4r2s7 testdir1 % rm test.txt 
    override --------- adohi08243536/adohi08243536 for test.txt? 
    adohi08243536@c4r2s7 testdir1 % ls
    test.txt

    adohi08243536@c4r2s7 testdir1 % vim test.txt
    permission denied

    adohi08243536@c4r2s7 Codyssey_01 % chmod 000 testdir1

    adohi08243536@c4r2s7 Codyssey_01 % cd testdir1
    cd: permission denied: testdir1

    adohi08243536@c4r2s7 Codyssey_01 % rm -r testdir1
    rm: testdir1: Permission denied

    adohi08243536@c4r2s7 Codyssey_01 % mv testdir1 testdir3
    mv: rename testdir1 to testdir3: Permission denied
## 3. 도커 설치 및 기본 점검
    adohi08243536@c4r2s7 Codyssey_01 % docker --version
    Docker version 28.5.2, build ecc6942

    adohi08243536@c4r2s7 Codyssey_01 % docker info
    Client:
    Version:    28.5.2
    Context:    orbstack
    Debug Mode: false
    Plugins:
    buildx: Docker Buildx (Docker Inc.)
        Version:  v0.29.1
        Path:     /Users/adohi08243536/.docker/cli-plugins/docker-buildx
    compose: Docker Compose (Docker Inc.)
        Version:  v2.40.3
        Path:     /Users/adohi08243536/.docker/cli-plugins/docker-compose

    Server:
    Containers: 0
    Running: 0
    Paused: 0
    Stopped: 0
    Images: 0
    Server Version: 28.5.2
    Storage Driver: overlay2
    Backing Filesystem: btrfs
    Supports d_type: true
    Using metacopy: false
    Native Overlay Diff: true
    userxattr: false
    Logging Driver: json-file
    Cgroup Driver: cgroupfs
    Cgroup Version: 2
    Plugins:
    Volume: local
    Network: bridge host ipvlan macvlan null overlay
    Log: awslogs fluentd gcplogs gelf journald json-file local splunk syslog
    CDI spec directories:
    /etc/cdi
    /var/run/cdi
    Swarm: inactive
    Runtimes: runc io.containerd.runc.v2
    Default Runtime: runc
    Init Binary: docker-init
    containerd version: 1c4457e00facac03ce1d75f7b6777a7a851e5c41
    runc version: d842d7719497cc3b774fd71620278ac9e17710e0
    init version: de40ad0
    Security Options:
    seccomp
    Profile: builtin
    cgroupns
    Kernel Version: 6.17.8-orbstack-00308-g8f9c941121b1
    Operating System: OrbStack
    OSType: linux
    Architecture: x86_64
    CPUs: 6
    Total Memory: 15.67GiB
    Name: orbstack
    ID: 758bb59f-2cd2-4fa0-83db-05922e59c199
    Docker Root Dir: /var/lib/docker
    Debug Mode: false
    Experimental: false
    Insecure Registries:
    ::1/128
    127.0.0.0/8
    Live Restore Enabled: false
    Product License: Community Engine
    Default Address Pools:
    Base: 192.168.97.0/24, Size: 24
    Base: 192.168.107.0/24, Size: 24
    Base: 192.168.117.0/24, Size: 24
    Base: 192.168.147.0/24, Size: 24
    Base: 192.168.148.0/24, Size: 24
    Base: 192.168.155.0/24, Size: 24
    Base: 192.168.156.0/24, Size: 24
    Base: 192.168.158.0/24, Size: 24
    Base: 192.168.163.0/24, Size: 24
    Base: 192.168.164.0/24, Size: 24
    Base: 192.168.165.0/24, Size: 24
    Base: 192.168.166.0/24, Size: 24
    Base: 192.168.167.0/24, Size: 24
    Base: 192.168.171.0/24, Size: 24
    Base: 192.168.172.0/24, Size: 24
    Base: 192.168.181.0/24, Size: 24
    Base: 192.168.183.0/24, Size: 24
    Base: 192.168.186.0/24, Size: 24
    Base: 192.168.207.0/24, Size: 24
    Base: 192.168.214.0/24, Size: 24
    Base: 192.168.215.0/24, Size: 24
    Base: 192.168.216.0/24, Size: 24
    Base: 192.168.223.0/24, Size: 24
    Base: 192.168.227.0/24, Size: 24
    Base: 192.168.228.0/24, Size: 24
    Base: 192.168.229.0/24, Size: 24
    Base: 192.168.237.0/24, Size: 24
    Base: 192.168.239.0/24, Size: 24
    Base: 192.168.242.0/24, Size: 24
    Base: 192.168.247.0/24, Size: 24
    Base: fd07:b51a:cc66:d000::/56, Size: 64

    WARNING: DOCKER_INSECURE_NO_IPTABLES_RAW is set
## 4. docker 기본 운영 명령 수행
### 1. docker run
adohi08243536@c4r2s7 Codyssey_01 % docker run -d -p 8080:80 --name test-nginx nginx

Unable to find image 'nginx:latest' locally
latest: Pulling from library/nginx
5435b2dcdf5c: Pull complete 
054715a6bffa: Pull complete 
88d1d984b765: Pull complete 
4a038fd18db1: Pull complete 
84e114c2bb36: Pull complete 
7b5d674621c2: Pull complete 
448ea5cac5d5: Pull complete 
Digest: sha256:7f0adca1fc6c29c8dc49a2e90037a10ba20dc266baaed0988e9fb4d0d8b85ba0
Status: Downloaded newer image for nginx:latest
5e63bfaacf20d9d63fa7008b5878201d4423b2d145ae699544005c6a766ac742
### 2. docker images
adohi08243536@c4r2s7 Codyssey_01 % docker images

REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
nginx        latest    a716c9c12c38   39 hours ago   161MB
### 3. docker logs
adohi08243536@c4r2s7 Codyssey_01 % docker ps

CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                                     NAMES
5e63bfaacf20   nginx     "/docker-entrypoint.…"   58 seconds ago   Up 57 seconds   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   test-nginx
### 4. docker logs
adohi08243536@c4r2s7 Codyssey_01 % docker logs test-nginx 

/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2026/04/09 08:05:32 [notice] 1#1: using the "epoll" event method
2026/04/09 08:05:32 [notice] 1#1: nginx/1.29.8
2026/04/09 08:05:32 [notice] 1#1: built by gcc 14.2.0 (Debian 14.2.0-19) 
2026/04/09 08:05:32 [notice] 1#1: OS: Linux 6.17.8-orbstack-00308-g8f9c941121b1
2026/04/09 08:05:32 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 20480:1048576
2026/04/09 08:05:32 [notice] 1#1: start worker processes
2026/04/09 08:05:32 [notice] 1#1: start worker process 29
2026/04/09 08:05:32 [notice] 1#1: start worker process 30
2026/04/09 08:05:32 [notice] 1#1: start worker process 31
2026/04/09 08:05:32 [notice] 1#1: start worker process 32
2026/04/09 08:05:32 [notice] 1#1: start worker process 33
2026/04/09 08:05:32 [notice] 1#1: start worker process 34
192.168.215.1 - - [09/Apr/2026:08:06:11 +0000] "GET / HTTP/1.1" 200 896 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Safari/605.1.15" "-"
2026/04/09 08:06:11 [error] 29#29: *1 open() "/usr/share/nginx/html/favicon.ico" failed (2: No such file or directory), client: 192.168.215.1, server: localhost, request: "GET /favicon.ico HTTP/1.1", host: "localhost:8080", referrer: "http://localhost:8080/"
192.168.215.1 - - [09/Apr/2026:08:06:11 +0000] "GET /favicon.ico HTTP/1.1" 404 153 "http://localhost:8080/" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Safari/605.1.15" "-"
### 5. docker stats
CONTAINER ID   NAME         CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O        PIDS 

5e63bfaacf20   test-nginx   0.00%     6.258MiB / 15.67GiB   0.04%     3.21kB / 2.06kB   274kB / 8.19kB   7
## 5. 컨테이너 실행 실습
### 1. hello-world
adohi08243536@c4r2s7 Codyssey_01 % docker run hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
4f55086f7dd0: Pull complete 
Digest: sha256:452a468a4bf985040037cb6d5392410206e47db9bf5b7278d281f94d1c2d0931

Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/
 ### 2. ubuntu 실행 및 명령 수행
adohi08243536@c4r2s7 Codyssey_01 % docker run -it --name my-ubuntu ubuntu /bin/bash

Unable to find image 'ubuntu:latest' locally
latest: Pulling from library/ubuntu
689b91d88a0f: Pull complete 
Digest: sha256:84e77dee7d1bc93fb029a45e3c6cb9d8aa4831ccfcc7103d36e876938d28895b
Status: Downloaded newer image for ubuntu:latest

root@f45f41c478f8:/# ls
bin   dev  home  lib64  mnt  proc  run   srv  tmp  var
boot  etc  lib   media  opt  root  sbin  sys  usr

root@f45f41c478f8:/# echo "hello ubuntu"
hello ubuntu

root@f45f41c478f8:/# cat /etc/os-release 

PRETTY_NAME="Ubuntu 24.04.4 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.4 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=noble
LOGO=ubuntu-logo

root@f45f41c478f8:/# exit

exit
### 3. 컨테이너 종료 및 유지
#### attach 후 종료

root@f45f41c478f8:/# exit

exit

adohi08243536@c4r2s7 Codyssey_01 % docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                                     NAMES
5e63bfaacf20   nginx     "/docker-entrypoint.…"   16 minutes ago   Up 16 minutes   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   test-nginx

#### attach 후 탈출

adohi08243536@c4r2s7 Codyssey_01 % docker start my-ubuntu
my-ubuntu

adohi08243536@c4r2s7 Codyssey_01 % docker attach my-ubuntu

root@f45f41c478f8:/# read escape sequence

adohi08243536@c4r2s7 Codyssey_01 % docker ps

CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                                     NAMES
f45f41c478f8   ubuntu    "/bin/bash"              6 minutes ago    Up 20 seconds                                             my-ubuntu
5e63bfaacf20   nginx     "/docker-entrypoint.…"   16 minutes ago   Up 16 minutes   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   test-nginx

### exec 후 종료
adohi08243536@c4r2s7 Codyssey_01 % docker start 

my-ubuntu            
my-ubuntu

adohi08243536@c4r2s7 Codyssey_01 % docker exec -it my-ubuntu /bin/bash

root@f45f41c478f8:/# exit

exit

adohi08243536@c4r2s7 Codyssey_01 % docker ps

CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                                     NAMES
f45f41c478f8   ubuntu    "/bin/bash"              9 minutes ago    Up 36 seconds                                             my-ubuntu
5e63bfaacf20   nginx     "/docker-entrypoint.…"   19 minutes ago   Up 19 minutes   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   test-nginx

## 6. docker 기반 커스텀 이미지 제작
### 1. docker image 선택
선택한 베이스 이미지
Base Image: nginx:stable-alpine

선택 이유: 경량화된 Alpine Linux 기반의 NGINX 이미지를 사용하여 보안성을 높이고 이미지 크기를 최소화하기 위함.

### Dockerfile
```
# 1. 베이스 이미지 지정
FROM nginx:stable-alpine

# 2. 커스텀 포인트: 메타데이터 추가 (관리자 정보)
LABEL maintainer="gemini@example.com"

# 3. 커스텀 포인트: 환경 변수 설정 (기본 언어 설정)
ENV LANG ko_KR.UTF-8

# 4. 커스텀 포인트: 정적 콘텐츠 교체 (기본 페이지를 내 콘텐츠로 대체)
COPY ./index.html /usr/share/nginx/html/index.html

# 5. 커스텀 포인트: 헬스체크 설정 (컨테이너 상태 모니터링)
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost/ || exit 1

# 6. 포트 노출
EXPOSE 80
```

커스텀 포인트 목적: 초기 화면인 index.html을 개인의 것으로 커스터마이징 하기 위함

### 2. 커스텀 이미지 빌드 및 컨테이너 빌드

adohi08243536@c4r2s7 docker-test % docker build -t my-custom-nginx:v1 . 

[+] Building 7.7s (7/7) FINISHED                                docker:orbstack
 => [internal] load build definition from Dockerfile                       0.2s
 => => transferring dockerfile: 638B                                       0.0s
 => [internal] load metadata for docker.io/library/nginx:stable-alpine     2.8s
 => [internal] load .dockerignore                                          0.1s
 => => transferring context: 2B                                            0.0s
 => [internal] load build context                                          0.2s
 => => transferring context: 31B                                           0.0s
 => [1/2] FROM docker.io/library/nginx:stable-alpine@sha256:a8b39bd9cf0f8  3.7s
 => => resolve docker.io/library/nginx:stable-alpine@sha256:a8b39bd9cf0f8  0.2s
 => => sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d 10.32kB / 10.32kB  0.0s
 => => sha256:589002ba0eaed121a1dbf42f6648f29e5be55d5c8a6 3.86MB / 3.86MB  0.5s
 => => sha256:0dcc88822d45581e65ae329f8be769762bf628d3b2b 2.49kB / 2.49kB  0.0s
 => => sha256:dc73b49f5124cf2ee538dfbdfbd121f0b4ccdcb20 12.29kB / 12.29kB  0.0s
 => => sha256:1d9cbdb003be4f77dc59400a5eb400afcac245934b5 1.83MB / 1.83MB  0.8s
 => => sha256:e914c6e98e37815624beb8c5043be292f121898059d4d50 626B / 626B  0.9s
 => => extracting sha256:589002ba0eaed121a1dbf42f6648f29e5be55d5c8a6ee0f8  0.1s
 => => sha256:d631a49fb4f72e5bc609d0af4ce6d3ed054498068dc16c7 956B / 956B  1.0s
 => => extracting sha256:1d9cbdb003be4f77dc59400a5eb400afcac245934b539c7b  0.1s
 => => sha256:8f7c784e247120771f7bdb83b2ab8e17af75af4858332b6 405B / 405B  1.3s
 => => sha256:44fa0a5a779fdf3b85972e8dfb3b2755a72a97290b6 1.21kB / 1.21kB  1.3s
 => => extracting sha256:e914c6e98e37815624beb8c5043be292f121898059d4d50c  0.0s
 => => extracting sha256:d631a49fb4f72e5bc609d0af4ce6d3ed054498068dc16c73  0.0s
 => => sha256:98104829f3fe8d2ead9a69b1f56c1f98955fd2b5933 1.40kB / 1.40kB  1.5s
 => => extracting sha256:8f7c784e247120771f7bdb83b2ab8e17af75af4858332b63  0.0s
 => => sha256:0151c82f84a9c78800cb330f93f88d6ffe39f030e 20.25MB / 20.25MB  2.0s
 => => extracting sha256:44fa0a5a779fdf3b85972e8dfb3b2755a72a97290b682794  0.0s
 => => extracting sha256:98104829f3fe8d2ead9a69b1f56c1f98955fd2b5933f0893  0.0s
 => => extracting sha256:0151c82f84a9c78800cb330f93f88d6ffe39f030ec9a60db  0.4s
 => [2/2] COPY ./index.html /usr/share/nginx/html/index.html               0.2s
 => exporting to image                                                     0.2s
 => => exporting layers                                                    0.1s
 => => writing image sha256:34d9d638f631d9d5135d3b4ba7603239247a750c5bbf5  0.0s
 => => naming to docker.io/library/my-custom-nginx:v1                      0.0s

adohi08243536@c4r2s7 docker-test % docker run -d -p 8080:80 --name my-web-server my-custom-nginx:v1

adohi08243536@c4r2s7 docker-test % docker ps

CONTAINER ID   IMAGE                COMMAND                  CREATED          STATUS                   PORTS                                     NAMES
3a62d0de1cdd   my-custom-nginx:v1   "/docker-entrypoint.…"   6 minutes ago    Up 6 minutes (healthy)   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   my-web-server
f45f41c478f8   ubuntu               "/bin/bash"              35 minutes ago   Up 26 minutes

### 3. 실행 결과
![Docker](./customdocker.png)

### 4. 포트 매핑 및 접속 증거
adohi08243536@c4r2s7 docker-test % curl -I http://localhost:8080

HTTP/1.1 200 OK

Server: nginx/1.28.3

Date: Thu, 09 Apr 2026 09:01:01 GMT

Content-Type: text/html

Content-Length: 407

Last-Modified: Thu, 09 Apr 2026 08:43:59 GMT

Connection: keep-alive

ETag: "69d766cf-197"

Accept-Ranges: bytes

adohi08243536@c4r2s7 docker-test % docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

NAMES           STATUS                    PORTS

my-web-server   Up 28 minutes (healthy)   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp

## 7. docker 볼륨 영속성 검증
### 1. docker 볼륨 생성 및 연결
adohi08243536@c4r2s7 docker-test % docker volume create my-data-vol

my-data-vol

adohi08243536@c4r2s7 docker-test % docker run -d \
  --name vol-test-server \
  -p 8888:80 \
  -v my-data-vol:/usr/share/nginx/html \
  my-custom-nginx:v1

adohi08243536@c4r2s7 docker-test % docker exec vol-test-server sh -c "echo 'Persistence Test Success' > /usr/share/nginx/html/test.txt"

adohi08243536@c4r2s7 docker-test % curl http://localhost:8888/test.txt

Persistence Test Success

### 2. 컨테이너 삭제 후 재연결
adohi08243536@c4r2s7 docker-test % docker rm -f vol-test-server

vol-test-server

adohi08243536@c4r2s7 docker-test % docker run -d \
  --name vol-recovered-server \
  -p 8888:80 \
  -v my-data-vol:/usr/share/nginx/html \
  my-custom-nginx:v1

93cae90ee1b7098e0f993867f28f6dbeb35db18497e5f46dd495039f9c33bfa6

adohi08243536@c4r2s7 docker-test % curl http://localhost:8888/test.txt

Persistence Test Success

### 3. 바인드 마운트
adohi08243536@c4r2s7 Codyssey_01 % mkdir html

adohi08243536@c4r2s7 Codyssey_01 % echo "Before Change" > html/index.html

adohi08243536@c4r2s7 Codyssey_01 % curl http://localhost:8081

Before Change

adohi08243536@c4r2s7 Codyssey_01 % echo "After Change - Bind Mount Success" > html/index.html

adohi08243536@c4r2s7 Codyssey_01 % curl http://localhost:8081                                

After Change - Bind Mount Success

실시간으로 반영됨
## 8. 트러블 슈팅
### html 인코딩 오류
한글 인코딩이 깨져서 외계어처럼 나와서 메타 코드를 삽입하여 해결
```
<html lang="ko">
<head>
    <meta charset="UTF-8">
```
### 깃 커밋 퍼미션 오류
chmod 명령어 테스트 중 원복하지 않아 깃 커밋/푸쉬가 퍼미션 오류로 진행되지 않음
모드 변경으로 해결
