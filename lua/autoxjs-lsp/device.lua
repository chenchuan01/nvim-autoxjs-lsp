-- AutoX.js 设备连接管理
-- 支持 ADB、局域网直连、TCP 服务端模式，多设备管理

local M = {}

local ui      = require('autoxjs-lsp.ui')
local history = require('autoxjs-lsp.history')

-- 内部状态
local state = {
  job_id      = nil,   -- bridge.js 进程 ID
  devices     = {},    -- id -> { label, host, port, active }
  active_id   = nil,   -- 当前活跃设备 ID
  server_port = nil,   -- 服务端监听端口（nil 表示未启动）
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
  vim.fn.chansend(state.job_id, vim.json.encode(cmd) .. '\n')
end

-- 处理 bridge.js 的 stdout 输出
local function on_stdout(_, data, _)
  for _, line in ipairs(data) do
    if line == '' then goto continue end
    local ok, msg = pcall(vim.json.decode, line)
    if not ok then goto continue end

    if msg.type == 'connected' then
      local dev = {
        label  = msg.label or (msg.host .. ':' .. msg.port),
        host   = msg.host,
        port   = msg.port,
        active = true,
      }
      -- 旧活跃设备取消活跃标记
      if state.active_id and state.devices[state.active_id] then
        state.devices[state.active_id].active = false
      end
      state.devices[msg.deviceId] = dev
      state.active_id = msg.deviceId
      ui.open()
      ui.append('CONN', '已连接: ' .. dev.label)
      -- 记录历史
      if msg.host and msg.host ~= '127.0.0.1' then
        history.add('ip', msg.host .. ':' .. msg.port)
      end

    elseif msg.type == 'disconnected' then
      local dev = state.devices[msg.deviceId]
      local label = dev and dev.label or (msg.label or '设备')
      state.devices[msg.deviceId] = nil
      if state.active_id == msg.deviceId then
        -- 切换到下一个可用设备
        state.active_id = nil
        for id, _ in pairs(state.devices) do
          state.active_id = id
          break
        end
      end
      ui.append('CONN', '已断开: ' .. label)

    elseif msg.type == 'server_started' then
      state.server_port = msg.port
      ui.open()
      ui.append('CONN', '服务端已启动，等待设备连接，端口: ' .. msg.port)

    elseif msg.type == 'server_stopped' then
      state.server_port = nil
      ui.append('CONN', '服务端已停止')

    elseif msg.type == 'device_list' then
      if not msg.devices or #msg.devices == 0 then
        ui.append('INFO', '当前无已连接设备')
      else
        ui.append('INFO', '已连接设备列表:')
        for _, dev in ipairs(msg.devices) do
          local mark = dev.active and ' [活跃]' or ''
          ui.append('INFO', '  ' .. dev.id:sub(1, 8) .. '  ' .. dev.label .. mark)
        end
      end

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
  state.job_id      = nil
  state.devices     = {}
  state.active_id   = nil
  state.server_port = nil
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
    on_stdout       = on_stdout,
    on_stderr       = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= '' then ui.append('DEBUG', '[bridge] ' .. line) end
      end
    end,
    on_exit         = on_exit,
    stdout_buffered = false,
  })
  if state.job_id <= 0 then
    vim.notify('AutoX.js: 启动 bridge.js 失败', vim.log.levels.ERROR)
    state.job_id = nil
    return false
  end
  return true
end

-- 通过 ADB 连接设备
function M.connect(device, port)
  port = port or 9317
  if not ensure_bridge() then return end
  -- 记录 ADB 设备历史
  if device then history.add('device', device) end
  ui.open()
  ui.append('CONN', '正在通过 ADB 连接: ' .. (device or '默认设备') .. ' 端口:' .. port)
  send_cmd({ cmd = 'connect', device = device, port = port })
end

-- 局域网直连
function M.connect_lan(host, port)
  port = port or 9317
  if not ensure_bridge() then return end
  ui.open()
  ui.append('CONN', '正在局域网连接: ' .. host .. ':' .. port)
  send_cmd({ cmd = 'connect_lan', host = host, port = port })
end

-- 启动 TCP 服务端
function M.start_server(port)
  port = port or 9317
  if not ensure_bridge() then return end
  send_cmd({ cmd = 'start_server', port = port })
end

-- 停止 TCP 服务端
function M.stop_server()
  send_cmd({ cmd = 'stop_server' })
end

-- 断开指定设备（或活跃设备）
function M.disconnect(device_id)
  if not state.job_id then return end
  send_cmd({ cmd = 'disconnect', deviceId = device_id })
end

-- 断开所有设备
function M.disconnect_all()
  if not state.job_id then return end
  send_cmd({ cmd = 'disconnect_all' })
end

-- 列出已连接设备
function M.list_devices()
  if not state.job_id then
    ui.append('INFO', '当前无已连接设备')
    return
  end
  send_cmd({ cmd = 'list_devices' })
end

-- 设置活跃设备（通过序号或 ID 前缀）
function M.set_active(id_or_prefix)
  for id, _ in pairs(state.devices) do
    if id == id_or_prefix or id:sub(1, #id_or_prefix) == id_or_prefix then
      state.active_id = id
      send_cmd({ cmd = 'set_active', deviceId = id })
      return
    end
  end
  vim.notify('AutoX.js: 未找到设备: ' .. id_or_prefix, vim.log.levels.WARN)
end

-- 运行当前文件（指定设备或活跃设备）
function M.run_file(device_id)
  if not state.active_id and not device_id then
    vim.notify('AutoX.js: 未连接到设备', vim.log.levels.WARN)
    return
  end
  local file    = vim.fn.expand('%:p')
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  ui.append('INFO', '运行: ' .. vim.fn.expand('%:t'))
  send_cmd({ cmd = 'run', file = file, content = content, deviceId = device_id })
end

-- 停止脚本
function M.stop(device_id)
  if not state.active_id and not device_id then return end
  ui.append('INFO', '停止脚本...')
  send_cmd({ cmd = 'stop', deviceId = device_id })
end

-- 保存文件到手机
function M.save_file(device_id)
  if not state.active_id and not device_id then
    vim.notify('AutoX.js: 未连接到设备', vim.log.levels.WARN)
    return
  end
  local file    = vim.fn.expand('%:p')
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  send_cmd({ cmd = 'save', file = file, content = content, deviceId = device_id })
end

-- 运行项目
function M.run_project(device_id)
  if not state.active_id and not device_id then
    vim.notify('AutoX.js: 未连接到设备', vim.log.levels.WARN)
    return
  end
  local project = require('autoxjs-lsp.project')
  local proj = project.get_project()
  if not proj then return end
  ui.append('INFO', '运行项目: ' .. proj.config.name)
  send_cmd({
    cmd      = 'run_project',
    name     = proj.config.name,
    files    = proj.files,
    deviceId = device_id,
  })
end

-- 保存项目到手机
function M.save_project(device_id)
  if not state.active_id and not device_id then
    vim.notify('AutoX.js: 未连接到设备', vim.log.levels.WARN)
    return
  end
  local project = require('autoxjs-lsp.project')
  local proj = project.get_project()
  if not proj then return end
  for _, f in ipairs(proj.files) do
    send_cmd({ cmd = 'save', file = f.name, content = f.content, deviceId = device_id })
  end
  ui.append('INFO', '项目已保存到设备: ' .. proj.config.name .. ' (' .. #proj.files .. ' 个文件)')
end

-- 获取连接状态
function M.is_connected()
  return state.active_id ~= nil
end

-- 显示历史记录并选择连接（使用 vim.ui.select）
function M.pick_history()
  local ip_list  = history.list('ip')
  local dev_list = history.list('device')
  local items = {}
  for _, v in ipairs(ip_list)  do table.insert(items, { kind = 'ip',     value = v, label = '[LAN] ' .. v }) end
  for _, v in ipairs(dev_list) do table.insert(items, { kind = 'device', value = v, label = '[ADB] ' .. v }) end
  if #items == 0 then
    vim.notify('AutoX.js: 暂无连接历史', vim.log.levels.INFO)
    return
  end
  vim.ui.select(items, {
    prompt = '选择历史连接:',
    format_item = function(item) return item.label end,
  }, function(choice)
    if not choice then return end
    if choice.kind == 'ip' then
      local host, port = choice.value:match('^(.+):(%d+)$')
      M.connect_lan(host or choice.value, tonumber(port) or 9317)
    else
      M.connect(choice.value)
    end
  end)
end

return M
