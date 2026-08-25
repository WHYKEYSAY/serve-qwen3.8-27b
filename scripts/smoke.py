#!/usr/bin/env python3
import argparse
import base64
import json
import mimetypes
import time
import urllib.request


def post(url, payload, timeout=300):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    start = time.monotonic()
    with urllib.request.urlopen(req, timeout=timeout) as response:
        data = json.load(response)
    return round(time.monotonic() - start, 3), data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:8002/v1")
    parser.add_argument("--image")
    parser.add_argument("--output")
    args = parser.parse_args()

    tests = [
        ("chinese", [{"role": "user", "content": "用恰好三句话解释 MoE 路由、负载均衡和 CPU 卸载的关系。"}], None),
        ("code", [{"role": "user", "content": "写 Python 函数 merge_intervals，并给出恰好三个 assert；只输出代码。"}], None),
        ("tool", [{"role": "user", "content": "查 Toronto 当前天气。必须调用工具，不要猜。"}], [{"type": "function", "function": {"name": "get_weather", "description": "Get current weather", "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}}}]),
    ]
    if args.image:
        mime = mimetypes.guess_type(args.image)[0] or "image/png"
        encoded = base64.b64encode(open(args.image, "rb").read()).decode()
        tests.append(("vision", [{"role": "user", "content": [{"type": "image_url", "image_url": {"url": f"data:{mime};base64,{encoded}"}}, {"type": "text", "text": "客观描述图片，不要猜测看不见的内容。"}]}], None))

    elapsed, completion = post(args.base.removesuffix("/v1") + "/completion", {
        "prompt": "Explain why explicit GPU ownership matters when an LLM server and a video diffusion pipeline share one workstation.",
        "n_predict": 256,
        "temperature": 0,
        "cache_prompt": False,
    })
    output = {"native_completion": {
        "elapsed_s": elapsed,
        "prompt_tok_s": completion.get("timings", {}).get("prompt_per_second"),
        "decode_tok_s": completion.get("timings", {}).get("predicted_per_second"),
        "predicted_n": completion.get("tokens_predicted"),
    }}
    for name, messages, tools in tests:
        payload = {"model": "qwen3.8-27b", "messages": messages, "max_tokens": 768, "temperature": 0.2}
        if tools:
            payload["tools"] = tools
            payload["tool_choice"] = "auto"
        elapsed, data = post(args.base + "/chat/completions", payload)
        output[name] = {"elapsed_s": elapsed, "response": data}
        print(json.dumps({name: output[name]}, ensure_ascii=False, indent=2))
    if args.output:
        with open(args.output, "w", encoding="utf-8") as handle:
            json.dump(output, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
