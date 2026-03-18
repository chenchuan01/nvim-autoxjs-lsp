# nvim-autoxjs-lsp

为 Neovim 提供 AutoX.js 的语言服务器协议（LSP）支持，包括代码补全、悬停提示、函数签名帮助等功能。

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Neovim](https://img.shields.io/badge/Neovim-0.8%2B-green.svg)
![Node.js](https://img.shields.io/badge/Node.js-18%2B-green.svg)
![AutoX.js](https://img.shields.io/badge/AutoX.js-v6-orange.svg)

## 功能特性

- ✅ **代码补全**：自动补全 AutoX.js 的所有 API
- ✅ **悬停提示**：显示函数的详细文档
- ✅ **函数签名**：显示参数类型和说明
- ✅ **基于官方文档**：所有数据来自 AutoX.js v6 官方文档（ES5 语法）

## 语法支持

本 LSP 支持 **AutoX.js v6**，使用 **ES5 语法**。请注意：
- 不支持 ES6+ 特性（如箭头函数、let/const、模板字符串等）
- 使用 `var` 声明变量
- 使用 `function` 关键字定义函数
- 不支持 class、async/await 等现代语法

## 安装

### 前置要求

- Neovim >= 0.8.0
- Node.js >= 18.0.0
- npm 或 pnpm

### 使用 lazy.nvim

```lua
{
  'chenchuan01/nvim-autoxjs-lsp',
  build = './build.sh',
  config = function()
    require('autoxjs-lsp').setup()
  end,
  ft = { 'javascript' },
}
```

### 使用 packer.nvim

```lua
use {
  'chenchuan01/nvim-autoxjs-lsp',
  config = function()
    require('autoxjs-lsp').setup()
  end,
  ft = { 'javascript' },
  run = './build.sh',
}
```

### 手动安装

1. 克隆仓库到 Neovim 的插件目录：

```bash
git clone https://github.com/chenchuan01/nvim-autoxjs-lsp.git ~/.local/share/nvim/site/pack/plugins/start/nvim-autoxjs-lsp
```

2. 运行构建脚本：

```bash
cd ~/.local/share/nvim/site/pack/plugins/start/nvim-autoxjs-lsp
./build.sh
```

3. 在 Neovim 配置中添加：

```lua
require('autoxjs-lsp').setup()
```

## 配置

```lua
require('autoxjs-lsp').setup({
  -- 文件类型
  filetypes = { 'javascript' },
  -- 根目录
  root_dir = vim.fn.getcwd(),
})
```

## 使用

打开任何 `.js` 文件，插件会自动启动并提供以下功能：

1. **代码补全**：输入 `app.` 会自动显示所有 app 模块的方法
2. **悬停提示**：将光标移到函数名上，按 `K` 查看文档
3. **函数签名**：输入函数名和 `(` 会显示参数提示

## 示例

```javascript
// 输入 app. 会显示补全列表
app.launchApp('微信');

// 悬停在 launchApp 上会显示：
// app.launchApp(appName: string)
// 通过应用名称启动应用
// 参数: appName (string): 应用名称
// 返回值: boolean - 是否成功启动
```

## 支持的模块

- `app` - 应用管理
- `console` - 控制台
- `device` - 设备信息
- `dialogs` - 对话框
- `files` - 文件系统
- `globals` - 全局函数
- `http` - 网络请求
- `coordinatesBasedAutomation` - 坐标操作
- `widgetsBasedAutomation` - 控件操作
- `keys` - 按键模拟
- `timers` - 定时器
- `storages` - 本地存储
- `ui` - 用户界面

## 故障排除

### LSP 服务器无法启动

检查 Node.js 是否安装：
```bash
node --version
```

重新运行构建脚本：
```bash
cd ~/.local/share/nvim/site/pack/plugins/start/nvim-autoxjs-lsp
./build.sh
```

### 补全不工作

确保文件类型正确：
```vim
:set filetype?
```

应该显示 `filetype=javascript`

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 致谢

- [AutoX.js](https://github.com/kkevsekk1/AutoX) - 强大的 Android 自动化工具
- [vscode-languageserver](https://github.com/microsoft/vscode-languageserver-node) - LSP 实现基础
