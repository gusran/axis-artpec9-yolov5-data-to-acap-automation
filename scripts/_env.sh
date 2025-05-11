# scripts/_env.sh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PYTHON=python3.11       # change if you pin another version
TRAIN_VENV="${ROOT_DIR}/.venv_train"
EXPORT_VENV="${ROOT_DIR}/.venv_export"

# convenience logging
log(){ printf "\e[1;34m%s\e[0m\n" "$*"; }

