# Qwen3.8-27B local experiment

Date: 2026-08-25

## Selection

Artificial Analysis lists Qwen3.8-27B at intelligence 52 in the xhigh configuration. Larger new leaders range from 1.6T to 2.8T total parameters and are not meaningful downloads for a 48 GB dual-GPU workstation. Qwen3.8-27B is therefore the highest-priority new local agent/vision candidate.

The official model is Apache-2.0, supports image/text input, uses 256K context, and documents `qwen3` reasoning plus `qwen3_coder` tool parsing for SGLang and vLLM. The local GGUF route is tested separately because parser behavior can differ from those official engines.

## Profile

| Item | Value |
|---|---|
| GPU | RTX 5090 32 GB |
| Quant | Q5_K_S, 19.68 GB |
| Projector | BF16, 0.93 GB |
| Engine | llama.cpp b9733, commit `f449e0553708b895adbd94a301431cef691f632d` |
| Context | 8,192 for smoke/throughput |
| KV | q8_0 K/V |
| Placement | `--device CUDA0 --fit off -ngl 99` |
| Port / alias | 8002 / `qwen3.8-27b` |

## Results

Successful run: `results/20260825T045922Z/`.

| Gate | Result |
|---|---|
| Health / residency | pass; model and projector loaded on the RTX 5090; `nvidia-smi` recorded 21,161 MiB used after load |
| Native `/completion` | 50.51 prompt tok/s; 63.24 decode tok/s over 256 generated tokens |
| Chinese constraint | pass; exactly three requested sentences; 63.93 decode tok/s |
| Python constraint | pass; correct `merge_intervals` implementation and exactly three assertions; 64.19 decode tok/s |
| Native OpenAI tool call | pass; `finish_reason=tool_calls`, `get_weather({"city":"Toronto"})`; 65.11 decode tok/s |
| Vision through mmproj | pass; accurately described the supplied ComfyUI example image without inventing unseen detail; 64.55 decode tok/s |

Cold load from the model's D: path through WSL 9p took about 12 minutes. Once resident, decode was consistently about 63–65 tok/s. The raw response JSON retains visible content, hidden reasoning, timings, fingerprints, and tool-call structure; the server log retains engine loading and timing evidence.

The first run directory, `results/20260825T045448Z/`, records the aborted automatic-fit attempt. It was intentionally stopped rather than waiting for a redundant full-file pre-scan.

## Caveats

- The GGUF is a community conversion; official weights and model card remain the authority for model behavior/license.
- Qwen3.8 is very new. llama.cpp support and tool-trigger performance can change rapidly, so record the exact engine commit.
- A 256K advertised context does not imply that 256K KV cache is sensible on this card. The first local profile intentionally tests 8K.
- Automatic `--fit` cold-scanned the D: model through WSL 9p and had read only 5.8 GB after about four minutes. The known-fitting single-card profile disables that pre-scan with `--fit off`; this is a storage-path optimization, not a quantization change.
- The GPU CSV is a post-load snapshot, not a sampled peak trace. It proves the measured resident state (21,161 MiB on the physical RTX 5090), not an absolute worst-case VRAM ceiling.
