#!/usr/bin/env bash
set -euo pipefail

IP_CMD=""

log() {
  echo "network_policy: $*" >&2
}

resolve_ip_cmd() {
  local candidate=""

  for candidate in ip /usr/sbin/ip /usr/bin/ip /sbin/ip /bin/ip; do
    if [[ "$candidate" == */* ]]; then
      [[ -x "$candidate" ]] && {
        echo "$candidate"
        return 0
      }
    elif command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done

  return 1
}

default_routes() {
  "$IP_CMD" route show default 2>/dev/null || true
}

delete_route() {
  local route_line="$1"
  local gateway=""
  local dev=""
  local field=""
  local previous=""

  for field in $route_line; do
    case "$previous" in
      via)
        gateway="$field"
        ;;
      dev)
        dev="$field"
        ;;
    esac
    previous="$field"
  done

  if [[ -n "$gateway" && -n "$dev" ]]; then
    "$IP_CMD" route del default via "$gateway" dev "$dev" || true
  elif [[ -n "$dev" ]]; then
    "$IP_CMD" route del default dev "$dev" || true
  else
    "$IP_CMD" route del default || true
  fi
}

drop_all_default_routes() {
  local route_line=""

  while IFS= read -r route_line; do
    [[ -n "$route_line" ]] || continue
    delete_route "$route_line"
  done < <(default_routes)
}

keep_only_gateway() {
  local wanted_gateway="${PREFERRED_DEFAULT_GATEWAY:-}"
  local route_line=""

  if [[ -z "$wanted_gateway" ]]; then
    log "PREFERRED_DEFAULT_GATEWAY is unset; leaving routes unchanged"
    return
  fi

  while IFS= read -r route_line; do
    [[ -n "$route_line" ]] || continue
    if [[ "$route_line" == *" via ${wanted_gateway} "* || "$route_line" == *" via ${wanted_gateway}" ]]; then
      continue
    fi
    delete_route "$route_line"
  done < <(default_routes)
}

main() {
  local policy="${ROUTE_POLICY:-preserve}"

  if ! IP_CMD="$(resolve_ip_cmd)"; then
    if [[ "$policy" == "preserve" ]]; then
      log "'ip' is not installed; leaving routes unchanged"
      if [[ "$#" -eq 0 ]]; then
        set -- bash
      fi
      exec "$@"
    fi

    log "'ip' is not installed but ROUTE_POLICY='${policy}' requires iproute2; rebuild the image before starting these containers"
    exit 1
  fi

  case "$policy" in
    drop-default)
      drop_all_default_routes
      ;;
    keep-only-gateway)
      keep_only_gateway
      ;;
    preserve)
      ;;
    *)
      log "unknown ROUTE_POLICY '${policy}'; leaving routes unchanged"
      ;;
  esac

  log "active routes:"
  "$IP_CMD" route >&2 || true

  if [[ "$#" -eq 0 ]]; then
    set -- bash
  fi

  exec "$@"
}

main "$@"
