#!/bin/bash
set -e

NET_HI="bridge_hi"
NET_LO="bridge_lo"



echo "Creating docker networks..."
# LO NETWORK
docker network create -d ipvlan \
    --subnet 10.0.1.0/24 \
    --gateway=10.0.1.200 \
    "$NET_LO"
    # -o parent=di-12345678 \

# HI NETWORK
docker network create -d ipvlan \
    --subnet 10.0.2.0/24 \
    --gateway=10.0.2.200 \
    "$NET_HI"
    # -o parent=di-12345678 \

echo "brige_lo and bridge_hi docker networks created."
