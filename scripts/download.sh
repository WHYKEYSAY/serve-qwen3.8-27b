#!/usr/bin/env bash
set -euo pipefail

quant="${QUANT:-Q5_K_S}"
model_dir="${MODEL_DIR:-/mnt/d/models/qwen3.8-27b/$quant}"
base="https://huggingface.co/bartowski/Qwen3.8-27B-GGUF/resolve/main"
mkdir -p "$model_dir"

case "$quant" in
  Q5_K_S) model_size=19680945760 ;;
  Q4_K_M) model_size=17772537440 ;;
  *) printf 'unsupported QUANT=%s (supported: Q5_K_S, Q4_K_M)\n' "$quant" >&2; exit 2 ;;
esac

download() {
  local name="$1" expected="$2"
  local path="$model_dir/$name"
  curl --fail --location --http1.1 --retry 20 --retry-delay 3 --continue-at - --output "$path" "$base/$name"
  local actual
  actual="$(stat -c %s "$path")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'size mismatch: %s expected=%s actual=%s\n' "$name" "$expected" "$actual" >&2
    exit 1
  fi
}

download "Qwen3.8-27B-$quant.gguf" "$model_size"
download mmproj-Qwen3.8-27B-bf16.gguf 931145952
