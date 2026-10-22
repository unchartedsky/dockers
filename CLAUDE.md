# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 저장소 개요

서비스 디렉토리 하나가 Docker 이미지 하나에 대응합니다. 이미지는 `.github/workflows/`의 워크플로우가 GHCR(`ghcr.io/unchartedsky`)로 빌드·푸시합니다. 기본 브랜치는 `main`입니다.

서비스별 빌드 방식은 세 가지입니다.
- **직접 Dockerfile 빌드**: 저장소의 `Dockerfile`을 그대로 사용 (`fulltextrss-base`)
- **템플릿 렌더링 후 빌드**: `Dockerfile.template`을 `subfuzion/envtpl`로 렌더링해 `Dockerfile` 생성 (`wordpress`, `gpt-researcher`, `tedicross`, `summerwind-actions-runner`)
- **업스트림 소스 기반**: 저장소에 Dockerfile이 없고 CI가 업스트림을 받아 빌드 (`dante-telegram`, `ikev2-vpn-server`, `gptr-mcp`)

## 주요 명령어

테스트 러너와 린터 설정은 없습니다. 검증은 로컬 문법 검사와 CI 실행으로 합니다.

```bash
# Dockerfile.template -> Dockerfile 렌더링 (Makefile이 파일 존재 여부로 대상 탐지)
make template

# 이미지 빌드 (태그: ghcr.io/unchartedsky/<service>:<short-commit>)
make image

# 빌드 + GHCR 푸시
make deploy

# 서비스별 스크립트
cd wordpress && ./prepare.sh          # Docker Hub 조회로 베이스 태그 결정 후 Dockerfile 생성
cd gpt-researcher && ./build.sh
cd tedicross && ./build.sh

# 로컬 검증
bash -n wordpress/prepare.sh          # 쉘 문법
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/wordpress.yml'))"  # 워크플로우 YAML

# 원격 CI 재실행 (60일 비활성 규칙으로 워크플로우가 멈췄을 때 포함)
gh workflow run wordpress.yml -R unchartedsky/dockers
```

`wordpress/BUILD_AND_TEST.md`는 2025-10 작성본으로 현재 상태와 맞지 않습니다(기본값 php8.2 가정, 저장소에 없는 파일 참조). 이 문서의 명령을 그대로 따르지 말고, 현재 동작은 `prepare.sh`와 워크플로우 파일을 기준으로 하세요.

## 아키텍처와 워크플로우 패턴

### 1) 서비스 디렉토리 = 이미지 단위
핵심 파일은 `Dockerfile` 또는 `Dockerfile.template`, 그리고 선택적 보조 스크립트(`prepare.sh`, `build.sh`)입니다. `Makefile`은 `Dockerfile.template` 유무로 `make template`, `Dockerfile` 유무로 `make image`/`make deploy` 대상을 자동 탐지합니다.

### 2) 이미지별 워크플로우
트리거는 보통 해당 서비스 경로 push, schedule 재빌드, `workflow_dispatch`입니다. 워크플로우 파일 자체 변경도 트리거에 포함되는 경우가 많습니다.

### 3) 멀티아치 빌드는 한 잡에서 해야 합니다 (wordpress)
`linux/amd64,linux/arm64/v8`은 한 잡에서 `docker/build-push-action`의 `platforms`로 함께 빌드해 매니페스트 리스트를 푸시합니다. 플랫폼별 matrix 잡으로 나누면 두 잡이 같은 태그를 각자 덮어써 나중에 끝난 아키텍처만 남습니다(실제로 arm64 전용 태그가 된 사례가 있었습니다). matrix를 다시 도입하지 마세요.

### 4) 태그 출력 참조
`wordpress.yml`에서 `prep` 단계는 커밋·브랜치 태그를, `prepare` 단계는 `prepare.sh`가 정한 베이스 버전 태그(예: `7.1.3-php8.5-apache`)를 출력합니다. 두 출력을 합쳐 build-push의 `tags`에 넘기려면 `steps.prepare.outputs.tags`를 읽어야 합니다. `steps.prep`만 읽으면 베이스 버전 태그가 빠집니다.

### 5) 브랜치 조건 (master 와 main 모두 허용)
- `fulltextrss-base.yaml`: GHCR push 단계는 `refs/heads/master` 또는 `refs/heads/main`일 때만 실행됩니다.
- `wordpress.yml`: `latest` 태그는 브랜치가 `master` 또는 `main`일 때만 붙습니다.
새 조건을 추가할 때도 두 브랜치를 함께 고려하세요.

### 6) `prepare.sh`는 fail-fast
Docker Hub 태그를 1~3페이지 조회하고 `php8.5` 계열만 매칭합니다. full 태그(`X.Y.Z-php8.5-apache`)를 우선하고, 없으면 `php8.5-apache` alias를 씁니다. 둘 다 없으면 `exit 1`로 실패합니다. 무음 fallback은 두지 않습니다.

### 7) 템플릿 렌더링 위치
- `make template`에서 중앙 렌더링 (`subfuzion/envtpl` 컨테이너)
- 서비스 스크립트에서 렌더링 (`wordpress/prepare.sh`가 `tmp/base_image_version.txt`를 남김)
- 워크플로우 단계에서 직접 렌더링 (`summerwind-actions-runner`)

## 주요 파일 규칙

- `.editorconfig`: LF, UTF-8, 최종 줄바꿈, Makefile은 탭 들여쓰기
- README 배지는 활성 워크플로우와 맞춰 유지
- `wordpress/prepare.sh`는 `set -euo pipefail`을 사용하므로 실패를 삼키는 변경을 넣지 말 것

## 변경 가이드라인

- 변경 범위는 서비스 단위로 최소화 (대상 서비스 디렉토리 + 관련 워크플로우/README만)
- 템플릿 기반 서비스는 `Dockerfile.template`만 수정하고, `Dockerfile`은 실제로 필요할 때만 갱신
- 워크플로우 수정 시 기존 패턴(트리거, GHCR 로그인, build-push)과 일관성 유지
- 새 이미지 서비스는 서비스 디렉토리 + 워크플로우 + README 배지로 추가
- Write every report, summary, or handoff to the user through the `ce-noslop` skill. This applies when you are the top-level agent writing to the user, not when you are a subagent reporting to its caller. Do not apply it to code, config, verbatim quotes, or text the user asked to post as written.
