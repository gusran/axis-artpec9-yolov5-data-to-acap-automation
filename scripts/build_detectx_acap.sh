#!/usr/bin/env bash
# Build an ACAP around the DetectX reference project
# --------------------------------------------------
# Usage: scripts/build_detectx_acap.sh \
#          -m best-int8.tflite \
#          -l labels.txt      \
#          -c artpec9
#
# Creates ./build_acap-detectx, stages all required files,
# runs DetectX's prepare.py + build.sh and finally copies
# the finished .eap bundle to build_acap-detectx/build/

set -euo pipefail

# ---------- argument parsing --------------------------------------------------
MODEL=""
LABELS=""
CHIP="artpec9"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--model)   MODEL="$(realpath "$2")"; shift 2 ;;
    -l|--labels)  LABELS="$(realpath "$2")"; shift 2 ;;
    -c|--chip)    CHIP="$2";                shift 2 ;;
    -h|--help)
      echo "Usage: $0 -m model.tflite -l labels.txt [-c artpec8|artpec9|cpu]"
      exit 0 ;;
    *) echo "Unknown flag $1"; exit 1 ;;
  esac
done

[[ -f "$MODEL"  ]] || { echo "❌ model not found: $MODEL";  exit 1; }
[[ -f "$LABELS" ]] || { echo "❌ labels not found: $LABELS"; exit 1; }

# ---------- constants ---------------------------------------------------------
WORKDIR="build_acap-detectx"
DETECTX_REPO="https://github.com/pandosme/DetectX.git"
APP_DIR="$WORKDIR/app"

# ---------- clone DetectX & stage files --------------------------------------
echo "📥 Cloning DetectX repository …"
rm -rf "$WORKDIR"
git clone --depth 1 "$DETECTX_REPO" "$WORKDIR"

echo "🗃️  Copying DetectX ACAP sources …"
cp -r "$WORKDIR"/acap/app            "$APP_DIR"
cp "$WORKDIR"/acap/Dockerfile        "$WORKDIR/"
cp "$WORKDIR"/acap/prepare.py        "$WORKDIR/"
cp "$WORKDIR"/acap/build.sh          "$WORKDIR/"

# ---------- inject our model + labels ----------------------------------------
echo "📦 Injecting model + labels …"
mkdir -p "$APP_DIR/model" "$APP_DIR/label"
cp "$MODEL"             "$APP_DIR/model/model.tflite"
cp "$LABELS"            "$APP_DIR/label/labels.txt"

# ---------- generate model_params.h ------------------------------------------
echo "🧮 Running prepare.py (extract model params) …"
python3 "$WORKDIR/prepare.py" \
        "$APP_DIR/model/model.tflite" \
        "$APP_DIR/label/labels.txt"

# ---------- build the ACAP image ---------------------------------------------
echo "🐳 Building Docker image / ACAP package …"
pushd "$WORKDIR" > /dev/null
chmod +x build.sh
./build.sh --chip "$CHIP"
popd      > /dev/null

# ---------- copy the resulting .eap bundle -----------------------------------
echo "📤 Copying finished .eap to $WORKDIR/build/"
mkdir -p "$WORKDIR/build"
CONTAINER_ID=$(docker create detectx_acap_image_placeholder) # image name set in build.sh
docker cp "${CONTAINER_ID}":/opt/app "${WORKDIR}/build"
docker rm "${CONTAINER_ID}" > /dev/null

echo -e "\n✅ DetectX ACAP ready →  $(ls -1 ${WORKDIR}/build/*.eap)\n"
