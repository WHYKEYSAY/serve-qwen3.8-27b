#!/usr/bin/env bash
set -euo pipefail

llama_server="${LLAMA_SERVER:-/opt/llama.cpp/build-master/bin/llama-server}"
model_dir="${MODEL_DIR:-/mnt/d/models/qwen3.8-27b/Q5_K_S}"

exec "$llama_server" \
  --model "$model_dir/Qwen3.8-27B-Q5_K_S.gguf" \
  --mmproj "$model_dir/mmproj-Qwen3.8-27B-bf16.gguf" \
  --alias qwen3.8-27b \
  --host 127.0.0.1 \
  --port 8002 \
  --device CUDA0 \
  --fit off \
  --n-gpu-layers 99 \
  --flash-attn on \
  --ctx-size 8192 \
  --parallel 1 \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --threads 16 \
  --jinja
