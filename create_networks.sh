#!/bin/bash
set -e

# --- Configuration Variables ---
# Original interface name
LONG_PARENT_IF="enx606d3cbcec44" 

# Target short name (max 10 chars so adding .10/.20 stays under 15 chars)
PARENT_IF="eth_main"

VLAN_LO_ID="10"
VLAN_HI_ID="20"

NET_LO="bridge_lo"
NET_HI="bridge_hi"

VLAN_LO_IF="${PARENT_IF}.${VLAN_LO_ID}"
VLAN_HI_IF="${PARENT_IF}.${VLAN_HI_ID}"

# --- Step 0: Rename Parent Interface if Necessary ---
echo "Checking interface name length..."

# If the long interface name exists on the system, rename it to the short name
if ip link show "$LONG_PARENT_IF" > /dev/null 2>&1; then
    echo "Renaming physical interface '${LONG_PARENT_IF}' to '${PARENT_IF}' to satisfy 15-char limit..."
    sudo ip link set dev "$LONG_PARENT_IF" down
    sudo ip link set dev "$LONG_PARENT_IF" name "$PARENT_IF"
    sudo ip link set dev "$PARENT_IF" up
fi

# Ensure parent interface is UP
sudo ip link set dev "$PARENT_IF" up

# --- Step 1: Create Host 802.1Q VLAN Sub-Interfaces ---
echo "Setting up VLAN sub-interfaces on ${PARENT_IF}..."

# Load 8021q kernel module if not already loaded
sudo modprobe 8021q 2>/dev/null || true

# Create VLAN 10 sub-interface (${PARENT_IF}.10)
if ! ip link show "$VLAN_LO_IF" > /dev/null 2>&1; then
    sudo ip link add link "$PARENT_IF" name "$VLAN_LO_IF" type vlan id "$VLAN_LO_ID"
    sudo ip link set dev "$VLAN_LO_IF" up
    echo "Created interface ${VLAN_LO_IF}"
fi

# Create VLAN 20 sub-interface (${PARENT_IF}.20)
if ! ip link show "$VLAN_HI_IF" > /dev/null 2>&1; then
    sudo ip link add link "$PARENT_IF" name "$VLAN_HI_IF" type vlan id "$VLAN_HI_ID"
    sudo ip link set dev "$VLAN_HI_IF" up
    echo "Created interface ${VLAN_HI_IF}"
fi

# --- Step 2: Create Docker Networks ---
echo "Creating Docker networks..."

# LO NETWORK (VLAN 10)
docker network create -d ipvlan \
    --subnet 10.0.1.0/24 \
    --gateway=10.0.1.200 \
    -o parent="$VLAN_LO_IF" \
    "$NET_LO"

# HI NETWORK (VLAN 20)
docker network create -d ipvlan \
    --subnet 10.0.2.0/24 \
    --gateway=10.0.2.200 \
    -o parent="$VLAN_HI_IF" \
    "$NET_HI"

echo "Success! Docker networks bridge_lo ($VLAN_LO_IF) and bridge_hi ($VLAN_HI_IF) created."