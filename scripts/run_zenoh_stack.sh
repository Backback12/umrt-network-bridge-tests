#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: /workspace/bridge_test/scripts/run_zenoh_stack.sh <base|rover-lo|rover-hi|rover-both>

Starts the Zenoh bridge processes for the requested stack role.
The base role also launches Foxglove on port 8765.
USAGE
}

role="${1:-}"
workspace="${BRIDGE_WORKSPACE:-/workspace/bridge_test}"
config_dir="${workspace}/config"
children=()

require_file() {
  local path="$1"

  if [[ ! -f "${path}" ]]; then
    echo "Missing required file: ${path}" >&2
    exit 1
  fi
}

require_zenoh_bridge() {
  if command -v zenoh-bridge-ros2dds >/dev/null 2>&1; then
    return
  fi

  cat >&2 <<'MISSING'
Missing required executable: zenoh-bridge-ros2dds

Install it in the image before starting this stack. The upstream Debian setup is:
  mkdir -p /etc/apt/keyrings
  curl -L https://download.eclipse.org/zenoh/debian-repo/zenoh-public-key | gpg --dearmor --yes --output /etc/apt/keyrings/zenoh-public-key.gpg
  echo "deb [signed-by=/etc/apt/keyrings/zenoh-public-key.gpg] https://download.eclipse.org/zenoh/debian-repo/ /" > /etc/apt/sources.list.d/zenoh.list
  apt-get update && apt-get install -y zenoh-bridge-ros2dds
MISSING
  exit 127
}

start_process() {
  local name="$1"
  shift

  echo "Starting ${name}"
  "$@" &
  children+=("$!")
}

cleanup() {
  trap - EXIT INT TERM

  if [[ "${#children[@]}" -gt 0 ]]; then
    kill "${children[@]}" 2>/dev/null || true
    wait "${children[@]}" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

case "${role}" in
  base|rover-lo|rover-hi|rover-both)
    ;;
  -h|--help|help|"")
    usage
    exit 0
    ;;
  *)
    echo "Unknown role: ${role}" >&2
    usage >&2
    exit 2
    ;;
esac

require_zenoh_bridge

# ROS setup scripts can reference unset variables, so source them with nounset off
# while keeping strict mode for this launcher.
set +u
source /opt/ros/humble/setup.bash
set -u

case "${role}" in
  base)
    require_file "${config_dir}/base-lo.json5"
    require_file "${config_dir}/base-hi.json5"
    start_process "Foxglove bridge" ros2 launch foxglove_bridge foxglove_bridge_launch.xml address:=0.0.0.0 port:=8765
    start_process "Zenoh base low bridge" zenoh-bridge-ros2dds -c "${config_dir}/base-lo.json5"
    start_process "Zenoh base high bridge" zenoh-bridge-ros2dds -c "${config_dir}/base-hi.json5"
    ;;
  rover-lo)
    require_file "${config_dir}/rover-lo.json5"
    start_process "Zenoh rover low bridge" zenoh-bridge-ros2dds -c "${config_dir}/rover-lo.json5"
    ;;
  rover-hi)
    require_file "${config_dir}/rover-hi.json5"
    start_process "Zenoh rover high bridge" zenoh-bridge-ros2dds -c "${config_dir}/rover-hi.json5"
    ;;
  rover-both)
    require_file "${config_dir}/rover-lo.json5"
    require_file "${config_dir}/rover-hi.json5"
    start_process "Zenoh rover low bridge" zenoh-bridge-ros2dds -c "${config_dir}/rover-lo.json5"
    start_process "Zenoh rover high bridge" zenoh-bridge-ros2dds -c "${config_dir}/rover-hi.json5"
    ;;
esac

wait -n "${children[@]}"
