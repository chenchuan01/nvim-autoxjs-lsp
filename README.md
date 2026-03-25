# nvim-autoxjs-lsp

为 Neovim 提供 AutoX.js 开发支持，包括代码补全、悬停提示、函数签名，以及与手机端 AutoX.js 的连接和实时调试功能。

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Neovim](https://img.shields.io/badge/Neovim-0.8%2B-green.svg)
![Node.js](https://img.shields.io/badge/Node.js-18%2B-green.svg)
![AutoX.js](https://img.shields.io/badge/AutoX.js-v6-orange.svg)

## 功能特性

**LSP 支持**
- ✅ **代码补全**：输入 `app.` 自动显示所有 API
- ✅ **悬停提示**：`K` 查看函数文档
- ✅ **函数签名**：输入 `(` 显示参数说明

**手机调试**
- ✅ **ADB 连接**：通过 ADB 端口转发连接手机
- ✅ **局域网直连**：通过 IP 直接连接手机（无需 ADB）
- ✅ **服务端模式**：启动 TCP 服务端，等待手机主动连接
- ✅ **多设备管理**：同时连接多台设备，指定设备运行
- ✅ **历史记录**：保存连接历史，快速重连
- ✅ **运行脚本**：一键将当前文件推送到手机运行
- ✅ **项目支持**：运行/保存整个项目到手机
- ✅ **实时日志**：底部窗口显示手机端输出，带颜色区分级别
- ✅ **停止脚本**：随时停止手机上正在运行的脚本

## 语法支持

本插件支持 **AutoX.js v6**，使用 **ES5 语法**：
- 使用 `var` 声明变量，`function` 定义函数
- 不支持箭头函数、let/const、模板字符串、class、async/await 等 ES6+ 特性

## 安装

### 前置要求

- Neovim >= 0.8.0
- Node.js >= 18.0.0
- npm 或 pnpm
- ADB（仅 ADB 连接模式需要）

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

```bash
git clone https://github.com/chenchuan01/nvim-autoxjs-lsp.git \
  ~/.local/share/nvim/site/pack/plugins/start/nvim-autoxjs-lsp
cd ~/.local/share/nvim/site/pack/plugins/start/nvim-autoxjs-lsp
./build.sh
```

在 Neovim 配置中添加：

```lua
require('autoxjs-lsp').setup()
```

## 配置

```lua
require('autoxjs-lsp').setup({
  -- 触发 LSP 的文件类型
  filetypes = { 'javascript' },
  -- 项目根目录
  root_dir = vim.fn.getcwd(),
  -- 快捷键（设为 false 禁用）
  keymaps = {
    connect     = '<leader>xc',  -- ADB 连接
    connect_lan = '<leader>xn',  -- 局域网直连
    server      = '<leader>xS',  -- 启动服务端
    history     = '<leader>xh',  -- 历史记录
    devices     = '<leader>xd',  -- 设备列表
    run         = '<leader>xr',  -- 运行脚本
    run_project = '<leader>xR',  -- 运行项目
    stop        = '<leader>xs',  -- 停止脚本
    save        = '<leader>xv',  -- 保存到手机
    log         = '<leader>xl',  -- 切换日志窗口
  },
})
```

## 使用

### LSP 功能

打开任何 `.js` 文件，插件自动启动：

| 操作 | 说明 |
|------|------|
| 输入 `app.` | 触发代码补全 |
| `K` | 查看光标处函数文档 |
| `<C-k>` | 查看函数签名 |

### 连接模式

#### 模式一：ADB 连接

适合 USB 连接或已配置 `adb connect` 的场景。

```vim
:AutoXConnect                        " 使用默认设备
:AutoXConnect 19231FDF6008VG         " 指定设备序列号
:AutoXConnect 19231FDF6008VG:9317    " 指定设备和端口
```

准备步骤：
1. 安装 ADB，手机开启 USB 调试
2. `adb devices` 确认设备已连接
3. 手机端 AutoX.js 开启"连接电脑"功能

#### 模式二：局域网直连

适合手机和电脑在同一局域网的场景，无需 ADB。

```vim
:AutoXConnectLAN 192.168.1.100        " 默认端口 9317
:AutoXConnectLAN 192.168.1.100:9317   " 指定端口
```

准备步骤：
1. 手机端 AutoX.js 开启"连接电脑"，记录显示的 IP 地址
2. 确保手机和电脑在同一局域网

#### 模式三：服务端模式

Neovim 作为服务端，等待手机主动连接。适合手机端主动发起连接的场景。

```vim
:AutoXStartServer        " 默认端口 9317
:AutoXStartServer 6789   " 指定端口
:AutoXStopServer         " 停止服务端
```

### 历史记录

连接成功后自动保存历史，下次可快速重连：

```vim
:AutoXHistory    " 弹出历史列表，选择后自动连接
```

### 多设备管理

```vim
:AutoXDevices              " 列出所有已连接设备
:AutoXSetDevice <id前缀>   " 切换活跃设备
:AutoXDisconnect           " 断开活跃设备
:AutoXDisconnectAll        " 断开所有设备
```

### 脚本操作

| 快捷键 | 命令 | 说明 |
|--------|------|------|
| `<leader>xr` | `:AutoXRun` | 运行当前文件 |
| `<leader>xR` | `:AutoXRunProject` | 运行整个项目 |
| `<leader>xs` | `:AutoXStop` | 停止脚本 |
| `<leader>xv` | `:AutoXSave` | 保存文件到手机 |
| `<leader>xl` | `:AutoXLog` | 切换日志窗口 |
| — | `:AutoXSaveProject` | 保存项目到手机 |
| — | `:AutoXClear` | 清空日志 |

所有脚本命令支持指定设备 ID：

```vim
:AutoXRun <device_id>     " 在指定设备运行
:AutoXSave <device_id>    " 保存到指定设备
```

### 项目支持

在项目目录创建 `.autoxjs.json` 配置文件：

```vim
:AutoXNewProject          " 在当前目录新建项目
:AutoXNewProject ~/myapp  " 在指定目录新建项目
```

`.autoxjs.json` 格式：

```json
{
  "name": "myapp",
  "version": "1.0.0",
  "main": "main.js",
  "ignore": ["node_modules", ".git"]
}
```

运行项目会将目录下所有 `.js` 文件（排除 `ignore` 列表）一并发送到手机。

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

```bash
node --version  # 需要 >= 18.0.0
./build.sh      # 重新安装依赖
```

### 补全不工作

```vim
:set filetype?   " 应显示 javascript
:LspInfo         " 查看 LSP 状态
```

### 连接失败

- **ADB 模式**：`adb devices` 确认设备在线，手机端 AutoX.js 开启"连接电脑"
- **局域网模式**：确认手机和电脑在同一局域网，检查防火墙是否放行端口
- **服务端模式**：确认手机端 AutoX.js 配置了正确的电脑 IP 和端口

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 致谢

- [AutoX.js](https://github.com/kkevsekk1/AutoX) - 强大的 Android 自动化工具
- [AutoJs6-VSCode-Extension](https://github.com/SuperMonster003/AutoJs6-VSCode-Extension) - 设计参考
- [vscode-languageserver](https://github.com/microsoft/vscode-languageserver-node) - LSP 实现基础
