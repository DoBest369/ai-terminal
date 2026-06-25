// AI Terminal —— WebSocket → SSH 中继
//
// 浏览器/移动端经 WebSocket 连到本服务，本服务用 ssh2 连到目标主机并双向桥接字节。
// 让无法直接跑 Node ssh2 的环境（移动 WebView / 纯网页）也能用 SSH。
//
// ⚠️ 安全：本服务会接收并使用客户端传来的 SSH 凭据去连接目标主机。
//    仅用于自托管 / 可信网络，务必加 TLS(wss) 与鉴权后再公网部署（见 README）。
//
// 协议（JSON 文本帧）：
//   client → relay: {t:"open",host,port,username,password|privateKey,cols,rows}
//                   {t:"data",d:"<utf8 输入>"}  {t:"resize",cols,rows}
//   relay → client: {t:"status",s:"connecting|connected|error|closed",msg?}
//                   {t:"data",d:"<base64 输出>"}

const http = require('http');
const { WebSocketServer } = require('ws');
const { Client } = require('ssh2');

const PORT = process.env.PORT || 8022;

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('AI Terminal SSH relay. Connect via WebSocket.');
});

const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  let conn = null;
  let stream = null;

  const send = (obj) => {
    if (ws.readyState === ws.OPEN) {
      try { ws.send(JSON.stringify(obj)); } catch (_) {}
    }
  };

  ws.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(raw.toString()); } catch (_) { return; }

    if (msg.t === 'open' && !conn) {
      conn = new Client();

      conn.on('ready', () => {
        send({ t: 'status', s: 'connected' });
        conn.shell({ term: 'xterm-256color', cols: msg.cols || 80, rows: msg.rows || 24 }, (err, s) => {
          if (err) { send({ t: 'status', s: 'error', msg: err.message }); return; }
          stream = s;
          const forward = (d) => send({ t: 'data', d: Buffer.from(d).toString('base64') });
          s.on('data', forward);
          if (s.stderr) s.stderr.on('data', forward);
          s.on('close', () => { send({ t: 'status', s: 'closed' }); try { ws.close(); } catch (_) {} });
        });
      });

      conn.on('keyboard-interactive', (name, instr, lang, prompts, cb) => {
        cb(prompts.length && msg.password ? [msg.password] : []);
      });
      conn.on('error', (e) => send({ t: 'status', s: 'error', msg: e.message }));
      conn.on('close', () => send({ t: 'status', s: 'closed' }));

      const cfg = {
        host: msg.host,
        port: msg.port || 22,
        username: msg.username,
        readyTimeout: 20000,
        keepaliveInterval: 10000,
        tryKeyboard: true,
      };
      if (msg.privateKey) {
        cfg.privateKey = msg.privateKey;
        if (msg.passphrase) cfg.passphrase = msg.passphrase;
      } else {
        cfg.password = msg.password;
      }

      send({ t: 'status', s: 'connecting' });
      try { conn.connect(cfg); } catch (e) { send({ t: 'status', s: 'error', msg: e.message }); }
    } else if (msg.t === 'data' && stream) {
      stream.write(msg.d);
    } else if (msg.t === 'resize' && stream) {
      try { stream.setWindow(msg.rows, msg.cols, 0, 0); } catch (_) {}
    }
  });

  ws.on('close', () => {
    try { if (stream) stream.end(); } catch (_) {}
    try { if (conn) conn.end(); } catch (_) {}
  });
});

server.listen(PORT, () => {
  console.log('AI Terminal SSH relay listening on ws://localhost:' + PORT);
});
