#!/usr/bin/env bash
set -e

# Parameter for parent interface (defaults to eth0 if not supplied)
PARENT_IF="${1:-eth0}"

echo "=================================================="
echo " Setting up VLANs and Docker ipvlan Networks"
echo " Parent Interface: ${PARENT_IF}"
echo "=================================================="

# Check for root/sudo privileges for ip/ethtool commands
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo or as root."
  exit 1
fi

# 1. Ensure kernel module for 802.1Q VLAN tagging is loaded
echo "[1/5] Loading 8021q VLAN kernel module..."
sudo modprobe 8021q

# 2. Ensure parent interface is UP and Hardware Offloading is set
echo "[2/5] Configuring parent interface hardware offloading..."
sudo ip link set dev "${PARENT_IF}" up
sudo ethtool -K "${PARENT_IF}" rxvlan on txvlan on 2>/dev/null || true

# 3. Create host VLAN 10 interface (Raw L2 conduit - NO IP assigned)
echo "[3/5] Setting up ${PARENT_IF}.10 (VLAN 10)..."
if ! ip link show "${PARENT_IF}.10" >/dev/null 2>&1; then
    sudo ip link add link "${PARENT_IF}" name "${PARENT_IF}.10" type vlan id 10
fi
sudo ip link set dev "${PARENT_IF}.10" up

# 4. Create host VLAN 20 interface (Raw L2 conduit - NO IP assigned)
echo "[4/5] Setting up ${PARENT_IF}.20 (VLAN 20)..."
if ! ip link show "${PARENT_IF}.20" >/dev/null 2>&1; then
    sudo ip link add link "${PARENT_IF}" name "${PARENT_IF}.20" type vlan id 20
fi
sudo ip link set dev "${PARENT_IF}.20" up

# 5. Create Docker ipvlan networks
echo "[5/5] Provisioning Docker ipvlan networks..."

# Remove stale Docker networks if they already exist
docker network rm bridge_lo bridge_hi 2>/dev/null || true

docker network create -d ipvlan \
    --subnet 10.0.10.0/24 \
    --gateway=10.0.10.200 \
    -o parent="${PARENT_IF}.10" \
    bridge_lo

docker network create -d ipvlan \
    --subnet 10.0.20.0/24 \
    --gateway=10.0.20.200 \
    -o parent="${PARENT_IF}.20" \
    bridge_hi

echo "=================================================="
echo " Network setup complete!"
echo " Created: ${PARENT_IF}.10 -> Docker network: bridge_lo"
echo " Created: ${PARENT_IF}.20 -> Docker network: bridge_hi"
echo "=================================================="