#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
This branch starts Zenoh automatically from Docker Compose, so the old
network_bridge process manager is no longer used.

Recreate the relevant stack after editing a JSON5 config:
  ./scripts/start_base.sh
  ./scripts/start_rover.sh lo
  ./scripts/start_rover.sh hi
  ./scripts/start_rover.sh both

Or directly:
  docker compose -f compose/compose-base.yaml up -d --force-recreate
  docker compose -f compose/compose-rover-lo.yaml up -d --force-recreate
  docker compose -f compose/compose-rover-hi.yaml up -d --force-recreate
  docker compose -f compose/compose-rover-both.yaml up -d --force-recreate
EOF
