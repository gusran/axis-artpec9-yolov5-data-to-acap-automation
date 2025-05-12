#!/usr/bin/env bash
# -------------------------------------------------------------
# build_detectx_acap.sh – package a DetectX-based ACAP
# -------------------------------------------------------------
# Example:
#   scripts/build_detectx_acap.sh \
#          -m yolov5/runs/train/exp9/weights/best-int8.tflite \
#          -l build_acap/labels.txt \
#          -c artpec9
set -euo pipefail

# ---------- argument parsing ---------------------------------
MODEL=""          # best-int8.tflite
LABELS=""         # labels.txt
CHIP="artpec9"    # artpec8 | artpec9 | tpu
IMG_SIZE=640      # model input resolution (DetectX → video 800×600)

usage() {
  echo "Usage: $0 -m model.tflite -l labels.txt [-c artpec8|artpec9|tpu] [-s IMG_SIZE]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--model)   MODEL="$(realpath "$2")"; shift 2 ;;
    -l|--labels)  LABELS="$(realpath "$2")"; shift 2 ;;
    -c|--chip)    CHIP="$2";                shift 2 ;;
    -s|--size)    IMG_SIZE="$2";            shift 2 ;;
    -h|--help)    usage ;;
    *) echo "Unknown flag $1"; usage ;;
  esac
done

[[ -f "$MODEL"  ]] || { echo "❌ model not found:  $MODEL";  exit 1; }
[[ -f "$LABELS" ]] || { echo "❌ labels not found: $LABELS"; exit 1; }

# ---------- constants ----------------------------------------
WORKDIR="build_acap-detectx"
DETECTX_REPO="https://github.com/pandosme/DetectX.git"
APP_DIR="$WORKDIR/app"
IMAGE_TAG="detectx-acap-${CHIP}"

# ---------- fresh clone --------------------------------------
echo "📥 Cloning DetectX repo …"
rm -rf "$WORKDIR"
git clone --depth 1 "$DETECTX_REPO" "$WORKDIR"

# ---------- stage ACAP sources -------------------------------
echo "🗃️  Staging DetectX ACAP sources …"
cp -r "$WORKDIR"/acap/app      "$APP_DIR"
cp    "$WORKDIR"/acap/Dockerfile "$WORKDIR/"

# ---------- overwrite prepare.py -----------------------------
echo "🔄 Injecting non-interactive prepare.py …"
cp detectx/prepare.py "$WORKDIR/prepare.py"   # our version
chmod +x            "$WORKDIR/prepare.py"

# ---------- inject model & labels ----------------------------
echo "📦 Adding model + labels …"
mkdir -p "$APP_DIR/model" "$APP_DIR/label"
cp "$MODEL"  "$APP_DIR/model/model.tflite"
cp "$LABELS" "$APP_DIR/label/labels.txt"

# ---------- generate DetectX model.json ----------------------
echo "🧮 Generating model.json …"
python3 "$WORKDIR/prepare.py" \
        --chip        "$CHIP" \
        --image-size  "$IMG_SIZE" \
        --labels      "$APP_DIR/label/labels.txt" \
        --model       "$APP_DIR/model/model.tflite"

# ---------- build Docker image / ACAP ------------------------
echo "🐳 Building Docker image …"
docker build \
       --progress=plain \
       --no-cache \
       --build-arg CHIP="$CHIP" \
       -t "$IMAGE_TAG" \
       "$WORKDIR"

echo "📤 Extracting .eap package …"
mkdir -p "$WORKDIR/build"
CID=$(docker create "$IMAGE_TAG")
docker cp "${CID}":/opt/app "$WORKDIR/build"
docker rm "${CID}" > /dev/null

echo -e "\n✅  DetectX ACAP ready → $(ls -1 $WORKDIR/build/*.eap)\n"
