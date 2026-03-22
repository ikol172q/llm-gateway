#!/bin/bash
# ============================================================
# 安装 xbar 插件
# ============================================================
set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_SRC="${SCRIPT_DIR}/llm-gateway.30s.sh"
XBAR_PLUGINS_DIR="$HOME/Library/Application Support/xbar/plugins"

echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}  安装 LLM Gateway xbar 插件${NC}"
echo -e "${CYAN}======================================${NC}"
echo ""

# 检查 xbar 是否安装
if [ ! -d "$XBAR_PLUGINS_DIR" ]; then
    echo -e "${YELLOW}⚠️  未检测到 xbar 插件目录${NC}"
    echo ""

    if command -v brew &>/dev/null; then
        read -p "是否用 Homebrew 安装 xbar? [Y/n]: " install_xbar
        if [[ ! "$install_xbar" =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}📦 安装 xbar...${NC}"
            brew install --cask xbar
            mkdir -p "$XBAR_PLUGINS_DIR"
            echo -e "${GREEN}✅ xbar 已安装${NC}"
        else
            echo -e "${RED}请手动安装 xbar: https://xbarapp.com${NC}"
            exit 1
        fi
    else
        echo -e "${RED}请先安装 xbar: https://xbarapp.com${NC}"
        exit 1
    fi
fi

# 复制插件并替换 $HOME 为实际路径 (xbar 运行环境可能无法解析 $HOME)
echo -e "${YELLOW}📋 安装插件...${NC}"
DEST="$XBAR_PLUGINS_DIR/llm-gateway.1m.sh"
sed "s|\\\$HOME|$HOME|g" "$PLUGIN_SRC" > "$DEST"
chmod +x "$DEST"

# 同样处理 action 脚本
for f in "${SCRIPT_DIR}/actions"/*.sh; do
    sed -i '' "s|\\\$HOME|$HOME|g" "$f" 2>/dev/null
done

echo -e "${GREEN}✅ 插件已安装到: ${DEST}${NC}"
echo ""

# 启动 xbar
if ! pgrep -x "xbar" &>/dev/null; then
    echo -e "${YELLOW}🚀 启动 xbar...${NC}"
    open -a xbar
    sleep 2
fi

echo ""
echo -e "${GREEN}✅ 完成！查看菜单栏，你应该能看到:${NC}"
echo ""
echo -e "  🟢 LLM  — 全部正常"
echo -e "  🟡 LLM  — 部分服务异常"
echo -e "  🔴 LLM  — 全部离线"
echo ""
echo -e "点击菜单栏图标可以:"
echo -e "  • 查看 Ollama / LiteLLM / API Key 状态"
echo -e "  • 一键启动/停止/重启服务"
echo -e "  • 查看日志和错误"
echo -e "  • 打开 Dashboard"
echo -e "  • 查看故障排查指南"
echo ""
echo -e "${CYAN}插件每 30 秒自动刷新一次${NC}"
