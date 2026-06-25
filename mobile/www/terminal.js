// 移动端 SSH 终端：xterm.js + WebSocket → 连到 relay/（再由 relay 连 SSH）。
(function () {
  'use strict';

  // 终端配色随当前主题（与 index.html 共享 localStorage）
  var THEME_XTERM = {
    midnight: { background: '#1a1a2e', foreground: '#e6e6e6', cursor: '#f39c12' },
    onedark: { background: '#282c34', foreground: '#abb2bf', cursor: '#61afef' },
    dracula: { background: '#282a36', foreground: '#f8f8f2', cursor: '#f1fa8c' },
    solarized: { background: '#002b36', foreground: '#839496', cursor: '#93a1a1' },
    nord: { background: '#2e3440', foreground: '#d8dee9', cursor: '#88c0d0' },
  };
  var themeId = localStorage.getItem('color_scheme') || 'midnight';
  document.documentElement.setAttribute('data-theme', themeId);

  var $ = function (id) { return document.getElementById(id); };
  var statusEl = $('status');
  function setStatus(s) { statusEl.textContent = s; }

  function b64ToBytes(b64) {
    var bin = atob(b64);
    var u = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
    return u;
  }

  var term = null, fit = null, ws = null;

  function connect() {
    var relay = $('relay').value.trim();
    var host = $('host').value.trim();
    var port = parseInt($('port').value, 10) || 22;
    var user = $('user').value.trim();
    var pass = $('pass').value;
    if (!relay || !host || !user) { setStatus('请填写中继地址 / 主机 / 用户名'); return; }

    term = new Terminal({
      theme: THEME_XTERM[themeId] || THEME_XTERM.midnight,
      fontFamily: 'Menlo, Monaco, "Courier New", monospace',
      fontSize: 13, cursorBlink: true, scrollback: 5000,
    });
    fit = new FitAddon.FitAddon();
    term.loadAddon(fit);
    $('form').classList.add('hide');
    $('termWrap').classList.add('show');
    term.open($('term'));
    setTimeout(function () { try { fit.fit(); } catch (e) {} }, 50);

    setStatus('正在连接中继…');
    try { ws = new WebSocket(relay); } catch (e) { setStatus('中继地址无效: ' + e.message); return; }

    ws.onopen = function () {
      ws.send(JSON.stringify({ t: 'open', host: host, port: port, username: user, password: pass, cols: term.cols, rows: term.rows }));
    };
    ws.onmessage = function (ev) {
      var msg; try { msg = JSON.parse(ev.data); } catch (e) { return; }
      if (msg.t === 'data') {
        term.write(b64ToBytes(msg.d));
      } else if (msg.t === 'status') {
        if (msg.s === 'connected') setStatus('已连接 ' + host);
        else if (msg.s === 'connecting') setStatus('连接 SSH 中…');
        else if (msg.s === 'error') { setStatus('错误: ' + (msg.msg || '')); term.writeln('\r\n\x1b[31m✗ ' + (msg.msg || '连接失败') + '\x1b[0m'); }
        else if (msg.s === 'closed') setStatus('连接已关闭');
      }
    };
    ws.onerror = function () { setStatus('无法连接中继（relay/ 是否在运行？）'); };
    ws.onclose = function () { setStatus('连接已断开'); };

    term.onData(function (d) {
      if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify({ t: 'data', d: d }));
    });

    window.addEventListener('resize', function () {
      if (!fit) return;
      try { fit.fit(); } catch (e) {}
      if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify({ t: 'resize', cols: term.cols, rows: term.rows }));
    });
  }

  $('connect').addEventListener('click', connect);
})();
