#!/bin/bash
set -e

# GPT-Researcher 커스텀 Docker 이미지 빌드 스크립트
# tedicross 빌드 패턴 따름

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 변수 설정
REPO="ghcr.io/unchartedsky"
IMAGE_NAME="gpt-researcher"
VERSION="${1:-latest}"
LATEST_TAG="latest"

echo -e "${BLUE}=== GPT-Researcher 커스텀 Docker 이미지 빌드 시작 ===${NC}"
echo -e "${YELLOW}이미지: ${REPO}/${IMAGE_NAME}${NC}"
echo -e "${YELLOW}버전: ${VERSION}${NC}"
echo ""

# 필수 도구 확인
if ! command -v docker &> /dev/null; then
    echo -e "${RED}오류: Docker가 설치되지 않았거나 실행되지 않고 있습니다.${NC}"
    exit 1
fi

# Dockerfile.template을 Dockerfile로 변환
echo -e "${BLUE}Dockerfile.template을 Dockerfile로 변환합니다...${NC}"
cp Dockerfile.template Dockerfile

# Docker 이미지 빌드
echo -e "${BLUE}Docker 이미지를 빌드합니다...${NC}"
docker build \
    --tag "${REPO}/${IMAGE_NAME}:${VERSION}" \
    --tag "${REPO}/${IMAGE_NAME}:${LATEST_TAG}" \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --progress=plain \
    .

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=== 빌드 완료! ===${NC}"
    echo -e "${GREEN}생성된 이미지:${NC}"
    echo -e "  - ${REPO}/${IMAGE_NAME}:${VERSION}"
    echo -e "  - ${REPO}/${IMAGE_NAME}:${LATEST_TAG}"
    echo ""

    # 이미지 정보 출력
    echo -e "${BLUE}=== 이미지 정보 ===${NC}"
    docker images | grep "${IMAGE_NAME}" | head -2
    echo ""

    # 사용 방법 안내
    echo -e "${BLUE}=== 사용 방법 ===${NC}"
    echo -e "${YELLOW}1. 로컬 테스트:${NC}"
    echo -e "   docker run --rm ${REPO}/${IMAGE_NAME}:${VERSION} python -c 'import duckduckgo_search'"
    echo ""
    echo -e "${YELLOW}2. 이미지 푸시:${NC}"
    echo -e "   docker push ${REPO}/${IMAGE_NAME}:${VERSION}"
    echo -e "   docker push ${REPO}/${IMAGE_NAME}:${LATEST_TAG}"
    echo ""

    echo -e "${GREEN}빌드가 성공적으로 완료되었습니다! 🚀${NC}"
else
    echo -e "${RED}빌드 실패! 오류를 확인해주세요.${NC}"
    exit 1
fi
