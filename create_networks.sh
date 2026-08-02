#!/usr/bin/env bash
set -e

# Target standardized interface name
TARGET_IF="eth_umrt"

# Parameter for original parent interface (defaults to long name if not supplied)
ORIG_IF="${1}"

echo "=================================================="
echo " Setting up VLANs and Docker ipvlan Networks"
echo " Original Interface: ${ORIG_IF}"
echo " Renamed Interface:  ${TARGET_IF}"
echo "=================================================="

# Check for root/sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo or as root."
  exit 1
fi

# 1. Rename the interface to eth_umrt (if not already renamed)
if ip link show "${ORIG_IF}" >/dev/null 2>&1; then
    echo "[1/6] Renaming interface ${ORIG_IF} -> ${TARGET_IF}..."
    sudo ip link set dev "${ORIG_IF}" down
    sudo ip link set dev "${ORIG_IF}" name "${TARGET_IF}"
elif ip link show "${TARGET_IF}" >/dev/null 2>&1; then
    echo "[1/6] Interface already named ${TARGET_IF}."
else
    echo "Error: Neither ${ORIG_IF} nor ${TARGET_IF} was found."
    exit 1
fi

# 2. Ensure kernel module for 802.1Q VLAN tagging is loaded
echo "[2/6] Loading 8021q VLAN kernel module..."
sudo modprobe 8021q

# 3. Ensure parent interface is UP and Hardware Offloading is set
echo "[3/6] Configuring ${TARGET_IF} hardware offloading..."
sudo ip link set dev "${TARGET_IF}" up
sudo ethtool -K "${TARGET_IF}" rxvlan on txvlan on 2>/dev/null || true

# 4. Create host VLAN 10 interface (eth_umrt.10)
echo "[4/6] Setting up ${TARGET_IF}.10 (VLAN 10)..."
if ! ip link show "${TARGET_IF}.10" >/dev/null 2>&1; then
    sudo ip link add link "${TARGET_IF}" name "${TARGET_IF}.10" type vlan id 10
fi
sudo ip link set dev "${TARGET_IF}.10" up

# 5. Create host VLAN 20 interface (eth_umrt.20)
echo "[5/6] Setting up ${TARGET_IF}.20 (VLAN 20)..."
if ! ip link show "${TARGET_IF}.20" >/dev/null 2>&1; then
    sudo ip link add link "${TARGET_IF}" name "${TARGET_IF}.20" type vlan id 20
fi
sudo ip link set dev "${TARGET_IF}.20" up

# 6. Create Docker ipvlan networks
echo "[6/6] Provisioning Docker ipvlan networks..."

# Remove stale Docker networks if they already exist
docker network rm bridge_lo bridge_hi 2>/dev/null || true

docker network create -d ipvlan \
    --subnet 10.0.10.0/24 \
    --gateway=10.0.10.200 \
    -o parent="${TARGET_IF}.10" \
    bridge_lo

docker network create -d ipvlan \
    --subnet 10.0.20.0/24 \
    --gateway=10.0.20.200 \
    -o parent="${TARGET_IF}.20" \
    bridge_hi

echo "=================================================="
echo " Network setup complete!"
echo " Created: ${PARENT_IF}.10 -> Docker network: bridge_lo"
echo " Created: ${PARENT_IF}.20 -> Docker network: bridge_hi"
echo "=================================================="