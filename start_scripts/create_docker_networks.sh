# Remove stale Docker networks if they already exist
#!/usr/bin/env bash
set -e

docker network rm bridge_lo bridge_hi 2>/dev/null || true

docker network create -d ipvlan \
    --subnet 10.0.10.0/24 \
    --gateway=10.0.10.200 \
    -o parent="umrt_eth.10" \
    bridge_lo

docker network create -d ipvlan \
    --subnet 10.0.20.0/24 \
    --gateway=10.0.20.200 \
    -o parent="umrt_eth.20" \
    bridge_hi

echo "=================================================="
echo " Network setup complete!"
echo " Created: umrt_eth.10 -> Docker network: bridge_lo"
echo " Created: umrt_eth.20 -> Docker network: bridge_hi"
echo "=================================================="