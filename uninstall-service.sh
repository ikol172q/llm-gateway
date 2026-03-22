#!/bin/bash
# 卸载 LiteLLM 开机自启服务
set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

PLIST_FILE="$HOME/Library/LaunchAgents/com.llmgateway.litellm.plist"

echo "正在卸载 LiteLLM 服务..."

launchctl bootout gui/$(id -u) "$PLIST_FILE" 2>/dev/null || true
rm -f "$PLIST_FILE"

echo -e "${GREEN}✅ 服务已卸载，下次开机不会自动启动${NC}"
echo -e "  如需手动启动: ${CYAN}./setup.sh${NC}"
