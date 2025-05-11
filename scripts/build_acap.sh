#!/usr/bin/env bash
# -------------------------------------------------------------
# build_acap.sh – build the final AXIS ACAP package *and*
#                 copy /opt/app out of the built image
# -------------------------------------------------------------
set -euo pipefail

# ---------- defaults ----------
ARCH="aarch64"
CHIP="artpec9"
TAG="object_detection_acap"
DATA_YAML=""
MODEL_TFLITE=""

# ---------- usage ------------
usage() {
  cat <<EOF
build_acap.sh  — build an AXIS ACAP package containing a YOLOv5 model
Options:
  -m, --model   FILE   Path to the exported TFLite model (required)
  -y, --data    FILE   Dataset YAML used for training (required – to extract labels)
  -c, --chip    STR    artpec8 | artpec9 | cpu        (default: ${CHIP})
  -a, --arch    STR    Target arch for Docker build   (default: ${ARCH})
  -t, --tag     STR    Docker image tag               (default: ${TAG})
  -h, --help           Show this help and exit
EOF
  exit "${1:-0}"
}

# ---------- arg-parsing -------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--model) MODEL_TFLITE="$2"; shift 2 ;;
    -y|--data)  DATA_YAML="$2";  shift 2 ;;
    -c|--chip)  CHIP="$2";       shift 2 ;;
    -a|--arch)  ARCH="$2";       shift 2 ;;
    -t|--tag)   TAG="$2";        shift 2 ;;
    -h|--help)  usage 0 ;;
    *) echo "Unknown option: $1"; usage 1 ;;
  esac
done

[[ -f "${MODEL_TFLITE}" ]] || { echo "❌ --model file not found"; usage 1; }
[[ -f "${DATA_YAML}"   ]] || { echo "❌ --data  file not found"; usage 1; }
[[ "${CHIP}" =~ ^(artpec8|artpec9|cpu)$ ]] || {
  echo "❌ --chip must be artpec8 | artpec9 | cpu"; usage 1; }

# ---------- 1. labels ---------
echo "🛈 Extracting labels → build_acap/labels.txt"
python build_acap/extract_labels.py "${DATA_YAML}" build_acap/labels.txt

# ---------- 2. model ----------
echo "🛈 Copying model → build_acap/best-int8.tflite"
cp -f "${MODEL_TFLITE}" build_acap/best-int8.tflite

# ---------- 3. docker build ---
echo "🛠  Building ACAP Docker image (${TAG}) …"
docker build \
  --tag "${TAG}" \
  --build-arg ARCH="${ARCH}" \
  --build-arg CHIP="${CHIP}" \
  build_acap

# ---------- 4. copy out -------
echo "📦  Extracting /opt/app from image into ./build"
CID=$(docker create "${TAG}")                      ## NEW
docker cp "${CID}":/opt/app ./build               ## NEW
docker rm "${CID}" 1>/dev/null

echo "✅  Build complete – files available in ./build"
