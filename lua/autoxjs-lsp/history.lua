-- AutoX.js 连接历史记录管理
-- 保存 IP 地址和 ADB 设备序列号，持久化到文件

local M = {}

local HISTORY_FILE = vim.fn.stdpath('data') .. '/autoxjs_history.json'
local MAX_ENTRIES = 20

-- 加载历史记录
local function load()
  local f = io.open(HISTORY_FILE, 'r')
  if not f then return { ip = {}, device = {} } end
  local content = f:read('*a')
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= 'table' then return { ip = {}, device = {} } end
  data.ip     = data.ip     or {}
  data.device = data.device or {}
  return data
end

-- 保存历史记录
local function save(data)
  local f = io.open(HISTORY_FILE, 'w')
  if not f then return end
  f:write(vim.json.encode(data))
  f:close()
end

-- 添加记录（去重 + 置顶）
function M.add(kind, value)
  if not value or value == '' then return end
  local data = load()
  local list = data[kind] or {}
  -- 去重
  for i = #list, 1, -1 do
    if list[i] == value then table.remove(list, i) end
  end
  -- 置顶
  table.insert(list, 1, value)
  -- 截断
  while #list > MAX_ENTRIES do table.remove(list) end
  data[kind] = list
  save(data)
end

-- 获取历史列表
function M.list(kind)
  local data = load()
  return data[kind] or {}
end

-- 清除历史记录
function M.clear(kind)
  local data = load()
  if kind then
    data[kind] = {}
  else
    data.ip     = {}
    data.device = {}
  end
  save(data)
end

return M
