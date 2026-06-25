const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const os = require('os');
const fs = require('fs');
const crypto = require('crypto');

// 品牌：应用名 Termind（智能终端）。dev 模式下 Electron 默认显示 "Electron"，显式覆盖。
app.setName('Termind');
// dev 模式设置 Dock 图标（打包版由 .icns 提供）
if (process.platform === 'darwin' && app.dock) {
  try { app.dock.setIcon(path.join(__dirname, '../../build/icon.png')); } catch {}
}

let mainWindow;
let ptyProcess = null;

// 多 SSH 会话存储
const sshSessions = new Map();

// ===== 主机密钥 TOFU（trust-on-first-use），对齐原生 R20 =====
function knownHostsPath() {
  return path.join(app.getPath('userData'), 'known_hosts.json');
}
function loadKnownHosts() {
  try {
    return JSON.parse(fs.readFileSync(knownHostsPath(), 'utf8')) || {};
  } catch {
    return {};
  }
}
function saveKnownHosts(map) {
  try {
    fs.writeFileSync(knownHostsPath(), JSON.stringify(map, null, 2));
  } catch (e) {
    console.error('保存 known_hosts 失败:', e.message);
  }
}
/** 计算主机公钥指纹（OpenSSH 风格 SHA256:base64 去尾=） */
function hostKeyFingerprint(keyBuf) {
  return 'SHA256:' + crypto.createHash('sha256').update(keyBuf).digest('base64').replace(/=+$/, '');
}

// 动态加载node-pty（需要rebuild）
let pty;
try {
  pty = require('node-pty');
} catch (e) {
  console.error('node-pty加载失败，需要重新编译:', e.message);
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    title: 'Termind',
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
    },
    titleBarStyle: 'hidden',
    trafficLightPosition: { x: 12, y: 12 },
    backgroundColor: '#1a1a2e',
  });

  mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));

  // 开发模式下打开DevTools
  if (process.env.NODE_ENV === 'development') {
    mainWindow.webContents.openDevTools();
  }
}

// 创建本地终端
ipcMain.on('terminal-create', (event) => {
  if (!pty) {
    event.reply('terminal-error', 'node-pty未正确安装，请运行: npm run rebuild');
    return;
  }

  try {
    const shell = process.env.SHELL || '/bin/zsh';

    ptyProcess = pty.spawn(shell, [], {
      name: 'xterm-256color',
      cols: 80,
      rows: 24,
      cwd: os.homedir(),
      env: { ...process.env, TERM: 'xterm-256color' },
    });

    ptyProcess.onData((data) => {
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send('terminal-data', data);
      }
    });

    ptyProcess.onExit(({ exitCode }) => {
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send('terminal-exit', exitCode);
      }
    });

    event.reply('terminal-ready');
  } catch (err) {
    event.reply('terminal-error', err.message);
  }
});

// 接收终端输入
ipcMain.on('terminal-input', (event, data) => {
  if (ptyProcess) {
    ptyProcess.write(data);
  }
});

// 调整终端大小
ipcMain.on('terminal-resize', (event, { cols, rows }) => {
  if (ptyProcess) {
    try {
      ptyProcess.resize(cols, rows);
    } catch (e) {
      // ignore resize errors
    }
  }
});

// AI Agent执行命令
ipcMain.handle('agent-execute', async (event, command) => {
  return new Promise((resolve) => {
    if (!pty) {
      resolve({ success: false, output: 'node-pty未安装' });
      return;
    }

    try {
      const shell = process.env.SHELL || '/bin/zsh';
      let output = '';
      let exitCode = 0;

      const proc = pty.spawn(shell, ['-c', command], {
        name: 'xterm-256color',
        cols: 120,
        rows: 30,
        cwd: os.homedir(),
        env: { ...process.env, TERM: 'xterm-256color' },
      });

      proc.onData((data) => {
        output += data;
        // 实时发送输出到渲染进程
        if (mainWindow && !mainWindow.isDestroyed()) {
          mainWindow.webContents.send('agent-output', data);
        }
      });

      proc.onExit(({ exitCode: code }) => {
        exitCode = code;
        resolve({ success: code === 0, output, exitCode });
      });

      // 超时处理
      setTimeout(() => {
        proc.kill();
        resolve({ success: false, output: output + '\n[命令超时]', exitCode: -1 });
      }, 60000);
    } catch (err) {
      resolve({ success: false, output: err.message, exitCode: -1 });
    }
  });
});

// SSH连接
const { Client } = require('ssh2');

// 选择私钥文件
ipcMain.handle('select-private-key', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    title: '选择私钥文件',
    defaultPath: path.join(os.homedir(), '.ssh'),
    properties: ['openFile'],
    filters: [
      { name: '私钥文件', extensions: ['pem', 'key', ''] },
      { name: '所有文件', extensions: ['*'] }
    ]
  });

  if (result.canceled || result.filePaths.length === 0) {
    return null;
  }
  return result.filePaths[0];
});

// ===== 已知主机（TOFU）管理：列出 / 删除单条 / 全部清除 =====
ipcMain.handle('known-hosts-list', async () => {
  const map = loadKnownHosts();
  return Object.keys(map)
    .sort()
    .map((host) => ({ host, fingerprint: map[host] }));
});

ipcMain.handle('known-hosts-remove', async (event, host) => {
  const map = loadKnownHosts();
  if (host in map) {
    delete map[host];
    saveKnownHosts(map);
  }
  return true;
});

ipcMain.handle('known-hosts-clear', async () => {
  saveKnownHosts({});
  return true;
});

ipcMain.on('ssh-connect', (event, { sessionId, config }) => {
  // 关闭该会话之前的连接
  if (sshSessions.has(sessionId)) {
    const session = sshSessions.get(sessionId);
    if (session.conn) {
      session.conn.end();
    }
    sshSessions.delete(sessionId);
  }

  const conn = new Client();
  // TOFU 主机密钥校验：被 hostVerifier 置为 true 时，连接失败信息标注为密钥变化
  let hostKeyChanged = false;

  // 创建会话记录
  sshSessions.set(sessionId, {
    conn: conn,
    stream: null,
    status: 'connecting',
    config: config
  });

  conn.on('ready', () => {
    const session = sshSessions.get(sessionId);
    if (session) {
      session.status = 'connected';
    }
    event.reply('ssh-status', { sessionId, status: 'connected', message: '连接成功' });

    conn.shell({ term: 'xterm-256color' }, (err, stream) => {
      if (err) {
        event.reply('ssh-status', { sessionId, status: 'error', message: err.message });
        return;
      }

      if (session) {
        session.stream = stream;
      }

      stream.on('data', (data) => {
        event.reply('ssh-data', { sessionId, data: data.toString() });
      });

      stream.stderr.on('data', (data) => {
        event.reply('ssh-data', { sessionId, data: data.toString() });
      });

      stream.on('close', () => {
        event.reply('ssh-status', { sessionId, status: 'disconnected', message: '连接已断开' });
        sshSessions.delete(sessionId);
      });

      stream.on('error', (err) => {
        event.reply('ssh-status', { sessionId, status: 'error', message: `流错误: ${err.message}` });
      });
    });
  });

  conn.on('error', (err) => {
    let errorMsg = err.message;
    // 主机密钥变化（TOFU 校验失败）—— 可能存在中间人攻击
    if (hostKeyChanged) {
      event.reply('ssh-status', {
        sessionId,
        status: 'error',
        message: '连接失败: 主机密钥已变化（可能存在中间人攻击）。如确认服务器更换了密钥，请删除本地 known_hosts.json 中对应主机后重连。',
      });
      sshSessions.delete(sessionId);
      return;
    }
    // 提供更友好的错误提示
    if (err.message.includes('Timed out')) {
      errorMsg = '连接超时，请检查网络或服务器地址';
    } else if (err.message.includes('authentication')) {
      errorMsg = '认证失败，请检查用户名和密码/私钥';
    } else if (err.message.includes('ECONNREFUSED')) {
      errorMsg = '连接被拒绝，请检查服务器地址和端口';
    } else if (err.message.includes('ECONNRESET')) {
      errorMsg = '连接被重置，服务器可能断开了连接';
    } else if (err.message.includes('EHOSTUNREACH')) {
      errorMsg = '无法访问主机，请检查网络连接';
    } else if (err.message.includes('Cannot parse privateKey')) {
      errorMsg = '私钥格式错误，请检查私钥文件';
    }
    event.reply('ssh-status', { sessionId, status: 'error', message: `连接失败: ${errorMsg}` });
    sshSessions.delete(sessionId);
  });

  conn.on('close', () => {
    event.reply('ssh-status', { sessionId, status: 'disconnected', message: '连接已关闭' });
    sshSessions.delete(sessionId);
  });

  conn.on('keyboard-interactive', (name, instructions, lang, prompts, finish) => {
    // 处理键盘交互认证（某些服务器需要）
    if (prompts.length > 0 && config.password) {
      finish([config.password]);
    } else {
      finish([]);
    }
  });

  try {
    // 构建连接配置
    const connectConfig = {
      host: config.host,
      port: config.port || 22,
      username: config.username,
      tryKeyboard: true,
      // TOFU 主机密钥校验：首次记录指纹并放行，之后比对，不一致则拒绝
      hostVerifier: (keyBuf, cb) => {
        try {
          const fp = hostKeyFingerprint(keyBuf);
          const hostID = `${config.host}:${config.port || 22}`;
          const store = loadKnownHosts();
          const known = store[hostID];
          if (!known) {
            store[hostID] = fp;
            saveKnownHosts(store);
            cb(true);
          } else if (known === fp) {
            cb(true);
          } else {
            hostKeyChanged = true;   // 在 error 处理里给出明确提示
            cb(false);
          }
        } catch (e) {
          cb(false);
        }
      },
      readyTimeout: 30000,
      keepaliveInterval: 10000,
      keepaliveCountMax: 3,
      algorithms: {
        kex: [
          'ecdh-sha2-nistp256',
          'ecdh-sha2-nistp384',
          'ecdh-sha2-nistp521',
          'diffie-hellman-group-exchange-sha256',
          'diffie-hellman-group14-sha256',
          'diffie-hellman-group14-sha1',
          'diffie-hellman-group1-sha1',
        ],
        cipher: [
          'aes128-ctr',
          'aes192-ctr',
          'aes256-ctr',
          'aes128-gcm',
          'aes128-gcm@openssh.com',
          'aes256-gcm',
          'aes256-gcm@openssh.com',
        ],
        serverHostKey: [
          'ssh-rsa',
          'ssh-ed25519',
          'ecdsa-sha2-nistp256',
          'ecdsa-sha2-nistp384',
          'ecdsa-sha2-nistp521',
          'rsa-sha2-256',
          'rsa-sha2-512',
        ],
        hmac: [
          'hmac-sha2-256',
          'hmac-sha2-512',
          'hmac-sha1',
        ],
      },
    };

    // 根据认证方式添加认证信息
    if (config.authType === 'privateKey' && config.privateKeyPath) {
      try {
        connectConfig.privateKey = fs.readFileSync(config.privateKeyPath);
        if (config.passphrase) {
          connectConfig.passphrase = config.passphrase;
        }
      } catch (readErr) {
        event.reply('ssh-status', { sessionId, status: 'error', message: `无法读取私钥文件: ${readErr.message}` });
        sshSessions.delete(sessionId);
        return;
      }
    } else {
      connectConfig.password = config.password;
    }

    conn.connect(connectConfig);
  } catch (err) {
    event.reply('ssh-status', { sessionId, status: 'error', message: err.message });
    sshSessions.delete(sessionId);
  }
});

ipcMain.on('ssh-input', (event, { sessionId, data }) => {
  const session = sshSessions.get(sessionId);
  if (session && session.stream) {
    session.stream.write(data);
  }
});

ipcMain.on('ssh-resize', (event, { sessionId, cols, rows }) => {
  const session = sshSessions.get(sessionId);
  if (session && session.stream) {
    session.stream.setWindow(rows, cols, 0, 0);
  }
});

ipcMain.on('ssh-disconnect', (event, sessionId) => {
  const session = sshSessions.get(sessionId);
  if (session && session.conn) {
    session.conn.end();
    sshSessions.delete(sessionId);
  }
});

// SSH执行命令获取系统信息
ipcMain.handle('ssh-exec', async (event, { sessionId, command }) => {
  return new Promise((resolve) => {
    const session = sshSessions.get(sessionId);
    if (!session || !session.conn) {
      resolve({ success: false, output: '' });
      return;
    }

    const timeout = setTimeout(() => {
      resolve({ success: false, output: '命令执行超时' });
    }, 30000);

    session.conn.exec(command, (err, stream) => {
      if (err) {
        clearTimeout(timeout);
        resolve({ success: false, output: err.message });
        return;
      }

      let output = '';
      stream.on('data', (data) => {
        output += data.toString();
      });
      stream.stderr.on('data', (data) => {
        output += data.toString();
      });
      stream.on('close', () => {
        clearTimeout(timeout);
        resolve({ success: true, output: output.trim() });
      });
      stream.on('error', (err) => {
        clearTimeout(timeout);
        resolve({ success: false, output: err.message });
      });
    });
  });
});

// 本地系统信息
ipcMain.handle('local-system-info', async () => {
  const os = require('os');

  const cpus = os.cpus();
  const totalMem = os.totalmem();
  const freeMem = os.freemem();
  const usedMem = totalMem - freeMem;

  // CPU使用率计算
  let totalIdle = 0, totalTick = 0;
  cpus.forEach(cpu => {
    for (let type in cpu.times) {
      totalTick += cpu.times[type];
    }
    totalIdle += cpu.times.idle;
  });
  const cpuUsage = Math.round((1 - totalIdle / totalTick) * 100);

  return {
    hostname: os.hostname(),
    platform: os.platform(),
    arch: os.arch(),
    cpuUsage: cpuUsage,
    cpuCores: cpus.length,
    memTotal: totalMem,
    memUsed: usedMem,
    memPercent: Math.round((usedMem / totalMem) * 100),
    uptime: os.uptime(),
    loadavg: os.loadavg(),
  };
});

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (ptyProcess) {
    ptyProcess.kill();
  }
  // 关闭所有 SSH 连接
  for (const [sessionId, session] of sshSessions) {
    if (session.conn) {
      session.conn.end();
    }
  }
  sshSessions.clear();
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});
