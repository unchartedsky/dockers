FROM alpine:3.22

# himalaya는 apk 패키지(0.9.0)가 v2 CLI와 호환되지 않아 릴리스 바이너리를 고정 설치한다.
RUN apk add --no-cache isync=1.5.1-r0 restic=0.18.0-r7 bash curl tzdata ca-certificates \
 && curl -fsSL -o /tmp/hm.tgz https://github.com/pimalaya/himalaya/releases/download/v2.2.1/himalaya.x86_64-linux.tgz \
 && tar -xzC /usr/local/bin -f /tmp/hm.tgz himalaya \
 && rm /tmp/hm.tgz

USER 1000
