-- AutoX.js LSP for Neovim
-- 提供 AutoX.js 的语法补全、悬停提示等功能
-- 以及与手机端 AutoX.js 的连接和调试功能

local M = {}

-- 获取插件根目录
local function get_plugin_root()
  local script_path = debug.getinfo(1).source:sub(2)
  return vim.fn.fnamemodify(script_path, ':h:h:h')
end

-- 默认配置
M.default_config = {
  filetypes = { 'javascript' },
  root_dir = function()
    return vim.fn.getcwd()
  end,
  settings = {},
  keymaps = {
    connect     = '<leader>xc',
    run         = '<leader>xr',
    stop        = '<leader>xs',
    save        = '<leader>xv',
    log         = '<leader>xl',
    connect_lan = '<leader>xn',
    server      = '<leader>xS',
    history     = '<leader>xh',
    devices     = '<leader>xd',
    run_project = '<leader>xR',
  },
}

-- 解析 "host:port" 或 "device[:port]" 参数
local function parse_arg(arg, default_port)
  if not arg or arg == '' then return nil, default_port end
  local host, port = arg:match('^(.+):(%d+)$')
  if host then
    return host, tonumber(port)
  end
  return arg, default_port
end

-- 注册调试命令和快捷键
local function setup_debug(config)
  local device  = require('autoxjs-lsp.device')
  local ui      = require('autoxjs-lsp.ui')
  local project = require('autoxjs-lsp.project')

  -- ADB 连接
  vim.api.nvim_create_user_command('AutoXConnect', function(opts)
    local dev, port = parse_arg(opts.args, 9317)
    device.connect(dev, port)
  end, { nargs = '?', desc = 'AutoX.js: ADB 连接 [device[:port]]' })

  -- 局域网直连
  vim.api.nvim_create_user_command('AutoXConnectLAN', function(opts)
    local host, port = parse_arg(opts.args, 9317)
    if not host then
      vim.notify('AutoX.js: 请指定 IP，例如 :AutoXConnectLAN 192.168.1.100', vim.log.levels.WARN)
      return
    end
    device.connect_lan(host, port)
  end, { nargs = '?', desc = 'AutoX.js: 局域网直连 <host[:port]>' })

  -- 启动服务端
  vim.api.nvim_create_user_command('AutoXStartServer', function(opts)
    local port = tonumber(opts.args ~= '' and opts.args or nil) or 9317
    device.start_server(port)
  end, { nargs = '?', desc = 'AutoX.js: 启动 TCP 服务端 [port]' })

  -- 停止服务端
  vim.api.nvim_create_user_command('AutoXStopServer', function()
    device.stop_server()
  end, { desc = 'AutoX.js: 停止 TCP 服务端' })

  -- 断开连接
  vim.api.nvim_create_user_command('AutoXDisconnect', function(opts)
    device.disconnect(opts.args ~= '' and opts.args or nil)
  end, { nargs = '?', desc = 'AutoX.js: 断开连接 [device_id]' })

  -- 断开所有连接
  vim.api.nvim_create_user_command('AutoXDisconnectAll', function()
    device.disconnect_all()
  end, { desc = 'AutoX.js: 断开所有连接' })

  -- 列出设备
  vim.api.nvim_create_user_command('AutoXDevices', function()
    device.list_devices()
    ui.open()
  end, { desc = 'AutoX.js: 列出已连接设备' })

  -- 设置活跃设备
  vim.api.nvim_create_user_command('AutoXSetDevice', function(opts)
    if opts.args == '' then
      vim.notify('AutoX.js: 请指定设备 ID 前缀', vim.log.levels.WARN)
      return
    end
    device.set_active(opts.args)
  end, { nargs = 1, desc = 'AutoX.js: 设置活跃设备 <device_id>' })

  -- 运行脚本
  vim.api.nvim_create_user_command('AutoXRun', function(opts)
    device.run_file(opts.args ~= '' and opts.args or nil)
  end, { nargs = '?', desc = 'AutoX.js: 运行当前文件 [device_id]' })

  -- 停止脚本
  vim.api.nvim_create_user_command('AutoXStop', function(opts)
    device.stop(opts.args ~= '' and opts.args or nil)
  end, { nargs = '?', desc = 'AutoX.js: 停止脚本 [device_id]' })

  -- 保存文件
  vim.api.nvim_create_user_command('AutoXSave', function(opts)
    device.save_file(opts.args ~= '' and opts.args or nil)
  end, { nargs = '?', desc = 'AutoX.js: 保存文件到手机 [device_id]' })

  -- 运行项目
  vim.api.nvim_create_user_command('AutoXRunProject', function(opts)
    device.run_project(opts.args ~= '' and opts.args or nil)
  end, { nargs = '?', desc = 'AutoX.js: 运行项目 [device_id]' })

  -- 保存项目
  vim.api.nvim_create_user_command('AutoXSaveProject', function(opts)
    device.save_project(opts.args ~= '' and opts.args or nil)
  end, { nargs = '?', desc = 'AutoX.js: 保存项目到手机 [device_id]' })

  -- 新建项目
  vim.api.nvim_create_user_command('AutoXNewProject', function(opts)
    project.new(opts.args ~= '' and opts.args or nil)
  end, { nargs = '?', desc = 'AutoX.js: 新建项目 [path]' })

  -- 历史记录
  vim.api.nvim_create_user_command('AutoXHistory', function()
    device.pick_history()
  end, { desc = 'AutoX.js: 从历史记录连接' })

  -- 日志窗口
  vim.api.nvim_create_user_command('AutoXLog', function()
    ui.toggle()
  end, { desc = 'AutoX.js: 切换日志窗口' })

  -- 清空日志
  vim.api.nvim_create_user_command('AutoXClear', function()
    ui.clear()
  end, { desc = 'AutoX.js: 清空日志' })

  -- 快捷键
  local km = config.keymaps
  if km then
    local o = { noremap = true, silent = true }
    local function kset(key, cmd, desc)
      if key then
        vim.keymap.set('n', key, cmd, vim.tbl_extend('force', o, { desc = desc }))
      end
    end
    kset(km.connect,     ':AutoXConnect<CR>',      'AutoX: ADB 连接')
    kset(km.connect_lan, ':AutoXConnectLAN<CR>',   'AutoX: 局域网连接')
    kset(km.server,      ':AutoXStartServer<CR>',  'AutoX: 启动服务端')
    kset(km.history,     ':AutoXHistory<CR>',      'AutoX: 历史连接')
    kset(km.devices,     ':AutoXDevices<CR>',      'AutoX: 设备列表')
    kset(km.run,         ':AutoXRun<CR>',          'AutoX: 运行脚本')
    kset(km.run_project, ':AutoXRunProject<CR>',   'AutoX: 运行项目')
    kset(km.stop,        ':AutoXStop<CR>',         'AutoX: 停止脚本')
    kset(km.save,        ':AutoXSave<CR>',         'AutoX: 保存到手机')
    kset(km.log,         ':AutoXLog<CR>',          'AutoX: 日志窗口')
  end
end

-- 设置插件
function M.setup(opts)
  opts = opts or {}
  local config = vim.tbl_deep_extend('force', M.default_config, opts)

  local plugin_root = get_plugin_root()
  local server_path = plugin_root .. '/server/server.js'

  if vim.fn.filereadable(server_path) == 0 then
    vim.notify(
      'AutoX.js LSP: server.js not found at ' .. server_path ..
      '\nPlease run build.sh first.',
      vim.log.levels.ERROR
    )
    return
  end

  -- 注册 LSP
  vim.api.nvim_create_autocmd('FileType', {
    pattern = config.filetypes,
    callback = function()
      local root_dir = type(config.root_dir) == 'function'
        and config.root_dir()
        or config.root_dir
      vim.lsp.start({
        name         = 'autoxjs_lsp',
        cmd          = { 'node', server_path, '--stdio' },
        root_dir     = root_dir,
        settings     = config.settings,
        capabilities = vim.lsp.protocol.make_client_capabilities(),
        on_attach    = function(_, bufnr)
          local bufopts = { noremap = true, silent = true, buffer = bufnr }
          vim.keymap.set('n', 'K',     vim.lsp.buf.hover,          bufopts)
          vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
        end,
        on_exit = function(code)
          if code ~= 0 then
            vim.notify('AutoX.js LSP exited with code ' .. code, vim.log.levels.WARN)
          end
        end,
      })
    end,
  })

  setup_debug(config)
end

return M
