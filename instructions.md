# Comms 25-26 network_bridge setup


#### docker network `bridge_lo`  
* subnet: `192.168.1.0/24`
* gateway: `192.168.1.200`

#### docker network `bridge_hi`
* subnet: `192.168.2.0/24`
* gateway: `192.168.2.200`


| | Base Station | Rover |
|--|--|--|
| Low (900MHz) | 192.168.1.1 | 192.168.1.2 |
| High (2.4GHz) | 192.168.2.1 | 192.168.2.2 |



# Instructions

## 1. create humble container with network_bridge
(Dockerfile file attached)

## 2. Build container 
```bash
$ docker build -t bridge_test:v1 .
```

## 3. Create two docker nets
   
```bash
$ docker network create -d ipvlan --subnet 192.168.1.0/24 -o --gateway=192.168.1.200 bridge_lo
$ docker network create -d ipvlan --subnet 192.168.2.0/24 -o --gateway=192.168.2.200 bridge_hi
```

## 4. Start Base Station Container 
**START BASE STATION FIRST SO THAT IT TAKES THE CORRECT IPs**  
Theres gotta be some way to manually configure the second IP I think.  

Currently this command I believe assigns the ip under bridge_hi to 192.168.2.1. The IP for the low bridge is automatically assigned (update!!!)


Create container `bridge_base`:
```bash
$ docker run -it --rm --name bridge_base --network=bridge_hi --ip=192.168.2.1 --network=bridge_lo bridge_test:v1

```
Source ROS2:
```
./ros_entrypoint.sh
```

<!-- Differentiate ROS DOMAIN ID between rover and base station (base station = 1)
```bash
$ export ROS_DOMAIN_ID=1
``` -->




## 5. Start Rover Container
<!-- ```bash
$ docker run -it --rm --name bridge_rover --network=bridge_hi --ip=192.168.2.2 --network=bridge_lo --ip=192.168.1.2 bridge_test:v1
```
It didnt like it when I put two ip parameters, so I just put one and then it auto configured the second IP properly??? -->
Create container `bridge_rover`:
```bash
$ docker run -it --rm --name bridge_rover --network=bridge_hi --ip=192.168.2.2 --network=bridge_lo bridge_test:v1
```
Source ROS2:
```
./ros_entrypoint.sh
```

<!-- Differentiate ROS DOMAIN ID between rover and base station (rover = 2)
```bash
$ export ROS_DOMAIN_ID=2
``` -->




## 6. Manually edit network_bridge configs (update!!!)
This shouldn't need to be manually configured every time. Somehow find a way to fix this. Maybe make a custom `umrt_network_bridge` package built off network_bridge.

The topics to send on each network are hard coded into all the yaml files. (update!!!)


### Base Station Container:
Copy files under this repo under `./base-2` into:
```bash
nano /opt/ros/humble/share/network_bridge/config/base-hi.yaml
nano /opt/ros/humble/share/network_bridge/config/base-lo.yaml
nano /opt/ros/humble/share/network_bridge/launch/udp.launch.py
```

### Rover Container:
Copy files under this repo under `./rover-2` into:
```bash
nano /opt/ros/humble/share/network_bridge/config/rover-hi.yaml
nano /opt/ros/humble/share/network_bridge/config/rover-lo.yaml
nano /opt/ros/humble/share/network_bridge/launch/udp.launch.py
```


## 7. Start Tunnels
### Rover Container
Differentiate ROS DOMAIN ID between rover and base station (rover = 2)
```bash
$ export ROS_DOMAIN_ID=2
```
Launch tunnel on rover side (need both to run properly)
```bash
$ ros2 launch network_bridge udp.launch.py
```


### Base Station Container
Differentiate ROS DOMAIN ID between rover and base station (rover = 1)
```bash
$ export ROS_DOMAIN_ID=1
```
Launch tunnel on base station side
```bash
$ ros2 launch network_bridge udp.launch.py
```





## (8. Testing with topics)
Open an extra terminal in `bridge_rover` OR `bridge_base`
```bash
$ docker exec -it <bridge_rover/bridge_base> bash
```
Source ROS2:
```
source /opt/ros/humble/setup.bash
```





### test pub sub
So far, its configured so the ROS2 topic prefix is:  
On Rover send to Base Station? `/bs_lo/<topic>`

<!-- |             | Publish from Rover | Publish from Base Station |
|----------------|-----------------|---------------------|
| Use Low Bridge | `/bs_lo/<name>` | `/rv_lo/<name>` |
| Use High Bridge| `/bs_hi/<name>` | `/rv_hi/<name>` | -->

Connor update this

|       | Use Low Bridge | Use High Bridge |
|----------------|-----------------|------------|
| Rover->Base (Rover) | `/bs_lo/<name>` | `/bs_hi/<name>` |
| Base->Rover (Base) | `/rv_lo/<name>` | `/rv_hi/<name>` |
| Rover->Base (Base) | `/rv_lo/<name>` | `/rv_hi/<name>` |
| Base->Rover (Rover) | `/bs_lo/<name>` | `/bs_hi/<name>` |

#### Rover side:
```bash
ros2 topic pub -r 1 /bs_lo/telemetry std_msgs/msg/String "{data: 'Hello'}"
```

#### Base side:
```bash
ros2 topic echo /rv_lo/telemetry
```

