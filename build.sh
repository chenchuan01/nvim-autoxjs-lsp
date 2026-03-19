#!/bin/bash

# AutoX.js LSP 安装脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/server"

echo "🚀 开始安装 AutoX.js LSP..."

# 检查 Node.js
if ! command -v node &> /dev/null; then
    echo "❌ 错误: 未找到 Node.js，请先安装 Node.js >= 18.0.0"
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ 错误: Node.js 版本过低，需要 >= 18.0.0"
    exit 1
fi

echo "✅ Node.js 版本: $(node -v)"

# 安装依赖
echo "📦 安装 LSP 服务器依赖..."
cd "$SERVER_DIR"

if command -v pnpm &> /dev/null; then
    echo "使用 pnpm 安装..."
    pnpm install
elif command -v npm &> /dev/null; then
    echo "使用 npm 安装..."
    npm install
else
    echo "❌ 错误: 未找到 npm 或 pnpm"
    exit 1
fi

echo "✅ 依赖安装完成"

# 测试服务器
echo "🧪 测试 LSP 服务器..."
if node server.js --version &> /dev/null; then
    echo "✅ LSP 服务器测试通过"
else
    echo "⚠️  警告: LSP 服务器测试失败，但可能仍然可用"
fi

echo ""
echo "🎉 安装完成！"
echo ""
echo "请在 Neovim 配置中添加："
echo ""
echo "require('autoxjs-lsp').setup()"
echo ""
echo "调试功能快捷键："
echo "  <leader>xc  连接手机 (:AutoXConnect <ip>)"
echo "  <leader>xr  运行当前文件 (:AutoXRun)"
echo "  <leader>xs  停止脚本 (:AutoXStop)"
echo "  <leader>xv  保存文件到手机 (:AutoXSave)"
echo "  <leader>xl  切换日志窗口 (:AutoXLog)"
echo ""
echo "或使用插件管理器安装（参见 README.md）"
