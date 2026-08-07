# Comms 25-26 network_bridge setup tests

https://index.ros.org/p/network_bridge/
https://github.com/brow1633/network_bridge

#### docker network `bridge_lo` VLAN 10
Connects to x.10 interface
* subnet: `10.0.10.0/24`
* gateway: `10.0.10.1`

#### docker network `bridge_hi` VLAN 20
Connects to x.20 interface
* subnet: `10.0.20.0/24`
* gateway: `10.0.20.1`


| | Base Station | Rover |
|--|--|--|
| Low (900MHz) VLAN 10 | 10.0.10.57 | 10.0.10.59 |
| High (2.4GHz) VLAN 20 | 10.0.20.57 | 10.0.20.59 |



# Instructions

## 1. Build image 
Create image called bridge_test:v1
```bash
docker build -t bridge_test:v1 .
```

## 3. Create VLAN 10/20 and lo/hi docker nets
```bash
./start_scripts/create_docker_networks.sh
```

## 4. Start Base Station or Rover Container 
```bash
./start_scripts/start_base_containers.sh
```
```bash
./start_scripts/start_rover_containers.sh
```

## Foxglove container layout
The base-side Foxglove bridge now runs in its own container, but that container is attached to both `bridge_lo` and `bridge_hi`. This lets a single Foxglove bridge discover topics from both radio paths, and Docker publishes the host-side connection at `ws://localhost:8765`.

Important: the Fast DDS whitelist only limits DDS traffic to the listed interfaces. It does not firewall the Foxglove WebSocket listener inside the container. Because Foxglove binds `0.0.0.0` in the container, peers that can already reach the container IPs may still be able to connect directly to `10.0.10.49:8765` or `10.0.20.49:8765` unless you add an explicit firewall or proxy rule.

## Testing with topics
Open an extra terminal in `bridge_base`, `bridge_rover_hi`, or `bridge_rover_lo`
```bash
$ docker exec -it <bridge_base/bridge_rover_hi/bridge_rover_lo> bash
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
ros2 topic pub -r 1 /rv_lo/controls std_msgs/msg/String "{data: 'controls from base station'}"
```
#### Echo rover telemetry
```bash
ros2 topic echo /bs_lo/telemetry
```

# Connect with Foxglove UI on Base Station
Start the base-side containers:
```bash
./start_scripts/start_base_containers.sh
```

Then open Foxglove on the host computer and connect to:
```
ws://localhost:8765
```



# Cleanup
To clean up, stop the containers and remove the Docker networks:
```bash
docker compose -f compose/compose-foxglove-bridge.yaml down
docker compose -f compose/compose-base.yaml down
docker compose -f compose/compose-rover-hi.yaml down
docker compose -f compose/compose-rover-lo.yaml down
docker network rm bridge_lo bridge_hi
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




# No Network Bridge test setup - One time setup
### 1. Customize
Edit `./configs/10-eth_umrt.link` with your interface MAC address with
```bash
iplink
```
And pls pick the right one.

### 2. copy
Copy all files under `./configs/` to your local `/etc/systemd/network/`. This also checks if the target dir exists.
```bash
[ -d /etc/systemd/network/ ] && cp ./configs/* /etc/systemd/network/
```
### 3. Enable
Enable service to run on boot (and start)
```bash
sudo systemctl enable --now systemd-networkd
```
Or reset:
```bash
sudo systemctl restart systemd-networkd
```
OR REBOOT:
```bash
reboot
```

### Create docker networks
```bash
./start_scripts/create_docker_networks.sh
```

If you have an issue saying "network di-XXXXXXXXXXXX is already using parent interface eth_umrt.10":
```bash
sudo systemctl stop docker.socket
sudo systemctl stop docker
# Move for backup but really delete
sudo mv /var/lib/docker/network/files/local-kv.db ~/local-kv.db.backup
sudo systemctl start docker

```

# Run test containers
### 1. Rover side?
```bash
./start_scripts/start_rover_containers.sh
```
### 2. Base station side?
```bash
./start_scripts/start_base_containers.sh
```
