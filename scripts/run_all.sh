#!/usr/bin/env bash
# -------------------------------------------------------------
#  run_pipeline.sh – train → export → build ACAP in one go
# -------------------------------------------------------------
set -euo pipefail

# ---------- defaults (override with flags) ----------
DATA_YAML="coco128.yaml"
MODEL_CFG="yolov5n.yaml"
EPOCHS=300
BATCH_SIZE=128
CHIP="artpec9"

usage() {
  echo "Usage: $0 [--data FILE] [--model FILE] [--epochs N] [--batch N] [--chip cpu|artpec8|artpec9]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --data)   DATA_YAML="$2"; shift 2 ;;
    --model)  MODEL_CFG="$2"; shift 2 ;;
    --epochs) EPOCHS="$2";    shift 2 ;;
    --batch)  BATCH_SIZE="$2";shift 2 ;;
    --chip)   CHIP="$2";      shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown flag $1"; usage ;;
  esac
done

# ---------- 1) Train -----------------------------------------
scripts/train_model.sh \
    -d "${DATA_YAML}" \
    -m "${MODEL_CFG}" \
    -e "${EPOCHS}" \
    -b "${BATCH_SIZE}"

# ---------- 2) Export ----------------------------------------
scripts/export_model.sh

# locate most-recent experiment directory
EXP_DIR=$(ls -td yolov5/runs/train/exp* | head -n1)
MODEL_TFLITE="${EXP_DIR}/weights/best-int8.tflite"

if [[ ! -f "${MODEL_TFLITE}" ]]; then
    echo "❌  Cannot find exported model at ${MODEL_TFLITE}"
    exit 1
fi

# ---------- 3) Build ACAP -----------------------------------
scripts/build_acap.sh \
    -m "${MODEL_TFLITE}" \
    -y "${DATA_YAML}" \
    -c "${CHIP}"
