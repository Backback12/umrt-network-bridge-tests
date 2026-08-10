#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

export REPO_DIR

docker compose -f "${REPO_DIR}/compose/compose-base.yaml" up -d

echo "Base container is up."
echo "Foxglove WebSocket: ws://localhost:8765"
echo "Start or reload network_bridge with: ./scripts/restart_network_bridge.sh base"
