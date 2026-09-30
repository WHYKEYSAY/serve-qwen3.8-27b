# Qwen3.8-27B: single-5090 256K profile

Reviewed2026-09-29. Selected tested configuration for text-only research/tool
work: **NInfer + mixed NVFP4 weights + K8V4 KV + MTP3**. One262144-token slot,
prefill chunk1024, thinking disabled, no prefix reuse, greedy decoding.
The total limit includes input, template/tool overhead and output.

This is an additional manual profile, not a replacement for the existing8K
llama.cpp launcher. It does not register services, change routing or stop other
GPU processes. Multi-agent applications must queue full-context requests.

## Start

Requires Linux/WSL, an RTX5090 with sufficient free VRAM, `bash`, `flock`,
`nvidia-smi`, the separately built NInfer executable and separately downloaded
artifact below. No weights, CUDA libraries, environments or binaries are bundled.

For the tested KECHENGY installation, review and source the non-secret example:

```bash
source configs/ninfer-256k.env.example
bash scripts/serve_ninfer_256k.sh mtp3
```

On another installation, override `NINFER_BINARY`, `NINFER_MODEL`,
`NINFER_CUDA_DIR` and `NINFER_RUNTIME_LIB_DIR` with your paths. `NINFER_GPU`
optionally selects a GPU UUID; otherwise exactly one RTX5090 must be detected.
`NINFER_LOCK_FILE` may point to an existing shared lock with an existing parent
directory. Without that override, the lock is checkout-local, not a global
GPU scheduler. A `PAUSED` file in this checkout prevents startup.

```bash
bash scripts/serve_ninfer_256k.sh mtp2      # closely competitive alternative
bash scripts/serve_ninfer_256k.sh baseline  # no speculation; lower memory use
```

OpenAI-compatible endpoint: `http://127.0.0.1:18086/v1`, model name
`qwen38-ninfer-256k`. An optional second argument changes the localhost port.
No authentication is configured; keep this bound to loopback. Startup requires
at least29800MiB free for MTP,28600MiB for baseline; these are conservative
guards, not guarantees against later external GPU use. Stop withCtrl-C.

The important engine arguments are:

```text
--host 127.0.0.1 --device 0
--max-context 262144 --kv-capacity 262144 --max-concurrency 1
--prefill-chunk 1024 --kv-dtype k8v4 --no-prefix-reuse --no-thinking
--greedy --spec mtp --draft-tokens 3 --lm-head-draft
```

The launcher passes option names and values as separate arguments.

## Pins and build provenance

- Engine: [Neroued/ninfer](https://github.com/Neroued/ninfer), commit
  `e31bc99b13f517c8aae70b997b7c4a49b4dcdc5d`.
- Artifact: [neroued/Qwen3.8-27B-nvfp4-NInfer](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer),
  revision `a107ba1b5b0609d9ca90d5ed61439f5f5cc7d64d`,
  file `qwen3_8_27b_nvfp4.ninfer`,23719715844bytes,Apache-2.0.
- Artifact SHA256:
  `74d2c57145e6ff11d1d2faa79594477f9bc903a611af1fb20218189fbbb77d82`.
- Tested executable SHA256:
  `d3ee413cb18471af2965d73465ca17e0912d2cf99d3133effe1660c7b062e55d`.
  A separately rebuilt executable need not be byte-identical.
- Tested build: GCC12.2, CUDA13.0.88, CMake4.4.3, Ninja1.13.2,
  dynamically linked libcurl and FFmpeg5.1.9. Upstream targets newer CUDA;
  this successful local build is not a general compatibility certification.
- The optional [FFmpeg5 compatibility patch](../results/ninfer-ffmpeg5-compat.patch)
  changes only video-rotation metadata access. Apply it to the pinned source
  when using the tested older FFmpeg headers; do not blindly apply it to newer
  upstream revisions. Text inference kernels were not patched.

Follow the pinned upstream build instructions and build the `ninfer-serve`
CMake target. Ensure its dynamic libraries resolve with `ldd` before launching.
On the tested machine, all build dependencies and artifacts were isolated onD:;
no global system packages were replaced. Large weight reads used sequential
loading; Windows-mounted random mmap access was slow.

## Measured results, not estimates

SingleRTX5090, one full-context slot. Near-full inputs were actually counted,
then checked against server usage; no shorter-input result substitutes for256K.
Model loading/startup compilation are excluded from request timings.

| Configuration / fixture | Input / actual output | Generation rate | Whole request |
|---|---:|---:|---:|
| NInfer K8V4 MTP3 / natural prose |257760 /1530|103.10tok/s|116.57s|
| NInfer K8V4 MTP3 / tool role |260800 /169|156.44tok/s|108.10s|
| NInfer K8V4 MTP2 / natural prose |257760 /1161|96.25tok/s|115.59s|
| NInfer K8V4 no MTP / natural prose |257760 /1572|51.69tok/s|131.29s|
| llama.cpp Q4_K_M +Q4 KV +MTP2 / schema, clean repeat |260844 /123|49.97tok/s|273.93s|
| llama.cpp Q5_K_S +Q4 KV +MTP2 / schema |260844 /123|47.87tok/s|274.91s|
| SGLang text-only mixed NVFP4 +FP8 KV |260842 /123|49.54tok/s client estimate|165.51s|
| vLLM text-only eager +8.25GiB FP8 KV |260842 /123|Steady-state not established|181.46s|

NInfer reports generation-wall timing; llama.cpp reports server decode timing;
SGLang's client estimate is corroborated by approximately49tok/s server logs.
vLLM's first request had additional decode JIT and an untuned single-token
output-head shape: its7.26tok/s client interval is **not** a steady-state speed.
SGLang/vLLM completed the count, capacity and current role checks. They were
not tested with every possible speculative/graph optimization.

The tool fixture passed typed argument, source, quote, conflict and untrusted
instruction checks. Natural prose was not formally quality-scored. It allowed
4096 output tokens but stopped at EOS; it is not a4096-token completion.
MTP3/MTP2 prose outputs differ, so their small rate difference is not proof of a
statistically established improvement or lossless identical output.

Use~103tok/s as the longer-output MTP3 sample, not156tok/s universally.
Cold near-full prompt processing took~101–107s for MTP3. Final tool-run
whole-GPU peak was29429MiB; minimum sampled `memory.free` was2759MiB.
Desktop activity changes headroom. Earlier total-minus-used gaps included
driver-reserved memory and must not be described as directly measured free VRAM.

NVFP4 here is a **mixed quantization artifact, not GGUF Q4_K_M**. If the
requirement is specifically GGUF Q4/Q5, the tested choice is llama.cpp
Q4_K_M +Q4_0 K/V +MTP2, roughly50–52tok/s. Its forced32768-output capacity
stress passed at229056input+32768output, but forced continuation past EOS does
not demonstrate useful32768-token reasoning.

## Limitations and retained adverse results

- NInfer supports the tested `tool_choice:auto` path, not strict constrained
  JSON or required/named tool-choice modes. Validate schemas and source evidence
  in the application. Do not assume drop-in compatibility with every API client.
- FP8 KV +MTP2 had very little headroom and severe slowdown; it was interrupted,
  not counted as a successful256K run. K8V4 recovered useful headroom.
- SGLang required a source-verified text-only HF configuration override;
  its superficially similar `--language-model-only` CLI flag rejected this
  architecture. The completed run skipped only visual parameters.
- vLLM's automatic10.05GiB cache reserved325502tokens and left very little
  headroom. Explicit8.25GiB still provided266895tokens and passed this test.
- Client defects were retained separately from model failures: current HF
  templates returned BatchEncoding, requiring explicit token IDs; WSL's host-
  forwarded loopback needed per-connection SO_DONTROUTE for some requests.
  Neither fix modified the system network. Build/link failures were not treated
  as inference-speed evidence.
- Development fixtures do not establish general research quality, DeepSeek
  equivalence, multimodal performance, warm-prefix reuse, DFlash2 performance or
  heterogeneous dual-GPU performance. No paid API or held-out course tasks were
  used. No automatic production promotion was performed.

## Evidence location

Raw synthetic test records remain local under `D:/AI/bench/`, not embedded in
this profile commit: `inse691-prose-finalists-20260929-b`,
`inse691-mtp3-role-final-20260929-a`,
`inse691-native-memory-final-20260929-h`,
`inse691-clean-repeat-20260929-a`, `inse691-schema-20260928-a` and
`inse691-longoutput-20260928-a`. The local campaign's `RECOMMENDATION.md`,
`RESULTS.md` and `SCORING-REVIEW.md` retain timing definitions and the uniformly
reviewed scorer correction. Remote readers can inspect this distilled report
but cannot independently reproduce its numbers from uncommitted raw logs alone.
