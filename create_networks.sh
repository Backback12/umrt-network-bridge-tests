#!/bin/bash
set -e

echo "Creating docker networks..."

# LO NETWORK
docker network create -d ipvlan \
    --subnet 192.168.1.0/24 \
    --gateway=192.168.1.200 \
    bridge_lo
    # -o parent=di-12345678 \

# HI NETWORK
docker network create -d ipvlan \
    --subnet 192.168.2.0/24 \
    --gateway=192.168.2.200 \ 
    bridge_hi
    # -o parent=di-12345678 \

echo "brige_lo and bridge_hi docker networks created."
