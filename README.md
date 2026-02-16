![](https://github.com/unchartedsky/dockers/actions/workflows/dante-telegram.yaml/badge.svg)
![](https://github.com/unchartedsky/dockers/actions/workflows/fulltextrss-base.yaml/badge.svg)
![](https://github.com/unchartedsky/dockers/actions/workflows/gpt-researcher.yml/badge.svg)
![](https://github.com/unchartedsky/dockers/actions/workflows/gptr-mcp.yml/badge.svg)
![](https://github.com/unchartedsky/dockers/actions/workflows/ikev2-vpn-server.yaml/badge.svg)
![](https://github.com/unchartedsky/dockers/actions/workflows/summerwind-actions-runner.yaml/badge.svg)
![](https://github.com/unchartedsky/dockers/actions/workflows/tedicross.yml/badge.svg)
![](https://github.com/unchartedsky/dockers/actions/workflows/wordpress.yml/badge.svg)

# Dockers

여러 서비스용 Docker 이미지를 한 저장소에서 관리하고, GitHub Actions로 GHCR(`ghcr.io/unchartedsky`)에 배포하는 레포입니다.

## 빠른 시작

### 전체 이미지 빌드/배포

```bash
# Dockerfile.template -> Dockerfile 렌더링
make template

# 각 서비스 이미지 빌드 (태그: ghcr.io/unchartedsky/<service>:<commit>)
make image

# 빌드 + GHCR 푸시
make deploy
```

### 서비스별 실행 명령

```bash
# WordPress: 최신 태그 조회 + Dockerfile 생성
cd wordpress && ./prepare.sh

# GPT-Researcher 커스텀 이미지 빌드
cd gpt-researcher && ./build.sh

# TediCross 커스텀 이미지 빌드
cd tedicross && ./build.sh
```

## 서비스 구성

| 서비스 | 디렉토리 | 빌드 방식 | 워크플로우 |
| --- | --- | --- | --- |
| dante-telegram | `dante-telegram/` | 업스트림 소스 다운로드 후 빌드 | `.github/workflows/dante-telegram.yaml` |
| fulltextrss-base | `fulltextrss-base/` | 직접 `Dockerfile` 빌드 | `.github/workflows/fulltextrss-base.yaml` |
| gpt-researcher | `gpt-researcher/` | `Dockerfile.template` 기반 커스텀 빌드 | `.github/workflows/gpt-researcher.yml` |
| gptr-mcp | (로컬 서비스 디렉토리 없음) | CI에서 업스트림 tarball 다운로드 후 빌드 | `.github/workflows/gptr-mcp.yml` |
| ikev2-vpn-server | `ikev2-vpn-server/` | 업스트림 소스 다운로드 후 빌드 | `.github/workflows/ikev2-vpn-server.yaml` |
| mysql | `mysql/` | 직접 `Dockerfile` 빌드 | (전용 workflow 없음) |
| summerwind-actions-runner | `summerwind-actions-runner/` | `Dockerfile.template` 렌더링 후 빌드 | `.github/workflows/summerwind-actions-runner.yaml` |
| tedicross | `tedicross/` | 업스트림 clone + `Dockerfile.template` 기반 빌드 | `.github/workflows/tedicross.yml` |
| wordpress | `wordpress/` | `prepare.sh`로 동적 버전 계산 후 템플릿 빌드 | `.github/workflows/wordpress.yml` |

## CI/CD 개요

- 서비스별 워크플로우는 보통 다음 트리거를 사용합니다.
  - 해당 서비스 경로 변경(push)
  - 주기적 재빌드(schedule)
  - 필요 시 수동 실행(`workflow_dispatch`)
- 공통 빌드 흐름
  1. `actions/checkout`
  2. Docker Buildx/QEMU 설정
  3. GHCR 로그인(`docker/login-action`)
  4. `docker/build-push-action`으로 빌드/푸시

## 문서/운영 규칙

- 새 워크플로우를 추가하거나 제거하면 이 README 상단 배지도 함께 동기화합니다.
- 템플릿 기반 서비스는 `Dockerfile.template`을 우선 수정하고, 필요한 경우에만 `Dockerfile`을 갱신합니다.
- 상세한 에이전트 작업 규칙은 `CLAUDE.md`를 참고하세요.
