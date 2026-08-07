#!/usr/bin/env bash
set -euo pipefail

RECREATE=0

usage() {
  cat <<'USAGE'
Usage: ./start_scripts/create_docker_networks.sh [--recreate]

Creates the two ipvlan Docker networks used by the radio VLANs:
  bridge_lo -> eth_umrt.10 -> 10.0.10.0/24
  bridge_hi -> eth_umrt.20 -> 10.0.20.0/24

No Docker gateway is configured. The containers only need directly connected
routes because there is no gateway/router device in this topology.

Options:
  --recreate   Remove existing bridge_lo/bridge_hi networks before creating them.
  -h, --help   Show this help text.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --recreate)
      RECREATE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_parent() {
  local parent="$1"

  if ! ip link show "$parent" >/dev/null 2>&1; then
    echo "Missing parent interface ${parent}." >&2
    echo "Install the systemd-networkd files in ./configs first, then restart systemd-networkd." >&2
    exit 1
  fi
}

network_exists() {
  docker network inspect "$1" >/dev/null 2>&1
}

inspect_network() {
  local name="$1"
  local template="$2"

  docker network inspect --format "${template}" "${name}"
}

validate_network() {
  local name="$1"
  local expected_subnet="$2"
  local expected_parent="$3"
  local driver=""
  local parent=""
  local subnet=""
  local gateway=""

  driver="$(inspect_network "${name}" '{{.Driver}}')"
  parent="$(inspect_network "${name}" '{{index .Options "parent"}}')"
  subnet="$(inspect_network "${name}" '{{(index .IPAM.Config 0).Subnet}}')"
  gateway="$(inspect_network "${name}" '{{(index .IPAM.Config 0).Gateway}}')"

  if [[ "${gateway}" == "<no value>" ]]; then
    gateway=""
  fi

  if [[ "${driver}" == "ipvlan" && "${parent}" == "${expected_parent}" && "${subnet}" == "${expected_subnet}" && -z "${gateway}" ]]; then
    echo "Docker network ${name} already exists and matches the expected config."
    return
  fi

  echo "Docker network ${name} exists but does not match the expected config." >&2
  echo "  found:    driver=${driver} parent=${parent} subnet=${subnet} gateway=${gateway:-none}" >&2
  echo "  expected: driver=ipvlan parent=${expected_parent} subnet=${expected_subnet} gateway=none" >&2
  echo "Run this after stopping attached containers: ./start_scripts/create_docker_networks.sh --recreate" >&2
  exit 1
}

remove_network_if_requested() {
  local name="$1"

  if [[ "${RECREATE}" -eq 1 ]] && network_exists "$name"; then
    docker network rm "$name" >/dev/null
  fi
}

create_network() {
  local name="$1"
  local subnet="$2"
  local parent="$3"

  remove_network_if_requested "$name"

  if network_exists "$name"; then
    validate_network "$name" "$subnet" "$parent"
    return
  fi

  docker network create \
    -d ipvlan \
    --subnet "${subnet}" \
    -o ipvlan_mode=l2 \
    -o parent="${parent}" \
    "${name}" >/dev/null
}

print_network() {
  local name="$1"

  docker network inspect \
    --format '  {{.Name}}: driver={{.Driver}} parent={{index .Options "parent"}} subnet={{(index .IPAM.Config 0).Subnet}} gateway={{(index .IPAM.Config 0).Gateway}}' \
    "$name"
}

require_command docker
require_command ip

require_parent eth_umrt.10
require_parent eth_umrt.20

create_network bridge_lo 10.0.10.0/24 eth_umrt.10
create_network bridge_hi 10.0.20.0/24 eth_umrt.20

echo "Docker radio networks are ready:"
print_network bridge_lo
print_network bridge_hi
