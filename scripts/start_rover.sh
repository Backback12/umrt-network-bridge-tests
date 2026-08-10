#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

export REPO_DIR

docker compose -f "${REPO_DIR}/compose/compose-rover.yaml" up -d

echo "Rover container is up."
echo "Start or reload network_bridge with: ./scripts/restart_network_bridge.sh rover"
