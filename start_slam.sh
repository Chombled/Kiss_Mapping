#!/bin/bash

# Conversion script for KISS-SLAM

SCRIPT_NAME=$(basename "$0")
VISUALIZE=false

usage() {
cat << EOF
Usage:
    $SCRIPT_NAME [-v] <Path_to_Data>

Description:
    Runs the KISS-SLAM pipeline on a dataset and optionally launches
    the visualization of the generated maps.

Options:
    -v            Start visualization after processing
    -h, --help    Show this help message and exit

Arguments:
    Path_to_Data  Path to the input dataset

Notes:
    The pipeline configuration is defined in:
        slam_config.yaml

Examples:
    Run SLAM only:
        $SCRIPT_NAME /path/to/data

    Run SLAM and visualization:
        $SCRIPT_NAME -v /path/to/data

    Show this page:
        $SCRIPT_NAME -h

EOF
}

# Handle long option --help
if [[ "$1" == "--help" ]]; then
    usage
    exit 0
fi

while getopts "vh" opt; do
    case $opt in
        v) VISUALIZE=true ;;
        h)
            usage
            exit 0
            ;;
            *)
                usage
                exit 1
                ;;
                esac
done

shift $((OPTIND - 1))

if [ -z "$1" ]; then
    echo "Error: Input Path is required."
    echo
    usage
    exit 1
fi

DATA_PATH="$1"

kiss_slam_pipeline --dataloader rosbag --config slam_config.yaml -t /lidar/points -rs "$DATA_PATH"

if [ "$VISUALIZE" = true ]; then
    kiss_slam_pipeline -v ./Slam_Output/latest/local_maps/plys
fi
