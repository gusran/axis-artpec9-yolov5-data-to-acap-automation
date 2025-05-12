#!/usr/bin/env bash
# ------------------------------------------------------------------
#  run_all.sh – train → export → build ACAP   (detectx | axis)
# ------------------------------------------------------------------
set -euo pipefail

scripts/clone_deps.sh

# ---------- defaults (override with flags) ------------------------
DATA_YAML="coco128.yaml"
MODEL_CFG="yolov5n.yaml"
EPOCHS=300
BATCH_SIZE=128
CHIP="artpec9"
DEVICE="mps"
ACAP_TYPE="detectx"          # detectx | axis (axis-yolov5-example)
# ------------------------------------------------------------------

usage() {
  cat <<EOF
Usage: $0 [options]

  --data FILE        dataset YAML       (default: ${DATA_YAML})
  --model FILE       model  YAML        (default: ${MODEL_CFG})
  --epochs N         training epochs    (default: ${EPOCHS})
  --batch  N         batch-size         (default: ${BATCH_SIZE})
  --chip  NAME       cpu | artpec8 | artpec9 (default: ${CHIP})
  --device NAME      mps | cpu | 0..    (default: ${DEVICE})
  --acap, -t TYPE    detectx | axis     (default: ${ACAP_TYPE})
  -h, --help         this help
EOF
  exit 1
}

# ---------- CLI parsing -------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --data)    DATA_YAML="$2"; shift 2 ;;
    --model)   MODEL_CFG="$2"; shift 2 ;;
    --epochs)  EPOCHS="$2";    shift 2 ;;
    --batch)   BATCH_SIZE="$2";shift 2 ;;
    --chip)    CHIP="$2";      shift 2 ;;
    --device)  DEVICE="$2";    shift 2 ;;
    --acap|-t) ACAP_TYPE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "❌  Unknown flag $1"; usage ;;
  esac
done

# ---------- 1) Train ----------------------------------------------
scripts/train_model.sh \
    -d "${DATA_YAML}" \
    -m "${MODEL_CFG}" \
    -e "${EPOCHS}" \
    -b "${BATCH_SIZE}" \
    -D "${DEVICE}"

# ---------- 2) Export ---------------------------------------------
scripts/export_model.sh -D "${DEVICE}"

# locate most-recent experiment directory
EXP_DIR=$(ls -td yolov5/runs/train/exp* | head -n1)
MODEL_TFLITE="${EXP_DIR}/weights/best-int8.tflite"

if [[ ! -f "${MODEL_TFLITE}" ]]; then
  echo "❌  Cannot find exported model at ${MODEL_TFLITE}"
  exit 1
fi

MODEL_TFLITE_FP="$(realpath "${MODEL_TFLITE}")"
DATA_YAML_FP="$(realpath "yolov5/data/${DATA_YAML}")"

# ---------- 3) Build ACAP -----------------------------------------
case "${ACAP_TYPE}" in
  detectx)
    scripts/build_acap_detectx.sh \
        -m "${MODEL_TFLITE_FP}" \
        -y "${DATA_YAML_FP}" \
        -c "${CHIP}"
    ;;
  axis|axis-yolov5-example)
    # original Axis example path – keep the name you already have
    scripts/build_acap_axis.sh \
        -m "${MODEL_TFLITE_FP}" \
        -y "${DATA_YAML_FP}" \
        -c "${CHIP}"
    ;;
  *)
    echo "❌  Unknown ACAP type '${ACAP_TYPE}' (use 'detectx' or 'axis')" >&2
    exit 1
    ;;
esac
