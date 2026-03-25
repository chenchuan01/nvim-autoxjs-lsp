#!/usr/bin/env bash
# 启动调试服务端，打印手机原始消息，诊断握手问题
cd "$(dirname "$0")/.."
node server/debug-server.js
