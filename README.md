Below is an updated **README.md** that matches the behaviour of the *current* scripts you just uploaded ( `clone_deps.sh`, `train_model.sh`, `export_model.sh`, `build_acap.sh`, `run_all.sh` ) and the new “copy-app” logic.

---

````markdown
# Automated ACAP Build Pipeline 🚦

End-to-end automation that turns **raw data → trained YOLOv5 model → INT-8 TFLite → Axis ACAP package** with **one command**.  
Everything – cloning third-party repos, virtual-env setup, training, export, label extraction, parameter generation and Docker build – is scripted so you can reproduce results locally or in CI.

---

## 🗂️ Project layout

```text
automated_acap/
├── build_acap/              # Dockerfile + helpers for the ACAP image
│   ├── Dockerfile
│   ├── extract_labels.py
│   └── (auto-generated files live here after a build)
├── model_conf/              # Custom YOLO model cfgs (artpec-optimised)
│   ├── yolov5n.yaml
│   ├── yolov5s.yaml
│   └── …
├── scripts/                 # Pipeline entry points
│   ├── _env.sh              # shared paths & helpers
│   ├── clone_deps.sh        # git-clone YOLOv5 + Axis SDK examples
│   ├── train_model.sh       # venv + training
│   ├── export_model.sh      # INT-8 export + artefact copy
│   ├── build_acap.sh        # labels / params / Docker build
│   └── run_all.sh           # orchestrates the three steps above
└── README.md                # you are here
````

`clone_deps.sh` pulls two sub-projects on first run:

* **ultralytics/yolov5**         → `./yolov5`
* **AxisCommunications/acap-native-sdk-examples** → `./acap-native-sdk-examples`

`build_acap.sh` automatically copies **object-detection-yolov5/app** from that SDK into `build_acap/app` before building the Docker image, so you never have to manage that folder manually.

---

## 📋 Prerequisites

| Tool / Resource                         | Version / Notes                                                    |
| --------------------------------------- | ------------------------------------------------------------------ |
| **Python**                              | ≥ 3.11 – only for host-side scripts                                |
| **Git**                                 | any – for cloning dependencies                                     |
| **Docker**                              | ≥ 24                                                               |
| **macOS (M-series)** or **Linux + GPU** | training; scripts default to Apple Metal (`--device mps`)          |
| Axis ACAP SDK image                     | `axisecp/acap-native-sdk:12.4.0-aarch64-ubuntu24.04` (auto-pulled) |

> The scripts create two *isolated* virtual-envs (`.venv_train` and `.venv_export`) in the repo – your system Python stays untouched.

---

## 🚀 Quick-start

```bash
cd automated_acap

# one-shot pipeline: clone → train → export → build acap
./scripts/run_all.sh
```

Outputs: `build_acap/build/object_detection_*.eap`

### Custom parameters

```bash
./scripts/run_all.sh \
    --data  path/to/dataset.yaml \
    --model yolov5s.yaml \
    --epochs 150 \
    --batch 64 \
    --device cpu          # or mps / 0 (CUDA)
    --chip artpec8        # artpec8 | artpec9 | cpu
```

---

## 🔨 Individual steps

### 1. Clone dependencies (idempotent)

```bash
./scripts/clone_deps.sh
```

### 2. Train YOLOv5

```bash
./scripts/train_model.sh \
    --data  coco128.yaml  \
    --model yolov5n.yaml  \
    --epochs 300          \
    --batch-size 128      \
    --device mps
```

Products: `yolov5/runs/train/exp*/`

### 3. Export to INT-8 TFLite

```bash
./scripts/export_model.sh \
    --device mps \
    --include tflite
```

Copies `best-int8.tflite` → `build_acap/`.

### 4. Build the ACAP package

```bash
./scripts/build_acap.sh \
    --model yolov5/runs/train/expX/weights/best-int8.tflite \
    --data  coco128.yaml \
    --chip  artpec9
```

* Extracts labels with `extract_labels.py`
* Generates `model_params.h` via `parameter_finder.py`
* Builds Docker image and **copies `/opt/app` out** to `build_acap/build/`

---

## ⚙️ Customisation tips

| Task                                 | How                                                                                     |
| ------------------------------------ | --------------------------------------------------------------------------------------- |
| Use CUDA instead of Apple Metal      | pass `--device 0` to `train_model.sh` / `export_model.sh` or set `DEVICE` in `_env.sh`. |
| Change ACAP base image / SDK version | edit ARGs at top of `build_acap/Dockerfile`.                                            |
| Add / tweak YOLO architecture        | drop a custom YAML into `model_conf/` and reference it with `--model`.                  |
| Train on your own dataset            | create `<dataset>.yaml` (same format as Ultralytics) and pass it with `--data`.         |

---

## 🐞 Troubleshooting

| Symptom                                   | Fix / Explanation                                                                             |
| ----------------------------------------- | --------------------------------------------------------------------------------------------- |
| `ModuleNotFoundError: cv2` or `PIL`       | `export_model.sh` installs only core deps; install extras: `pip install opencv-python pillow` |
| `Illegal instruction` from **TensorFlow** | Ensure CPU vs Apple-silicon wheel: `tensorflow-cpu`, `tensorflow-macos`, etc.                 |
| Docker fails at `manifest.json.<chip>`    | Provide matching `--chip` or add the missing manifest in SDK example repo.                    |
| Metal out-of-memory during training       | Lower `--batch-size` or use `--img 416` in model cfg.                                         |

---

## 🙋 FAQ

**Q :** *Why two virtual-envs?*
**A :** Training wants a Metal/CUDA-enabled PyTorch; export wants TensorFlow + other libs. Keeping them separate avoids version pin conflicts.

**Q :** *Can I flash the ACAP directly to a camera?*
**A :** Yes: `acapctl push --ip 192.168.x.x build_acap/build/object_detection_*.eap`

**Q :** *How to use in CI?*
**A :** Mount Docker socket and run `scripts/run_all.sh`. Example GitHub Action is in `.github/workflows/`.

---

## ✨ Credits

* **Ultralytics YOLOv5** – [https://github.com/ultralytics/yolov5](https://github.com/ultralytics/yolov5)
* **Axis ACAP Native SDK** – [https://github.com/AxisCommunications/acap-native-sdk-examples](https://github.com/AxisCommunications/acap-native-sdk-examples)
* Automation scripts by Gustav Rånby


