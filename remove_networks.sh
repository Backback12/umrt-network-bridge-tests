#!/bin/bash
set -e

# --- Configuration Variables ---
LONG_PARENT_IF="enx606d3cbcec44"
PARENT_IF="eth_main"

VLAN_LO_ID="10"
VLAN_HI_ID="20"

NET_LO="bridge_lo"
NET_HI="bridge_hi"

VLAN_LO_IF="${PARENT_IF}.${VLAN_LO_ID}"
VLAN_HI_IF="${PARENT_IF}.${VLAN_HI_ID}"

echo "Starting cleanup..."

# --- Step 1: Remove Docker Networks ---
echo "Removing Docker networks..."

if docker network inspect "$NET_LO" >/dev/null 2>&1; then
    docker network rm "$NET_LO"
    echo "Removed Docker network: ${NET_LO}"
else
    echo "Docker network '${NET_LO}' not found. Skipping."
fi

if docker network inspect "$NET_HI" >/dev/null 2>&1; then
    docker network rm "$NET_HI"
    echo "Removed Docker network: ${NET_HI}"
else
    echo "Docker network '${NET_HI}' not found. Skipping."
fi

# --- Step 2: Delete VLAN Sub-Interfaces ---
echo "Deleting VLAN sub-interfaces..."

if ip link show "$VLAN_LO_IF" >/dev/null 2>&1; then
    sudo ip link delete dev "$VLAN_LO_IF"
    echo "Deleted interface: ${VLAN_LO_IF}"
fi

if ip link show "$VLAN_HI_IF" >/dev/null 2>&1; then
    sudo ip link delete dev "$VLAN_HI_IF"
    echo "Deleted interface: ${VLAN_HI_IF}"
fi

# --- Step 3: Revert Parent Interface Name ---
echo "Checking parent interface..."

if ip link show "$PARENT_IF" >/dev/null 2>&1; then
    echo "Restoring original interface name '${LONG_PARENT_IF}'..."
    sudo ip link set dev "$PARENT_IF" down
    sudo ip link set dev "$PARENT_IF" name "$LONG_PARENT_IF"
    sudo ip link set dev "$LONG_PARENT_IF" up
    echo "Successfully renamed '${PARENT_IF}' back to '${LONG_PARENT_IF}'."
fi

echo "Cleanup complete!"