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