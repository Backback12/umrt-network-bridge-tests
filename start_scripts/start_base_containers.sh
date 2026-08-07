#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
IMAGE_NAME="${BRIDGE_TEST_IMAGE:-bridge_test:v1}"

echo "Building ${IMAGE_NAME}..."
docker build -t "${IMAGE_NAME}" "${REPO_DIR}"

echo "Launching base station and Foxglove containers..."
BRIDGE_TEST_IMAGE="${IMAGE_NAME}" docker compose -f "${REPO_DIR}/compose/compose-base.yaml" up -d

echo "Base side is up."
echo "Foxglove WebSocket: ws://localhost:8765"
