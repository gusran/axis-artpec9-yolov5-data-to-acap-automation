#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
"${DIR}/train_model.sh"   "$@"      # you can pass data/model overrides
"${DIR}/export_model.sh"
"${DIR}/build_acap.sh"

