#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

echo "Launching Base Station Containers..."
docker compose -f "${REPO_DIR}/compose/compose-base.yaml" up -d --build
docker compose -f "${REPO_DIR}/compose/compose-foxglove-bridge.yaml" up -d --build
echo "Done Launching Base Station Containers."
