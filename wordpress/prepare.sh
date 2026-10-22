#!/bin/bash

set -euo pipefail
set -x

THIS_DIR=$(cd "$(dirname "$0")"; pwd)

if [[ -d "${THIS_DIR}/tmp" ]]; then
    rm -rf "${THIS_DIR}/tmp"
fi

mkdir -p "${THIS_DIR}/tmp"

# Docker template - WordPress official image
# Docker Hub 단일 페이지는 beta 태그로 가득 차 stable 태그를 놓칠 수 있어 여러 페이지를 조회한다
fetch_wordpress_tags() {
    for page in 1 2 3; do
        curl --silent --fail "https://registry.hub.docker.com/v2/repositories/library/wordpress/tags?page_size=100&page=${page}" | \
            jq -r '.results[].name'
    done
}

# PHP 8.5 variant만 사용 (beta, rc, alpha 제외)
TAGS=$(fetch_wordpress_tags | grep -v 'beta\|rc\|alpha' || true)

# 1순위: 버전이 붙은 full 태그 (최신 버전), 2순위: alias 태그
WORDPRESS_VERSION=$(echo "${TAGS}" | grep -E '^[0-9]+\.[0-9]+.*-php8\.5-apache$' | sort --version-sort | tail -n1 || true)
if [[ -z "${WORDPRESS_VERSION}" ]]; then
    WORDPRESS_VERSION=$(echo "${TAGS}" | grep -E '^php8\.5-apache$' || true)
fi

if [[ -z "${WORDPRESS_VERSION}" ]]; then
    echo "ERROR: php8.5-apache 계열 WordPress 태그를 찾지 못했습니다" >&2
    exit 1
fi

echo "Using WordPress official image version: ${WORDPRESS_VERSION}"

cat "${THIS_DIR}/Dockerfile.template" | docker run --env WORDPRESS_VERSION="${WORDPRESS_VERSION}" -i --rm subfuzion/envtpl > "${THIS_DIR}/Dockerfile"

echo "${WORDPRESS_VERSION}" > "${THIS_DIR}/tmp/base_image_version.txt"

echo "Dockerfile generated successfully with WordPress version: ${WORDPRESS_VERSION}"
