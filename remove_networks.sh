#!/usr/bin/env bash
set -e

# Parameter for parent interface (defaults to eth0 if not supplied)
PARENT_IF="${1:-eth0}"

echo "=================================================="
echo " Cleaning up VLANs and Docker ipvlan Networks"
echo " Parent Interface: ${PARENT_IF}"
echo "=================================================="

# Check for root/sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo or as root."
  exit 1
fi

# 1. Remove Docker networks
echo "[1/3] Removing Docker ipvlan networks..."
docker network rm bridge_lo bridge_hi 2>/dev/null || echo "Docker networks already removed."

# 2. Delete host VLAN interfaces
echo "[2/3] Deleting host VLAN sub-interfaces..."
if ip link show "${PARENT_IF}.10" >/dev/null 2>&1; then
    sudo ip link delete dev "${PARENT_IF}.10"
    echo "Removed ${PARENT_IF}.10"
fi

if ip link show "${PARENT_IF}.20" >/dev/null 2>&1; then
    sudo ip link delete dev "${PARENT_IF}.20"
    echo "Removed ${PARENT_IF}.20"
fi

# 3. Clean up host ipvlan shim if present
if ip link show ipvlan_host >/dev/null 2>&1; then
    sudo ip link delete dev ipvlan_host
    echo "Removed host shim interface (ipvlan_host)"
fi

echo "=================================================="
echo " Cleanup complete! Network interfaces restored."
echo "=================================================="