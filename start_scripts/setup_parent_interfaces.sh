#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
CONFIG_DIR="${REPO_DIR}/configs"
TARGET_DIR="/etc/systemd/network"
LINK_FILE="${CONFIG_DIR}/10-eth_umrt.link"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo so it can install files under ${TARGET_DIR}." >&2
  exit 1
fi

if grep -q "INSERT YOUR INTERFACE MAC" "${LINK_FILE}"; then
  echo "Edit ${LINK_FILE} and replace the placeholder MAC address before running this." >&2
  exit 1
fi

install -d "${TARGET_DIR}"
install -m 0644 "${CONFIG_DIR}"/*.link "${TARGET_DIR}/"
install -m 0644 "${CONFIG_DIR}"/*.netdev "${TARGET_DIR}/"
install -m 0644 "${CONFIG_DIR}"/*.network "${TARGET_DIR}/"

systemctl enable --now systemd-networkd
systemctl restart systemd-networkd

echo "Installed systemd-networkd VLAN parent configuration."
echo "Expected links:"
ip -br link show eth_umrt eth_umrt.10 eth_umrt.20 || true
