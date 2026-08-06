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

## 1. Build image 
Create image called bridge_test:v1
```bash
docker build -t bridge_test:v1 .
```

## 3. Create VLAN 10/20 and lo/hi docker nets
```bash
./create_networks.sh <your_parent_network_interface>
```

## 4. Start Base Station or Rover Container 
```bash
docker compose -f compose-base.yaml up -d
```
```bash
docker compose -f compose-rover.yaml up -d
```

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
This is to enable connecting to the container from your host computer with Foxglove
```bash
./create_foxglove_host_bridge.sh <.20 interface name>
```
It might work differently than changing your host IP to be under the 10.0.1.x subet?

Start Foxglove and open the connection to:
```
ws://10.0.20.57:8765
```



# Cleanup
To clean up, run scripts:
```bash
./remove_foxglove_bridge_host.sh
./remove_networks.sh <your_parent_network_interface>
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


