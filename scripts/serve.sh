#!/usr/bin/env bash
set -euo pipefail

llama_server="${LLAMA_SERVER:-/opt/llama.cpp/build-master/bin/llama-server}"
quant="${QUANT:-Q5_K_S}"
model_dir="${MODEL_DIR:-/mnt/d/models/qwen3.8-27b/$quant}"
model="${MODEL:-$model_dir/Qwen3.8-27B-$quant.gguf}"
mmproj="${MMPROJ:-$model_dir/mmproj-Qwen3.8-27B-bf16.gguf}"
spec_type="${SPEC_TYPE:-draft-mtp}"
spec_draft_n_max="${SPEC_DRAFT_N_MAX:-2}"
batch_size="${BATCH_SIZE:-}"
ubatch_size="${UBATCH_SIZE:-}"

args=("$llama_server" \
  --model "$model" \
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
  --jinja \
  --no-mmap)

if [[ -n "$mmproj" ]]; then
  args+=(--mmproj "$mmproj")
fi
if [[ "$spec_type" != "none" ]]; then
  args+=(--spec-type "$spec_type" --spec-draft-n-max "$spec_draft_n_max")
fi
if [[ -n "$batch_size" ]]; then
  args+=(--batch-size "$batch_size")
fi
if [[ -n "$ubatch_size" ]]; then
  args+=(--ubatch-size "$ubatch_size")
fi

exec "${args[@]}"
