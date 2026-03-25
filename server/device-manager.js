/**
 * 设备连接管理
 * - 服务端模式：WebSocket（手机用 Ktor client 连接）
 * - 客户端模式：TCP（ADB 端口转发 / 局域网直连）
 */

import net from 'net';
import { randomUUID } from 'crypto';

// 设备连接表：id -> { write, close, connected, host, port, label, scriptId }
export const devices = new Map();
let activeDeviceId = null;
export function getActiveId() { return activeDeviceId; }
export function setActiveId(id) { activeDeviceId = id; }

// 向 Neovim 发送消息的回调（由 bridge.js 注入）
let _send = null;
export function setSend(fn) { _send = fn; }
function send(msg) { if (_send) _send(msg); }

// 处理来自手机端的一条消息
function handleDeviceMessage(deviceId, line) {
  if (!line.trim()) return;
  let msg;
  try { msg = JSON.parse(line); } catch (e) { return; }
  const dev = devices.get(deviceId);
  if (!dev) return;

  switch (msg.type) {
    case 'hello': {
      // serveHello 检查：versionCode >= 11090 时期望 "ok"，否则期望 "连接成功"
      // versionCode = version.replace('.','') 转为 long（如 "6.3.5" → 635）
      const appVersion = (msg.data && msg.data.app_version) || '0';
      const versionCode = parseInt(appVersion.replace(/\./g, ''), 10) || 0;
      const okData = versionCode >= 11090 ? 'ok' : '连接成功';
      dev.write({
        type: 'hello',
        version: appVersion,
        data: okData,
        message_id: randomUUID(),
        debug: false,
      });
      dev.connected = true;
      send({ type: 'connected', deviceId, host: dev.host, port: dev.port, label: dev.label });
      break;
    }
    case 'log': {
      const log = msg.data && msg.data.log;
      if (log) send({ type: 'log', level: log.level || 'INFO', message: log.message || '', deviceId });
      break;
    }
    case 'print': {
      const val = msg.data && msg.data.value;
      if (val !== undefined) send({ type: 'log', level: 'INFO', message: String(val), deviceId });
      break;
    }
    case 'exception': {
      const err = msg.data && msg.data.exception;
      if (err) send({ type: 'log', level: 'ERROR', message: err.message || String(err), deviceId });
      break;
    }
    case 'script_start':
      dev.scriptId = msg.data && msg.data.id;
      send({ type: 'script_started', id: dev.scriptId, deviceId });
      break;
    case 'script_end':
      send({ type: 'script_stopped', id: dev.scriptId, deviceId });
      dev.scriptId = null;
      break;
    default:
      break;
  }
}

// 设备移除后更新活跃设备
function onDeviceRemoved(deviceId) {
  devices.delete(deviceId);
  if (activeDeviceId === deviceId) {
    setActiveId(devices.size > 0 ? devices.keys().next().value : null);
  }
}

// 注册 WebSocket 连接（服务端模式：手机主动连接）
export function registerWebSocket(ws, host, port) {
  const deviceId = randomUUID();
  const dev = {
    write:     (msg) => ws.send(JSON.stringify(msg)),
    close:     ()    => ws.close(),
    connected: false,
    host,
    port,
    label:     host + ':' + port,
    scriptId:  null,
  };
  devices.set(deviceId, dev);
  setActiveId(deviceId);

  ws.on('message', (data) => {
    const line = data.toString();
    handleDeviceMessage(deviceId, line);
  });

  ws.on('close', () => {
    if (dev.connected) send({ type: 'disconnected', deviceId, label: dev.label });
    onDeviceRemoved(deviceId);
  });

  ws.on('error', (err) => {
    send({ type: 'error', message: '设备错误 [' + dev.label + ']: ' + err.message });
    onDeviceRemoved(deviceId);
  });

  return deviceId;
}

// 注册 TCP 连接（客户端模式：ADB 转发 / 局域网直连）
export function registerTcpSocket(socket, host, port) {
  const deviceId = randomUUID();
  let buffer = '';
  const dev = {
    write:     (msg) => socket.write(JSON.stringify(msg) + '\n'),
    close:     ()    => socket.destroy(),
    connected: false,
    host,
    port,
    label:     host + ':' + port,
    scriptId:  null,
  };
  devices.set(deviceId, dev);
  setActiveId(deviceId);

  socket.setTimeout(10000);

  socket.on('connect', () => {
    socket.setTimeout(0);
    // 客户端主动发握手
    dev.write({ type: 'hello', data: { version: 2 } });
  });

  socket.on('data', (data) => {
    buffer += data.toString();
    const lines = buffer.split('\n');
    buffer = lines.pop();
    for (const line of lines) handleDeviceMessage(deviceId, line);
  });

  socket.on('timeout', () => {
    send({ type: 'error', message: '连接超时: ' + dev.label });
    socket.destroy();
  });

  socket.on('error', (err) => {
    let message = '连接错误 [' + dev.label + ']: ' + err.message;
    if (err.message.includes('ECONNREFUSED')) {
      message += '\n请检查手机端 AutoX.js 是否已开启"连接电脑"功能';
    }
    send({ type: 'error', message });
    onDeviceRemoved(deviceId);
  });

  socket.on('close', () => {
    if (dev.connected) send({ type: 'disconnected', deviceId, label: dev.label });
    onDeviceRemoved(deviceId);
  });

  return deviceId;
}

// 局域网直连（TCP 客户端）
export function connectLan(host, port) {
  const socket = new net.Socket();
  const deviceId = registerTcpSocket(socket, host, port);
  socket.connect(port, host);
  return deviceId;
}

// 向指定设备发送消息
export function sendToDevice(deviceId, msg) {
  const dev = devices.get(deviceId);
  if (!dev || !dev.connected) {
    send({ type: 'error', message: '设备未连接: ' + deviceId });
    return false;
  }
  try {
    dev.write(msg);
    return true;
  } catch (e) {
    send({ type: 'error', message: '发送失败: ' + e.message });
    return false;
  }
}

// 列出所有设备
export function listDevices() {
  const list = [];
  for (const [id, dev] of devices) {
    list.push({ id, label: dev.label, host: dev.host, port: dev.port, active: id === activeDeviceId });
  }
  send({ type: 'device_list', devices: list });
}
