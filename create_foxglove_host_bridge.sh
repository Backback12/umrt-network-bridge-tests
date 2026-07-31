#!/usr/bin/env bash
set -e

# Parameter for target VLAN parent sub-interface (defaults to eth0.20)
VLAN_IF="${1:-eth0.20}"
SHIM_NAME="ipvlan_host"
SHIM_IP="10.0.20.49/24"

echo "=================================================="
echo " Adding Host IPVLAN Shim Interface for Foxglove"
echo " Target Parent Interface: ${VLAN_IF}"
echo " Shim Interface Name:    ${SHIM_NAME}"
echo " Assigned Host IP:        ${SHIM_IP}"
echo "=================================================="

# Check for root/sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo or as root."
  exit 1
fi

# 1. Clean up any existing shim interface
echo "[1/4] Cleaning up old shim interface if present..."
sudo ip link delete dev "${SHIM_NAME}" 2>/dev/null || true

# 2. Attach ipvlan shim interface to the specified VLAN sub-interface
echo "[2/4] Attaching ${SHIM_NAME} to ${VLAN_IF}..."
sudo ip link add link "${VLAN_IF}" name "${SHIM_NAME}" type ipvlan mode l2

# 3. Assign an IP address on the 10.0.20.0/24 subnet to the host shim
echo "[3/4] Assigning IP ${SHIM_IP} to ${SHIM_NAME}..."
sudo ip addr add "${SHIM_IP}" dev "${SHIM_NAME}"

# 4. Bring the shim interface UP
echo "[4/4] Bringing up ${SHIM_NAME}..."
sudo ip link set dev "${SHIM_NAME}" up

# Optional: Disable Reverse Path Filtering if asymmetric routing drops packets
# sudo sysctl -w net.ipv4.conf.all.rp_filter=0
# sudo sysctl -w net.ipv4.conf.${SHIM_NAME}.rp_filter=0

echo "=================================================="
echo " Setup complete!"
echo " Host is now reachable on 10.0.20.0/24 via ${SHIM_NAME}"
echo " Connect Foxglove Studio to: ws://10.0.20.57:8765"
echo "=================================================="