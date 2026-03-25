#!/usr/bin/env node
// 调试服务端：使用正确的握手格式（data 根据 versionCode 决定）
import { WebSocketServer } from 'ws';
import { randomUUID } from 'crypto';

const PORT = 9317;
const wss = new WebSocketServer({ port: PORT, host: '0.0.0.0' });

wss.on('listening', () => {
  console.log('调试服务端监听 0.0.0.0:' + PORT);
  console.log('握手逻辑：versionCode >= 11090 → data="ok"，否则 → data="连接成功"');
  console.log('');
});

wss.on('connection', (ws, req) => {
  const label = req.socket.remoteAddress + ':' + req.socket.remotePort;
  console.log('[连接] ' + label);

  ws.on('message', (data) => {
    const str = data.toString();
    console.log('[收到] ' + str);

    let msg;
    try { msg = JSON.parse(str); } catch (e) {
      console.log('[解析失败] ' + e.message);
      return;
    }

    if (msg.type === 'hello') {
      const appVersion = (msg.data && msg.data.app_version) || '0';
      const versionCode = parseInt(appVersion.replace(/\./g, ''), 10) || 0;
      const okData = versionCode >= 11090 ? 'ok' : '连接成功';
      const reply = {
        type: 'hello',
        version: appVersion,
        data: okData,
        message_id: randomUUID(),
        debug: false,
      };
      const replyStr = JSON.stringify(reply);
      ws.send(replyStr);
      console.log('[发送] ' + replyStr);
      console.log('  → versionCode=' + versionCode + '  data=' + JSON.stringify(okData));
    } else {
      console.log('[后续消息 ✅ 握手成功] type=' + msg.type);
    }
  });

  ws.on('close', (code, reason) => {
    const r = reason && reason.length > 0 ? reason.toString() : '(无)';
    if (code === 1000 || code === 1001) {
      console.log('[正常断开] code=' + code);
    } else {
      console.log('[❌ 异常断开] code=' + code + '  reason=' + r);
    }
    console.log('');
  });

  ws.on('error', (e) => console.log('[错误] ' + e.message));
});
