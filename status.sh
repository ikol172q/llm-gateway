#!/bin/bash
# ============================================================
# LiteLLM + Ollama 状态看板
# 随时跑一下看整体运行情况: ./status.sh
# 也可以 watch 实时刷新:   watch -n5 ./status.sh
# ============================================================

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
DIM='\033[2m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "${SCRIPT_DIR}/.env" ]; then
    source "${SCRIPT_DIR}/.env" 2>/dev/null
fi
KEY="${LITELLM_MASTER_KEY:-sk-your-secret-key-here}"

clear 2>/dev/null || true
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       LLM Gateway 状态看板               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo -e "${DIM}  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo ""

# ---- Ollama 状态 ----
echo -e "${CYAN}▸ Ollama${NC}"
if curl -s http://localhost:11434/api/tags &>/dev/null; then
    echo -e "  状态:  ${GREEN}● 运行中${NC}  (http://localhost:11434)"
    # 列出已加载模型
    MODELS=$(curl -s http://localhost:11434/api/tags | python3 -c "
import sys,json
try:
    data = json.load(sys.stdin)
    for m in data.get('models', []):
        name = m['name']
        size_gb = m.get('size', 0) / 1e9
        print(f'    {name:30s} {size_gb:.1f} GB')
except: pass
" 2>/dev/null)
    if [ -n "$MODELS" ]; then
        echo -e "  模型:"
        echo "$MODELS"
    fi
    # 当前加载在内存中的
    PS_OUT=$(curl -s http://localhost:11434/api/ps | python3 -c "
import sys,json
try:
    data = json.load(sys.stdin)
    for m in data.get('models', []):
        name = m['name']
        vram = m.get('size_vram', 0) / 1e9
        print(f'    {name:30s} VRAM {vram:.1f} GB')
except: pass
" 2>/dev/null)
    if [ -n "$PS_OUT" ]; then
        echo -e "  ${GREEN}内存中:${NC}"
        echo "$PS_OUT"
    fi
else
    echo -e "  状态:  ${RED}● 未运行${NC}"
    echo -e "  ${DIM}启动: ollama serve${NC}"
fi

echo ""

# ---- LiteLLM 状态 ----
echo -e "${CYAN}▸ LiteLLM Proxy${NC}"
HEALTH=$(curl -s -H "Authorization: Bearer $KEY" http://localhost:4000/health 2>/dev/null)
if echo "$HEALTH" | grep -q "healthy"; then
    echo -e "  状态:  ${GREEN}● 运行中${NC}  (http://localhost:4000)"
    echo -e "  面板:  http://localhost:4000/ui"

    # 可用模型
    echo -e "  路由表:"
    curl -s http://localhost:4000/v1/models -H "Authorization: Bearer $KEY" 2>/dev/null | python3 -c "
import sys,json
try:
    data = json.load(sys.stdin)
    for m in data.get('data', []):
        mid = m['id']
        print(f'    ✅ {mid}')
except: pass
" 2>/dev/null

    # 健康检查各模型
    echo ""
    echo -e "  模型健康:"
    python3 -c "
import json, sys
try:
    h = json.loads('''$HEALTH''')
    endpoints = h.get('healthy_endpoints', [])
    unhealthy = h.get('unhealthy_endpoints', [])
    for ep in endpoints:
        model = ep.get('model', 'unknown')
        print(f'    \033[0;32m●\033[0m {model}')
    for ep in unhealthy:
        model = ep.get('model', 'unknown')
        print(f'    \033[0;31m●\033[0m {model} (unhealthy)')
    if not endpoints and not unhealthy:
        print('    (无详细端点信息)')
except:
    print('    (解析失败)')
" 2>/dev/null

else
    echo -e "  状态:  ${RED}● 未运行${NC}"
    echo -e "  ${DIM}启动: ./setup.sh${NC}"
fi

echo ""

# ---- 云端 API Key 状态 ----
echo -e "${CYAN}▸ API Keys${NC}"
if [ -n "$DEEPSEEK_API_KEY" ] && [ "$DEEPSEEK_API_KEY" != "" ]; then
    echo -e "  DeepSeek:   ${GREEN}● 已配置${NC}"
else
    echo -e "  DeepSeek:   ${YELLOW}○ 未配置${NC}  ${DIM}→ .env 填 DEEPSEEK_API_KEY${NC}"
fi
if [ -n "$TOGETHERAI_API_KEY" ] && [ "$TOGETHERAI_API_KEY" != "" ]; then
    echo -e "  Together:   ${GREEN}● 已配置${NC}"
else
    echo -e "  Together:   ${YELLOW}○ 未配置${NC}  ${DIM}→ .env 填 TOGETHERAI_API_KEY${NC}"
fi

echo ""
echo -e "${DIM}提示: 实时监控可用 watch -n5 ./status.sh${NC}"
