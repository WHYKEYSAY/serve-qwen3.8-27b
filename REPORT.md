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
| Engine | current local llama.cpp |
| Context | 8,192 for smoke/throughput |
| KV | q8_0 K/V |
| Port / alias | 8002 / `qwen3.8-27b` |

## Results

Pending reproducible run. Raw JSON and server logs will be stored under `results/<UTC timestamp>/`.

The acceptance gates are:

1. server health and full GPU residency;
2. honest native `/completion` decode timing;
3. Chinese constrained answer;
4. Python code constraint compliance;
5. native OpenAI tool call;
6. image description through mmproj.

## Caveats

- The GGUF is a community conversion; official weights and model card remain the authority for model behavior/license.
- Qwen3.8 is very new. llama.cpp support and tool-trigger performance can change rapidly, so record the exact engine commit.
- A 256K advertised context does not imply that 256K KV cache is sensible on this card. The first local profile intentionally tests 8K.

