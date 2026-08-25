#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
result_dir="$root/results/$stamp"
mkdir -p "$result_dir"
restore_122b=0
server_pid=""

quant="${QUANT:-Q5_K_S}"
model_path="${MODEL:-${MODEL_DIR:-/mnt/d/models/qwen3.8-27b/$quant}/Qwen3.8-27B-$quant.gguf}"
mmproj_path="${MMPROJ:-${MODEL_DIR:-/mnt/d/models/qwen3.8-27b/$quant}/mmproj-Qwen3.8-27B-bf16.gguf}"
printf '{\n  "model": "%s",\n  "mmproj": "%s",\n  "spec_type": "%s",\n  "spec_draft_n_max": %s,\n  "batch_size": "%s",\n  "ubatch_size": "%s"\n}\n' \
  "$model_path" "$mmproj_path" "${SPEC_TYPE:-draft-mtp}" "${SPEC_DRAFT_N_MAX:-2}" \
  "${BATCH_SIZE:-default}" "${UBATCH_SIZE:-default}" >"$result_dir/config.json"

cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  if (( restore_122b )); then
    systemctl --user start keying-122b.service
    for _ in $(seq 1 180); do
      curl -fsS --max-time 2 http://127.0.0.1:8001/health >/dev/null 2>&1 && break
      sleep 5
    done
  fi
}
trap cleanup EXIT

if systemctl --user is-active --quiet keying-122b.service; then
  restore_122b=1
  systemctl --user stop keying-122b.service
fi
for _ in $(seq 1 60); do
  pgrep -f '/llama-server .*--port 8001' >/dev/null || break
  sleep 2
done

"$root/scripts/serve.sh" >"$result_dir/server.log" 2>&1 &
server_pid=$!
for _ in $(seq 1 180); do
  if curl -fsS --max-time 2 http://127.0.0.1:8002/health >/dev/null 2>&1; then
    break
  fi
  kill -0 "$server_pid" 2>/dev/null || { tail -100 "$result_dir/server.log"; exit 1; }
  sleep 5
done
curl -fsS http://127.0.0.1:8002/health >"$result_dir/health.json"
nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader >"$result_dir/gpu.csv"
test_image="${TEST_IMAGE:-/mnt/c/Users/whyke/Documents/comfy/ComfyUI/input/example.png}"
smoke_args=(--output "$result_dir/smoke.json")
if [[ -f "$test_image" ]]; then
  smoke_args+=(--image "$test_image")
fi
python3 "$root/scripts/smoke.py" "${smoke_args[@]}" | tee "$result_dir/smoke.txt"
