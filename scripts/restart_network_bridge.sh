#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/tmp/network_bridge_control"
PROCESS_NAME="network_bridge"

usage() {
  cat <<'USAGE'
Usage: ./scripts/restart_network_bridge.sh <base|rover> [restart|start|stop|status|logs]

Examples:
  ./scripts/restart_network_bridge.sh base
  ./scripts/restart_network_bridge.sh rover
  ./scripts/restart_network_bridge.sh rover logs

The default action is restart. Restart re-reads the launch file and YAML configs
mounted under /workspace/bridge_test/config.
USAGE
}

target="${1:-}"
action="${2:-restart}"

case "${target}" in
  base|bridge_base)
    side="base"
    container_name="bridge_base"
    launch_file="/workspace/bridge_test/config/base.launch.py"
    ;;
  rover|bridge_rover)
    side="rover"
    container_name="bridge_rover"
    launch_file="/workspace/bridge_test/config/rover.launch.py"
    ;;
  -h|--help|help|"")
    usage
    exit 0
    ;;
  *)
    echo "Unknown target: ${target}" >&2
    usage >&2
    exit 2
    ;;
esac

container_running() {
  [[ "$(docker inspect -f '{{.State.Running}}' "${container_name}" 2>/dev/null || true)" == "true" ]]
}

require_container() {
  if ! container_running; then
    echo "${container_name} is not running." >&2
    echo "Start it first with ./scripts/start_${side}.sh" >&2
    exit 1
  fi
}

exec_script() {
  docker exec -i "${container_name}" bash -s -- "$@"
}

drop_default_routes() {
  if [[ "${KEEP_DEFAULT_ROUTE:-0}" == "1" ]]; then
    return
  fi

  exec_script <<'IN_CONTAINER'
set -euo pipefail

while IFS= read -r route_line; do
  [[ -n "${route_line}" ]] || continue
  if [[ "${route_line}" =~ ^default[[:space:]]+via[[:space:]]+([^[:space:]]+)[[:space:]]+dev[[:space:]]+([^[:space:]]+) ]]; then
    ip route del default via "${BASH_REMATCH[1]}" dev "${BASH_REMATCH[2]}" 2>/dev/null || true
  elif [[ "${route_line}" =~ ^default[[:space:]]+dev[[:space:]]+([^[:space:]]+) ]]; then
    ip route del default dev "${BASH_REMATCH[1]}" 2>/dev/null || true
  else
    ip route del default 2>/dev/null || true
  fi
done < <(ip route show default 2>/dev/null || true)
IN_CONTAINER
}

start_bridge() {
  exec_script "${PROCESS_NAME}" "${STATE_DIR}/${PROCESS_NAME}.pid" "${STATE_DIR}/${PROCESS_NAME}.log" "${launch_file}" <<'IN_CONTAINER'
set -euo pipefail

name="$1"
pid_file="$2"
log_file="$3"
launch_file="$4"

mkdir -p "$(dirname "${pid_file}")"
touch "${log_file}"

if [[ -f "${pid_file}" ]]; then
  old_pid="$(cat "${pid_file}" 2>/dev/null || true)"
  if [[ -n "${old_pid}" ]] && kill -0 "${old_pid}" 2>/dev/null; then
    echo "${name} is already running with PID ${old_pid}."
    exit 0
  fi
fi

echo "===== $(date -Is) starting ${name}: ${launch_file} =====" >> "${log_file}"
if command -v setsid >/dev/null 2>&1; then
  nohup setsid bash -lc "source /opt/ros/humble/setup.bash && exec ros2 launch ${launch_file}" >> "${log_file}" 2>&1 &
else
  nohup bash -lc "source /opt/ros/humble/setup.bash && exec ros2 launch ${launch_file}" >> "${log_file}" 2>&1 &
fi
echo "$!" > "${pid_file}"
echo "Started ${name} with PID $(cat "${pid_file}")."
IN_CONTAINER
}

stop_bridge() {
  exec_script "${PROCESS_NAME}" "${STATE_DIR}/${PROCESS_NAME}.pid" <<'IN_CONTAINER'
set -euo pipefail

name="$1"
pid_file="$2"

if [[ ! -f "${pid_file}" ]]; then
  echo "${name} is not running."
  exit 0
fi

pid="$(cat "${pid_file}" 2>/dev/null || true)"
if [[ -z "${pid}" ]] || ! kill -0 "${pid}" 2>/dev/null; then
  rm -f "${pid_file}"
  echo "${name} is not running."
  exit 0
fi

kill -TERM "-${pid}" 2>/dev/null || kill -TERM "${pid}" 2>/dev/null || true

for _ in {1..40}; do
  if ! kill -0 "${pid}" 2>/dev/null; then
    rm -f "${pid_file}"
    echo "Stopped ${name}."
    exit 0
  fi
  sleep 0.25
done

kill -KILL "-${pid}" 2>/dev/null || kill -KILL "${pid}" 2>/dev/null || true
rm -f "${pid_file}"
echo "Killed ${name} after timeout."
IN_CONTAINER
}

status_bridge() {
  exec_script "${STATE_DIR}/${PROCESS_NAME}.pid" <<'IN_CONTAINER'
set -euo pipefail

pid_file="$1"

if [[ -f "${pid_file}" ]] && kill -0 "$(cat "${pid_file}")" 2>/dev/null; then
  echo "network_bridge: running (PID $(cat "${pid_file}"))"
else
  echo "network_bridge: stopped"
fi

echo "Routes:"
ip route
IN_CONTAINER
}

logs_bridge() {
  docker exec -it "${container_name}" tail -n 120 -f "${STATE_DIR}/${PROCESS_NAME}.log"
}

require_container

case "${action}" in
  restart|reset)
    stop_bridge
    drop_default_routes
    start_bridge
    ;;
  start)
    drop_default_routes
    start_bridge
    ;;
  stop)
    stop_bridge
    ;;
  status)
    status_bridge
    ;;
  logs)
    logs_bridge
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown action: ${action}" >&2
    usage >&2
    exit 2
    ;;
esac
