# Add an existing container to the radio bridge

Use this when another repo already has a Compose service or a start script that runs a ROS container, and you want selected rover topics to cross the radio bridge.

The one-time setup scripts for host VLANs and Docker networks stay in this repo. Run them once on the machine that owns the radio interface. Your application container only needs to join `bridge_hi` or `bridge_lo`.

## Pick the radio

Use high radio for high-bandwidth topics:

```text
Docker network: bridge_hi
Subnet: 10.0.20.0/24
Base bridge IP: 10.0.20.57
Rover bridge IP: 10.0.20.59
```

Use low radio for low-bandwidth topics:

```text
Docker network: bridge_lo
Subnet: 10.0.10.0/24
Base bridge IP: 10.0.10.57
Rover bridge IP: 10.0.10.59
```

Pick a unique IP for your app container. Do not reuse `.57` or `.59`.

## Existing Compose Files

Add one external network to the service that should publish or subscribe on the radio side.

High radio example:

```yaml
services:
  my_rover_app:
    image: my_rover_app:latest
    environment:
      ROS_DOMAIN_ID: "0"
      ROS_LOCALHOST_ONLY: "0"
      RMW_IMPLEMENTATION: "rmw_fastrtps_cpp"
    networks:
      bridge_hi:
        ipv4_address: 10.0.20.60

networks:
  bridge_hi:
    external: true
```

Low radio example:

```yaml
services:
  my_rover_app:
    image: my_rover_app:latest
    environment:
      ROS_DOMAIN_ID: "0"
      ROS_LOCALHOST_ONLY: "0"
      RMW_IMPLEMENTATION: "rmw_fastrtps_cpp"
    networks:
      bridge_lo:
        ipv4_address: 10.0.10.60

networks:
  bridge_lo:
    external: true
```

Avoid `network_mode: host` for containers using this bridge. Do not publish ROS ports from the rover app container unless that app specifically needs a host-facing service.

## Docker Run Start Scripts

For scripts that call `docker run`, add the Docker network, static IP, and ROS environment.

High radio:

```bash
docker run --rm -it \
  --name my_rover_hi_app \
  --network bridge_hi \
  --ip 10.0.20.60 \
  -e ROS_DOMAIN_ID=0 \
  -e ROS_LOCALHOST_ONLY=0 \
  -e RMW_IMPLEMENTATION=rmw_fastrtps_cpp \
  my_rover_app:latest
```

Low radio:

```bash
docker run --rm -it \
  --name my_rover_lo_app \
  --network bridge_lo \
  --ip 10.0.10.60 \
  -e ROS_DOMAIN_ID=0 \
  -e ROS_LOCALHOST_ONLY=0 \
  -e RMW_IMPLEMENTATION=rmw_fastrtps_cpp \
  my_rover_app:latest
```

If the script already has `--network`, replace it with the correct radio network. A container can only use one `--network` option during `docker run`; add any extra networks afterward with `docker network connect` only if you really need them.

## Update the bridged topics

Only edit the rover-side network bridge configs:

```text
config/rover-hi.yaml
config/rover-lo.yaml
```

The `topics:` list is the allowlist of rover topics that should be sent toward base. Use the full topic names directly. Do not add `subscribe_namespace` or `publish_namespace`.

High radio example:

```yaml
topics:
  - "/bs_hi/camera"
  - "/bs_hi/compressed_camera"
```

Low radio example:

```yaml
topics:
  - "/bs_lo/telemetry"
  - "/bs_lo/heartbeat"
```

After editing either rover config, restart the rover-side `network_bridge` process so it reloads the YAML:

```bash
./scripts/restart_network_bridge.sh rover
```

If you edited the base configs in this repo, reload the base bridge with:

```bash
./scripts/restart_network_bridge.sh base
```

Foxglove is launched inside `bridge_base` by:

```bash
./scripts/start_base.sh
```

Connect from the host with:

```text
ws://localhost:8765
```

## Quick Checks

Check that your app can see the rover bridge container on the same radio network:

```bash
docker exec my_rover_hi_app ping -c 2 10.0.20.59
docker exec my_rover_lo_app ping -c 2 10.0.10.59
```

Check that your app is publishing an allowed topic:

```bash
docker exec -it my_rover_hi_app bash
source /opt/ros/humble/setup.bash
ros2 topic list
```

If a topic is visible locally but not on base, make sure it is listed exactly in `config/rover-hi.yaml` or `config/rover-lo.yaml`, then restart the rover bridge.
