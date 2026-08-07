#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "network_policy: $*" >&2
}

delete_default_route() {
  local route_line="$1"
  local gateway=""
  local dev=""
  local previous=""
  local field=""

  for field in ${route_line}; do
    case "${previous}" in
      via)
        gateway="${field}"
        ;;
      dev)
        dev="${field}"
        ;;
    esac
    previous="${field}"
  done

  if [[ -n "${gateway}" && -n "${dev}" ]]; then
    ip route del default via "${gateway}" dev "${dev}" || true
  elif [[ -n "${dev}" ]]; then
    ip route del default dev "${dev}" || true
  else
    ip route del default || true
  fi
}

drop_default_routes() {
  local route_line=""

  while IFS= read -r route_line; do
    [[ -n "${route_line}" ]] || continue
    delete_default_route "${route_line}"
  done < <(ip route show default 2>/dev/null || true)
}

main() {
  local policy="${ROUTE_POLICY:-drop-default}"

  if [[ "${policy}" == "drop-default" ]]; then
    drop_default_routes
  elif [[ "${policy}" != "preserve" ]]; then
    log "unknown ROUTE_POLICY '${policy}'; expected drop-default or preserve"
  fi

  if [[ -f /opt/ros/humble/setup.bash ]]; then
    set +u
    source /opt/ros/humble/setup.bash
    set -u
  fi

  log "active routes:"
  ip route >&2 || true

  if [[ "$#" -eq 0 ]]; then
    set -- bash
  fi

  exec "$@"
}

main "$@"
