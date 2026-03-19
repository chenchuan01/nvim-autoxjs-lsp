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
  -- 调试快捷键前缀（设为 false 禁用）
  keymaps = {
    connect  = '<leader>xc',
    run      = '<leader>xr',
    stop     = '<leader>xs',
    save     = '<leader>xv',
    log      = '<leader>xl',
  },
}

-- 注册调试命令和快捷键
local function setup_debug(config)
  local device = require('autoxjs-lsp.device')
  local ui     = require('autoxjs-lsp.ui')

  -- 用户命令
  vim.api.nvim_create_user_command('AutoXConnect', function(opts)
    local arg = opts.args ~= '' and opts.args or nil
    local dev_serial = nil
    local port = 9317
    if arg then
      -- 支持格式：设备序列号[:端口]
      local d, p = arg:match('^(.+):(%d+)$')
      if d then
        dev_serial = d
        port = tonumber(p)
      else
        dev_serial = arg
      end
    end
    device.connect(dev_serial, port)
  end, { nargs = '?', desc = 'AutoX.js: 通过 ADB 连接手机 [device[:port]]' })

  vim.api.nvim_create_user_command('AutoXDisconnect', function()
    device.disconnect()
  end, { desc = 'AutoX.js: 断开连接' })

  vim.api.nvim_create_user_command('AutoXRun', function()
    device.run_file()
  end, { desc = 'AutoX.js: 在手机上运行当前文件' })

  vim.api.nvim_create_user_command('AutoXStop', function()
    device.stop()
  end, { desc = 'AutoX.js: 停止手机上的脚本' })

  vim.api.nvim_create_user_command('AutoXSave', function()
    device.save_file()
  end, { desc = 'AutoX.js: 保存当前文件到手机' })

  vim.api.nvim_create_user_command('AutoXLog', function()
    ui.toggle()
  end, { desc = 'AutoX.js: 切换日志窗口' })

  vim.api.nvim_create_user_command('AutoXClear', function()
    ui.clear()
  end, { desc = 'AutoX.js: 清空日志' })

  -- 快捷键
  local km = config.keymaps
  if km then
    local o = { noremap = true, silent = true }
    if km.connect  then vim.keymap.set('n', km.connect,  ':AutoXConnect<CR>',    vim.tbl_extend('force', o, { desc = 'AutoX: 连接手机' })) end
    if km.run      then vim.keymap.set('n', km.run,      ':AutoXRun<CR>',        vim.tbl_extend('force', o, { desc = 'AutoX: 运行脚本' })) end
    if km.stop     then vim.keymap.set('n', km.stop,     ':AutoXStop<CR>',       vim.tbl_extend('force', o, { desc = 'AutoX: 停止脚本' })) end
    if km.save     then vim.keymap.set('n', km.save,     ':AutoXSave<CR>',       vim.tbl_extend('force', o, { desc = 'AutoX: 保存到手机' })) end
    if km.log      then vim.keymap.set('n', km.log,      ':AutoXLog<CR>',        vim.tbl_extend('force', o, { desc = 'AutoX: 日志窗口' })) end
  end
end

-- 设置插件
function M.setup(opts)
  opts = opts or {}
  local config = vim.tbl_deep_extend('force', M.default_config, opts)

  local plugin_root = get_plugin_root()
  local server_path = plugin_root .. '/server/server.js'

  -- 检查服务器文件是否存在
  if vim.fn.filereadable(server_path) == 0 then
    vim.notify(
      'AutoX.js LSP: server.js not found at ' .. server_path ..
      '\nPlease run build.sh first.',
      vim.log.levels.ERROR
    )
    return
  end

  -- 注册 LSP 配置
  vim.api.nvim_create_autocmd('FileType', {
    pattern = config.filetypes,
    callback = function(ev)
      local root_dir = type(config.root_dir) == 'function'
        and config.root_dir()
        or config.root_dir

      vim.lsp.start({
        name = 'autoxjs_lsp',
        cmd = { 'node', server_path, '--stdio' },
        root_dir = root_dir,
        settings = config.settings,
        capabilities = vim.lsp.protocol.make_client_capabilities(),
        on_attach = function(client, bufnr)
          -- 设置 LSP 快捷键
          local bufopts = { noremap = true, silent = true, buffer = bufnr }
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
          vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
        end,
        on_exit = function(code, signal, client_id)
          if code ~= 0 then
            vim.notify(
              'AutoX.js LSP exited with code ' .. code,
              vim.log.levels.WARN
            )
          end
        end,
      })
    end,
  })

  -- 注册调试命令和快捷键
  setup_debug(config)
end

return M
