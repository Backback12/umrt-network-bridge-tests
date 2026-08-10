#
# LAUNCH FOR ROVER SIDE
#
from pathlib import Path

from launch import LaunchDescription
from launch_ros.actions import Node


def generate_launch_description():
    config_dir = Path(__file__).resolve().parent
    rover_hi_config = str(config_dir / "rover-hi.yaml")
    rover_lo_config = str(config_dir / "rover-lo.yaml")

    return LaunchDescription(
        [
            Node(
                package="network_bridge",
                executable="network_bridge",
                name="Udp1",
                output="screen",
                parameters=[rover_hi_config],
            ),
            Node(
                package="network_bridge",
                executable="network_bridge",
                name="Udp2",
                output="screen",
                parameters=[rover_lo_config],
            ),
        ]
    )
