-- AutoX.js 设备连接管理
-- 通过 jobstart 管理 bridge.js 进程，与手机端 AutoX.js 通信

local M = {}

local ui = require('autoxjs-lsp.ui')

-- 内部状态
local state = {
  job_id    = nil,   -- bridge.js 进程 ID
  connected = false, -- 是否已连接到手机
  host      = nil,
  port      = nil,
}

-- 获取 bridge.js 路径
local function get_bridge_path()
  local script_path = debug.getinfo(1).source:sub(2)
  local plugin_root = vim.fn.fnamemodify(script_path, ':h:h:h')
  return plugin_root .. '/server/bridge.js'
end

-- 向 bridge.js 发送命令
local function send_cmd(cmd)
  if not state.job_id then
    ui.append('ERROR', 'bridge 进程未启动')
    return
  end
  local line = vim.json.encode(cmd) .. '\n'
  vim.fn.chansend(state.job_id, line)
end

-- 处理 bridge.js 的 stdout 输出
local function on_stdout(_, data, _)
  for _, line in ipairs(data) do
    if line == '' then goto continue end
    local ok, msg = pcall(vim.json.decode, line)
    if not ok then goto continue end

    if msg.type == 'connected' then
      state.connected = true
      ui.open()
      ui.append('CONN', '已连接到设备 ' .. (state.host or '') .. ':' .. (state.port or 9317))

    elseif msg.type == 'disconnected' then
      state.connected = false
      ui.append('CONN', '已断开连接')

    elseif msg.type == 'log' then
      ui.append(msg.level or 'INFO', msg.message or '')

    elseif msg.type == 'error' then
      ui.append('ERROR', msg.message or '未知错误')

    elseif msg.type == 'script_started' then
      ui.append('INFO', '脚本开始运行')

    elseif msg.type == 'script_stopped' then
      ui.append('INFO', '脚本已停止')
    end

    ::continue::
  end
end

-- 处理 bridge.js 退出
local function on_exit(_, code, _)
  state.job_id    = nil
  state.connected = false
  if code ~= 0 then
    ui.append('ERROR', 'bridge 进程异常退出，code=' .. code)
  end
end

-- 启动 bridge.js 进程（如果尚未启动）
local function ensure_bridge()
  if state.job_id then return true end
  local bridge_path = get_bridge_path()
  if vim.fn.filereadable(bridge_path) == 0 then
    vim.notify('AutoX.js: bridge.js 不存在: ' .. bridge_path, vim.log.levels.ERROR)
    return false
  end
  state.job_id = vim.fn.jobstart({ 'node', bridge_path }, {
    on_stdout = on_stdout,
    on_stderr = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= '' then
          ui.append('DEBUG', '[bridge] ' .. line)
        end
      end
    end,
    on_exit   = on_exit,
    stdout_buffered = false,
  })
  if state.job_id <= 0 then
    vim.notify('AutoX.js: 启动 bridge.js 失败', vim.log.levels.ERROR)
    state.job_id = nil
    return false
  end
  return true
end



-- 断开连接
function M.disconnect()
  if not state.job_id then return end
  send_cmd({ cmd = 'disconnect' })
end

-- 运行当前文件
function M.run_file()
  if not state.connected then
    vim.notify('AutoX.js: 未连接到设备，请先执行 :AutoXConnect', vim.log.levels.WARN)
    return
  end
  local file    = vim.fn.expand('%:p')
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  ui.append('INFO', '运行: ' .. vim.fn.expand('%:t'))
  send_cmd({ cmd = 'run', file = file, content = content })
end

-- 停止脚本
function M.stop()
  if not state.connected then return end
  ui.append('INFO', '停止脚本...')
  send_cmd({ cmd = 'stop' })
end

-- 保存文件到手机
function M.save_file()
  if not state.connected then
    vim.notify('AutoX.js: 未连接到设备，请先执行 :AutoXConnect', vim.log.levels.WARN)
    return
  end
  local file    = vim.fn.expand('%:p')
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  send_cmd({ cmd = 'save', file = file, content = content })
end

-- 通过 ADB 连接到手机
function M.connect(device, port)
  port = port or 9317
  if not ensure_bridge() then return end
  state.host = '127.0.0.1'
  state.port = port
  ui.open()
  ui.append('CONN', '正在通过 ADB 连接设备 ' .. (device or '默认') .. ' ...')
  send_cmd({ cmd = 'connect', device = device, port = port })
end

-- 获取连接状态
function M.is_connected()
  return state.connected
end

return M
