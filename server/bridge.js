#!/usr/bin/env node
/**
 * AutoX.js 调试桥接进程
 * 支持多种连接模式：ADB 转发、局域网直连、WebSocket 服务端
 */

import { WebSocketServer } from 'ws';
import { createInterface } from 'readline';
import { randomUUID } from 'crypto';
import { basename } from 'path';
import { exec } from 'child_process';
import {
  devices,
  setSend, getActiveId,
  registerWebSocket, registerTcpSocket, connectLan,
  sendToDevice, listDevices,
} from './device-manager.js';

// 向 Neovim 发送消息（stdout）
function send(msg) {
  process.stdout.write(JSON.stringify(msg) + '\n');
}
setSend(send);

// WebSocket 服务端
let wss = null;
let wssPort = null;

// ADB 端口转发
function adbForward(deviceSerial, port, callback) {
  let cmd = 'adb';
  if (deviceSerial) cmd += ` -s ${deviceSerial}`;
  cmd += ` forward tcp:${port} tcp:${port}`;
  send({ type: 'log', level: 'INFO', message: `执行: ${cmd}` });
  exec(cmd, (error, stdout) => {
    if (error) {
      send({ type: 'error', message: `ADB 转发失败: ${error.message}` });
      callback(error);
      return;
    }
    send({ type: 'log', level: 'INFO', message: `ADB 转发成功: ${stdout.trim()}` });
    callback(null);
  });
}

// 启动 WebSocket 服务端（手机用 Ktor WebSocket 连接）
function startServer(port) {
  if (wss) {
    send({ type: 'error', message: '服务端已在运行，端口: ' + wssPort });
    return;
  }
  wss = new WebSocketServer({ port, host: '0.0.0.0' });
  wss.on('connection', (ws, req) => {
    const host = req.socket.remoteAddress;
    const remotePort = req.socket.remotePort;
    send({ type: 'log', level: 'INFO', message: `新设备连接: ${host}:${remotePort}` });
    registerWebSocket(ws, host, remotePort);
  });
  wss.on('listening', () => {
    wssPort = port;
    send({ type: 'server_started', port });
  });
  wss.on('error', (err) => {
    send({ type: 'error', message: '服务端错误: ' + err.message });
    wss = null;
    wssPort = null;
  });
}

// 停止 WebSocket 服务端
function stopServer() {
  if (!wss) {
    send({ type: 'error', message: '服务端未运行' });
    return;
  }
  wss.close(() => {
    send({ type: 'server_stopped' });
    wss = null;
    wssPort = null;
  });
}

// 获取目标设备 ID
function resolveTarget(deviceId) {
  const id = deviceId || getActiveId();
  if (!id) send({ type: 'error', message: '没有活跃设备，请先连接' });
  return id;
}

// 处理来自 Neovim 的命令
function handleCommand(cmd) {
  switch (cmd.cmd) {
    case 'connect':
      adbForward(cmd.device, cmd.port || 9317, (err) => {
        if (!err) connectLan('127.0.0.1', cmd.port || 9317);
      });
      break;

    case 'connect_lan':
      connectLan(cmd.host, cmd.port || 9317);
      break;

    case 'start_server':
      startServer(cmd.port || 9317);
      break;

    case 'stop_server':
      stopServer();
      break;

    case 'disconnect': {
      const id = cmd.deviceId || getActiveId();
      if (!id) { send({ type: 'disconnected' }); break; }
      const dev = devices.get(id);
      if (dev) dev.close();
      break;
    }

    case 'disconnect_all':
      for (const dev of devices.values()) dev.close();
      if (wss) stopServer();
      break;

    case 'set_active': {
      const dev = devices.get(cmd.deviceId);
      if (dev) {
        send({ type: 'log', level: 'INFO', message: '活跃设备: ' + dev.label });
      } else {
        send({ type: 'error', message: '设备不存在: ' + cmd.deviceId });
      }
      break;
    }

    case 'list_devices':
      listDevices();
      break;

    case 'run': {
      const targetId = resolveTarget(cmd.deviceId);
      if (!targetId) break;
      const id = randomUUID();
      const name = cmd.file ? basename(cmd.file) : 'script.js';
      const dev = devices.get(targetId);
      if (dev) dev.scriptId = id;
      sendToDevice(targetId, { type: 'run', data: { id, name, script: cmd.content || '' } });
      break;
    }

    case 'stop': {
      const targetId = resolveTarget(cmd.deviceId);
      if (!targetId) break;
      const dev = devices.get(targetId);
      if (dev && dev.scriptId) {
        sendToDevice(targetId, { type: 'stop', data: { id: dev.scriptId } });
      } else {
        sendToDevice(targetId, { type: 'stopAll' });
      }
      break;
    }

    case 'save': {
      const targetId = resolveTarget(cmd.deviceId);
      if (!targetId) break;
      const name = cmd.file ? basename(cmd.file) : 'script.js';
      sendToDevice(targetId, { type: 'save', data: { id: randomUUID(), name, script: cmd.content || '' } });
      send({ type: 'log', level: 'INFO', message: '文件已保存到设备: ' + name });
      break;
    }

    case 'run_project': {
      const targetId = resolveTarget(cmd.deviceId);
      if (!targetId) break;
      sendToDevice(targetId, {
        type: 'run_project',
        data: { id: randomUUID(), name: cmd.name || 'project', files: cmd.files || [] },
      });
      break;
    }

    default:
      send({ type: 'error', message: '未知命令: ' + cmd.cmd });
  }
}

// 监听 stdin
const rl = createInterface({ input: process.stdin });
rl.on('line', (line) => {
  if (!line.trim()) return;
  try {
    handleCommand(JSON.parse(line));
  } catch (e) {
    send({ type: 'error', message: '命令解析失败: ' + e.message });
  }
});

rl.on('close', () => {
  for (const dev of devices.values()) dev.close();
  if (wss) wss.close();
  process.exit(0);
});
