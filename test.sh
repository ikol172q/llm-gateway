#!/bin/bash
# ============================================================
# LiteLLM 快速测试脚本
# 确保 setup.sh 已运行且 LiteLLM 正在监听 :4000
# ============================================================

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# 从 .env 读取 master key
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "${SCRIPT_DIR}/.env" ]; then
    source "${SCRIPT_DIR}/.env"
fi
KEY="${LITELLM_MASTER_KEY:-sk-your-secret-key-here}"

echo -e "${CYAN}=============================${NC}"
echo -e "${CYAN}  LiteLLM 连通性测试${NC}"
echo -e "${CYAN}=============================${NC}"
echo ""

# Test 1: 检查服务
echo -n "1. LiteLLM 服务状态... "
if curl -s -H "Authorization: Bearer $KEY" http://localhost:4000/health | grep -q "healthy"; then
    echo -e "${GREEN}✅ 健康${NC}"
else
    echo -e "${RED}❌ 无法连接 (确保 setup.sh 已运行)${NC}"
    exit 1
fi

# Test 2: 列出可用模型
echo ""
echo "2. 可用模型列表:"
curl -s http://localhost:4000/v1/models -H "Authorization: Bearer $KEY" | python3 -m json.tool 2>/dev/null | grep '"id"' | sed 's/.*"id": "\(.*\)".*/   ✅ \1/'
echo ""

# Test 3: 测试本地模型
echo -n "3. 测试本地模型 (local-general → Qwen3 14B)... "
RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KEY" \
  -d '{
    "model": "local-general",
    "messages": [{"role": "user", "content": "用一句话介绍你自己"}],
    "max_tokens": 100
  }' 2>/dev/null)

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    REPLY=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['choices'][0]['message']['content'][:80])" 2>/dev/null)
    echo -e "${GREEN}✅${NC}"
    echo -e "   回复: ${REPLY}..."
else
    echo -e "${RED}❌ HTTP $HTTP_CODE${NC}"
    echo "   (Ollama 可能还在加载模型，等几秒重试)"
fi

# Test 4: 测试 gpt-4o 别名
echo ""
echo -n "4. 测试别名 (gpt-4o → 本地 Qwen3 14B)... "
RESPONSE2=$(curl -s -w "\n%{http_code}" http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KEY" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "print hello world in Python"}],
    "max_tokens": 50
  }' 2>/dev/null)

HTTP_CODE2=$(echo "$RESPONSE2" | tail -1)
if [ "$HTTP_CODE2" = "200" ]; then
    echo -e "${GREEN}✅ 别名路由正常${NC}"
else
    echo -e "${RED}❌ HTTP $HTTP_CODE2${NC}"
fi

# Test 5: 测试云端 DeepSeek
echo ""
echo -n "5. 测试云端模型 (cloud-cheap → DeepSeek)... "
RESPONSE3=$(curl -s -w "\n%{http_code}" http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KEY" \
  -d '{
    "model": "cloud-cheap",
    "messages": [{"role": "user", "content": "Say hello in one word"}],
    "max_tokens": 10
  }' 2>/dev/null)

HTTP_CODE3=$(echo "$RESPONSE3" | tail -1)
if [ "$HTTP_CODE3" = "200" ]; then
    echo -e "${GREEN}✅ DeepSeek 连通${NC}"
else
    echo -e "${RED}❌ HTTP $HTTP_CODE3 (检查 .env 里的 DEEPSEEK_API_KEY)${NC}"
fi

# Test 6: 测试云端 Qwen3 235B
echo ""
echo -n "6. 测试云端模型 (cloud-strong → Qwen3 235B)... "
RESPONSE4=$(curl -s -w "\n%{http_code}" http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KEY" \
  -d '{
    "model": "cloud-strong",
    "messages": [{"role": "user", "content": "你好"}],
    "max_tokens": 10
  }' 2>/dev/null)

HTTP_CODE4=$(echo "$RESPONSE4" | tail -1)
if [ "$HTTP_CODE4" = "200" ]; then
    echo -e "${GREEN}✅ Qwen3 235B 连通${NC}"
else
    echo -e "${RED}❌ HTTP $HTTP_CODE4 (检查 .env 里的 TOGETHERAI_API_KEY)${NC}"
fi

echo ""
echo -e "${CYAN}=============================${NC}"
echo -e "  Dashboard: ${GREEN}http://localhost:4000/ui${NC}"
echo -e "  API Base:  ${GREEN}http://localhost:4000/v1${NC}"
echo -e "${CYAN}=============================${NC}"
