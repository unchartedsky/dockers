#!/bin/bash

# TediCross 커스텀 Docker 이미지 빌드 스크립트
# GitHub에서 소스코드를 가져와서 빌드

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 변수 설정
REPO_URL="https://github.com/TediCross/TediCross"
REPO_BRANCH="stable"
TMP_DIR="tmp"
IMAGE_NAME="tedicross-custom"
VERSION="0.12.4-node22"
LATEST_TAG="latest"

echo -e "${BLUE}=== TediCross 커스텀 Docker 이미지 빌드 시작 ===${NC}"
echo -e "${YELLOW}저장소: ${REPO_URL}${NC}"
echo -e "${YELLOW}브랜치: ${REPO_BRANCH}${NC}"
echo -e "${YELLOW}이미지 이름: ${IMAGE_NAME}${NC}"
echo -e "${YELLOW}버전: ${VERSION}${NC}"
echo ""

# 필수 도구 확인
if ! command -v git &> /dev/null; then
    echo -e "${RED}오류: git이 설치되지 않았습니다.${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}오류: Docker가 설치되지 않았거나 실행되지 않고 있습니다.${NC}"
    exit 1
fi

# 기존 tmp 디렉토리 정리
if [ -d "$TMP_DIR" ]; then
    echo -e "${YELLOW}기존 ${TMP_DIR} 디렉토리를 삭제합니다...${NC}"
    rm -rf "$TMP_DIR"
fi

# GitHub에서 TediCross 소스코드 클론
echo -e "${BLUE}GitHub에서 TediCross 소스코드를 가져옵니다...${NC}"
git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$TMP_DIR"

if [ $? -ne 0 ]; then
    echo -e "${RED}오류: 소스코드 클론에 실패했습니다.${NC}"
    exit 1
fi

# 소스코드 정보 출력
cd "$TMP_DIR"
COMMIT_HASH=$(git rev-parse --short HEAD)
COMMIT_DATE=$(git log -1 --format=%cd --date=short)
echo -e "${GREEN}소스코드 정보:${NC}"
echo -e "  커밋: ${COMMIT_HASH}"
echo -e "  날짜: ${COMMIT_DATE}"
cd ..

# Dockerfile.template을 Dockerfile로 변환
echo -e "${BLUE}Dockerfile.template을 Dockerfile로 변환합니다...${NC}"
if command -v envsubst &> /dev/null; then
    # envsubst 사용 (환경 변수 치환)
    envsubst < Dockerfile.template > Dockerfile
else
    # 단순 복사 (환경 변수가 없는 경우)
    cp Dockerfile.template Dockerfile
fi

# Docker 이미지 빌드
echo -e "${BLUE}Docker 이미지를 빌드합니다...${NC}"
docker build \
    --tag "${IMAGE_NAME}:${VERSION}" \
    --tag "${IMAGE_NAME}:${LATEST_TAG}" \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --progress=plain \
    .

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=== 빌드 완료! ===${NC}"
    echo -e "${GREEN}생성된 이미지:${NC}"
    echo -e "  - ${IMAGE_NAME}:${VERSION}"
    echo -e "  - ${IMAGE_NAME}:${LATEST_TAG}"
    echo ""

    # 이미지 정보 출력
    echo -e "${BLUE}=== 이미지 정보 ===${NC}"
    docker images | grep "${IMAGE_NAME}" | head -2
    echo ""

    # 사용 방법 안내
    echo -e "${BLUE}=== 사용 방법 ===${NC}"
    echo -e "${YELLOW}1. 로컬 테스트:${NC}"
    echo -e "   docker run --rm -it ${IMAGE_NAME}:${VERSION}"
    echo ""
    echo -e "${YELLOW}2. 백그라운드 실행:${NC}"
    echo -e "   docker run -d --name tedicross \\"
    echo -e "     -v \$(pwd)/data:/opt/TediCross/data \\"
    echo -e "     ${IMAGE_NAME}:${VERSION}"
    echo ""
    echo -e "${YELLOW}3. 설정 파일 확인:${NC}"
    echo -e "   data/settings.yaml 파일에 Telegram/Discord 토큰을 설정하세요."
    echo ""

    # 정리 옵션
    echo -e "${YELLOW}임시 파일 정리를 원하시면 다음 명령을 실행하세요:${NC}"
    echo -e "   rm -rf ${TMP_DIR}"
    echo ""

    echo -e "${GREEN}빌드가 성공적으로 완료되었습니다! 🚀${NC}"
else
    echo -e "${RED}빌드 실패! 오류를 확인해주세요.${NC}"
    exit 1
fi
