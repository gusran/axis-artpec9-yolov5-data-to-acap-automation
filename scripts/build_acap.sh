#!/usr/bin/env bash
source "$(dirname "$0")/_env.sh"
set -e

CHIP=${1:-artpec9}   # optional arg

cd "${ROOT_DIR}/build_acap"

# ❶ make labels.txt from chosen data yaml
python3 extract_labels.py "${ROOT_DIR}/yolov5/data/coco.yaml" labels.txt

# ❷ run parameter_finder to create header (inside temp venv to avoid conflicts)
python3 "${ROOT_DIR}/yolov5/app/parameter_finder.py" best-int8.tflite

# ❸ copy header beside Dockerfile
cp model_params.h .

# ❹ build ACAP
docker build \
  --tag object_detection_coco_granby \
  --build-arg ARCH=aarch64 \
  --build-arg CHIP="${CHIP}" \
  .

