#!/usr/bin/env bash
source "$(dirname "$0")/_env.sh"

DATA_YAML=${1:-coco.yaml}       # first arg or default
MODEL_YAML=${2:-yolov5n.yaml}   # second arg or default
EPOCHS=${3:-300}
BATCH=${4:-128}

log "▶ Cloning Ultralytics/YOLOv5 (if missing)…"
git -C "${ROOT_DIR}" clone --depth 1 https://github.com/ultralytics/yolov5.git || true
cd "${ROOT_DIR}/yolov5"

log "▶ Injecting custom model configs…"
cp -f "${ROOT_DIR}/model_conf/"* models/

log "▶ Creating/activating training venv…"
[ -d "${TRAIN_VENV}" ] || ${PYTHON} -m venv "${TRAIN_VENV}"
source "${TRAIN_VENV}/bin/activate"

pip install -qr requirements.txt
pip install --upgrade torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cpu

log "▶ Starting training…"
${PYTHON} train.py \
  --name axis-train \
  --data "${DATA_YAML}" \
  --epochs "${EPOCHS}" \
  --weights '' \
  --cfg "${MODEL_YAML}" \
  --batch-size "${BATCH}" \
  --device mps

