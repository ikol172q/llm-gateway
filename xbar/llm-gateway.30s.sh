#!/bin/bash
# <xbar.title>LLM Gateway Monitor</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>irene</xbar.author>
# <xbar.desc>Monitor LiteLLM + Ollama status with troubleshooting</xbar.desc>
# <xbar.image>https://example.com/icon.png</xbar.image>
# <xbar.dependencies>bash,curl,python3</xbar.dependencies>
# <xbar.abouturl>https://github.com/BerriAI/litellm</xbar.abouturl>

# ============================================================
# 配置 — 按你的实际路径修改
# ============================================================
GATEWAY_DIR="$HOME/.llm-gateway"
LITELLM_PORT=4000
OLLAMA_PORT=11434
PLIST_FILE="$HOME/Library/LaunchAgents/com.llmgateway.litellm.plist"
LOG_FILE="$HOME/Library/Logs/llm-gateway/litellm.log"
ERR_LOG="$HOME/Library/Logs/llm-gateway/litellm-error.log"

# 加载 API key
ENV_FILE="$HOME/.llm-gateway/.env"
KEY="$(/usr/bin/grep '^LITELLM_MASTER_KEY=' "$ENV_FILE" 2>/dev/null | /usr/bin/cut -d= -f2-)"
DEEPSEEK_API_KEY="$(/usr/bin/grep '^DEEPSEEK_API_KEY=' "$ENV_FILE" 2>/dev/null | /usr/bin/cut -d= -f2-)"
TOGETHERAI_API_KEY="$(/usr/bin/grep '^TOGETHERAI_API_KEY=' "$ENV_FILE" 2>/dev/null | /usr/bin/cut -d= -f2-)"
KEY="${KEY:-sk-your-secret-key-here}"

# ============================================================
# 状态检测
# ============================================================
OLLAMA_OK=false
LITELLM_OK=false
OLLAMA_MODELS=""
LITELLM_MODELS=""
LOADED_MODELS=""

# Ollama
if curl -s --max-time 3 "http://localhost:${OLLAMA_PORT}/api/tags" &>/dev/null; then
    OLLAMA_OK=true
    OLLAMA_MODELS=$(curl -s --max-time 3 "http://localhost:${OLLAMA_PORT}/api/tags" | python3 -c "
import sys,json
try:
    data = json.load(sys.stdin)
    for m in data.get('models', []):
        name = m['name']
        size_gb = m.get('size', 0) / 1e9
        print(f'{name} ({size_gb:.1f}GB)')
except: pass
" 2>/dev/null)
    LOADED_MODELS=$(curl -s --max-time 3 "http://localhost:${OLLAMA_PORT}/api/ps" | python3 -c "
import sys,json
try:
    data = json.load(sys.stdin)
    for m in data.get('models', []):
        name = m['name']
        vram = m.get('size_vram', 0) / 1e9
        print(f'{name} (VRAM {vram:.1f}GB)')
except: pass
" 2>/dev/null)
fi

# LiteLLM — 用轻量的 /health/liveliness 端点检测，避免大 JSON 超时
HEALTH_JSON=""
HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 -H "Authorization: Bearer $KEY" "http://localhost:${LITELLM_PORT}/health/liveliness" 2>/dev/null)
if [ "$HEALTH_CODE" = "200" ]; then
    LITELLM_OK=true
    HEALTH_JSON=$(curl -s --max-time 5 -H "Authorization: Bearer $KEY" "http://localhost:${LITELLM_PORT}/health" 2>/dev/null)
    LITELLM_MODELS=$(curl -s --max-time 3 "http://localhost:${LITELLM_PORT}/v1/models" -H "Authorization: Bearer $KEY" 2>/dev/null | python3 -c "
import sys,json
try:
    data = json.load(sys.stdin)
    for m in data.get('data', []):
        print(m['id'])
except: pass
" 2>/dev/null)
fi

# API Keys
DS_OK=false
TG_OK=false
[ -n "$DEEPSEEK_API_KEY" ] && [ "$DEEPSEEK_API_KEY" != "" ] && DS_OK=true
[ -n "$TOGETHERAI_API_KEY" ] && [ "$TOGETHERAI_API_KEY" != "" ] && TG_OK=true

# launchd 服务状态
SERVICE_LOADED=false
if launchctl print gui/$(id -u)/com.llmgateway.litellm &>/dev/null 2>&1; then
    SERVICE_LOADED=true
fi

# ============================================================
# 菜单栏图标
# ============================================================
if $OLLAMA_OK && $LITELLM_OK; then
    echo "🟢 LLM | refresh=true"
elif $OLLAMA_OK || $LITELLM_OK; then
    echo "🟡 LLM | refresh=true"
else
    echo "🔴 LLM | refresh=true"
fi

echo "---"

# ============================================================
# Ollama 区块
# ============================================================
if $OLLAMA_OK; then
    echo "✅ Ollama — 运行中 | color=green"
else
    echo "❌ Ollama — 未运行 | color=red"
fi

if $OLLAMA_OK; then
    echo "--已安装模型:"
    if [ -n "$OLLAMA_MODELS" ]; then
        while IFS= read -r m; do
            echo "--  $m | font=Menlo size=12"
        done <<< "$OLLAMA_MODELS"
    else
        echo "--  (无模型) | color=gray"
    fi
    if [ -n "$LOADED_MODELS" ]; then
        echo "--当前在 GPU 内存中:"
        while IFS= read -r m; do
            echo "--  🟢 $m | font=Menlo size=12 color=green"
        done <<< "$LOADED_MODELS"
    else
        echo "--  (无模型在内存中) | color=gray"
    fi
fi

echo "---"

# ============================================================
# LiteLLM 区块
# ============================================================
if $LITELLM_OK; then
    echo "✅ LiteLLM Proxy — 运行中 (port ${LITELLM_PORT}) | color=green"
else
    echo "❌ LiteLLM Proxy — 未运行 | color=red"
    # 显示最近的错误
    if [ -f "$ERR_LOG" ]; then
        RECENT_ERR=$(tail -5 "$ERR_LOG" 2>/dev/null | grep -i -m1 "error\|fatal\|permission\|denied\|failed\|traceback" | cut -c1-90)
        if [ -n "$RECENT_ERR" ]; then
            echo "--⚠️ 最近错误: | color=red"
            echo "--  ${RECENT_ERR} | font=Menlo size=11 color=red"
        fi
    fi
fi

if $LITELLM_OK && [ -n "$LITELLM_MODELS" ]; then
    echo "--路由表:"
    while IFS= read -r m; do
        echo "--  ✅ $m | font=Menlo size=12"
    done <<< "$LITELLM_MODELS"
fi

if $SERVICE_LOADED; then
    echo "--服务: 已注册 (开机自启) | color=green"
else
    echo "--服务: 未注册 | color=orange"
fi

echo "---"

# ============================================================
# 模型管理区块
# ============================================================
MODELS_DIR="$GATEWAY_DIR/models"
GW="$GATEWAY_DIR/gateway"

echo "📦 模型管理"

# 列出已配置模型，带 enable/disable 切换
if [ -d "$MODELS_DIR" ]; then
    for model_file in "$MODELS_DIR"/*.yaml; do
        [ -f "$model_file" ] || continue
        mname=$(grep '^name=' "$model_file" 2>/dev/null | cut -d= -f2-)
        mmodel=$(grep '^model=' "$model_file" 2>/dev/null | cut -d= -f2-)
        mbase=$(basename "$model_file" .yaml)

        if [ -f "$MODELS_DIR/${mbase}.disabled" ]; then
            echo "--○ ${mname} ${DIM}(已禁用)${NC} | color=gray"
            echo "----模型: ${mmodel} | font=Menlo size=11 color=gray"
            echo "----✅ 启用 | bash=$GW param1=enable param2=$mname terminal=false refresh=true"
            echo "----🗑 删除 | bash=$GW param1=remove param2=$mname terminal=false refresh=true"
        else
            # 判断本地/云端
            if echo "$mmodel" | /usr/bin/grep -q "^ollama"; then
                echo "--🟢 ${mname} (本地) | color=green"
            else
                echo "--🔵 ${mname} (云端) | color=#4a9eff"
            fi
            echo "----模型: ${mmodel} | font=Menlo size=11"
            echo "----⏸ 禁用 | bash=$GW param1=disable param2=$mname terminal=false refresh=true"
            echo "----🗑 删除 | bash=$GW param1=remove param2=$mname terminal=false refresh=true"
        fi
    done
fi

echo "--"
echo "--➕ 添加模型"
echo "----🏠 本地 Ollama 模型"
# 列出 Ollama 里有但还没配置的模型 (按 model= 字段匹配，不仅仅按文件名)
if $OLLAMA_OK && [ -n "$OLLAMA_MODELS" ]; then
    ALL_CONFIGURED=$(/usr/bin/grep -h '^model=' "$MODELS_DIR"/*.yaml 2>/dev/null | /usr/bin/cut -d= -f2-)
    while IFS= read -r om; do
        oname=$(echo "$om" | sed 's/ .*//' | sed 's/:/-/g')
        oraw=$(echo "$om" | sed 's/ .*//')
        if ! echo "$ALL_CONFIGURED" | /usr/bin/grep -q "ollama_chat/${oraw}"; then
            echo "------➕ $oraw | bash=$GW param1=add param2=$oname param3=ollama_chat/$oraw terminal=false refresh=true"
        fi
    done <<< "$OLLAMA_MODELS"
fi
echo "------📥 拉取新模型... | bash=$GW param1=pull terminal=true"

echo "----☁️ 云端模型 (常用)"
echo "------DeepSeek Chat | bash=$GW param1=add param2=deepseek-chat param3=deepseek/deepseek-chat terminal=false refresh=true"
echo "------DeepSeek Reasoner | bash=$GW param1=add param2=deepseek-reasoner param3=deepseek/deepseek-reasoner terminal=false refresh=true"
echo "------Qwen3 235B (Together) | bash=$GW param1=add param2=qwen3-235b param3=together_ai/Qwen/Qwen3-235B-A22B terminal=false refresh=true"
echo "------Claude Sonnet 4.6 | bash=$GW param1=add param2=claude param3=anthropic/claude-sonnet-4-6-20250214 terminal=false refresh=true"

echo "---"

# ============================================================
# API Keys 区块
# ============================================================
echo "🔑 API Keys"
if $DS_OK; then
    echo "--DeepSeek:  ✅ 已配置 | color=green"
else
    echo "--DeepSeek:  ⚠️ 未配置 | color=orange"
fi
if $TG_OK; then
    echo "--Together:  ✅ 已配置 | color=green"
else
    echo "--Together:  ⚠️ 未配置 (可选) | color=gray"
fi
echo "--编辑 API Keys | bash=/usr/bin/open param1=-a param2=TextEdit param3=$GATEWAY_DIR/.env terminal=false"

echo "---"

# ============================================================
# 快捷操作
# ============================================================
ACTIONS_DIR="$HOME/.llm-gateway/xbar/actions"
echo "🚀 操作"

if $LITELLM_OK; then
    echo "--🛑 停止 LiteLLM | bash=$ACTIONS_DIR/stop-litellm.sh terminal=false refresh=true"
else
    echo "--▶️  启动 LiteLLM | bash=$ACTIONS_DIR/start-litellm.sh terminal=false refresh=true"
fi

if $OLLAMA_OK; then
    echo "--🛑 停止 Ollama | bash=/usr/bin/pkill param1=-f param2=ollama terminal=false refresh=true"
else
    echo "--▶️  启动 Ollama | bash=/usr/bin/open param1=-a param2=Ollama terminal=false refresh=true"
fi

echo "--🔄 全部重启 | bash=$ACTIONS_DIR/restart-all.sh terminal=false refresh=true"

echo "---"

# ============================================================
# 打开页面 & 日志
# ============================================================
echo "🔗 打开"
echo "--Dashboard (localhost:4000/ui) | href=http://localhost:4000/ui"
echo "--Ollama 模型库 | href=https://ollama.com/library"
echo "--DeepSeek 控制台 | href=https://platform.deepseek.com"
echo "--Together 控制台 | href=https://api.together.ai"

echo "---"

echo "📋 日志"
echo "--查看 LiteLLM 日志 | bash=/usr/bin/open param1=-a param2=Console param3=$LOG_FILE terminal=false"
echo "--查看错误日志 | bash=/usr/bin/open param1=-a param2=Console param3=$ERR_LOG terminal=false"
echo "--Terminal 打开日志 | bash=$ACTIONS_DIR/tail-log.sh terminal=true"
echo "--Terminal 打开错误日志 | bash=$ACTIONS_DIR/tail-errors.sh terminal=true"
if [ -f "$ERR_LOG" ]; then
    LAST_ERR=$(tail -1 "$ERR_LOG" 2>/dev/null | cut -c1-80)
    if [ -n "$LAST_ERR" ]; then
        echo "--最近一条错误:"
        echo "--  ${LAST_ERR}... | font=Menlo size=11 color=red"
    fi
fi

echo "---"

# ============================================================
# Troubleshooting 指南
# ============================================================
echo "🔧 故障排查"
echo "--"
echo "--━━━ Ollama 问题 ━━━ | size=13"
echo "--"
echo "--Ollama 没启动? | color=white"
echo "--  → 打开 Ollama app，或终端跑 ollama serve | font=Menlo size=11 color=gray"
echo "--"
echo "--模型加载慢 / 首次请求超时? | color=white"
echo "--  → 首次加载到 GPU 需要 20-30s，属正常 | font=Menlo size=11 color=gray"
echo "--  → 检查内存: 36GB 同时只能跑 1-2 个大模型 | font=Menlo size=11 color=gray"
echo "--  → 手动预热: ollama run qwen3:14b 'hi' | font=Menlo size=11 color=gray"
echo "--"
echo "--拉取模型失败? | color=white"
echo "--  → 检查网络，重试: ollama pull qwen3:14b | font=Menlo size=11 color=gray"
echo "--"
echo "--━━━ LiteLLM 问题 ━━━ | size=13"
echo "--"
echo "--401 Unauthorized? | color=white"
echo "--  → 请求必须带 Authorization: Bearer <MASTER_KEY> | font=Menlo size=11 color=gray"
echo "--  → 检查 .env 中 LITELLM_MASTER_KEY 是否正确 | font=Menlo size=11 color=gray"
echo "--"
echo "--cloud-cheap 报错? (DeepSeek) | color=white"
echo "--  → 检查 .env 中 DEEPSEEK_API_KEY | font=Menlo size=11 color=gray"
echo "--  → DeepSeek 可能限流: 等 1 分钟重试 | font=Menlo size=11 color=gray"
echo "--  → 验证 key: curl https://api.deepseek.com/v1/models -H 'Authorization: Bearer \$KEY' | font=Menlo size=11 color=gray"
echo "--"
echo "--cloud-strong 报错? (Qwen3 235B) | color=white"
echo "--  → 检查 .env 中 TOGETHERAI_API_KEY | font=Menlo size=11 color=gray"
echo "--  → Together 免费额度可能用完: 检查余额 | font=Menlo size=11 color=gray"
echo "--"
echo "--端口 4000 被占用? | color=white"
echo "--  → lsof -i :4000 查看谁在占 | font=Menlo size=11 color=gray"
echo "--  → kill -9 \$(lsof -ti :4000) 强制释放 | font=Menlo size=11 color=gray"
echo "--"
echo "--LiteLLM 崩溃 / 启动失败? | color=white"
echo "--  → 查看错误日志: tail -50 $ERR_LOG | font=Menlo size=11 color=gray"
echo "--  → 升级: cd $GATEWAY_DIR && .venv/bin/pip install -U litellm | font=Menlo size=11 color=gray"
echo "--  → 重装 venv: rm -rf .venv && ./setup.sh | font=Menlo size=11 color=gray"
echo "--"
echo "--━━━ 常用命令 ━━━ | size=13"
echo "--"
echo "--运行完整测试 | bash=$ACTIONS_DIR/run-test.sh terminal=true"
echo "--编辑 .env | bash=/usr/bin/open param1=-a param2=TextEdit param3=$GATEWAY_DIR/.env terminal=false"
echo "--编辑配置 | bash=/usr/bin/open param1=-a param2=TextEdit param3=$GATEWAY_DIR/litellm_config.yaml terminal=false"
echo "--打开项目目录 | bash=/usr/bin/open param1=$GATEWAY_DIR terminal=false"
echo "--打开 Troubleshooting 文档 | bash=/usr/bin/open param1=$GATEWAY_DIR/TROUBLESHOOTING.md terminal=false"

echo "---"
echo "刷新 | refresh=true"
