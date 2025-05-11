#!/usr/bin/env bash
set -euo pipefail

# ---------- default values ----------
DATA_YAML="coco.yaml"
MODEL_CFG="yolov5n.yaml"
EPOCHS=300
BATCH_SIZE=128
DEVICE="mps"
RUN_NAME="exp"

usage() {
cat <<EOF
Usage: $0 [options]

Options:
  -d, --data FILE         Dataset yaml (default: ${DATA_YAML})
  -m, --model FILE        Model cfg yaml (default: ${MODEL_CFG})
  -e, --epochs N          Number of training epochs (default: ${EPOCHS})
  -b, --batch-size N      Batch size (default: ${BATCH_SIZE})
  -n, --name NAME         Training run name (default: ${RUN_NAME})
  -D, --device DEV        Torch device string (default: ${DEVICE})
  -h, --help              Show this help and exit
EOF
}

# ---------- getopt / getopts ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--data)        DATA_YAML="$2"; shift 2 ;;
        -m|--model)       MODEL_CFG="$2"; shift 2 ;;
        -e|--epochs)      EPOCHS="$2"; shift 2 ;;
        -b|--batch-size)  BATCH_SIZE="$2"; shift 2 ;;
        -n|--name)        RUN_NAME="$2"; shift 2 ;;
        -D|--device)      DEVICE="$2"; shift 2 ;;
        -h|--help)        usage; exit 0 ;;
        *) echo "Unknown option $1"; usage; exit 1 ;;
    esac
done

# ---------- env & deps ----------
python3 -m venv .venv_train
source .venv_train/bin/activate
pip install --upgrade pip
pip install -r yolov5/requirements.txt
pip install --upgrade torch torchvision torchaudio  # or mps/cu11

# ---------- train ----------
cd yolov5
python train.py \
      --name "${RUN_NAME}" \
      --data "${DATA_YAML}" \
      --epochs "${EPOCHS}" \
      --weights '' \
      --cfg "models/${MODEL_CFG}" \
      --batch-size "${BATCH_SIZE}" \
      --device "${DEVICE}"
