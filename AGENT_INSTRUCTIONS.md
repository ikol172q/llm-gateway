# LLM Gateway — Agent Integration Guide

## What is this?

A local LiteLLM proxy running at `http://localhost:4000` that provides a unified OpenAI-compatible API. It routes requests to either a local Ollama model or cloud APIs based on the model name you specify.

## Connection Details

```
Base URL:  http://localhost:4000/v1
API Key:   sk-your-secret-key-here
Protocol:  OpenAI-compatible (chat completions)
```

## Available Models

| Model Name          | Backend               | Cost        | Best For                                    |
|---------------------|-----------------------|-------------|---------------------------------------------|
| `local`             | Ollama Qwen3 14B      | Free        | General tasks, Q&A, simple coding, Chinese  |
| `deepseek-chat`     | DeepSeek V3 API       | ~$0.14/M in | Stronger reasoning, longer context, Chinese |
| `deepseek-reasoner` | DeepSeek R1 API       | ~$0.55/M in | Math, logic, complex multi-step reasoning   |

## How to Use

### Python (openai SDK)

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:4000/v1",
    api_key="sk-your-secret-key-here"
)

response = client.chat.completions.create(
    model="local",  # or "deepseek-chat" or "deepseek-reasoner"
    messages=[{"role": "user", "content": "your prompt here"}]
)

print(response.choices[0].message.content)
```

### cURL

```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-your-secret-key-here" \
  -d '{
    "model": "local",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### Any OpenAI-compatible SDK/tool

Just set:
- `OPENAI_API_BASE` or `base_url` → `http://localhost:4000/v1`
- `OPENAI_API_KEY` or `api_key` → `sk-your-secret-key-here`
- `model` → one of the model names above

## Model Selection Guide

Use this decision logic when choosing a model:

```
Is the task simple (Q&A, translation, summarization, basic code)?
  → Use "local" (free, ~25 tok/s, good Chinese support)

Does it need stronger reasoning or longer context?
  → Use "deepseek-chat" (fast, cheap, excellent Chinese)

Does it involve math, logic proofs, or complex multi-step analysis?
  → Use "deepseek-reasoner" (slow but powerful, chain-of-thought)
```

## Fallback Behavior

If `local` (Ollama) is unavailable or fails, LiteLLM automatically falls back to `deepseek-chat`. No error handling needed on your side.

## Streaming

Streaming is supported. Add `stream=True`:

```python
response = client.chat.completions.create(
    model="local",
    messages=[{"role": "user", "content": "Explain quantum computing"}],
    stream=True
)
for chunk in response:
    print(chunk.choices[0].delta.content or "", end="")
```

## Health Check

```bash
curl -H "Authorization: Bearer sk-your-secret-key-here" http://localhost:4000/health
```

Returns `healthy_endpoints` if running.

## Limitations

- `local` (Qwen3 14B) has a ~32K context window; for longer inputs use `deepseek-chat`
- `deepseek-reasoner` is slower and more expensive; only use when you genuinely need deep reasoning
- First request to `local` after a cold start may take 20-30 seconds (GPU model loading)
- All requests require the `Authorization: Bearer` header
