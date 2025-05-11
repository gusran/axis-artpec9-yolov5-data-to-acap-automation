#!/usr/bin/env bash
set -euo pipefail

# defaults
DEVICE="cpu"
INCLUDE="tflite"
INT8=1

usage() {
cat <<EOF
Usage: $0 [options]

Options:
  -w, --weights FILE      Explicit .pt weights (default: auto-pick last run/best.pt)
  -d, --device DEV        Torch device (cpu, mps, 0…)  (default: ${DEVICE})
  -i, --include LIST      Formats to export (comma-separated, default: ${INCLUDE})
  -h, --help              Show help
EOF
}

WEIGHTS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--weights) WEIGHTS="$2"; shift 2 ;;
        -d|--device)  DEVICE="$2";  shift 2 ;;
        -i|--include) INCLUDE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option $1"; usage; exit 1 ;;
    esac
done

# auto-discover last run
if [[ -z "${WEIGHTS}" ]]; then
    LAST_RUN=$(ls -td yolov5/runs/train/exp* | head -n1)
    WEIGHTS="${LAST_RUN}/weights/best.pt"
fi

python3 -m venv .venv_export
source .venv_export/bin/activate
pip install --upgrade pip
pip install -r yolov5/requirements.txt
pip install coremltools onnx onnx-simplifier tensorflow-macos tensorflowjs # minimal extras

cd yolov5
python export.py \
    --weights "${WEIGHTS}" \
    --include "${INCLUDE}" \
    --int8 ${INT8} \
    --device "${DEVICE}"
