FROM ros:humble-ros-base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bash-completion \
        ffmpeg \
        iproute2 \
        iputils-ping \
        less \
        nano \
        ros-humble-ffmpeg-image-transport \
        ros-humble-ffmpeg-image-transport-msgs \
        ros-humble-foxglove-bridge \
        ros-humble-foxglove-compressed-video-transport \
        ros-humble-foxglove-msgs \
        ros-humble-image-transport \
        ros-humble-image-transport-plugins \
        ros-humble-joy \
        ros-humble-joy-teleop \
        ros-humble-rmw-fastrtps-cpp \
        ros-humble-teleop-twist-joy \
        ros-humble-usb-cam \
        ros-humble-vision-msgs \
    && rm -rf /var/lib/apt/lists/*

COPY container_scripts/network_policy.sh /usr/local/bin/network_policy.sh
COPY dds-configs /dds-configs

RUN chmod +x /usr/local/bin/network_policy.sh \
    && echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc
