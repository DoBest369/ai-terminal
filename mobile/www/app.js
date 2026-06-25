// AI Terminal 移动端 Web 壳（Capacitor）。
// 注意：node ssh2 / node-pty 在 WebView 不可用；移动端 SSH 走 R17 方案（WebSocket 中继 / 原生插件）。
// 本壳负责：统一配色主题 + 应用框架 UI + 占位提示。

(function () {
  'use strict';

  // 主题切换（与原生 / Electron 版一致，持久化到 localStorage）
  var THEME_KEY = 'color_scheme';
  var select = document.getElementById('theme');
  var saved = localStorage.getItem(THEME_KEY) || 'midnight';

  function applyTheme(id) {
    document.documentElement.setAttribute('data-theme', id);
    localStorage.setItem(THEME_KEY, id);
  }
  applyTheme(saved);
  if (select) {
    select.value = saved;
    select.addEventListener('change', function () { applyTheme(select.value); });
  }

  // 示例连接（真实连接列表后续从存储读取）
  var sample = [
    { name: '生产服务器', sub: 'root@192.168.1.10:22', status: 'success' },
    { name: '开发机', sub: 'deploy@dev.example.com:2222', status: 'secondary' },
    { name: '数据库主机', sub: 'admin@db.internal.net:22', status: 'danger' }
  ];
  var statusColor = { success: 'var(--success)', secondary: 'var(--text-secondary)', danger: 'var(--danger)' };

  var host = document.getElementById('conns');
  if (host) {
    sample.forEach(function (c) {
      var row = document.createElement('div');
      row.className = 'conn';
      row.innerHTML =
        '<span class="dot" style="background:' + (statusColor[c.status] || 'var(--text-secondary)') + '"></span>' +
        '<div><div class="name">' + c.name + '</div><div class="sub">' + c.sub + '</div></div>';
      host.appendChild(row);
    });
  }
})();
