#
# LAUNCH FOR ROVER SIDE
#
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch_ros.actions import Node


def generate_launch_description():
    config_dir = get_package_share_directory("network_bridge")
    rover_hi_config = config_dir + "/config/rover-hi.yaml"
    rover_lo_config = config_dir + "/config/rover-lo.yaml"

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