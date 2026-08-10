#
# LAUNCH FOR BASE STATION SIDE
#
from pathlib import Path

from launch import LaunchDescription
from launch_ros.actions import Node


def generate_launch_description():
    config_dir = Path(__file__).resolve().parent
    base_hi_config = str(config_dir / "base-hi.yaml")
    base_lo_config = str(config_dir / "base-lo.yaml")

    return LaunchDescription(
        [
            Node(
                package="network_bridge",
                executable="network_bridge",
                name="Udp1",
                output="screen",
                parameters=[base_hi_config],
            ),
            Node(
                package="network_bridge",
                executable="network_bridge",
                name="Udp2",
                output="screen",
                parameters=[base_lo_config],
            ),
        ]
    )
