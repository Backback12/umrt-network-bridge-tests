#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "network_policy: $*" >&2
}

default_routes() {
  ip route show default 2>/dev/null || true
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
    ip route del default via "$gateway" dev "$dev" || true
  elif [[ -n "$dev" ]]; then
    ip route del default dev "$dev" || true
  else
    ip route del default || true
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

  if ! command -v ip >/dev/null 2>&1; then
    log "'ip' is not installed; skipping route policy"
    if [[ "$#" -eq 0 ]]; then
      set -- bash
    fi
    exec "$@"
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
  ip route >&2 || true

  if [[ "$#" -eq 0 ]]; then
    set -- bash
  fi

  exec "$@"
}

main "$@"
