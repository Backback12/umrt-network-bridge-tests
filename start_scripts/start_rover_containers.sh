#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

echo "Launching Rover Containers..."
docker compose -f "${REPO_DIR}/compose/compose-rover-hi.yaml" up -d
docker compose -f "${REPO_DIR}/compose/compose-rover-lo.yaml" up -d
echo "Done Launching Rover Containers."
