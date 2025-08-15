# TediCross 커스텀 Docker 이미지

> 네트워크 타임아웃 문제 해결을 위한 TediCross 최적화 Docker 이미지

## 📋 개요

TediCross 애플리케이션에서 `api.telegram.org`에 연결할 때 발생하는 ETIMEDOUT 오류를 해결하기 위해 네트워크 설정을 최적화한 커스텀 Docker 이미지입니다.

### 🎯 해결된 문제

- **원본 문제**: TediCross에서 api.telegram.org 연결 시 ETIMEDOUT 오류
- **원인**: node-fetch 라이브러리의 네트워크 타임아웃 설정 문제
- **해결 방법**: 네트워크 설정 최적화 및 타임아웃 증가

## 🐳 주요 개선사항

### 네트워크 최적화
- **DNS 해석 최적화**: IPv4 우선, 신뢰할 수 있는 DNS 서버 사용 (8.8.8.8, 1.1.1.1)
- **타임아웃 증가**: 연결 및 요청 타임아웃을 60초로 설정
- **TLS 검증 비활성화**: 연결 문제 해결을 위한 임시 조치
- **프록시 설정 초기화**: 불필요한 프록시 설정 제거

### 추가 도구
- 네트워크 디버깅 도구: `curl`, `bind-tools`, `iputils`, `net-tools`
- 자동 네트워크 테스트: 시작 시 연결 상태 확인

### 환경 변수
```bash
NODE_OPTIONS="--dns-result-order=ipv4first --max-old-space-size=4096 --unhandled-rejections=warn"
NODE_TLS_REJECT_UNAUTHORIZED="0"
no_proxy="localhost,127.0.0.1,::1,api.telegram.org,discord.com"
```

## 🚀 사용 방법

### 1. 이미지 빌드

```bash
# 디렉토리 이동
cd tedicross

# 빌드 스크립트 실행
./build.sh

# 또는 직접 빌드
docker build \
  --tag "tedicross-custom:0.12.4-network-fix" \
  --tag "tedicross-custom:latest" \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --progress=plain \
  .
```

### 2. 로컬 테스트

```bash
# 대화형 모드로 테스트
docker run --rm -it tedicross-custom:0.12.4-network-fix

# 설정 파일과 함께 실행
docker run --rm -it \
  -v $(pwd)/data:/opt/TediCross/data \
  tedicross-custom:0.12.4-network-fix
```

### 3. 백그라운드 실행

```bash
docker run -d --name tedicross \
  -v $(pwd)/data:/opt/TediCross/data \
  --restart unless-stopped \
  tedicross-custom:0.12.4-network-fix
```

### 4. SOCKS5 프록시 사용

SOCKS5 프록시를 통해 연결하려면 환경 변수를 설정하세요:

```bash
# SOCKS5 프록시 사용
docker run -d --name tedicross \
  -e SOCKS5_PROXY_HOST=your-proxy-host \
  -e SOCKS5_PROXY_PORT=1080 \
  -v $(pwd)/data:/opt/TediCross/data \
  tedicross-custom:0.12.4-node22
```

### 5. Docker Compose

```yaml
version: '3.8'

services:
  tedicross:
    image: tedicross-custom:0.12.4-node22
    container_name: tedicross
    environment:
      # SOCKS5 프록시 설정 (선택사항)
      - SOCKS5_PROXY_HOST=your-proxy-host
      - SOCKS5_PROXY_PORT=1080
    volumes:
      - ./data:/opt/TediCross/data
    restart: unless-stopped
    # build:  # 로컬 빌드를 원하는 경우
    #   context: .
    #   dockerfile: Dockerfile
```

### 5. Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tedicross
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tedicross
  template:
    metadata:
      labels:
        app: tedicross
    spec:
      containers:
      - name: tedicross
        image: tedicross-custom:0.12.4-network-fix
        imagePullPolicy: Never  # 로컬 이미지 사용
        volumeMounts:
        - name: config-volume
          mountPath: /opt/TediCross/data
      volumes:
      - name: config-volume
        configMap:
          name: tedicross-config
```

## ⚙️ 설정 파일 (data/settings.yaml)

```yaml
telegram:
  token: "YOUR_TELEGRAM_BOT_TOKEN"
  requestTimeout: 60000      # 60초 타임아웃
  connectionTimeout: 30000   # 30초 연결 타임아웃

discord:
  token: "YOUR_DISCORD_BOT_TOKEN"
  requestTimeout: 60000      # 60초 타임아웃
  connectionTimeout: 30000   # 30초 연결 타임아웃

debug: true
networkTimeout: 30000        # 네트워크 타임아웃
```

## 🔍 디버깅

### 로그 확인
컨테이너 시작 시 다음과 같은 로그를 확인할 수 있습니다:

```
=== TediCross 네트워크 최적화 시작 ===
DNS 설정이 적용되었습니다.
=== 네트워크 연결 테스트 ===
DNS 해석 테스트 (api.telegram.org):
연결 테스트 (api.telegram.org):
연결 테스트 (discord.com):
=== 환경 변수 확인 ===
NODE_OPTIONS: --dns-result-order=ipv4first --max-old-space-size=4096 --unhandled-rejections=warn
NODE_TLS_REJECT_UNAUTHORIZED: 0
=== TediCross 애플리케이션 시작 ===
```

### 문제 해결 체크리스트
- [ ] DNS 해석이 정상적으로 작동하는가?
- [ ] api.telegram.org에 연결할 수 있는가?
- [ ] 환경 변수가 올바르게 설정되었는가?
- [ ] 프록시 설정이 비어있는가?
- [ ] 설정 파일이 올바른 위치에 있는가?

### 컨테이너 내부 접근
```bash
# 실행 중인 컨테이너에 접근
docker exec -it tedicross /bin/bash

# 네트워크 테스트
nslookup api.telegram.org
curl -I https://api.telegram.org
```

## 📦 이미지 정보

- **이미지 이름**: `tedicross-custom:0.12.4-network-fix`
- **베이스 이미지**: `node:22.9-alpine3.20`
- **예상 크기**: 약 400-500MB
- **포트**: 8501 (TediCross 기본 포트)
- **볼륨**: `/opt/TediCross/data/`

## 🔧 개발자 정보

### 파일 구조
```
tedicross/
├── Dockerfile          # 커스텀 Docker 이미지 정의
├── .dockerignore       # Docker 빌드 제외 파일
├── build.sh           # 빌드 스크립트
└── README.md          # 사용 방법 안내
```

### 빌드 과정
1. Alpine Linux 기반 Node.js 22.9 이미지 사용
2. 네트워크 도구 및 필수 패키지 설치
3. 네트워크 최적화 환경 변수 설정
4. DNS 설정 최적화
5. 시작 스크립트 생성 및 권한 설정
6. 볼륨 및 엔트리포인트 설정

## 📝 라이선스

이 커스텀 이미지는 원본 TediCross 프로젝트의 라이선스를 따릅니다.

## 🤝 기여

문제가 발생하거나 개선사항이 있다면 이슈를 생성해주세요.

---

**참고**: 이 이미지는 TediCross의 네트워크 타임아웃 문제를 해결하기 위해 특별히 최적화되었습니다. 프로덕션 환경에서 사용하기 전에 충분한 테스트를 권장합니다.
