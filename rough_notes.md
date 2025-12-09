#I think my progress for comms 25-26 network_bridge with alias setup

1. create humble container with network_bridge
2. Build container `docker build -t bridge_test:v1 .`
3. Create two docker nets
   
```bash
docker network create -d ipvlan --subnet 192.168.1.0/24 -o --gateway=192.168.1.200 bridge_lo
docker network create -d ipvlan --subnet 192.168.2.0/24 -o --gateway=192.168.2.200 bridge_hi
```

4. Start two docker containers, one rover one 
idk if this works
```bash
$ docker run -it --rm --name bridge_rover --network=bridge_hi --ip=192.168.2.2 --network=bridge_lo --ip=192.168.1.2 bridge_test:v1
```
It didnt like it when I put two ip parameters, so I just put one and then it auto configured the second IP properly???
```bash
$ docker run -it --rm --name bridge_rover --network=bridge_hi --ip=192.168.2.2 --network=bridge_lo bridge_test:v1
$ docker inspect bridge_rover
```


5. start base station container 
** START BASE STATION FIRST SO THAT IT TAKES THE CORRECT IPs**
Theres gotta be some way to manually configure the second IP I think

```bash
$ docker run -it --rm --name bridge_rover --network=bridge_hi --ip=192.168.2.1 --network=bridge_lo bridge_test:v1
```



1. EDIT CONFIGS FOR THINGY
UDP configs under:
```bash
nano /opt/ros/humble/share/network_bridge/config/Udp1.yaml
nano /opt/ros/humble/share/network_bridge/config/Udp2.yaml
nano /opt/ros/humble/share/network_bridge/launch/udp.launch.py
```


2. UPDATE ROS DOMAIN - Start UDP sending node on rover
```bash
$ export ROS_DOMAIN_ID=2
$ ros2 launch network_bridge udp.launch.py
```
(start another container to start sending messages)
```bash
docker exec -it bridge_rover bash
```

3. UPDATE ROS DOMAIN - Start UDP receiving on base
```bash
$ export ROS_DOMAIN_ID=1
$ ros2 launch network_bridge udp.launch.py
```



test pub sub
```bash
ros2 topic pub -r 1 /my_updates std_msgs/msg/String "{data: 'Hello'}"
```
```bash
ros2 topic echo /my_updates
```


GOT SOMETHING!!!! CHECK