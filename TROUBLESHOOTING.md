# LLM Gateway 故障排查指南

> 所有常见问题和解决方案，踩过的坑全在这里

---

## 快速诊断

```bash
# 一键查看全部状态
~/.llm-gateway/status.sh

# 或者看 xbar 菜单栏 🟢/🟡/🔴 LLM 图标
```

---

## 1. LiteLLM Proxy 未运行

### 症状
- xbar 显示 🟡 或 🔴
- `curl http://localhost:4000/health` 无响应

### 排查步骤

```bash
# 看端口是否被占
lsof -i :4000

# 看 launchd 服务状态
launchctl print gui/$(id -u)/com.llmgateway.litellm 2>&1 | head -20

# 看错误日志
tail -20 ~/Library/Logs/llm-gateway/litellm-error.log

# 手动启动测试
~/.llm-gateway/.venv/bin/litellm --config ~/.llm-gateway/litellm_config.yaml --port 4000
```

### 常见原因

**a) 端口 4000 被占用**
```bash
kill -9 $(lsof -ti :4000)
launchctl kickstart -k gui/$(id -u)/com.llmgateway.litellm
```

**b) venv 路径失效（移动过项目目录）**

移动目录后 venv 内部的路径是硬编码的，必须重建：
```bash
cd ~/.llm-gateway
rm -rf .venv
python3 -m venv .venv
.venv/bin/pip install 'litellm[proxy]'
./install-service.sh
```

**c) macOS 权限拒绝（PermissionError: Operation not permitted）**

launchd 无法访问 `~/Desktop`、`~/Documents`、`~/Downloads` 下的文件。
解决：项目必须放在不受限的位置，如 `~/.llm-gateway`。
```bash
# 如果项目在受限目录，移动到 home 下
mv ~/Desktop/LLMGateways/llm-gateway ~/.llm-gateway
cd ~/.llm-gateway
rm -rf .venv && python3 -m venv .venv && .venv/bin/pip install 'litellm[proxy]'
./install-service.sh
```

**d) Python 3.9 兼容性警告（guardrail 报错）**

启动时会看到类似 `unsupported operand type(s) for |: 'type' and 'NoneType'` 的错误。
这是 LiteLLM 的 guardrail 模块使用了 Python 3.10+ 语法，**不影响核心功能**，可以忽略。

---

## 2. 401 Unauthorized

### 症状
- 请求返回 `{"error":"Authentication Error, No api key passed in."}`
- xbar 显示 LiteLLM 未运行（实际在跑，但 health check 被拒）

### 原因
所有请求都必须带 `Authorization: Bearer <MASTER_KEY>`，包括 `/health` 端点。

### 解决
```bash
# 查看你的 master key
grep LITELLM_MASTER_KEY ~/.llm-gateway/.env

# 正确的请求方式
curl -H "Authorization: Bearer <你的key>" http://localhost:4000/health
```

---

## 3. 云端模型报错

### DeepSeek (cloud-cheap) 失败
```bash
# 验证 key
curl -s https://api.deepseek.com/v1/models -H "Authorization: Bearer $(grep '^DEEPSEEK_API_KEY=' ~/.llm-gateway/.env | cut -d= -f2-)"
```
- 返回模型列表 → key 有效，可能是 DeepSeek 限流，等 1 分钟重试
- 返回 401 → key 无效，去 https://platform.deepseek.com/api_keys 重新获取

### Qwen3 235B (cloud-strong) 失败
```bash
# 验证 key
curl -s https://api.together.xyz/v1/models -H "Authorization: Bearer $(grep '^TOGETHERAI_API_KEY=' ~/.llm-gateway/.env | cut -d= -f2-)" | head -5
```
- 免费额度可能用完，去 https://api.together.ai 检查余额

### 更新 API Key
```bash
nano ~/.llm-gateway/.env   # 编辑 key
# 重启服务使新 key 生效
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.llmgateway.litellm.plist
./install-service.sh
```

---

## 4. Ollama 问题

### Ollama 没启动
```bash
# 打开 Ollama app（推荐，会自动管理）
open -a Ollama

# 或手动启动
ollama serve
```

### 模型加载慢 / 首次请求超时
- 首次加载到 GPU 需要 **20-30 秒**，属正常
- 36GB 内存同时只能跑 1-2 个大模型，Ollama 会自动管理
- 手动预热：`ollama run qwen3:14b "hi"`

### 拉取模型失败
```bash
ollama pull qwen3:14b    # 重试
ollama list              # 看已有模型
```

### 内存不够 / 模型被卸载
```bash
# 看当前加载在内存中的模型
curl -s http://localhost:11434/api/ps | python3 -m json.tool
```
36GB 建议：日常只跑 qwen3:14b (~10GB)，需要编程时切 devstral:24b (~16GB)。

---

## 5. xbar 插件问题

### 插件不显示
1. 确认文件在正确位置且可执行：
```bash
ls -la ~/Library/Application\ Support/xbar/plugins/llm-gateway.1m.sh
chmod +x ~/Library/Application\ Support/xbar/plugins/llm-gateway.1m.sh
```
2. 重启 xbar：`killall xbar && sleep 3 && open -a xbar`

### 插件显示黄色但服务实际在跑
- 可能是 health check 超时或认证失败
- 确认 xbar 插件里的路径和 key 是否正确
- 更新插件：`cp ~/.llm-gateway/xbar/llm-gateway.30s.sh ~/Library/Application\ Support/xbar/plugins/llm-gateway.1m.sh`

### 出现多个 LLM 图标
```bash
# 清理重复的插件文件
ls ~/Library/Application\ Support/xbar/plugins/ | grep llm
# 只保留 llm-gateway.1m.sh，删掉其他的
rm ~/Library/Application\ Support/xbar/plugins/llm-gateway.30s.sh 2>/dev/null
killall xbar && sleep 3 && open -a xbar
```

### xbar 自身没有开机自启
菜单栏点 xbar 图标 → 勾选 **Start at Login**

---

## 6. 服务管理命令速查

```bash
# 启动服务
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.llmgateway.litellm.plist

# 停止服务
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.llmgateway.litellm.plist

# 重启服务
launchctl kickstart -k gui/$(id -u)/com.llmgateway.litellm

# 查看服务状态
launchctl print gui/$(id -u)/com.llmgateway.litellm

# 查看日志
tail -f ~/Library/Logs/llm-gateway/litellm.log
tail -f ~/Library/Logs/llm-gateway/litellm-error.log

# 完整测试
cd ~/.llm-gateway && ./test.sh
```

---

## 7. 升级和维护

```bash
# 升级 LiteLLM
cd ~/.llm-gateway
.venv/bin/pip install -U litellm
launchctl kickstart -k gui/$(id -u)/com.llmgateway.litellm

# 升级 Ollama 模型
ollama pull qwen3:14b    # 会自动拉最新版

# 重装 venv（核弹选项）
cd ~/.llm-gateway
rm -rf .venv
./setup.sh
./install-service.sh
```
