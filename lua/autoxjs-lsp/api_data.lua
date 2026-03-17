-- AutoX.js API 数据加载模块
local M = {}

-- 获取插件目录
local function get_plugin_dir()
  local script_path = debug.getinfo(1).source:sub(2)
  return vim.fn.fnamemodify(script_path, ':h:h:h')
end

-- 加载 API 数据
function M.load()
  local plugin_dir = get_plugin_dir()
  local api_file = plugin_dir .. '/docs/autoxjs-api-detailed.json'

  local file = io.open(api_file, 'r')
  if not file then
    vim.notify('Failed to load AutoX.js API data', vim.log.levels.ERROR)
    return nil
  end

  local content = file:read('*all')
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    vim.notify('Failed to parse AutoX.js API data', vim.log.levels.ERROR)
    return nil
  end

  return data
end

-- 缓存 API 数据
M.api_data = nil

function M.get()
  if not M.api_data then
    M.api_data = M.load()
  end
  return M.api_data
end

return M
