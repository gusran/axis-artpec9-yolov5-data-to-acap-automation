#!/usr/bin/env bash
source "$(dirname "$0")/_env.sh"
cd "${ROOT_DIR}/yolov5"

# locate latest exp
LATEST_EXP=$(ls -1d runs/train/axis-train* | sort -V | tail -n1)
BEST_PT="${LATEST_EXP}/weights/best.pt"
[ -f "${BEST_PT}" ] || { echo "❌ best.pt not found"; exit 1; }

log "▶ Creating/activating export venv…"
[ -d "${EXPORT_VENV}" ] || ${PYTHON} -m venv "${EXPORT_VENV}"
source "${EXPORT_VENV}/bin/activate"
pip install -qr requirements.txt
pip install coremltools onnx onnxruntime tensorflow

log "▶ Exporting TFLite INT8…"
${PYTHON} export.py \
  --weights "${BEST_PT}" \
  --include tflite \
  --int8 \
  --device mps

# copy artefacts next to Dockerfile
mkdir -p "${ROOT_DIR}/build_acap"
cp "${BEST_PT%.pt}-int8.tflite" "${ROOT_DIR}/build_acap/best-int8.tflite"

