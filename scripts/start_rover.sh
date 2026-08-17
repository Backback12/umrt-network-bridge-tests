#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
variant="${1:-both}"

export REPO_DIR

case "${variant}" in
  lo)
    compose_file="${REPO_DIR}/compose/compose-rover-lo.yaml"
    stack_name="rover-lo"
    ;;
  hi)
    compose_file="${REPO_DIR}/compose/compose-rover-hi.yaml"
    stack_name="rover-hi"
    ;;
  both)
    compose_file="${REPO_DIR}/compose/compose-rover-both.yaml"
    stack_name="rover-both"
    ;;
  -h|--help|help)
    echo "Usage: ./scripts/start_rover.sh [lo|hi|both]"
    exit 0
    ;;
  *)
    echo "Unknown rover variant: ${variant}" >&2
    echo "Usage: ./scripts/start_rover.sh [lo|hi|both]" >&2
    exit 2
    ;;
esac

docker compose -f "${compose_file}" up -d

echo "Rover container (${stack_name}) is up."
echo "Zenoh bridges start automatically with the container."
echo "If you change JSON5 configs, recreate with: docker compose -f ${compose_file#${REPO_DIR}/} up -d --force-recreate"
