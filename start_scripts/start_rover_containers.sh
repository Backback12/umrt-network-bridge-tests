#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
IMAGE_NAME="${BRIDGE_TEST_IMAGE:-bridge_test:v1}"

echo "Building ${IMAGE_NAME}..."
docker build -t "${IMAGE_NAME}" "${REPO_DIR}"

echo "Launching rover containers..."
BRIDGE_TEST_IMAGE="${IMAGE_NAME}" docker compose -f "${REPO_DIR}/compose/compose-rover.yaml" up -d

echo "Rover side is up."
