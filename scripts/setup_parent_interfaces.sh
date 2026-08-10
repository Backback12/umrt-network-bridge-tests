#!/usr/bin/env bash
set -euo pipefail

TARGET_IF="${TARGET_IF:-eth_umrt}"
ORIG_IF="${1:-}"

usage() {
  cat <<'USAGE'
Usage: sudo ./scripts/setup_parent_interfaces.sh <parent_interface>

Renames the radio parent interface to eth_umrt, then creates:
  eth_umrt.10
  eth_umrt.20

This is a one-time host setup step. Run ./scripts/create_docker_networks.sh
afterward to create bridge_lo and bridge_hi.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "${ORIG_IF}" ]]; then
  usage >&2
  exit 2
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo so it can configure host network interfaces." >&2
  exit 1
fi

echo "Setting up radio parent interfaces:"
echo "  original: ${ORIG_IF}"
echo "  target:   ${TARGET_IF}"

if ip link show "${ORIG_IF}" >/dev/null 2>&1; then
  ip link set dev "${ORIG_IF}" down
  ip link set dev "${ORIG_IF}" name "${TARGET_IF}"
elif ip link show "${TARGET_IF}" >/dev/null 2>&1; then
  echo "Interface is already named ${TARGET_IF}."
else
  echo "Neither ${ORIG_IF} nor ${TARGET_IF} exists." >&2
  exit 1
fi

modprobe 8021q

ip link set dev "${TARGET_IF}" up
if command -v ethtool >/dev/null 2>&1; then
  ethtool -K "${TARGET_IF}" rxvlan on txvlan on 2>/dev/null || true
fi

if ! ip link show "${TARGET_IF}.10" >/dev/null 2>&1; then
  ip link add link "${TARGET_IF}" name "${TARGET_IF}.10" type vlan id 10
fi
ip link set dev "${TARGET_IF}.10" up

if ! ip link show "${TARGET_IF}.20" >/dev/null 2>&1; then
  ip link add link "${TARGET_IF}" name "${TARGET_IF}.20" type vlan id 20
fi
ip link set dev "${TARGET_IF}.20" up

echo "Parent interfaces are ready:"
ip -br link show "${TARGET_IF}" "${TARGET_IF}.10" "${TARGET_IF}.20" || true
