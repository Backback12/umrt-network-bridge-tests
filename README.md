# Comms 25-26 network_bridge setup tests

https://index.ros.org/p/network_bridge/
https://github.com/brow1633/network_bridge

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
./scripts/start_rover.sh
```

## 4. Start or restart network_bridge
Run this after changing any launch or YAML config. The same script works on base and rover:
```bash
./scripts/restart_network_bridge.sh base
./scripts/restart_network_bridge.sh rover
```
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

### Test topics over interfaces
Its configured now so that the ROS2 topic prefix determines what to communicate over:

<!-- |             | Send to Base Station | Send to Rover |
|----------------|-----------------|---------------------|
| Use Low Bridge | `/bs_lo/<name>` | `/rv_lo/<name>` |
| Use High Bridge| `/bs_hi/<name>` | `/rv_hi/<name>` | -->

Connor update this

|       | Use Low Bridge | Use High Bridge |
|----------------|-----------------|------------|
| Send to Base Station | `/bs_lo/<name>` | `/bs_hi/<name>` |
| Send to Rover | `/rv_lo/<name>` | `/rv_hi/<name>` |

**I THINK RIGHT NOW IT ONLY WORKS WITH THESE TOPICS:**
```
/bs_hi/camera
/bs_lo/telemetry
/rv_hi/selfie
/rv_lo/controls
```

### Rover side:
#### Start send string telemetry
```bash
ros2 topic pub -r 1 /bs_lo/telemetry std_msgs/msg/String "{data: 'Telemetry data'}"
```
#### Start USB Camera test:
```bash
ros2 run usb_cam usb_cam_node_exe --ros-args   -p video_device:="/dev/video0"   -p pixel_format:="mjpeg2rgb"   -p image_encoding:="mono8"   -p image_width:=160   -p image_height:=120   -r image_raw:=/bs_hi/camera
```

<!-- ```bash
ros2 run usb_cam usb_cam_node_exe --ros-args \
  -p video_device:="/dev/video0" \
  -p pixel_format:="mjpeg2rgb" \
  -p image_encoding:="mono8" \
  -p image_width:=160 \
  -p image_height:=120 \
  -p qos_overrides./bs_hi/camera.publisher.reliability:=best_effort \
  -p qos_overrides./bs_hi/camera.publisher.durability:=volatile \
  -r image_raw:=/bs_hi/camera
``` -->


Or if no video:
```bash
ros2 topic pub -r 1 /bs_hi/camera std_msgs/msg/String "{data: 'CAMERA STUFF'}"
```

### Base side:
#### Test Publishing
```bash
ros2 topic pub -r 1 /rv_hi/selfie std_msgs/msg/String "{data: 'selfie hi data'}"
ros2 topic pub -r 1 /bs_lo/controls std_msgs/msg/String "{data: 'controls from base station'}"
```
#### Echo rover telemetry
```bash
ros2 topic echo /rv_lo/telemetry
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
docker compose -f compose/compose-rover.yaml down
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
