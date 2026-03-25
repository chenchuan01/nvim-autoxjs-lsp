-- AutoX.js 项目管理
-- 支持 .autoxjs.json 项目配置，运行/保存整个项目

local M = {}

local PROJECT_FILE = '.autoxjs.json'

-- 查找项目根目录（向上查找 .autoxjs.json）
function M.find_root(start_dir)
  local dir = start_dir or vim.fn.expand('%:p:h')
  local prev = nil
  while dir ~= prev do
    if vim.fn.filereadable(dir .. '/' .. PROJECT_FILE) == 1 then
      return dir
    end
    prev = dir
    dir = vim.fn.fnamemodify(dir, ':h')
  end
  return nil
end

-- 读取项目配置
function M.load_config(root)
  local path = root .. '/' .. PROJECT_FILE
  local f = io.open(path, 'r')
  if not f then return nil end
  local content = f:read('*a')
  f:close()
  local ok, cfg = pcall(vim.json.decode, content)
  if not ok then return nil end
  return cfg
end

-- 新建项目（在当前目录创建 .autoxjs.json）
function M.new(path)
  path = path or vim.fn.getcwd()
  local cfg_path = path .. '/' .. PROJECT_FILE
  if vim.fn.filereadable(cfg_path) == 1 then
    vim.notify('AutoX.js: 项目已存在: ' .. cfg_path, vim.log.levels.WARN)
    return false
  end
  local cfg = {
    name    = vim.fn.fnamemodify(path, ':t'),
    version = '1.0.0',
    main    = 'main.js',
    ignore  = { 'node_modules', '.git' },
  }
  local f = io.open(cfg_path, 'w')
  if not f then
    vim.notify('AutoX.js: 无法创建项目文件: ' .. cfg_path, vim.log.levels.ERROR)
    return false
  end
  f:write(vim.json.encode(cfg))
  f:close()
  vim.notify('AutoX.js: 项目已创建: ' .. cfg_path, vim.log.levels.INFO)
  return true
end

-- 收集项目文件列表
local function collect_files(root, ignore_list)
  local ignore_set = {}
  for _, v in ipairs(ignore_list or {}) do ignore_set[v] = true end

  local files = {}
  local function scan(dir, rel)
    local entries = vim.fn.readdir(dir)
    for _, name in ipairs(entries) do
      if not ignore_set[name] then
        local full = dir .. '/' .. name
        local rel_path = rel and (rel .. '/' .. name) or name
        if vim.fn.isdirectory(full) == 1 then
          scan(full, rel_path)
        elseif name:match('%.js$') then
          local f = io.open(full, 'r')
          if f then
            local content = f:read('*a')
            f:close()
            table.insert(files, { name = rel_path, content = content })
          end
        end
      end
    end
  end
  scan(root, nil)
  return files
end

-- 获取项目信息（root, config, files）
function M.get_project(path)
  local root = path or M.find_root()
  if not root then
    vim.notify('AutoX.js: 未找到项目（.autoxjs.json）', vim.log.levels.WARN)
    return nil
  end
  local cfg = M.load_config(root)
  if not cfg then
    vim.notify('AutoX.js: 项目配置解析失败', vim.log.levels.ERROR)
    return nil
  end
  local files = collect_files(root, cfg.ignore)
  return { root = root, config = cfg, files = files }
end

return M
