#!/usr/bin/env bash
set -euo pipefail

# Directory layout variables
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT_DIR}"               # keep third-party code here
Y5_DIR="${SRC_DIR}/yolov5"
AXIS_DIR="${SRC_DIR}/acap-native-sdk-examples"

# Clone YOLOv5 if it does not exist
if [[ ! -d "${Y5_DIR}/.git" ]]; then
  echo "Cloning Ultralytics/yolov5 ..."
  git clone --depth 1 https://github.com/ultralytics/yolov5 "${Y5_DIR}"
fi

# Clone Axis SDK examples if it does not exist
if [[ ! -d "${AXIS_DIR}/.git" ]]; then
  echo "Cloning AxisCommunications/acap-native-sdk-examples ..."
  git clone --depth 1 https://github.com/AxisCommunications/acap-native-sdk-examples "${AXIS_DIR}"
fi
