# Remove stale Docker networks if they already exist
#!/usr/bin/env bash
set -e

docker network rm bridge_lo bridge_hi 2>/dev/null || true

docker network create -d ipvlan \
    --subnet 10.0.10.0/24 \
    --gateway=10.0.10.1 \
    -o ipvlan_mode=l2 \
    -o parent="eth_umrt.10" \
    bridge_lo

docker network create -d ipvlan \
    --subnet 10.0.20.0/24 \
    --gateway=10.0.20.1 \
    -o ipvlan_mode=l2 \
    -o parent="eth_umrt.20" \
    bridge_hi

echo "=================================================="
echo " Network setup complete!"
echo " Created: umrt_eth.10 -> Docker network: bridge_lo"
echo " Created: umrt_eth.20 -> Docker network: bridge_hi"
echo "=================================================="
