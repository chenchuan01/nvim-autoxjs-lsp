-- AutoX.js 日志窗口 UI
-- 底部 split 窗口，带颜色区分日志级别

local M = {}

local LOG_WIN_HEIGHT = 12
local LOG_BUF_NAME = 'AutoX.js Log'

local state = {
  bufnr = nil,
  winid = nil,
}

-- 初始化高亮组
local function setup_highlights()
  vim.api.nvim_set_hl(0, 'AutoXLogInfo',  { fg = '#6bcf7f', default = true })
  vim.api.nvim_set_hl(0, 'AutoXLogWarn',  { fg = '#ffd93d', default = true })
  vim.api.nvim_set_hl(0, 'AutoXLogError', { fg = '#ff6b6b', default = true })
  vim.api.nvim_set_hl(0, 'AutoXLogDebug', { fg = '#888888', default = true })
  vim.api.nvim_set_hl(0, 'AutoXLogConn',  { fg = '#61afef', default = true })
end

-- 获取或创建日志缓冲区
local function get_or_create_buf()
  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    return state.bufnr
  end
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, LOG_BUF_NAME)
  vim.api.nvim_set_option_value('buftype',   'nofile',  { buf = bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'hide',    { buf = bufnr })
  vim.api.nvim_set_option_value('swapfile',  false,     { buf = bufnr })
  vim.api.nvim_set_option_value('modifiable', true,     { buf = bufnr })
  state.bufnr = bufnr
  return bufnr
end

-- 打开日志窗口
function M.open()
  if state.winid and vim.api.nvim_win_is_valid(state.winid) then
    return
  end
  local bufnr = get_or_create_buf()
  vim.cmd('botright ' .. LOG_WIN_HEIGHT .. 'split')
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid, bufnr)
  vim.api.nvim_set_option_value('wrap',   false, { win = winid })
  vim.api.nvim_set_option_value('number', false, { win = winid })
  vim.api.nvim_set_option_value('winfixheight', true, { win = winid })
  -- q 关闭
  vim.keymap.set('n', 'q', function() M.close() end,
    { noremap = true, silent = true, buffer = bufnr })
  state.winid = winid
  -- 回到上一个窗口
  vim.cmd('wincmd p')
end

-- 关闭日志窗口
function M.close()
  if state.winid and vim.api.nvim_win_is_valid(state.winid) then
    vim.api.nvim_win_close(state.winid, true)
  end
  state.winid = nil
end

-- 切换日志窗口
function M.toggle()
  if state.winid and vim.api.nvim_win_is_valid(state.winid) then
    M.close()
  else
    M.open()
  end
end

-- 追加一行日志（带高亮）
function M.append(level, message)
  local bufnr = get_or_create_buf()
  local prefix_map = {
    INFO  = '[INFO] ',
    WARN  = '[WARN] ',
    ERROR = '[ERROR]',
    DEBUG = '[DEBUG]',
    CONN  = '[CONN] ',
  }
  local hl_map = {
    INFO  = 'AutoXLogInfo',
    WARN  = 'AutoXLogWarn',
    ERROR = 'AutoXLogError',
    DEBUG = 'AutoXLogDebug',
    CONN  = 'AutoXLogConn',
  }
  local prefix = prefix_map[level] or '[LOG]  '
  local hl     = hl_map[level]     or 'Normal'
  
  -- 将消息按换行符分割成多行
  local lines = {}
  for line in (message .. '\n'):gmatch('([^\n]*)\n') do
    table.insert(lines, line)
  end
  
  vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  -- 第一行为空时替换，否则追加
  local first = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
  
  -- 添加第一行（带前缀）
  local first_line = prefix .. '  ' .. (lines[1] or '')
  local first_line_idx
  if line_count == 1 and (first == nil or first == '') then
    vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { first_line })
    first_line_idx = 0
    line_count = 1
  else
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { first_line })
    first_line_idx = line_count
    line_count = line_count + 1
  end
  
  -- 添加后续行（缩进对齐）
  for i = 2, #lines do
    if lines[i] ~= '' then  -- 跳过空行
      local continuation_line = string.rep(' ', #prefix + 2) .. lines[i]
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { continuation_line })
      line_count = line_count + 1
    end
  end
  -- 为第一行添加高亮
  vim.api.nvim_buf_add_highlight(bufnr, -1, hl, first_line_idx, 0, #prefix)
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })

  -- 自动滚动到底部
  if state.winid and vim.api.nvim_win_is_valid(state.winid) then
    vim.api.nvim_win_set_cursor(state.winid, { line_count, 0 })
  end
end

-- 清空日志
function M.clear()
  local bufnr = get_or_create_buf()
  vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
end

setup_highlights()

return M
