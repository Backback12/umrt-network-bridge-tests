# Custom ROS2 container

Use this when another project wants to attach one container to either the high or low radio network.

## Required files

Copy these into your project/image:

```text
container_scripts/network_policy.sh
dds-configs/fastdds-rover-hi.xml
dds-configs/fastdds-rover-lo.xml
```

Install `iproute2` in the image, copy the files, and make the script executable:

```dockerfile
COPY container_scripts/network_policy.sh /usr/local/bin/network_policy.sh
COPY dds-configs /dds-configs
RUN chmod +x /usr/local/bin/network_policy.sh
```

## Compose: high radio

Pick a unique IP in `10.0.20.0/24`.

```yaml
services:
  my_rover_hi_app:
    image: my_rover_app:latest
    entrypoint: ["/usr/local/bin/network_policy.sh"]
    command: ["bash"]
    cap_add:
      - NET_ADMIN
    environment:
      ROS_DOMAIN_ID: "0"
      ROS_LOCALHOST_ONLY: "0"
      RMW_IMPLEMENTATION: "rmw_fastrtps_cpp"
      ROUTE_POLICY: "drop-default"
      FASTDDS_DEFAULT_PROFILES_FILE: "/dds-configs/fastdds-rover-hi.xml"
      FASTRTPS_DEFAULT_PROFILES_FILE: "/dds-configs/fastdds-rover-hi.xml"
    networks:
      bridge_hi:
        ipv4_address: 10.0.20.X

networks:
  bridge_hi:
    external: true
```

## Compose: low radio

Pick a unique IP in `10.0.10.0/24`.

```yaml
services:
  my_rover_lo_app:
    image: my_rover_app:latest
    entrypoint: ["/usr/local/bin/network_policy.sh"]
    command: ["bash"]
    cap_add:
      - NET_ADMIN
    environment:
      ROS_DOMAIN_ID: "0"
      ROS_LOCALHOST_ONLY: "0"
      RMW_IMPLEMENTATION: "rmw_fastrtps_cpp"
      ROUTE_POLICY: "drop-default"
      FASTDDS_DEFAULT_PROFILES_FILE: "/dds-configs/fastdds-rover-lo.xml"
      FASTRTPS_DEFAULT_PROFILES_FILE: "/dds-configs/fastdds-rover-lo.xml"
    networks:
      bridge_lo:
        ipv4_address: 10.0.10.X

networks:
  bridge_lo:
    external: true
```

## Heavy internal topics

DDS does not send topic payloads unless a compatible subscriber exists, but every participant in the same ROS domain can discover the topic. If base or Foxglove subscribes to a heavy raw topic, that data can cross the radio.

For raw-internal plus compressed-to-base workflows:

- Keep raw topics private by running them with `ROS_LOCALHOST_ONLY=1` or on a separate `ROS_DOMAIN_ID`.
- Run the compressor/republisher where it can see the raw topic.
- Publish only the compressed topic in this radio domain.
- Do not expose raw camera/image topics to Foxglove unless you really want that bandwidth used.
