-- AutoX.js LSP for Neovim
-- 提供 AutoX.js 的语法补全、悬停提示等功能

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
}

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
      '\nPlease run install.sh first.',
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
          vim.notify('AutoX.js LSP attached', vim.log.levels.INFO)
          -- 设置快捷键
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

  vim.notify('AutoX.js LSP plugin loaded', vim.log.levels.DEBUG)
end

return M
