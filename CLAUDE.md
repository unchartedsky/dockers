# CLAUDE.md

이 문서는 Claude Code(claude.ai/code)가 이 저장소에서 작업할 때 따라야 할 가이드를 제공합니다.

## 저장소 개요

이 저장소는 최상위 서비스 디렉토리(예: `wordpress/`, `gpt-researcher/`, `tedicross/`, `fulltextrss-base/`)별로 Docker 이미지를 관리하며, `.github/workflows/`의 GitHub Actions를 통해 GHCR로 이미지를 배포합니다.

서비스별 빌드 방식은 크게 다음 패턴을 사용합니다.
- **직접 Dockerfile 빌드**: 기존 `Dockerfile`을 그대로 사용해 빌드 (예: `fulltextrss-base`)
- **템플릿 기반 빌드**: `Dockerfile.template`을 `subfuzion/envtpl`로 렌더링해 `Dockerfile` 생성 후 빌드 (예: `summerwind-actions-runner`, `wordpress`)

## 주요 명령어

### 로컬 전체 빌드 (Makefile)
- 모든 `Dockerfile.template` 렌더링:
  - `make template`
- 최상위 서비스 디렉토리의 이미지 빌드:
  - `make image`
- 빌드 후 GHCR(`ghcr.io/unchartedsky`)로 푸시:
  - `make deploy`

### 서비스별 빌드
- WordPress (동적 베이스 태그 계산 + Dockerfile 생성):
  - `cd wordpress && ./prepare.sh`
  - 필요 시 이후 `docker build` 수행
- GPT-Researcher 커스텀 이미지:
  - `cd gpt-researcher && ./build.sh`
- TediCross 커스텀 이미지:
  - `cd tedicross && ./build.sh`

### 빠른 검증
- 워크플로우 YAML 검증 (`yamllint` 설치 시):
  - `yamllint .github/workflows`
- 변경 사항 확인:
  - `git status --short`
  - `git diff`

## 아키텍처 및 워크플로우 패턴

### 1) 서비스 디렉토리 = 이미지 단위
각 최상위 디렉토리는 보통 하나의 이미지 단위입니다. 핵심 파일은 대체로 아래 중 하나입니다.
- `Dockerfile`
- `Dockerfile.template`
- 보조 스크립트 (`prepare.sh`, `build.sh`)

`Makefile`은 파일 존재 여부로 대상을 자동 탐지합니다.
- `Dockerfile.template`가 있는 디렉토리 → `make template`
- `Dockerfile`이 있는 디렉토리 → `make image` / `make deploy`

### 2) 이미지별 CI/CD 워크플로우
워크플로우는 이미지 단위로 분리되어 있으며 보통 다음 조건으로 실행됩니다.
- 해당 서비스 디렉토리/워크플로우 파일 경로 변경
- schedule 기반 주기적 재빌드
- 필요 시 `workflow_dispatch`

일반적인 워크플로우 단계:
1. checkout
2. buildx 설정(필요 시 qemu 포함)
3. GHCR 인증(`docker/login-action`)
4. 이미지 빌드/푸시

### 3) 템플릿 렌더링 전략
`Dockerfile.template` 기반 서비스는 다음 중 하나로 렌더링됩니다.
- `make template`에서 중앙 렌더링 (`subfuzion/envtpl` 컨테이너)
- 워크플로우 단계에서 직접 렌더링 (예: `summerwind-actions-runner`)
- 서비스 스크립트에서 렌더링 (예: `wordpress/prepare.sh`가 `WORDPRESS_VERSION` 계산 후 `tmp/base_image_version.txt` 생성)

### 4) 업스트림 소스 추적형 이미지
일부 이미지는 CI에서 업스트림 소스를 가져와 빌드합니다.
- `gptr-mcp`: 워크플로우에서 업스트림 tarball 다운로드 후 빌드
- `tedicross`: 워크플로우에서 업스트림 stable 브랜치 clone 후 빌드
- `gpt-researcher`: 공식 GHCR 베이스 이미지 위에 `requirements-custom.txt` 패키지 추가

## 주요 파일 규칙

- `.editorconfig` 규칙 준수 (LF, UTF-8, Makefile 탭 들여쓰기)
- README 배지는 활성 워크플로우와 항상 동기화
- `wordpress/prepare.sh`는 fail-fast 옵션(`set -e`, `set -o pipefail`, `set -x`)을 사용하므로 흐름을 우회하지 말 것

## 변경 가이드라인

- 변경 범위는 가능한 서비스 단위로 최소화 (대상 서비스 디렉토리 + 관련 workflow/readme만)
- 템플릿 기반 서비스는 `Dockerfile.template` 우선 수정, `Dockerfile`은 실제 필요한 경우에만 갱신
- 워크플로우 수정 시 기존 패턴(트리거, GHCR 로그인, build-push)과 일관성 유지
- 새 이미지 서비스 추가 시 기존 구조를 따를 것: 서비스 디렉토리 + 워크플로우 + README 배지
