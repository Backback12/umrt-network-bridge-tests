#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

export REPO_DIR

docker compose -f "${REPO_DIR}/compose/compose-base.yaml" up -d

echo "Base container is up."
echo "Foxglove WebSocket: ws://localhost:8765"
echo "Zenoh bridges start automatically with the container."
echo "If you change JSON5 configs, recreate with: docker compose -f compose/compose-base.yaml up -d --force-recreate"
