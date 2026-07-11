#
# LAUNCH FOR BASE STATION SIDE
#
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch_ros.actions import Node


def generate_launch_description():
    config_dir = get_package_share_directory("network_bridge")
    base_hi_config = config_dir + "/config/base-hi.yaml"
    base_lo_config = config_dir + "/config/base-lo.yaml"

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