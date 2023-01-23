#!/bin/bash

set -e
set pipefail
set -x

THIS_DIR=$(cd "$(dirname "$0")"; pwd)

if [[ -d "${THIS_DIR}/tmp" ]]; then
    rm -rf "${THIS_DIR}/tmp"
fi

mkdir -p "${THIS_DIR}/tmp"

# Docker template
BASE_IMAGE_VERSION=$(curl --silent https://registry.hub.docker.com/v1/repositories/bitnami/wordpress/tags | jq -r '.[].name' | sort --version-sort | grep -v latest | grep -v '_' | tail -n1)
EXIT_CODE=$?
if [[ "${EXIT_CODE}" -ne "0" ]]; then
    echo "WARN the version ${BASE_IMAGE_VERSION} is not yet deployed and latest version will be used!"
    BASE_IMAGE_VERSION=latest
fi

cat "${THIS_DIR}/Dockerfile.template" | docker run --env BASE_IMAGE_VERSION="${BASE_IMAGE_VERSION}" -i --rm subfuzion/envtpl > "${THIS_DIR}/Dockerfile" ;

echo "${BASE_IMAGE_VERSION}" > "${THIS_DIR}/tmp/base_image_version.txt"
