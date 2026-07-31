#!/usr/bin/env bash
set -e

SHIM_NAME="ipvlan_host"

echo "=================================================="
echo " Removing Host IPVLAN Shim Interface"
echo " Interface Name: ${SHIM_NAME}"
echo "=================================================="

# Check for root/sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo or as root."
  exit 1
fi

# Delete the shim interface
if ip link show "${SHIM_NAME}" >/dev/null 2>&1; then
    echo "Deleting ${SHIM_NAME}..."
    sudo ip link delete dev "${SHIM_NAME}"
    echo "Successfully removed ${SHIM_NAME}."
else
    echo "Interface ${SHIM_NAME} does not exist. Nothing to do."
fi

echo "=================================================="
echo " Cleanup complete!"
echo "=================================================="