#!/bin/bash
# ============================================================
# 将 LiteLLM 注册为 macOS 开机自启服务 (LaunchAgent)
# 运行一次即可，之后每次开机自动启动，无需手动开 Terminal
# ============================================================
set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$PLIST_DIR/com.llmgateway.litellm.plist"
LOG_DIR="$HOME/Library/Logs/llm-gateway"
VENV_DIR="${SCRIPT_DIR}/.venv"
LITELLM_BIN="${VENV_DIR}/bin/litellm"

echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}  注册 LiteLLM 开机自启服务${NC}"
echo -e "${CYAN}======================================${NC}"
echo ""

# ---- 前置检查 ----
if [ ! -f "$SCRIPT_DIR/litellm_config.yaml" ]; then
    echo -e "${RED}❌ 找不到 litellm_config.yaml，请在 llm-gateway 目录下运行${NC}"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${RED}❌ 找不到 .env 文件，请先运行 setup.sh 或手动 cp .env.example .env${NC}"
    exit 1
fi

if [ ! -f "$LITELLM_BIN" ]; then
    echo -e "${RED}❌ 找不到 .venv/bin/litellm，请先运行 ./setup.sh 创建虚拟环境${NC}"
    exit 1
fi
echo -e "${GREEN}✅ LiteLLM (venv): ${LITELLM_BIN}${NC}"

# ---- 读取 .env 中的变量 ----
source "$SCRIPT_DIR/.env"

# ---- 创建日志目录 ----
mkdir -p "$LOG_DIR"
mkdir -p "$PLIST_DIR"

# ---- 读取 .env 中所有变量用于 plist ----
ENV_KEYS=""
while IFS='=' read -r key value; do
    # 跳过注释和空行
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    # 去掉值的引号
    value="${value%\"}"
    value="${value#\"}"
    [ -z "$value" ] && continue
    ENV_KEYS="${ENV_KEYS}
        <key>${key}</key>
        <string>${value}</string>"
done < "$SCRIPT_DIR/.env"

# ---- 生成 plist (直接调用 venv 里的 litellm，不用 wrapper) ----
cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.llmgateway.litellm</string>

    <key>ProgramArguments</key>
    <array>
        <string>${LITELLM_BIN}</string>
        <string>--config</string>
        <string>${SCRIPT_DIR}/litellm_config.yaml</string>
        <string>--port</string>
        <string>4000</string>
    </array>

    <key>WorkingDirectory</key>
    <string>${SCRIPT_DIR}</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>${LOG_DIR}/litellm.log</string>

    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/litellm-error.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>${ENV_KEYS}
    </dict>
</dict>
</plist>
EOF

# ---- 卸载旧服务 (如果有) ----
launchctl bootout gui/$(id -u) "$PLIST_FILE" 2>/dev/null || true

# ---- 加载服务 ----
launchctl bootstrap gui/$(id -u) "$PLIST_FILE"

echo ""
echo -e "${GREEN}✅ 服务已注册并启动！${NC}"
echo ""
echo -e "  状态查看:  ${CYAN}./status.sh${NC}"
echo -e "  Dashboard: ${CYAN}http://localhost:4000/ui${NC}"
echo -e "  日志:      ${CYAN}tail -f ~/Library/Logs/llm-gateway/litellm.log${NC}"
echo ""
echo -e "  ${GREEN}● 开机自动启动${NC} — 不需要开 Terminal"
echo -e "  ${GREEN}● 崩溃自动重启${NC} — KeepAlive 保活"
echo ""
echo -e "管理命令:"
echo -e "  停止:  ${CYAN}launchctl bootout gui/\$(id -u) $PLIST_FILE${NC}"
echo -e "  启动:  ${CYAN}launchctl bootstrap gui/\$(id -u) $PLIST_FILE${NC}"
echo -e "  卸载:  ${CYAN}./uninstall-service.sh${NC}"
