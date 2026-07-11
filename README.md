# Comms 25-26 network_bridge setup

https://index.ros.org/p/network_bridge/
https://github.com/brow1633/network_bridge

#### docker network `bridge_lo`  
* subnet: `10.0.1.0/24`
* gateway: `10.0.1.200`

#### docker network `bridge_hi`
* subnet: `10.0.2.0/24`
* gateway: `10.0.2.200`


| | Base Station | Rover |
|--|--|--|
| Low (900MHz) | 10.0.1.1 | 10.0.1.2 |
| High (2.4GHz) | 10.0.2.1 | 10.0.2.2 |



# Instructions

## 1. create humble container with network_bridge
(Dockerfile file attached, copied from UMRT base station Dockerfile lol)

## 2. Build container 
```bash
$ docker build -t bridge_test:v1 .
```

## 3. Create hi/lo docker nets
**MODIFY PARENT NETWORK ADAPTERS BASED ON YOUR INTERFACES**
```bash
$ ./create_networks.sh
```

## 4. Start Base Station or Rover Container 
```bash
$ docker compose -f compose-base.yaml up -d
```
```bash
$ docker compose -f compose-rover.yaml up -d
```

## 5. Set up interface on base station to route exposed port?
```bash
# 1. Create a local ipvlan interface on your host link to <bridge_lo parent>
sudo ip link add link <bridge_lo parent> name ipvlan_host type ipvlan mode l2

# 2. Give your laptop host an IP address on that 10.0.1.x subnet
sudo ip addr add 10.0.1.50/24 dev ipvlan_host

# 3. Bring the interface up
sudo ip link set dev ipvlan_host up

# 4. Add a route telling your laptop to use this interface to talk to the container
sudo ip route add 10.0.1.0/24 dev ipvlan_host
```
It might work differently than changing your host IP to be under the 10.0.1.x subet

## Testing with topics
Open an extra terminal in `bridge_rover` OR `bridge_base`
```bash
$ docker exec -it <bridge_rover/bridge_base> bash
```
Source ROS2:
```
source /opt/ros/humble/setup.bash
```





### test pub sub
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

### Rover side:
**I THINK RIGHT NOW IT ONLY WORKS WITH THESE TOPICS:**
```
/bs_hi/camera
/bs_lo/telemetry
/rv_hi/selfie
/rv_lo/controls
```

Testing
```bash
ros2 topic pub -r 1 /bs_lo/telemetry std_msgs/msg/String "{data: 'Hello'}"
```
Start USB Camera test:
```bash
ros2 run usb_cam usb_cam_node_exe --ros-args   -p video_device:="/dev/video0"   -p pixel_format:="mjpeg2rgb"   -p image_encoding:="mono8"   -p image_width:=160   -p image_height:=120   -r image_raw:=/bs_hi/camera
```

### Base side:
```bash
ros2 topic echo /rv_lo/telemetry
```

<div height="100px"></div>

# Analyze networks
Show the network interfaces for the docker networks you created:
```
docker network list | grep "bridge_"
```
Copy NETWORK ID, add "di-" in front of it. Or "br-"?  
Just lok for similar id when you run `ip link show` on the host.


<!-- 
    e0896d43699f 
    192b397e24b4
-->
Analyze network:
```
sudo iftop -i di-<docker_network_id>
```



# Isolating Networks
On host, test disconnects:
```
docker network disconnect bridge_hi bridge_rover
```
bridge_lo is still connected and transmitting!!!!!!

```
docker network disconnect bridge_lo bridge_rover
```
bridge_hi is still connected and transmitting!!!!!!



Not working when working with actual ethernet interfaces? Go check
