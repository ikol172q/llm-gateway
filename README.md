# LiteLLM 混合路由方案 — 搭建指南

## 架构概览

```
你的应用 / Agent / 编程工具
         │
         ▼
   LiteLLM Proxy (localhost:4000)
   统一 OpenAI 兼容接口
         │
    ┌─────┼─────────────┐
    ▼     ▼             ▼
  Ollama  Groq/         Anthropic
  (本地)  Together/      (备用前沿)
          DeepSeek
          (云端开源)
```

所有请求都走 `http://localhost:4000`，LiteLLM 根据你指定的 model 名称自动路由到本地或云端。

---

## 第一步：安装 Ollama + 拉取本地模型

```bash
# 安装 Ollama (如果还没装)
brew install ollama

# 启动 Ollama 服务
ollama serve

# 拉取模型 (新终端窗口)
ollama pull qwen3:14b        # 日常主力 (~9GB)
ollama pull qwen3:8b          # 快速响应 (~5GB)
ollama pull devstral:24b      # 编程专用 (~14GB) — 可选，较大
```

> **内存提示**: 36GB 不建议同时加载所有模型。Ollama 会自动管理，不用的模型会从内存卸载。
> 日常只跑 qwen3:14b 就够了，需要编程时再切 devstral。

---

## 第二步：安装 LiteLLM

```bash
pip install 'litellm[proxy]'
```

---

## 第三步：配置环境变量

```bash
# 复制模板
cp .env.example .env

# 编辑 .env，填入你的 API Key
# 至少填一个云端 key (推荐先注册 Groq，免费额度最多)
```

**推荐注册顺序** (都有免费额度):
1. **Groq** — https://console.groq.com — 免费层，速度最快
2. **DeepSeek** — https://platform.deepseek.com — 价格最低
3. **Together.ai** — https://api.together.ai — 可调用 Qwen3 235B

---

## 第四步：启动 LiteLLM Proxy

```bash
# 加载环境变量并启动
source .env && litellm --config litellm_config.yaml --port 4000
```

看到以下输出说明启动成功:
```
LiteLLM: Proxy initialized with Config, Set models: [...]
INFO:     Uvicorn running on http://0.0.0.0:4000
```

**后台常驻运行** (推荐):
```bash
# 用 tmux 保持后台运行
tmux new -d -s litellm 'source .env && litellm --config litellm_config.yaml --port 4000'

# 查看日志
tmux attach -t litellm

# 脱离 (不会停止): Ctrl+B 然后按 D
```

---

## 第五步：测试

```bash
# 测试本地模型
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-your-secret-key-here" \
  -d '{
    "model": "local-general",
    "messages": [{"role": "user", "content": "你好，你是什么模型？"}]
  }'

# 测试云端模型
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-your-secret-key-here" \
  -d '{
    "model": "cloud-fast",
    "messages": [{"role": "user", "content": "Hello, what model are you?"}]
  }'

# 测试别名 (gpt-4o → 实际走本地 Qwen3 14B)
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-your-secret-key-here" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Write a Python hello world"}]
  }'
```

---

## 日常使用：接入你的工具

### Python / Agent 应用
```python
from openai import OpenAI

client = OpenAI(
    api_key="sk-your-secret-key-here",   # 你的 LITELLM_MASTER_KEY
    base_url="http://localhost:4000/v1"
)

# 简单任务 → 本地免费
response = client.chat.completions.create(
    model="local-general",  # → Ollama Qwen3 14B
    messages=[{"role": "user", "content": "解释一下 Python 装饰器"}]
)

# 复杂任务 → 云端开源模型
response = client.chat.completions.create(
    model="cloud-strong",   # → Together Qwen3 235B
    messages=[{"role": "user", "content": "重构这个复杂的分布式系统..."}]
)
```

### Cursor / VS Code AI 编程助手
在设置中:
- API Base: `http://localhost:4000/v1`
- API Key: `sk-your-secret-key-here`
- Model: `gpt-4o` (实际走本地 Qwen3 14B)

### Aider
```bash
aider --openai-api-base http://localhost:4000/v1 --openai-api-key sk-your-secret-key-here
```

### OpenCode / Claude Code
```bash
ANTHROPIC_BASE_URL=http://localhost:4000 \
ANTHROPIC_API_KEY=sk-your-secret-key-here \
claude
```

---

## 模型选择速查表

| 任务类型 | 用哪个 model 名 | 实际走向 | 成本 |
|---------|-----------------|---------|------|
| 日常对话、问答 | `local-general` | 本地 Qwen3 14B | $0 |
| 代码补全、简单编程 | `local-code` | 本地 Devstral 24B | $0 |
| 快速分类、摘要 | `local-fast` | 本地 Qwen3 8B | $0 |
| 需要更强推理 | `cloud-fast` | Groq Llama 4 Scout | ~$0.11/M |
| 最便宜的云端 | `cloud-cheap` | DeepSeek V3.2 | ~$0.28/M |
| 最强开源模型 | `cloud-strong` | Qwen3 235B | ~$0.50/M |
| 兼容现有工具 | `gpt-4o` | 本地 Qwen3 14B | $0 |
| 兼容现有工具 | `gpt-3.5-turbo` | 本地 Qwen3 8B | $0 |

---

## Fallback 机制

配置中已设置自动降级:
- `local-general` 失败 → 自动切 `cloud-fast` (Groq)
- `local-code` 失败 → 自动切 `cloud-strong` (Qwen3 235B)
- `gpt-4o` 别名失败 → 自动切 `cloud-fast`

你不需要在应用代码里处理 fallback 逻辑，LiteLLM 会透明地完成。

---

## 查看花费和用量

LiteLLM 内置 Dashboard:
```
http://localhost:4000/ui
```
可以看到每个模型的请求次数、token 消耗、成本追踪。

---

## 未来升级路径

1. **内存升级到 64GB+** → 本地跑 Qwen3 32B 或 70B 量化版，减少云端依赖
2. **流量增大** → 加 Redis 做分布式缓存，或迁移到 Bifrost
3. **上生产** → 加 PostgreSQL 做持久化日志，启用 virtual keys 做多用户管理
4. **迁移网关** → 所有方案都是 OpenAI 兼容接口，换网关只改 base_url 一行
