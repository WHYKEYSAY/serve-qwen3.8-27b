#!/usr/bin/env bash
# Isolated, manually invoked candidate; does not register or replace services.
set -euo pipefail
if [[ "${1:-}" == "--help" ]]; then
  echo 'Usage: bash serve_ninfer_256k.sh [mtp2|mtp3|baseline] [localhost-port]'
  echo 'Single RTX5090, 262144 total context, NVFP4 weights, K8V4 KV.'
  echo 'Prefix reuse and thinking disabled to match the measured configuration.'
  echo 'Overrides: NINFER_BINARY, NINFER_MODEL, NINFER_GPU (GPU UUID),'
  echo 'NINFER_CUDA_DIR, NINFER_RUNTIME_LIB_DIR, NINFER_LOCK_FILE.'
  exit 0
fi
profile="${1:-mtp3}"
port="${2:-18086}"
case "$profile" in mtp2|mtp3|baseline) ;; *) echo 'Profile must be mtp2, mtp3 or baseline' >&2; exit 2;; esac
[[ "$port" =~ ^[0-9]+$ ]] && ((port > 0 && port < 65536)) || { echo 'Invalid port' >&2; exit 2; }
campaign_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
gpu_uuid="${NINFER_GPU:-}"
cuda_dir="${NINFER_CUDA_DIR:-/mnt/d/AI/bench/sglang-0519/lib/python3.11/site-packages/nvidia/cu13}"
model="${NINFER_MODEL:-/mnt/d/models/qwen3.8-27b/ninfer-nvfp4-a107ba1b/qwen3_8_27b_nvfp4.ninfer}"
binary="${NINFER_BINARY:-$campaign_root/ninfer-bin/ninfer-serve}"
runtime_lib="${NINFER_RUNTIME_LIB_DIR:-$campaign_root/ninfer-sysroot/usr/lib/x86_64-linux-gnu}"
[[ -x "$binary" && -f "$model" ]] || { echo 'Pinned binary/model missing; set NINFER_BINARY and NINFER_MODEL (see docs/256k-ninfer.md).' >&2; exit 2; }
if [[ -z "$gpu_uuid" ]]; then
  gpu_uuid="$(nvidia-smi --query-gpu=uuid,name --format=csv,noheader | awk -F', ' '$2 == "NVIDIA GeForce RTX 5090" {print $1}')"
  [[ -n "$gpu_uuid" && "$gpu_uuid" != *$'\n'* ]] || { echo 'Select exactly one RTX5090 using NINFER_GPU=<GPU UUID>.' >&2; exit 2; }
fi
[[ "$gpu_uuid" == GPU-* && "$gpu_uuid" != *$'\n'* ]] || { echo 'NINFER_GPU must be a single GPU UUID.' >&2; exit 2; }
exec 9>"${NINFER_LOCK_FILE:-$campaign_root/.gpu-test.lock}"
flock -n 9 || { echo 'This campaign already owns the GPU; no model started.' >&2; exit 3; }
[[ ! -e "$campaign_root/PAUSED" ]] || { echo 'Campaign PAUSED; no model started.' >&2; exit 3; }
free_mib="$(nvidia-smi -i "$gpu_uuid" --query-gpu=memory.free --format=csv,noheader,nounits)"
free_mib="${free_mib//[[:space:]]/}"
[[ "$free_mib" =~ ^[0-9]+$ ]] || { echo 'Cannot verify GPU memory' >&2; exit 3; }
required_mib=29800
[[ "$profile" == baseline ]] && required_mib=28600
((free_mib >= required_mib)) || { echo "Only ${free_mib}MiB free; ${profile} guard requires ${required_mib}MiB. No process was stopped." >&2; exit 3; }
mkdir -p "$campaign_root/runtime-cache/cuda_cache_path" "$campaign_root/runtime-cache/tmpdir"
export CUDA_VISIBLE_DEVICES="$gpu_uuid"
export CUDA_CACHE_PATH="$campaign_root/runtime-cache/cuda_cache_path"
export TMPDIR="$campaign_root/runtime-cache/tmpdir"
export LD_LIBRARY_PATH="$runtime_lib:$cuda_dir/lib:/usr/lib/wsl/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
spec=()
[[ "$profile" == mtp2 || "$profile" == mtp3 ]] && spec=(--spec mtp --draft-tokens "${profile#mtp}" --lm-head-draft)
echo "Starting isolated ${profile} candidate on localhost:${port}; context is input+output <=262144."
exec "$binary" "$model" \
  --host 127.0.0.1 --port "$port" --device 0 \
  --max-context 262144 --kv-capacity 262144 --max-concurrency 1 \
  --prefill-chunk 1024 --kv-dtype k8v4 --no-prefix-reuse --no-thinking \
  --greedy --model-id qwen38-ninfer-256k "${spec[@]}"
