# ROS2 VLAN bridge test

This project creates one ROS2 base-side stack and one rover-side stack across two isolated radio VLANs.

The important rule is simple: rover high and rover low do not share a Docker network. Only the base-side containers are attached to both VLANs.

## Topology

There is no gateway/router device in this setup. All communication is directly connected on the two VLAN subnets.

| Side | Container | Network | IP |
| --- | --- | --- | --- |
| Base | `bridge_base` | VLAN 10 / `bridge_lo` | `10.0.10.57` |
| Base | `bridge_base` | VLAN 20 / `bridge_hi` | `10.0.20.57` |
| Foxglove | `foxglove_bridge` | VLAN 10 / `bridge_lo` | `10.0.10.49` |
| Foxglove | `foxglove_bridge` | VLAN 20 / `bridge_hi` | `10.0.20.49` |
| Rover low | `bridge_rover_lo` | VLAN 10 / `bridge_lo` | `10.0.10.59` |
| Rover high | `bridge_rover_hi` | VLAN 20 / `bridge_hi` | `10.0.20.59` |

`foxglove_bridge` also joins a normal Docker bridge network named by Compose. That local bridge is only for the host-side Foxglove WebSocket publish path. `bridge_base` is only attached to the two radio VLAN networks, and the rover containers are each attached to only one radio VLAN.

## What was wrong before

- The Docker ipvlan networks were configured with gateway IPs (`10.0.10.1`, `10.0.20.1`) even though this topology has no gateway device. That gave containers useless default routes and made the dual-homed base/Foxglove path fragile.
- The base and Foxglove containers had two Docker default routes, then a route script tried to keep only one nonexistent gateway. Direct VLAN routes are the only routes this setup needs.
- Foxglove was attached only to ipvlan networks while also trying to publish `127.0.0.1:8765`. A normal Docker bridge attachment is the reliable way to make the WebSocket available on host localhost.
- The compose files and start scripts rebuilt images implicitly with `--build`. The scripts now build the image first, then start containers from that image.
- The old Fast DDS XML files were trying to compensate for a network design problem. This version keeps only small Fast DDS profiles that map directly to the container IPs, because Fast DDS otherwise used the first base interface and did not carry high-side topic data.
- The old Docker network script had text before the shebang and a typo in the printed interface name. It also removed networks every time, which is painful when containers are attached.
- `configs/10-eth_umrt.link` still contains a placeholder MAC address. Replace it before installing the host network config.

Seeing a topic name from the other rover side but being unable to echo it can still happen with DDS discovery and multi-homed participants. That is not the same as the two rover containers having direct network reachability.

## DDS policy

The Docker network layout is the real isolation boundary. The Fast DDS XML files only make DDS interface selection deterministic:

- `fastdds-base.xml` allows `10.0.10.57` and `10.0.20.57`.
- `fastdds-foxglove.xml` allows `10.0.10.49` and `10.0.20.49`, but not the local Docker bridge address used for the host WebSocket.
- `fastdds-rover-lo.xml` allows only `10.0.10.59`.
- `fastdds-rover-hi.xml` allows only `10.0.20.59`.

I tried the fully default Fast DDS path first. The low VLAN carried real ROS sample data, but the high VLAN only passed ICMP and did not echo ROS samples from base. These minimal profiles fix that without using ROS topic bridges or gateway routing.

## Host parent interfaces

Edit the MAC address in:

```bash
configs/10-eth_umrt.link
```

Then install the systemd-networkd parent/VLAN config:

```bash
sudo ./start_scripts/setup_parent_interfaces.sh
```

Expected host links:

```text
eth_umrt
eth_umrt.10
eth_umrt.20
```

## Create Docker radio networks

Create the gateway-less ipvlan networks:

```bash
./start_scripts/create_docker_networks.sh
```

If stale networks already exist with the old gateway config, recreate them:

```bash
./start_scripts/create_docker_networks.sh --recreate
```

Expected Docker networks:

| Docker network | Driver | Parent | Subnet | Gateway |
| --- | --- | --- | --- | --- |
| `bridge_lo` | `ipvlan` | `eth_umrt.10` | `10.0.10.0/24` | none |
| `bridge_hi` | `ipvlan` | `eth_umrt.20` | `10.0.20.0/24` | none |

## Start containers

Start the base side:

```bash
./start_scripts/start_base_containers.sh
```

Start the rover side:

```bash
./start_scripts/start_rover_containers.sh
```

Both scripts build `bridge_test:v1` before starting their Compose stack. Override the image tag with `BRIDGE_TEST_IMAGE` if needed.

## Foxglove

After the base side is running, open Foxglove on the host and connect to:

```text
ws://localhost:8765
```

## Quick checks

Check addresses and routes:

```bash
docker exec bridge_base ip -br addr
docker exec bridge_base ip route
docker exec bridge_rover_lo ip route
docker exec bridge_rover_hi ip route
```

The containers should have direct routes for their attached subnets and no default route.

Check network isolation:

```bash
docker exec bridge_rover_lo ping -c 2 10.0.10.57
docker exec bridge_rover_hi ping -c 2 10.0.20.57
docker exec bridge_rover_lo ping -c 2 10.0.20.59
```

The first two should work. The last one should fail because rover low and rover high are not connected to the same network.

Check ROS topics:

```bash
docker exec -it bridge_rover_lo bash
ros2 topic pub -r 1 /bs_lo/telemetry std_msgs/msg/String "{data: 'Telemetry data'}"
```

```bash
docker exec -it bridge_rover_hi bash
ros2 topic pub -r 1 /bs_hi/camera std_msgs/msg/String "{data: 'CAMERA STUFF'}"
```

```bash
docker exec -it bridge_base bash
ros2 topic echo /bs_lo/telemetry
ros2 topic echo /bs_hi/camera
```

Base-to-rover examples:

```bash
docker exec -it bridge_base bash
ros2 topic pub -r 1 /rv_lo/controls std_msgs/msg/String "{data: 'controls from base station'}"
ros2 topic pub -r 1 /rv_hi/selfie std_msgs/msg/String "{data: 'selfie hi data'}"
```

## Cleanup

```bash
docker compose -f compose/compose-base.yaml down
docker compose -f compose/compose-rover.yaml down
docker network rm bridge_lo bridge_hi
```

## Managed switch reminder

| VLAN ID | Purpose | Tagged ports | Untagged ports |
| --- | --- | --- | --- |
| 10 | 900 MHz | 6, 7, 8 | 1 |
| 20 | 2.4 GHz | 6, 7, 8 | 2 |
| 30 | Local | 3, 4, 5, 6, 7, 8 | |
| 99 | Debug | 1, 2, 8 | |

| Port | PVID |
| --- | --- |
| 1 | 10 |
| 2 | 20 |
| 3 | 1 |
| 4 | 1 |
| 5 | 1 |
| 6 | 1 |
| 7 | 1 |
| 8 | 1 |
