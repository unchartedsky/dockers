![](https://github.com/unchartedsky/dockers/actions/workflows/fulltextrss-base.yaml/badge.svg)
![](https://github.com/unchartedsky/dockers/actions/workflows/gpt-researcher.yml/badge.svg)
![](https://github.com/unchartedsky/dockers/actions/workflows/gptr-mcp.yml/badge.svg)
![](https://github.com/unchartedsky/dockers/actions/workflows/hyperresearch.yml/badge.svg)
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
| fulltextrss-base | `fulltextrss-base/` | 직접 `Dockerfile` 빌드 | `.github/workflows/fulltextrss-base.yaml` |
| gpt-researcher | `gpt-researcher/` | `Dockerfile.template` 기반 커스텀 빌드 | `.github/workflows/gpt-researcher.yml` |
| gptr-mcp | (로컬 서비스 디렉토리 없음) | CI에서 업스트림 tarball 다운로드 후 빌드 | `.github/workflows/gptr-mcp.yml` |
| hyperresearch | `hyperresearch/` | Hyperresearch 운영용 extras와 mcp-proxy를 포함한 MCP 이미지 | `.github/workflows/hyperresearch.yml` |
| mysql | `mysql/` | 직접 `Dockerfile` 빌드 | (전용 workflow 없음) |
| summerwind-actions-runner | `summerwind-actions-runner/` | `Dockerfile.template` 렌더링 후 빌드 | `.github/workflows/summerwind-actions-runner.yaml` |
| tedicross | `tedicross/` | 업스트림 clone + `Dockerfile.template` 기반 빌드 | `.github/workflows/tedicross.yml` |
| wordpress | `wordpress/` | `prepare.sh`로 동적 버전 계산 후 템플릿 빌드 | `.github/workflows/wordpress.yml` |

### Hyperresearch MCP

`hyperresearch[all]`로 MCP, Exa, Tavily, Parallel, Crawl4AI, Watchdog용 Python 패키지를 설치합니다. 개발용 패키지, 서비스 API 키, 브라우저 바이너리는 이미지에 넣지 않습니다. 기본 URL 수집은 별도 키 없이 동작하는 builtin을 사용합니다. 키나 브라우저가 필요한 제공자는 별도의 실행 설정이 필요합니다.

서비스는 `/vault`에 쓰기 가능한 볼륨을 마운트하고, `HYPERRESEARCH_MCP_HOST`에 프록시가 받는 Host authority, `MCP_PROXY_AUTH_TOKEN`에 비밀 토큰을 설정해야 합니다. 포트는 `8080`, Streamable HTTP 경로는 `/mcp`입니다. 평문 HTTP는 신뢰된 내부 구간에서만 사용하고, 외부 접속에는 별도 TLS와 접근 제한을 적용합니다.

푸시 시에는 빌드와 오프라인 시험만 실행합니다. GHCR에 발행하려면 기본 브랜치에서 Hyperresearch 워크플로를 수동 실행하고, 크롤링이 승인된 공개 HTTPS 시험 URL을 `verify_url`에 지정합니다. 비밀이나 실제 연구 데이터가 들어 있는 URL은 사용하지 않습니다. 두 시험을 모두 통과한 동일 이미지만 발행합니다.

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
