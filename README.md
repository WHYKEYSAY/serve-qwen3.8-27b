# serve-qwen3.8-27b

Reproducible local serving and benchmark playbook for Qwen3.8-27B on an RTX 5090.

## New: tested 256K NInfer profile

The separate [256K profile](docs/256k-ninfer.md) uses mixed NVFP4 weights,
K8V4 KV and MTP3 on one RTX5090. Measured with257760 input tokens:
**103.10 tokens/s** for1530 natural-EOS output tokens. A260800-input tool
fixture also passed the documented development checks. These are not8K results
or proof of general research quality. The existing8K `scripts/serve.sh` is unchanged.

See the profile for artifact/source pins, setup, interface limitations and the
Q4/Q5/SGLang/vLLM comparison. No weights, compiled binaries or runtime caches
are included with this new profile.

## Why this model

Qwen3.8-27B is the only newly released open model near the top of the current intelligence leaderboard that is also physically sensible on one 32 GB consumer GPU. It is a dense 27B multimodal model with 256K native context, tool use, and Apache-2.0 weights.

The first profile uses:

- `bartowski/Qwen3.8-27B-GGUF`
- `Qwen3.8-27B-Q5_K_S.gguf` — 19,680,945,760 bytes
- `mmproj-Qwen3.8-27B-bf16.gguf` — 931,145,952 bytes
- single RTX 5090, full layer offload, 8K test context, q8 KV
- built-in MTP speculative decoding at depth 2

## Download and serve

```bash
./scripts/download.sh
./scripts/serve.sh
```

MTP2 is enabled by default. Disable it for a strict non-speculative baseline with `SPEC_TYPE=none ./scripts/serve.sh`. The optional Q4_K_M speed profile can be downloaded and launched with:

```bash
QUANT=Q4_K_M ./scripts/download.sh
QUANT=Q4_K_M ./scripts/serve.sh
```

The server listens on `127.0.0.1:8002` as `qwen3.8-27b`. The standing `keying-deep` service occupies both GPUs, so stop it through systemd before serving and restore it afterward. The experiment runner handles that automatically:

```bash
./scripts/run-experiment.sh
```

## Status

Verified 2026-08-25 on llama.cpp b9733. The original non-speculative Q5 profile measured 63–65 tok/s; enabling the embedded MTP head at depth 2 raised the same five-test mean from 64.20 to **100.92 tok/s** (+57.2%), with 92.68–113.10 tok/s across native text, Chinese, Python, tool use, and vision. All behavioral gates still pass. See [REPORT.md](REPORT.md) and the checked-in raw results.

## Sources

- [Official Qwen3.8 repository](https://github.com/QwenLM/Qwen3.8)
- [Official Qwen3.8-27B model card](https://huggingface.co/Qwen/Qwen3.8-27B)
- [Artificial Analysis small open models](https://artificialanalysis.ai/models/open-source/small)
- [GGUF artifacts](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF)
