#!/usr/bin/env bash
set -euo pipefail

model_dir="${MODEL_DIR:-/mnt/d/models/qwen3.8-27b/Q5_K_S}"
base="https://huggingface.co/bartowski/Qwen3.8-27B-GGUF/resolve/main"
mkdir -p "$model_dir"

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

download Qwen3.8-27B-Q5_K_S.gguf 19680945760
download mmproj-Qwen3.8-27B-bf16.gguf 931145952

