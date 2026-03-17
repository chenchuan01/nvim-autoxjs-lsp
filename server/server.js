#!/usr/bin/env node
/**
 * AutoX.js Language Server Protocol Server
 * 基于 vscode-languageserver 实现，通过 stdio 与 Neovim 通信
 */

import { createConnection, TextDocuments, ProposedFeatures, CompletionItemKind, MarkupKind } from 'vscode-languageserver/node.js';
import { TextDocument } from 'vscode-languageserver-textdocument';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// 创建 LSP 连接（stdio 模式）
const connection = createConnection(ProposedFeatures.all);
const documents = new TextDocuments(TextDocument);

// 加载 API 数据
let apiData = null;
let completionItems = [];
let apiMap = new Map(); // 快速查找 Map

function loadApiData() {
  try {
    const apiPath = join(__dirname, '../docs/autoxjs-api-detailed.json');
    apiData = JSON.parse(readFileSync(apiPath, 'utf-8'));
    connection.console.log('AutoX.js API data loaded successfully');
    buildCompletionItems();
  } catch (error) {
    connection.console.error(`Failed to load API data: ${error.message}`);
  }
}

function buildCompletionItems() {
  if (!apiData?.modules) return;

  for (const module of apiData.modules) {
    if (!module.apis) continue;

    for (const api of module.apis) {
      const params = api.params || [];
      const paramStr = params.map(p => {
        const opt = p.required ? '' : '?';
        return `${opt}${p.name}: ${p.type}`;
      }).join(', ');

      const docLines = [
        `**${api.name}**`,
        '',
        api.description || '',
      ];

      if (params.length > 0) {
        docLines.push('', '**参数:**');
        for (const p of params) {
          const req = p.required ? '' : ' *(可选)*';
          docLines.push(`- \`${p.name}\` *(${p.type})*${req}: ${p.description || ''}`);
        }
      }

      if (api.returns) {
        docLines.push('', `**返回值:** \`${api.returns.type}\` - ${api.returns.description || ''}`);
      }

      if (api.example) {
        docLines.push('', '**示例:**', '```javascript', api.example, '```');
      }

      const item = {
        label: api.name,
        kind: CompletionItemKind.Function,
        detail: `(${paramStr}) => ${api.returns?.type || 'void'}`,
        documentation: {
          kind: MarkupKind.Markdown,
          value: docLines.join('\n'),
        },
        insertText: api.name,
      };

      completionItems.push(item);
      apiMap.set(api.name, { api, module });

      // 也添加短名称（去掉模块前缀）
      const shortName = api.name.includes('.') ? api.name.split('.').pop() : null;
      if (shortName && !apiMap.has(shortName)) {
        apiMap.set(shortName, { api, module });
      }
    }
  }

  connection.console.log(`Built ${completionItems.length} completion items`);
}

// 初始化
connection.onInitialize((params) => {
  loadApiData();
  return {
    capabilities: {
      textDocumentSync: 1, // Full
      completionProvider: {
        resolveProvider: false,
        triggerCharacters: ['.'],
      },
      hoverProvider: true,
      signatureHelpProvider: {
        triggerCharacters: ['(', ','],
      },
    },
    serverInfo: {
      name: 'autoxjs-lsp',
      version: '1.0.0',
    },
  };
});

// 代码补全
connection.onCompletion((params) => {
  return completionItems;
});

// 悬停提示
connection.onHover((params) => {
  const document = documents.get(params.textDocument.uri);
  if (!document) return null;

  const text = document.getText();
  const offset = document.offsetAt(params.position);

  // 提取光标处的单词（支持 module.method 格式）
  let start = offset;
  let end = offset;
  while (start > 0 && /[a-zA-Z0-9_.]/.test(text[start - 1])) start--;
  while (end < text.length && /[a-zA-Z0-9_.]/.test(text[end])) end++;

  const word = text.substring(start, end);
  if (!word) return null;

  // 查找 API
  const found = apiMap.get(word);
  if (!found) return null;

  const { api } = found;
  const params2 = api.params || [];
  const lines = [
    `### ${api.name}`,
    '',
    api.description || '',
  ];

  if (params2.length > 0) {
    lines.push('', '**参数:**');
    for (const p of params2) {
      const req = p.required ? '' : ' *(可选)*';
      lines.push(`- \`${p.name}\` *(${p.type})*${req}: ${p.description || ''}`);
    }
  }

  if (api.returns) {
    lines.push('', `**返回值:** \`${api.returns.type}\` - ${api.returns.description || ''}`);
  }

  if (api.example) {
    lines.push('', '**示例:**', '```javascript', api.example, '```');
  }

  return {
    contents: {
      kind: MarkupKind.Markdown,
      value: lines.join('\n'),
    },
  };
});

// 函数签名帮助
connection.onSignatureHelp((params) => {
  const document = documents.get(params.textDocument.uri);
  if (!document) return null;

  const text = document.getText();
  const offset = document.offsetAt(params.position);

  // 向前查找函数名
  let pos = offset - 1;
  let depth = 0;
  while (pos >= 0) {
    const ch = text[pos];
    if (ch === ')') depth++;
    else if (ch === '(') {
      if (depth === 0) break;
      depth--;
    }
    pos--;
  }

  if (pos < 0) return null;

  // 提取函数名
  let nameEnd = pos;
  let nameStart = nameEnd;
  while (nameStart > 0 && /[a-zA-Z0-9_.]/.test(text[nameStart - 1])) nameStart--;
  const funcName = text.substring(nameStart, nameEnd);

  const found = apiMap.get(funcName);
  if (!found) return null;

  const { api } = found;
  const apiParams = api.params || [];
  const paramStr = apiParams.map(p => {
    const opt = p.required ? '' : '?';
    return `${opt}${p.name}: ${p.type}`;
  }).join(', ');

  return {
    signatures: [{
      label: `${api.name}(${paramStr})`,
      documentation: {
        kind: MarkupKind.Markdown,
        value: api.description || '',
      },
      parameters: apiParams.map(p => ({
        label: `${p.name}: ${p.type}`,
        documentation: {
          kind: MarkupKind.Markdown,
          value: p.description || '',
        },
      })),
    }],
    activeSignature: 0,
    activeParameter: 0,
  };
});

// 启动
documents.listen(connection);
connection.listen();

