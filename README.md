# serve-qwen3.8-27b

Reproducible local serving and benchmark playbook for Qwen3.8-27B on an RTX 5090.

## Why this model

Qwen3.8-27B is the only newly released open model near the top of the current intelligence leaderboard that is also physically sensible on one 32 GB consumer GPU. It is a dense 27B multimodal model with 256K native context, tool use, and Apache-2.0 weights.

The first profile uses:

- `bartowski/Qwen3.8-27B-GGUF`
- `Qwen3.8-27B-Q5_K_S.gguf` — 19,680,945,760 bytes
- `mmproj-Qwen3.8-27B-bf16.gguf` — 931,145,952 bytes
- single RTX 5090, full layer offload, 8K test context, q8 KV

## Download and serve

```bash
./scripts/download.sh
./scripts/serve.sh
```

The server listens on `127.0.0.1:8002` as `qwen3.8-27b`. The standing `keying-deep` service occupies both GPUs, so stop it through systemd before serving and restore it afterward. The experiment runner handles that automatically:

```bash
./scripts/run-experiment.sh
```

## Status

Verified 2026-08-25 on llama.cpp b9733: full single-5090 residency, 63–65 tok/s decode, constrained Chinese and Python passes, valid native tool calling, and a successful image-understanding test. The post-load snapshot used 21,161 MiB on the RTX 5090. See [REPORT.md](REPORT.md) and the checked-in raw results.

## Sources

- [Official Qwen3.8 repository](https://github.com/QwenLM/Qwen3.8)
- [Official Qwen3.8-27B model card](https://huggingface.co/Qwen/Qwen3.8-27B)
- [Artificial Analysis small open models](https://artificialanalysis.ai/models/open-source/small)
- [GGUF artifacts](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF)
