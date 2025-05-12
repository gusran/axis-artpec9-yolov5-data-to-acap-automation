#!/usr/bin/env bash
set -euo pipefail

# ---------- CLI flags --------------------------------------------------
MODEL="" DATA_YAML="" CHIP="artpec9"
usage() { echo "Usage: $0 -m model.tflite -d data.yaml [-c artpec8|artpec9|cpu|tpu]"; exit 1; }
while [[ $# -gt 0 ]]; do case "$1" in
  -m|--model) MODEL="$(realpath "$2")"; shift 2 ;;
  -d|--data)  DATA_YAML="$(realpath "$2")"; shift 2 ;;
  -c|--chip)  CHIP="$2"; shift 2 ;;
  *) usage ;;
esac; done
[[ -f $MODEL && -f $DATA_YAML ]] || usage

# ---------- constants --------------------------------------------------
WORKDIR="build_acap-detectx"
SRC_DIR="$WORKDIR/_src"                  # <─ temp clone folder
APP_DIR="$WORKDIR/app"
DETECTX_REPO="https://github.com/pandosme/DetectX.git"

# ---------- clone DetectX ---------------------------------------------
echo "📥 Cloning DetectX …"
rm -rf "$WORKDIR"
git clone --depth 1 "$DETECTX_REPO" "$SRC_DIR"

# ---------- stage ACAP sources (no self-copy) -------------------------
echo "🗃️  Staging ACAP sources …"
mkdir -p "$WORKDIR"
cp -r "$SRC_DIR/acap/app"              "$APP_DIR"
cp     "$SRC_DIR/acap/Dockerfile"      "$WORKDIR/"
cp     detectx/prepare.py              "$WORKDIR/prepare.py"   # our patched version

# ---------- extract labels & inject artefacts -------------------------
echo "🛈 Extracting labels …"
source .venv_export/bin/activate
python build_acap/extract_labels.py "$DATA_YAML" "$WORKDIR/labels.txt"
deactivate

mkdir -p "$APP_DIR/model" "$APP_DIR/label"
cp "$MODEL"              "$APP_DIR/model/model.tflite"
cp "$WORKDIR/labels.txt" "$APP_DIR/label/labels.txt"

# ---------- run prepare.py --------------------------------------------
pushd "$WORKDIR" > /dev/null
python prepare.py --chip "$CHIP" --img 640
popd > /dev/null

# ---------- Docker build ----------------------------------------------
IMAGE_TAG="detectx_acap_${CHIP}"
docker build --build-arg CHIP="$CHIP" -t "$IMAGE_TAG" "$WORKDIR"

# ---------- extract .eap ----------------------------------------------
mkdir -p "$WORKDIR/build"
CID=$(docker create "$IMAGE_TAG")
docker cp "${CID}":/opt/app "$WORKDIR/build"
docker rm "${CID}" >/dev/null
echo -e "\n✅ ACAP ready → $(ls -1 $WORKDIR/build/*.eap)\n"
