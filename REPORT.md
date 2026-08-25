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
| Speculation | built-in MTP, `--spec-type draft-mtp --spec-draft-n-max 2` |
| Port / alias | 8002 / `qwen3.8-27b` |

## Baseline

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

## Optimization sweep

The baseline server log reported that speculative decoding could use checkpoints but had no implementation selected. Qwen3.8's embedded MTP head is the material optimization: it drafts multiple tokens and lets the full dense target verify them together.

All rows below use the same five tests and report the server's own decode timing. “Mean” is an unweighted mean across native completion, Chinese, Python, tool call, and vision; it is a compact comparison, not a quality score.

| Profile | Native | Chinese | Python | Tool | Vision | Mean |
|---|---:|---:|---:|---:|---:|---:|
| Q5 baseline, no speculation | 63.24 | 63.93 | 64.19 | 65.11 | 64.55 | **64.20** |
| **Q5 + MTP2, default batch** | **92.68** | **101.55** | **113.10** | **101.70** | **95.56** | **100.92** |
| Q5 + MTP3 | 79.08 | 95.45 | 110.83 | 109.87 | 82.76 | 95.60 |
| Q4_K_M + MTP2 | 105.45 | 96.80 | 100.88 | 114.14 | 87.67 | 100.99 |
| Q5 + MTP2, `b512/ub64` | 77.11 | 82.64 | 98.60 | 106.12 | 77.24 | 88.34 |

The chosen default is **Q5_K_S + MTP2 + llama.cpp's default batch sizes**. It improves the five-test mean by **57.2%**, reaches 100+ tok/s on Chinese, code, and tool use, and keeps all behavioral gates passing. Native completion and vision are prompt-dependent at 92.7 and 95.6 tok/s because their second-position draft acceptance was lower.

MTP3 over-speculates for this workload: third-position acceptance falls sharply and verification waste reduces overall speed. The older Qwen3.5/3.6 35B-A3B `b512/ub64` recipe also regresses this model. Q4_K_M is a legitimate speed-oriented alternative—especially for native completion and short tool calls—but it does not consistently beat Q5 across generated paths, and its lower weight precision makes it a poor default when the mean speed is effectively tied.

Raw runs:

- `results/20260825T052326Z/`: chosen Q5 + MTP2 profile.
- `results/20260825T053004Z/`: Q5 + MTP3 rejection.
- `results/20260825T054104Z/`: Q4_K_M + MTP2 comparison.
- `results/20260825T054405Z/`: Q5 + MTP2 with reduced batch sizes.

The user's earlier Qwen3.5-35B-A3B result is not a like-for-like dense-model target. That model is a 35B-total, roughly 3B-active MoE and measured about 196.9 tok/s; Qwen3.8-27B activates the dense 27B path on every token. The correct historical dense comparison is Qwen3.6-27B at about 61.8 tok/s, which closely matches the unoptimized Qwen3.8 baseline.

## Caveats

- The GGUF is a community conversion; official weights and model card remain the authority for model behavior/license.
- Qwen3.8 is very new. llama.cpp support and tool-trigger performance can change rapidly, so record the exact engine commit.
- A 256K advertised context does not imply that 256K KV cache is sensible on this card. The first local profile intentionally tests 8K.
- Automatic `--fit` cold-scanned the D: model through WSL 9p and had read only 5.8 GB after about four minutes. The known-fitting single-card profile disables that pre-scan with `--fit off`; this is a storage-path optimization, not a quantization change.
- The GPU CSV is a post-load snapshot, not a sampled peak trace. It proves the measured resident state (21,161 MiB on the physical RTX 5090), not an absolute worst-case VRAM ceiling.
- MTP speed depends on prompt entropy and draft acceptance, so no single tok/s number describes every request. The checked-in logs preserve `draft_n`, accepted counts, and per-position acceptance rates.
