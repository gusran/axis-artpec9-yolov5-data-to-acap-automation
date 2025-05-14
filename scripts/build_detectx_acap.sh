#!/usr/bin/env bash
# ------------------------------------------------------------------
# build_detectx_acap.sh – build an ACAP package using DetectX
#                        (flag-compatible with build_acap.sh)
# ------------------------------------------------------------------
set -euo pipefail

# ---------- defaults ------------------------------------------------
ARCH="aarch64"
CHIP="artpec9"                     # artpec8 | artpec9 | cpu | tpu
TAG="detectx_acap"
DATA_YAML=""
MODEL_TFLITE=""
IMG_SIZE=640                       # DetectX expects square input
WORKDIR="build_acap-detectx"
SRC_DIR="$WORKDIR/_src"
APP_DIR="$WORKDIR/app"
DETECTX_REPO="https://github.com/pandosme/DetectX.git"

# ---------- helper --------------------------------------------------
usage () {
  cat <<EOF
build_detectx_acap.sh  – build DetectX ACAP

  -m, --model FILE   INT8-TFLite model (required)
  -y, --data  FILE   dataset YAML      (required – for labels)
  -c, --chip  STR    artpec8 | artpec9 | cpu | tpu   (default $CHIP)
  -a, --arch  STR    Docker arch                       (default $ARCH)
  -t, --tag   STR    Docker image tag                  (default $TAG)
  -s, --size  INT    model input size (480/640/768…)   (default $IMG_SIZE)
  -h, --help         this help
EOF
  exit "${1:-0}"
}

# ---------- CLI parsing ---------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--model) MODEL_TFLITE=$(realpath "$2"); shift 2 ;;
    -y|--data)  DATA_YAML=$(realpath "$2");    shift 2 ;;
    -c|--chip)  CHIP="$2";                     shift 2 ;;
    -a|--arch)  ARCH="$2";                     shift 2 ;;
    -t|--tag)   TAG="$2";                      shift 2 ;;
    -s|--size)  IMG_SIZE="$2";                 shift 2 ;;
    -h|--help)  usage ;;
    *) echo "Unknown option $1"; usage 1 ;;
  esac
done

[[ -f $MODEL_TFLITE ]] || { echo "❌ --model file not found"; usage 1; }
[[ -f $DATA_YAML    ]] || { echo "❌ --data  file not found"; usage 1; }
[[ $CHIP =~ ^(artpec8|artpec9|cpu|tpu)$ ]] || {
  echo "❌ --chip must be artpec8 | artpec9 | cpu | tpu"; usage 1; }

# ---------- 0. fresh clone ------------------------------------------
echo "📥 Cloning DetectX …"
rm -rf "$WORKDIR"
git clone --depth 1 "$DETECTX_REPO" "$SRC_DIR"

# ---------- 1. stage ACAP sources -----------------------------------
echo "🗃️  Staging DetectX ACAP sources …"
mkdir -p "$WORKDIR"
cp -r "$SRC_DIR/app"          "$APP_DIR"
cp     "$SRC_DIR/Dockerfile"  "$WORKDIR/"
cp     "$SRC_DIR/build.sh"    "$WORKDIR/"

# overwrite DetectX' interactive script with our cli-friendly one
cp detectx/prepare.py         "$WORKDIR/prepare.py"
cp detectx/index.html         "$WORKDIR/app/html/index.html"
cp detectx/about.html         "$WORKDIR/app/html/about.html"

# ---------- 2. extract labels ---------------------------------------
echo "🛈 Extracting labels …"
source .venv_export/bin/activate
python build_acap/extract_labels.py "$DATA_YAML" "$WORKDIR/labels.txt"

# ---------- 3. inject model + labels --------------------------------
mkdir -p "$APP_DIR/model" "$APP_DIR/label"
cp "$MODEL_TFLITE"       "$APP_DIR/model/model.tflite"
cp "$WORKDIR/labels.txt" "$APP_DIR/model/labels.txt"

# ---------- 4. run prepare.py (json + params) -----------------------
pushd "$WORKDIR" >/dev/null
python prepare.py \
  --chip "$CHIP" \
  --image-size "$IMG_SIZE" \
  --labels "app/model/labels.txt"
popd >/dev/null

# ---------- 5. docker build -----------------------------------------
echo "🐳 Building Docker image ($TAG) …"
docker build --progress plain --no-cache \
  --build-arg CHIP="$CHIP" \
  --build-arg ARCH="$ARCH" \
  -t "$TAG" \
  "$WORKDIR"

# ---------- 6. copy .eap bundle out ---------------------------------
mkdir -p "$WORKDIR/build"
CID=$(docker create "$TAG")
docker cp "$CID":/opt/app "$WORKDIR/build"
docker rm "$CID" >/dev/null

echo -e "\n✅ DetectX ACAP ready → $(ls -1 $WORKDIR/build/app/*.eap)\n"
