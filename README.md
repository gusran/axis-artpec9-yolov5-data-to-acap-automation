## Automated ACAP Build Pipeline 🚦

End-to-end automation that turns **raw data → trained YOLOv5 model → INT-8 TFLite → Axis ACAP package** with a single command.
Both the classic *Axis “object-detection-yolov5”* demo **and** the community *DetectX* project are supported; the pipeline handles cloning, virtual-env setup, training, export, label/parameter generation and Docker builds automatically. ([Docker Hub][1], [Docker Hub][2])

---

## 🗂️ Project layout

```text
automated_acap/
├── build_acap/              # Axis demo image (auto-populated)
├── build_acap-detectx/      # DetectX image (auto-populated)
├── detectx/prepare.py       # Patched non-interactive generator
├── model_conf/              # Artpec-optimised YOLO cfgs
├── scripts/                 # Automation entry points
│   ├── clone_deps.sh        # git-clone YOLOv5 + SDK examples + DetectX
│   ├── train_model.sh       # venv + training
│   ├── export_model.sh      # INT-8 export
│   ├── build_acap_axis.sh   # build Axis demo ACAP
│   ├── build_detectx_acap.sh# build DetectX ACAP
│   └── run_all.sh           # orchestrates everything
└── README.md                # you are here
```

`clone_deps.sh` checks out:

* **Ultralytics / YOLOv5** ([Docker Hub][1]) → `./yolov5`
* **Axis Native-SDK examples** ([Docker Hub][3]) → `./acap-native-sdk-examples`
* **pandosme / DetectX** ([Docker Hub][2]) → `./build_acap-detectx/_src`

---

## 📋 Prerequisites

| Tool / Resource                         | Version / Notes                                                        |
| --------------------------------------- | ---------------------------------------------------------------------- |
| **Python**                              | ≥ 3.11 – host-side scripts                                             |
| **Git**                                 | any – for cloning                                                      |
| **Docker**                              | ≥ 24                                                                   |
| **macOS (M-series)** or **Linux + GPU** | training (Metal or CUDA) ([Docker Hub][4])                             |
| Axis SDK image                          | `axisecp/acap-native-sdk:12.4.0-aarch64-ubuntu24.04` ([Docker Hub][5]) |

> Two isolated virtual-envs (`.venv_train` and `.venv_export`) are created automatically; your system Python remains untouched.

---

## 🚀 Quick-start

```bash
cd automated_acap
./scripts/run_all.sh                          # default: DetectX + coco128 + yolov5n
```

Outputs land in:

```text
build_acap/build/                 # Axis demo .eap
build_acap-detectx/build/         # DetectX .eap   ← default
```

### Custom run

```bash
./scripts/run_all.sh \
  --data   my_dataset.yaml \
  --model  yolov5s.yaml \
  --epochs 150 \
  --batch  64 \
  --device 0          # CUDA GPU
  --chip   artpec8    # artpec8 | artpec9 | cpu | tpu
  --acap   axis       # axis | detectx (default)
```

---

## 🔨 Individual steps

### 1️⃣ Clone dependencies

```bash
./scripts/clone_deps.sh       # idempotent
```

### 2️⃣ Train YOLOv5

```bash
./scripts/train_model.sh \
  --data coco128.yaml \
  --model yolov5n.yaml \
  --epochs 300 \
  --batch-size 128 \
  --device mps            # or 0 / cpu
```

Artifacts → `yolov5/runs/train/exp*/` ([Docker Hub][1])

### 3️⃣ Export INT-8 TFLite

```bash
./scripts/export_model.sh --device mps
```

Copies `best-int8.tflite` to both build contexts.

### 4️⃣ Build ACAP

```bash
# DetectX (default)
./scripts/build_detectx_acap.sh \
  --model yolov5/runs/train/exp*/weights/best-int8.tflite \
  --data  coco128.yaml \
  --chip  artpec9

# Axis reference
./scripts/build_acap_axis.sh  ...same flags...
```

Both builders:

* Extract labels (`extract_labels.py`) ([Docker Hub][6])
* Generate `model_params.h` via TensorFlow introspection (DetectX uses patched `prepare.py`). ([Docker Hub][7])
* Produce a Docker image (`detectx_acap` / `object_detection_acap`) and copy `/opt/app` out via `docker cp`. ([Docker Hub][8])

---

## ⚙️ Customisation tips

| Task                    | How                                        |
| ----------------------- | ------------------------------------------ |
| Switch to CUDA          | `--device 0`                               |
| Different base image    | edit ARGs at top of respective Dockerfile  |
| Tweak YOLO architecture | drop new YAML in `model_conf/`             |
| Train on custom dataset | create `<name>.yaml` and pass via `--data` |

---

## 🐞 Troubleshooting

| Symptom                                      | Explanation / Fix                                                                                 |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `ModuleNotFoundError: cv2` or `PIL`          | Install extras: `pip install opencv-python pillow` ([Docker Hub][8])                              |
| `Illegal instruction` from TensorFlow        | Use correct wheel: `tensorflow-macos` (Apple Silicon) or `tensorflow-cpu` (x86) ([Docker Hub][7]) |
| Metal OOM during training                    | Reduce `--batch-size` or use smaller `--img` (e.g. 416) ([Docker Hub][4])                         |
| Docker build fails at `manifest.json.<chip>` | Ensure `--chip` matches or add the file in SDK repo. ([Docker Hub][3])                            |

---

## 🙋 FAQ

**Why two virtual-envs?**
Training needs a Metal/CUDA-enabled PyTorch; export needs TensorFlow + CoreML/ONNX. Two envs avoid dependency clashes.

**How do I push the ACAP to a camera?**
`acapctl push --ip 192.168.x.x build_acap-detectx/build/*.eap` ([Docker Hub][6])

**CI usage?**
Run `scripts/run_all.sh` inside a GitHub Action; mount Docker (`services: docker:dind`) and cache the YOLOv5 weights.

---

## ✨ Credits

* **Ultralytics YOLOv5** ([Docker Hub][1])
* **Axis Native SDK & examples** ([Docker Hub][3])
* **DetectX** ([Docker Hub][2])

Automation scripts & integrations by **Gustav Rånby**.

[1]: https://hub.docker.com/layers/axisecp/acap-native-sdk/latest-armv7hf/images/sha256-b4525f4a7bb4c2a59e5687c83fa7ba8bc24a4972f8dba8d82c23fa2a4c48ea65?utm_source=chatgpt.com "Image Layer Details - axisecp/acap-native-sdk:latest ... - Docker Hub"
[2]: https://hub.docker.com/r/axisecp/acap-native-sdk?utm_source=chatgpt.com "axisecp/acap-native-sdk - Docker Image"
[3]: https://hub.docker.com/u/axisecp?utm_source=chatgpt.com "axisecp - Docker Hub"
[4]: https://hub.docker.com/layers/axisecp/acap-native-sdk/12.4.0-armv7hf/images/sha256-f35d5f0c705da6205c36e2afb877d2ceb1d7d3646e3af1ed38042cf8b30462d1?utm_source=chatgpt.com "axisecp/acap-native-sdk:12.4.0-armv7hf - Docker Hub"
[5]: https://hub.docker.com/layers/axisecp/acap-native-sdk/12.4.0-aarch64/images/sha256-5c32a54ec45f1b866a2ea91c643cf8df51e10288a7e474159a5b8e3880a13740?utm_source=chatgpt.com "Image Layer Details - axisecp/acap-native-sdk:12.4.0-aarch64"
[6]: https://hub.docker.com/r/axisecp/acap-sdk?utm_source=chatgpt.com "axisecp/acap-sdk - Docker Image"
[7]: https://hub.docker.com/layers/axisecp/acap-native-sdk/12.0.0-aarch64-ubuntu24.04/images/sha256-8c2c65275a95a51373241202860624ed24891e589f15f4c9c5cf1ac09995a3e8?utm_source=chatgpt.com "axisecp/acap-native-sdk:12.0.0-aarch64-ubuntu24.04 | Docker Hub"
[8]: https://hub.docker.com/layers/axisecp/acap-native-sdk/1.12-armv7hf-ubuntu22.04/images/sha256-14ff2f1180e31049609c1f468dac94490b7cef6f5319ff1b8a3228a265b8d2fe?context=explore&utm_source=chatgpt.com "axisecp/acap-native-sdk:1.12-armv7hf-ubuntu22.04 - Docker Hub"
