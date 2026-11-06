FROM alpine:3.22

# slackdump v4.5.2 공식 릴리스 바이너리를 고정 설치한다 (공식 Docker 이미지 미제공).
# apk 유틸은 버전 고정하지 않는다 — 보안 유틸성 패키지고 최종 산출물 참조는 digest로 고정된다.
RUN apk add --no-cache bash curl sqlite rsync jq tzdata ca-certificates \
 && curl -fsSL -o /tmp/sd.tgz https://github.com/rusq/slackdump/releases/download/v4.5.2/slackdump_Linux_x86_64.tar.gz \
 && tar -xzC /usr/local/bin -f /tmp/sd.tgz slackdump \
 && rm /tmp/sd.tgz

USER 1000
