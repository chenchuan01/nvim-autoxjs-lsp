#!/usr/bin/env node
/**
 * AutoX.js 调试桥接进程
 * 通过 stdin 接收 Neovim 命令，通过 TCP 连接手机端 AutoX.js
 * 通过 stdout 返回日志和状态给 Neovim
 */

import net from 'net';
import { createInterface } from 'readline';
import { randomUUID } from 'crypto';
import { basename } from 'path';
import { exec } from 'child_process';

// 当前运行脚本的 ID
let currentScriptId = null;
// TCP socket
let socket = null;
// 是否已连接
let connected = false;
// 消息缓冲区（处理 TCP 粘包）
let buffer = '';

// 向 Neovim 发送消息（stdout）
function send(msg) {
  process.stdout.write(JSON.stringify(msg) + '\n');
}

// 向手机端发送消息（TCP）
function sendToDevice(msg) {
  if (!socket || !connected) {
    send({ type: 'error', message: '未连接到设备' });
    return false;
  }
  try {
    socket.write(JSON.stringify(msg) + '\n');
    return true;
  } catch (e) {
    send({ type: 'error', message: '发送失败: ' + e.message });
    return false;
  }
}

// 处理来自手机端的消息
function handleDeviceMessage(line) {
  if (!line.trim()) return;
  let msg;
  try {
    msg = JSON.parse(line);
  } catch (e) {
    return;
  }

  switch (msg.type) {
    case 'hello':
      send({ type: 'connected' });
      break;
    case 'log': {
      const log = msg.data && msg.data.log;
      if (log) {
        send({ type: 'log', level: log.level || 'INFO', message: log.message || '' });
      }
      break;
    }
    case 'print': {
      const val = msg.data && msg.data.value;
      if (val !== undefined) {
        send({ type: 'log', level: 'INFO', message: String(val) });
      }
      break;
    }
    case 'exception': {
      const err = msg.data && msg.data.exception;
      if (err) {
        send({ type: 'log', level: 'ERROR', message: err.message || String(err) });
      }
      break;
    }
    case 'script_start':
      send({ type: 'script_started', id: msg.data && msg.data.id });
      break;
    case 'script_end':
      send({ type: 'script_stopped', id: msg.data && msg.data.id });
      currentScriptId = null;
      break;
    default:
      break;
  }
}

// ADB 端口转发
function adbForward(deviceSerial, port, callback) {
  if (typeof port === 'function') {
    // 兼容旧调用：adbForward(deviceSerial, callback)
    callback = port;
    port = 9317;
  }
  let cmd = 'adb';
  if (deviceSerial) {
    cmd += ` -s ${deviceSerial}`;
  }
  cmd += ` forward tcp:${port} tcp:${port}`;
  send({ type: 'log', level: 'INFO', message: `执行: ${cmd}` });
  exec(cmd, (error, stdout, stderr) => {
    if (error) {
      send({ type: 'error', message: `ADB 转发失败: ${error.message}` });
      callback(error);
      return;
    }
    send({ type: 'log', level: 'INFO', message: `ADB 转发成功: ${stdout.trim()}` });
    callback(null);
  });
}

// 连接到手机端
function connect(host, port) {
  if (connected) {
    send({ type: 'error', message: '已经连接到设备' });
    return;
  }

  socket = new net.Socket();
  socket.setTimeout(10000);

  socket.on('connect', () => {
    connected = true;
    socket.setTimeout(0);
    // 发送握手
    socket.write(JSON.stringify({ type: 'hello', data: { version: 2 } }) + '\n');
  });

  socket.on('data', (data) => {
    buffer += data.toString();
    const lines = buffer.split('\n');
    buffer = lines.pop();
    for (const line of lines) {
      handleDeviceMessage(line);
    }
  });

  socket.on('timeout', () => {
    send({ type: 'error', message: '连接超时' });
    socket.destroy();
  });

  socket.on('error', (err) => {
    let message = '连接错误: ' + err.message;
    if (err.message.includes('ECONNREFUSED')) {
      message += '\n端口转发成功，但无法连接到手机端 AutoX.js\n请检查:\n1. 手机端 AutoX.js 是否已开启"连接电脑"功能：\n   - 打开 AutoX.js 应用\n   - 点击右下角"我的"选项卡\n   - 找到"连接电脑"或"远程调试"开关并启用\n   - 确保应用在前台运行（不要最小化）\n2. 如果已开启，尝试重启手机端 AutoX.js 应用\n3. 确保手机已通过 USB 连接电脑，且 USB 调试已授权\n4. AutoX.js 可能使用不同端口，尝试其他端口如: :AutoXConnect :9527 或 :AutoXConnect :8080';
    }
    send({ type: 'error', message: message });
    connected = false;
    socket = null;
  });

  socket.on('close', () => {
    if (connected) {
      send({ type: 'disconnected' });
    }
    connected = false;
    socket = null;
    currentScriptId = null;
  });

  socket.connect(port, host);
}

// 处理来自 Neovim 的命令（stdin）
function handleCommand(cmd) {
  switch (cmd.cmd) {
    case 'connect':
      adbForward(cmd.device, cmd.port || 9317, (err) => {
        if (err) {
          send({ type: 'error', message: 'ADB 连接失败: ' + err.message + '\n请检查:\n1. adb devices 是否显示设备（adb devices）\n2. 手机是否已通过 USB 连接或 adb connect\n3. 是否已授权 USB 调试（手机弹出授权框时点击允许）\n4. 如果使用网络 ADB，确保端口 5555 开放且设备与电脑在同一网络' });
        } else {
          connect('127.0.0.1', cmd.port || 9317);
        }
      });
      break;

    case 'disconnect':
      if (socket) {
        socket.destroy();
      } else {
        send({ type: 'disconnected' });
      }
      break;

    case 'run': {
      const id = randomUUID();
      currentScriptId = id;
      const name = cmd.file ? basename(cmd.file) : 'script.js';
      sendToDevice({
        type: 'run',
        data: { id, name, script: cmd.content || '' },
      });
      break;
    }

    case 'stop':
      if (currentScriptId) {
        sendToDevice({ type: 'stop', data: { id: currentScriptId } });
      } else {
        sendToDevice({ type: 'stopAll' });
      }
      break;

    case 'save': {
      const id = randomUUID();
      const name = cmd.file ? basename(cmd.file) : 'script.js';
      sendToDevice({
        type: 'save',
        data: { id, name, script: cmd.content || '' },
      });
      send({ type: 'log', level: 'INFO', message: '文件已保存到设备: ' + name });
      break;
    }

    default:
      send({ type: 'error', message: '未知命令: ' + cmd.cmd });
  }
}

// 监听 stdin（来自 Neovim 的命令）
const rl = createInterface({ input: process.stdin });
rl.on('line', (line) => {
  if (!line.trim()) return;
  try {
    const cmd = JSON.parse(line);
    handleCommand(cmd);
  } catch (e) {
    send({ type: 'error', message: '命令解析失败: ' + e.message });
  }
});

rl.on('close', () => {
  if (socket) socket.destroy();
  process.exit(0);
});
