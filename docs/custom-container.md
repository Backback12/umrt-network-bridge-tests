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

Only edit the rover-side Zenoh bridge configs:

```text
config/rover-hi.json5
config/rover-lo.json5
```

The `allow.publishers` list is the rover-to-base allowlist. The `allow.subscribers` list is the base-to-rover allowlist. Use full topic names as anchored regular expressions.

High radio example:

```json5
allow: {
  publishers: [
    "^/camera$",
    "^/compressed_camera$",
  ],
  subscribers: [],
}
```

Low radio example:

```json5
allow: {
  publishers: [
    "^/telemetry$",
    "^/heartbeat$",
  ],
  subscribers: [
    "^/controls$",
  ],
}
```

After editing either rover config, recreate the rover-side stack so it reloads the JSON5:

```bash
docker compose -f compose/compose-rover-lo.yaml up -d --force-recreate
docker compose -f compose/compose-rover-hi.yaml up -d --force-recreate
docker compose -f compose/compose-rover-both.yaml up -d --force-recreate
```

If you edited the base configs in this repo, recreate the base stack with:

```bash
docker compose -f compose/compose-base.yaml up -d --force-recreate
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

If a topic is visible locally but not on base, make sure it is listed exactly in `config/rover-hi.json5` or `config/rover-lo.json5`, then recreate the rover stack.
