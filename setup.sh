#!/bin/bash
# ============================================================
# LiteLLM Hybrid 一键安装+启动脚本
# 适用于: macOS + Homebrew + Mac Studio M4 Max 36GB
# ============================================================
set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}  LiteLLM Hybrid 方案安装向导${NC}"
echo -e "${CYAN}======================================${NC}"
echo ""

# ---- Step 1: 检查 Homebrew ----
if ! command -v brew &>/dev/null; then
    echo -e "${RED}❌ 未检测到 Homebrew，请先安装:${NC}"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
fi
echo -e "${GREEN}✅ Homebrew 已安装${NC}"

# ---- Step 2: 安装 Ollama ----
if ! command -v ollama &>/dev/null; then
    echo -e "${YELLOW}📦 正在安装 Ollama...${NC}"
    brew install ollama
else
    echo -e "${GREEN}✅ Ollama 已安装 ($(ollama --version 2>/dev/null || echo 'unknown'))${NC}"
fi

# ---- Step 3: 启动 Ollama 服务 ----
if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
    echo -e "${YELLOW}🚀 启动 Ollama 服务...${NC}"
    ollama serve &>/dev/null &
    sleep 3
    if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
        echo -e "${RED}❌ Ollama 启动失败，请手动运行: ollama serve${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✅ Ollama 服务运行中${NC}"

# ---- Step 4: 拉取模型 ----
echo ""
echo -e "${CYAN}📥 拉取本地模型 (首次需要下载，请耐心等待)${NC}"

pull_model() {
    local model=$1
    local desc=$2
    if ollama list 2>/dev/null | grep -q "^${model}"; then
        echo -e "${GREEN}  ✅ ${model} 已存在${NC}"
    else
        echo -e "${YELLOW}  ⬇️  正在拉取 ${model} (${desc})...${NC}"
        ollama pull "$model"
        echo -e "${GREEN}  ✅ ${model} 拉取完成${NC}"
    fi
}

pull_model "qwen3:14b"    "~9GB, 日常主力"
pull_model "qwen3:8b"     "~5GB, 快速响应"

echo ""
read -p "是否也拉取 Devstral 24B 编程模型? (~14GB, 较大) [y/N]: " pull_devstral
if [[ "$pull_devstral" =~ ^[Yy]$ ]]; then
    pull_model "devstral:24b" "~14GB, 编程专用"
fi

# ---- Step 5: 创建 venv + 安装 LiteLLM ----
echo ""
VENV_DIR="${SCRIPT_DIR}/.venv"
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}📦 创建虚拟环境...${NC}"
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

if [ ! -f "$VENV_DIR/bin/litellm" ]; then
    echo -e "${YELLOW}📦 安装 LiteLLM (在 venv 中)...${NC}"
    pip install 'litellm[proxy]' --quiet
else
    echo -e "${GREEN}✅ LiteLLM 已安装 (venv)${NC}"
fi

# ---- Step 6: 配置 .env ----
ENV_FILE="${SCRIPT_DIR}/.env"
if [ ! -f "$ENV_FILE" ]; then
    cp "${SCRIPT_DIR}/.env.example" "$ENV_FILE"
    echo ""
    echo -e "${YELLOW}⚠️  已创建 .env 文件，请编辑填入你的 API Key:${NC}"
    echo -e "   ${CYAN}nano ${ENV_FILE}${NC}"
    echo ""
    echo "   需要填两个云端 key:"
    echo "   - DeepSeek:  https://platform.deepseek.com/api_keys"
    echo "   - Together:  https://api.together.ai/settings/api-keys"
    echo ""
    read -p "填好后按 Enter 继续，或按 Ctrl+C 稍后手动启动... "
fi

# 加载 .env
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
    echo -e "${GREEN}✅ 环境变量已加载${NC}"
fi

# ---- Step 7: 启动 LiteLLM ----
echo ""
echo -e "${CYAN}🚀 启动 LiteLLM Proxy...${NC}"
echo -e "   配置: ${SCRIPT_DIR}/litellm_config.yaml"
echo -e "   端口: 4000"
echo -e "   Dashboard: http://localhost:4000/ui"
echo ""

# 检查端口
if lsof -i :4000 &>/dev/null; then
    echo -e "${YELLOW}⚠️  端口 4000 已被占用，尝试终止旧进程...${NC}"
    lsof -ti :4000 | xargs kill -9 2>/dev/null || true
    sleep 1
fi

echo -e "${GREEN}✅ 一切就绪！启动中...${NC}"
echo -e "${CYAN}   按 Ctrl+C 停止${NC}"
echo ""

"${VENV_DIR}/bin/litellm" --config "${SCRIPT_DIR}/litellm_config.yaml" --port 4000
