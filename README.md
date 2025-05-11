# Automated ACAP Build Pipeline

This repository turns **raw data → trained YOLOv5 model → INT‑8 TFLite → Axis ACAP package** in a single command.  All heavy‑lifting (virtual‑env setup, training, export, model‑parameter extraction, Docker build) is scripted so you can reproduce results locally or in CI.

---

## 🗂️ Project layout

```text
automated_acap/
├── build_acap/              # Dockerfile + helper scripts for the ACAP image
│   ├── Dockerfile
│   └── extract_labels.py
├── model_conf/              # Custom YOLO model configs (artpec‑optimised)
│   ├── yolov5n.yaml
│   └── …
├── scripts/                 # Automation entry points
│   ├── _env.sh              # shared paths & logging helpers
│   ├── train_model.sh       # clone + venv + training
│   ├── export_model.sh      #  INT‑8 TFLite export + artefact copy
│   ├── build_acap.sh        # labels extraction + ACAP Docker build
│   └── run_all.sh           # orchestrates the three stages above
└── README.md                # you are here
```

---

## 📋 Prerequisites

| Tool                                                       | Version                                                       | Purpose                         |
| ---------------------------------------------------------- | ------------------------------------------------------------- | ------------------------------- |
| **Python**                                                 | ≥ 3.11                                                        | local scripting & venv          |
| **Git**                                                    | any                                                           | clone YOLO and SDK examples     |
| **Docker**                                                 | ≥ 24                                                          | build Axis ACAP image           |
| **macOS with Apple‑silicon (M‑series)** or Ubuntu 22 + GPU | training; scripts default to Apple **Metal** (`--device mps`) |                                 |
| **Axis ACAP SDK Docker image**                             | `axisecp/acap-native-sdk:12.4.0-aarch64-ubuntu24.04`          | used in `build_acap/Dockerfile` |

> **Note** The training/export steps create two virtual environments (`.venv_train` and `.venv_export`) inside the repo. They are independent of the system Python.

---

## 🚀 Quick‑start (TL;DR)

```bash
cd automated_acap
chmod +x scripts/*.sh          # first time only

# 1️⃣ train → 2️⃣ export → 3️⃣ build ACAP — default coco128 + yolov5n
./scripts/run_all.sh

# Custom dataset / model / chip:
./scripts/run_all.sh my_data.yaml yolov5s.yaml artpec8
```

The final ACAP package (`object_detection_coco_granby_*.eap`) will appear in `build_acap/build/`.

---

## 🔨 Individual steps

### 1. Train a YOLOv5 model

```bash
./scripts/train_model.sh [data_yaml] [model_yaml] [epochs] [batch]
```

* **data\_yaml** – dataset file (default `coco.yaml`)
* **model\_yaml** – one of the customised configs in *model\_conf/*
* Training artefacts end up in `yolov5/runs/train/exp*/`.

### 2. Export the best checkpoint

```bash
./scripts/export_model.sh
```

* Locates latest `exp*`, grabs `best.pt`, exports to **INT‑8 TFLite**.
* Copies `best-int8.tflite` into `build_acap/`.

### 3. Build the ACAP package

```bash
./scripts/build_acap.sh [chip]
```

* Extracts labels from the data YAML via `extract_labels.py`.
* Runs `parameter_finder.py` to generate `model_params.h`.
* Builds Docker image using appropriate `manifest.json.<chip>` and outputs the `.eap` bundle.

---

## ⚙️ Script customisation

* **Change training device** – edit `scripts/_env.sh` and replace `--device mps` with `--device 0` (CUDA GPU) or `cpu`.
* **Different ACAP base image** – tweak `ARCH`, `VERSION`, `UBUNTU_VERSION`, `SDK` in `build_acap/Dockerfile`.
* **Model hyper‑parameters** – place modified YAMLs into *model\_conf/* and reference them when running `train_model.sh`.

---

## 🐞 Troubleshooting

| Symptom                                            | Cause / Fix                                                                                                      |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `Illegal instruction` during `parameter_finder.py` | Ensure `tensorflow` wheel matches the architecture (Apple Silicon → `tensorflow-macos`; x86 → `tensorflow-cpu`). |
| Docker build fails at `manifest.json.<chip>`       | Pass the chip argument (`artpec8`, `artpec9`, `cpu`) to `build_acap.sh`; or add the missing manifest file.       |
| Training crashes with Metal backend error          | Lower `--batch-size` or use `--img 416` to fit GPU memory.                                                       |

---

## 🙋 FAQ

\*\*Q \*\* *Why two virtual‑envs?*  – `train_model.sh` needs PyTorch‑Metal; `export_model.sh` needs TensorFlow + CoreML; keeping them separate avoids version fights.

\*\*Q \*\* *Can I push the ACAP directly to a camera?*  – Yes: `acapctl push --ip 192.168.x.x build_acap/build/object_detection_coco_granby_*.eap`.

\*\*Q \*\* *CI usage?*  – Wrap `scripts/run_all.sh` in GitHub Actions; remember to mount the Docker socket (`services: docker:dind`).

---

## ✨ Credits

* YOLOv5 by **Ultralytics** – [https://github.com/ultralytics/yolov5](https://github.com/ultralytics/yolov5)
* Axis **ACAP Native SDK** & example – [https://github.com/AxisCommunications/acap-native-sdk-examples](https://github.com/AxisCommunications/acap-native-sdk-examples)
* Automation scaffolding written by Gustav Rånby

