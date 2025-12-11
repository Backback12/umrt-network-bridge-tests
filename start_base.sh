#!/bin/bash
# set -e

CONTAINER_NAME="bridge_base"
IMAGE="bridge_test:v1"

NET_HI="bridge_hi"
IP_HI="10.0.2.1"
NET_LO="bridge_lo"
IP_LO="10.0.1.1"




# clean up after container closes, --rm doesnt seem to work with this setup
cleanup() {
    echo "Cleaning container..."
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
}
trap cleanup EXIT


echo "Creating container..."
docker create \
    -it \
    --name "$CONTAINER_NAME" \
    --network="$NET_LO" --ip="$IP_LO" \
    --entrypoint /bin/bash \
    "$IMAGE"


echo "Connecting container to ($NET_HI)..."
docker network connect --ip="$IP_HI" "$NET_HI" "$CONTAINER_NAME"


echo "Starting container..."
docker start -ai "$CONTAINER_NAME"
