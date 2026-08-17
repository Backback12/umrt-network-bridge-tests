# Comms 25-26 Zenoh bridge setup tests

This branch swaps the previous `network_bridge` UDP setup for `zenoh-bridge-ros2dds`:

https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds

#### docker network `bridge_lo` VLAN 10
Connects to x.10 interface
* subnet: `10.0.10.0/24`
* gateway: `10.0.10.200`

#### docker network `bridge_hi` VLAN 20
Connects to x.20 interface
* subnet: `10.0.20.0/24`
* gateway: `10.0.20.200`


| | Base Station | Rover |
|--|--|--|
| Low (900MHz) VLAN 10 | 10.0.10.57 | 10.0.10.59 |
| High (2.4GHz) VLAN 20 | 10.0.20.57 | 10.0.20.59 |



# Instructions

## 1. Create VLAN 10/20 parent interfaces
```bash
sudo ./scripts/setup_parent_interfaces.sh <your_parent_network_interface>
```

## 2. Create lo/hi Docker networks
```bash
./scripts/create_docker_networks.sh
```

## 3. Start Base Station or Rover Container
```bash
./scripts/start_base.sh
```
Foxglove runs inside `bridge_base` and is published on the host at:
```text
ws://localhost:8765
```
```bash
./scripts/start_rover.sh lo
./scripts/start_rover.sh hi
./scripts/start_rover.sh both
```

Zenoh starts automatically when the container starts. After changing a JSON5 config, recreate the relevant stack:
```bash
docker compose -f compose/compose-base.yaml up -d --force-recreate
docker compose -f compose/compose-rover-lo.yaml up -d --force-recreate
docker compose -f compose/compose-rover-hi.yaml up -d --force-recreate
docker compose -f compose/compose-rover-both.yaml up -d --force-recreate
```

## 4. Install `zenoh-bridge-ros2dds` in the image

The compose files now assume the rover/base image already contains the `zenoh-bridge-ros2dds` executable.
Using the Debian package from Eclipse Zenoh is enough:

```bash
mkdir -p /etc/apt/keyrings
curl -L https://download.eclipse.org/zenoh/debian-repo/zenoh-public-key | gpg --dearmor --yes --output /etc/apt/keyrings/zenoh-public-key.gpg
echo "deb [signed-by=/etc/apt/keyrings/zenoh-public-key.gpg] https://download.eclipse.org/zenoh/debian-repo/ /" > /etc/apt/sources.list.d/zenoh.list
apt-get update
apt-get install -y zenoh-bridge-ros2dds
```

If you already maintain a custom base image, installing that one package there should be the only extra image change required for this branch.

For adding existing app containers or `docker run` start scripts to the radio networks, see [docs/custom-container.md](docs/custom-container.md).

## Testing with topics
Open an extra terminal in `bridge_rover` OR `bridge_base`
```bash
$ docker exec -it <bridge_rover/bridge_base> bash
```
Source ROS2:
```bash
source /opt/ros/humble/setup.bash
```

### Bridged topics

Only the topics listed in the Zenoh JSON5 allowlists will cross each radio link.

Low radio:
```
/rover/poe/imu
/telemetry
/cmd_velocity
/controls
```

High radio:
```
/rover/poe/encoded_video
/arm_cam0/image_raw/ffmpeg
/camera
```

### Rover side:
#### Start send string telemetry
```bash
ros2 topic pub -r 1 /telemetry std_msgs/msg/String "{data: 'Telemetry data'}"
```
#### Start USB Camera test:
```bash
ros2 run usb_cam usb_cam_node_exe --ros-args   -p video_device:="/dev/video0"   -p pixel_format:="mjpeg2rgb"   -p image_encoding:="mono8"   -p image_width:=160   -p image_height:=120   -r image_raw:=/camera
```

Or if no video:
```bash
ros2 topic pub -r 1 /camera std_msgs/msg/String "{data: 'CAMERA STUFF'}"
```

### Base side:
#### Test Publishing
```bash
ros2 topic pub -r 1 /controls std_msgs/msg/String "{data: 'controls from base station'}"
```
#### Echo rover telemetry
```bash
ros2 topic echo /telemetry
```

# Connect with Foxglove UI on Base Station
Start the base container, then open Foxglove on the host and connect to:
```
ws://localhost:8765
```



# Cleanup
To stop containers:
```bash
docker compose -f compose/compose-base.yaml down
docker compose -f compose/compose-rover-lo.yaml down
docker compose -f compose/compose-rover-hi.yaml down
docker compose -f compose/compose-rover-both.yaml down
```


# MANAGED NETWORK SWITCH CONFIG
## 802.1Q VLAN
| VLAN_ID | Tagged Ports | Untagged Ports |
|---------|--------------|----------------|
| 1 (Default) | | 2,3,4,5,6,7,8 |
| 10 (900_MHZ) | 6.7.8 | 1 |
| 20 (2400_MHZ) | 6,7,8 | 2 |
| 30 (LOCAL) | 3,4,5,6,7,8 | |
| 99 (DEBUG) | 1,2,8 | 

## 802.1Q PVID Setting
| Port | PVID |
|------|------|
| 1 | 10 |
| 2 | 20 |
| 3 | 1 |
| 4 | 1 |
| 5 | 1 |
| 6 | 1 |
| 7 | 1 |
| 8 | 1 |
