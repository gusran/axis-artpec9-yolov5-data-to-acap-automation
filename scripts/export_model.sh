#!/usr/bin/env bash
set -euo pipefail

# defaults
DEVICE="mps"
INCLUDE="tflite"

usage() {
cat <<EOF
Usage: $0 [options]

Options:
  -w, --weights FILE      Explicit .pt weights (default: auto-pick last run/best.pt)
  -D, --device DEV        Torch device (cpu, mps, 0…)  (default: ${DEVICE})
  -i, --include LIST      Formats to export (comma-separated, default: ${INCLUDE})
  -h, --help              Show help
EOF
}

WEIGHTS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--weights) WEIGHTS="$2"; shift 2 ;;
        -D|--device)  DEVICE="$2";  shift 2 ;;
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

virtualenv -p python3.11 .venv_export
source .venv_export/bin/activate
pip install --upgrade pip
pip install pandas torch requests opencv-python pillow tensorflowjs

BEST_PT="$(realpath "$WEIGHTS")"

cd yolov5
python export.py \
    --weights "$BEST_PT" \
    --include "${INCLUDE}" \
    --int8 \
    --device "${DEVICE}"
