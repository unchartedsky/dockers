#!/bin/bash

set -e
set -o pipefail
set -x

THIS_DIR=$(cd "$(dirname "$0")"; pwd)

if [[ -d "${THIS_DIR}/tmp" ]]; then
    rm -rf "${THIS_DIR}/tmp"
fi

mkdir -p "${THIS_DIR}/tmp"

# Docker template - WordPress official image
# Fetch latest stable PHP 8.2 Apache version (excluding beta, rc, alpha)
WORDPRESS_VERSION=$(curl --silent "https://registry.hub.docker.com/v2/repositories/library/wordpress/tags?page_size=100" | \
    jq -r '.results[].name' | \
    grep -v 'beta\|rc\|alpha' | \
    grep -E '^[0-9]+\.[0-9]+.*-php8\.2-apache$' | \
    sort --version-sort | \
    tail -n1 || true)

EXIT_CODE=$?
if [[ "${EXIT_CODE}" -ne "0" ]] || [[ -z "${WORDPRESS_VERSION}" ]]; then
    echo "WARN: Could not fetch latest version, falling back to php8.2-apache"
    WORDPRESS_VERSION="php8.2-apache"
fi

echo "Using WordPress official image version: ${WORDPRESS_VERSION}"

cat "${THIS_DIR}/Dockerfile.template" | docker run --env WORDPRESS_VERSION="${WORDPRESS_VERSION}" -i --rm subfuzion/envtpl > "${THIS_DIR}/Dockerfile"

echo "${WORDPRESS_VERSION}" > "${THIS_DIR}/tmp/base_image_version.txt"

echo "Dockerfile generated successfully with WordPress version: ${WORDPRESS_VERSION}"
