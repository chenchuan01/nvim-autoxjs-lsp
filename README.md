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
- ✅ **连接手机**：通过 TCP 连接手机端 AutoX.js
- ✅ **运行脚本**：一键将当前文件推送到手机运行
- ✅ **实时日志**：底部窗口显示手机端输出，带颜色区分级别
- ✅ **停止脚本**：随时停止手机上正在运行的脚本
- ✅ **保存文件**：将文件保存到手机本地

## 语法支持

本插件支持 **AutoX.js v6**，使用 **ES5 语法**：
- 使用 `var` 声明变量，`function` 定义函数
- 不支持箭头函数、let/const、模板字符串、class、async/await 等 ES6+ 特性

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
  -- 调试快捷键（设为 false 禁用对应快捷键）
  keymaps = {
    connect = '<leader>xc',  -- 连接手机
    run     = '<leader>xr',  -- 运行脚本
    stop    = '<leader>xs',  -- 停止脚本
    save    = '<leader>xv',  -- 保存到手机
    log     = '<leader>xl',  -- 切换日志窗口
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

### 手机调试（ADB 连接）

#### 连接准备

1. **安装 ADB 工具**：确保 `adb` 命令可用
2. **连接设备**：
   - USB 连接：手机通过 USB 线连接电脑，开启 USB 调试
   - 网络连接：执行 `adb connect <设备IP>:5555` 连接远程设备
3. **验证连接**：
   ```bash
   adb devices
   # 应显示连接的设备，例如：
   # List of devices attached
   # 19231FDF6008VG   device
   ```
4. **手机端设置**：在 AutoX.js 应用中开启"连接电脑"功能

#### 连接设备

```vim
:AutoXConnect [device_serial[:port]]
```

示例：
```vim
:AutoXConnect           # 使用默认设备
:AutoXConnect 19231FDF6008VG    # 指定设备序列号
:AutoXConnect 19231FDF6008VG:9317  # 指定设备和端口
```

此命令会自动执行 `adb forward tcp:9317 tcp:9317` 并连接到 `127.0.0.1:9317`。

#### 运行和调试

| 快捷键 | 命令 | 说明 |
|--------|------|------|
| `<leader>xc` | `:AutoXConnect [device[:port]]` | 通过 ADB 连接手机 |
| `<leader>xr` | `:AutoXRun` | 将当前文件推送到手机运行 |
| `<leader>xs` | `:AutoXStop` | 停止手机上的脚本 |
| `<leader>xv` | `:AutoXSave` | 保存当前文件到手机 |
| `<leader>xl` | `:AutoXLog` | 切换日志窗口 |
| —            | `:AutoXDisconnect` | 断开连接 |
| —            | `:AutoXClear` | 清空日志 |

日志窗口中按 `q` 关闭。

#### 故障排除

##### 连接错误：`ECONNREFUSED 127.0.0.1:9317`
- ✅ ADB 端口转发成功
- ❌ 手机端 AutoX.js 未响应
- **解决方法**：
  1. 确认手机端 AutoX.js 已开启"连接电脑"
  2. 重启手机端 AutoX.js 应用
  3. 保持 AutoX.js 应用在前台运行

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

### 无法连接手机

- 确认手机和电脑在同一局域网
- 确认手机端 AutoX.js 已开启"连接电脑"
- 检查防火墙是否放行 9317 端口
- 尝试 `:AutoXConnect <ip>:9317` 显式指定端口

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 致谢

- [AutoX.js](https://github.com/kkevsekk1/AutoX) - 强大的 Android 自动化工具
- [AutoJs6-VSCode-Extension](https://github.com/SuperMonster003/AutoJs6-VSCode-Extension) - 设计参考
- [vscode-languageserver](https://github.com/microsoft/vscode-languageserver-node) - LSP 实现基础
