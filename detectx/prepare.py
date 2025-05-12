#!/usr/bin/env python3
"""
prepare.py – non-interactive generator of DetectX model.json

Usage example
-------------
python detectx/prepare.py \
        --chip artpec9 \
        --image-size 640 \
        --labels detectx/app/model/labels.txt \
        --model detectx/app/model/model.tflite
"""
from __future__ import annotations
import argparse, json, os, sys
from pathlib import Path

# ---------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------
CHIP_MAP = {
    "artpec8": "axis-a8-dlpu-tflite",
    "a8":      "axis-a8-dlpu-tflite",
    "artpec9": "a9-dlpu-tflite",
    "a9":      "a9-dlpu-tflite",
    "tpu":     "google-edge-tpu-tflite",
}

VIDEO_DIM = {          # width , height
    480: (640, 480),
    640: (800, 600),  # DetectX special-case
    768: (1024,768),
    960: (1280,960),
    1440: (1920,1440),
}

def video_dims(sz:int) -> tuple[int,int]:
    return VIDEO_DIM.get(sz, (640, sz))

def load_labels(fp:Path) -> list[str]:
    try:
        return [ln.strip() for ln in fp.read_text().splitlines() if ln.strip()]
    except FileNotFoundError:
        print(f"⚠️  labels file {fp} not found – using dummies", file=sys.stderr)
        return [f"class{i}" for i in range(2)]

def tflite_params(model_path:Path):
    try:
        import tensorflow as tf  # lightweight import
    except ImportError:
        print("⚠️  TensorFlow not installed – skipping TFLite introspection", file=sys.stderr)
        return dict(scale=0, zero=0, boxes=0, classes=0)

    itp = tf.lite.Interpreter(model_path=str(model_path))
    itp.allocate_tensors()
    out = itp.get_output_details()[0]
    scale, zero = out["quantization"]
    boxes  = int(out["shape"][1])
    classes = int(out["shape"][2]) - 5
    return dict(scale=scale, zero=zero, boxes=boxes, classes=classes)

# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------
def main():
    p = argparse.ArgumentParser(description="Generate DetectX model.json")
    p.add_argument("--chip",        default="artpec9", choices=list(CHIP_MAP))
    p.add_argument("--image-size",  type=int, default=640)
    p.add_argument("--labels",      type=Path, required=True)
    p.add_argument("--model",       type=Path, required=True)
    p.add_argument("--out-json",    type=Path,
                   default=Path("app/model/model.json"))
    p.add_argument("--objectness",  type=float, default=0.25)
    p.add_argument("--nms",         type=float, default=0.05)
    args = p.parse_args()

    chip_str = CHIP_MAP[args.chip.lower()]
    v_w, v_h = video_dims(args.image_size)
    labels   = load_labels(args.labels)
    tfl      = tflite_params(args.model)

    cfg = {
        "modelWidth":   args.image_size,
        "modelHeight":  args.image_size,
        "quant":        tfl["scale"],
        "zeroPoint":    tfl["zero"],
        "boxes":        tfl["boxes"],
        "classes":      tfl["classes"] or len(labels),
        "objectness":   args.objectness,
        "nms":          args.nms,
        "path":         str(Path("model") / args.model.name),
        "scaleMode":    0,
        "videoWidth":   v_w,
        "videoHeight":  v_h,
        "videoAspect":  "4:3",
        "chip":         chip_str,
        "labels":       labels,
        "description":  ""
    }

    args.out_json.parent.mkdir(parents=True, exist_ok=True)
    args.out_json.write_text(json.dumps(cfg, indent=2))
    print(f"✅  Wrote DetectX config → {args.out_json}")

    if len(labels) != cfg["classes"]:
        print(f"⚠️  label count {len(labels)} ≠ classes {cfg['classes']}", file=sys.stderr)

if __name__ == "__main__":
    main()
