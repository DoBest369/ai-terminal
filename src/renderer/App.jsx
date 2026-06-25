import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Terminal } from 'xterm';
import { FitAddon } from 'xterm-addon-fit';
import {
  Monitor, Zap, HardDrive, Globe, BarChart3, Clock,
  Lock, Plus, Play, Square, Settings, ChevronLeft,
  ChevronRight, Eye, EyeOff, Edit, Trash2, Check, X,
  Info, Bot, Laptop, Save, Folder, Copy, Files, Cpu
} from 'lucide-react';
import './styles/app.css';

const { ipcRenderer } = window.require('electron');

// 配色方案（与原生版 AppColorScheme 一致）。UI 由 CSS 变量 [data-theme] 驱动，
// 这里仅提供 xterm 终端主题。
const THEMES = {
  midnight: { name: '午夜', xterm: { background: '#1a1a2e', foreground: '#e6e6e6', cursor: '#f39c12', cursorAccent: '#1a1a2e', selectionBackground: 'rgba(233,69,96,0.3)', black: '#282c34', red: '#e06c75', green: '#98c379', yellow: '#e5c07b', blue: '#61afef', magenta: '#c678dd', cyan: '#56b6c2', white: '#abb2bf', brightBlack: '#5c6370', brightRed: '#ff7b86', brightGreen: '#b5e890', brightYellow: '#ffd596', brightBlue: '#7cc5ff', brightMagenta: '#dd9bf0', brightCyan: '#6fd6e2', brightWhite: '#ffffff' } },
  onedark: { name: 'One Dark', xterm: { background: '#282c34', foreground: '#abb2bf', cursor: '#61afef', cursorAccent: '#282c34', selectionBackground: 'rgba(97,175,239,0.3)', black: '#282c34', red: '#e06c75', green: '#98c379', yellow: '#e5c07b', blue: '#61afef', magenta: '#c678dd', cyan: '#56b6c2', white: '#abb2bf', brightBlack: '#5c6370', brightRed: '#e06c75', brightGreen: '#98c379', brightYellow: '#e5c07b', brightBlue: '#61afef', brightMagenta: '#c678dd', brightCyan: '#56b6c2', brightWhite: '#ffffff' } },
  dracula: { name: 'Dracula', xterm: { background: '#282a36', foreground: '#f8f8f2', cursor: '#f1fa8c', cursorAccent: '#282a36', selectionBackground: 'rgba(189,147,249,0.3)', black: '#21222c', red: '#ff5555', green: '#50fa7b', yellow: '#f1fa8c', blue: '#bd93f9', magenta: '#ff79c6', cyan: '#8be9fd', white: '#f8f8f2', brightBlack: '#6272a4', brightRed: '#ff6e6e', brightGreen: '#69ff94', brightYellow: '#ffffa5', brightBlue: '#d6acff', brightMagenta: '#ff92df', brightCyan: '#a4ffff', brightWhite: '#ffffff' } },
  solarized: { name: 'Solarized', xterm: { background: '#002b36', foreground: '#839496', cursor: '#93a1a1', cursorAccent: '#002b36', selectionBackground: 'rgba(38,139,210,0.3)', black: '#073642', red: '#dc322f', green: '#859900', yellow: '#b58900', blue: '#268bd2', magenta: '#d33682', cyan: '#2aa198', white: '#eee8d5', brightBlack: '#586e75', brightRed: '#cb4b16', brightGreen: '#586e75', brightYellow: '#657b83', brightBlue: '#839496', brightMagenta: '#6c71c4', brightCyan: '#93a1a1', brightWhite: '#fdf6e3' } },
  nord: { name: 'Nord', xterm: { background: '#2e3440', foreground: '#d8dee9', cursor: '#88c0d0', cursorAccent: '#2e3440', selectionBackground: 'rgba(136,192,208,0.3)', black: '#3b4252', red: '#bf616a', green: '#a3be8c', yellow: '#ebcb8b', blue: '#81a1c1', magenta: '#b48ead', cyan: '#88c0d0', white: '#e5e9f0', brightBlack: '#4c566a', brightRed: '#bf616a', brightGreen: '#a3be8c', brightYellow: '#ebcb8b', brightBlue: '#81a1c1', brightMagenta: '#b48ead', brightCyan: '#8fbcbb', brightWhite: '#eceff4' } },
};
const getXtermTheme = (id) => (THEMES[id] || THEMES.midnight).xterm;

// 生成唯一ID
const generateId = () => Math.random().toString(36).substr(2, 9);

// 高危命令判定（对齐原生 AIService.dangerousPatterns，子串匹配）。模块级纯函数，AI 自动执行与快捷执行共用。
const DANGEROUS_PATTERNS = ['rm -rf', 'rm -fr', ':(){', 'mkfs', 'dd if=', '> /dev/',
  'chmod -r 000', 'shutdown', 'reboot', 'halt', 'init 0', 'forkbomb'];
const isDangerousCommand = (command) => {
  const lower = (command || '').toLowerCase();
  return DANGEROUS_PATTERNS.some((p) => lower.includes(p));
};

// 格式化字节
const formatBytes = (bytes) => {
  if (!bytes || bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
};

// 格式化运行时间
const formatUptime = (seconds) => {
  if (!seconds) return '-';
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  if (days > 0) return `${days}天${hours}时`;
  if (hours > 0) return `${hours}时${mins}分`;
  return `${mins}分钟`;
};

// 状态栏组件
const StatusBar = ({ info, type, host }) => {
  if (!info) {
    return (
      <div className="status-bar">
        <div className="status-item">
          <span className="status-label">状态</span>
          <span className="status-value">等待连接...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="status-bar">
      <div className="status-item">
        <Monitor className="status-icon" size={16} />
        <span className="status-label">主机</span>
        <span className="status-value">{info.hostname || host}</span>
      </div>
      <div className="status-item">
        <Zap className="status-icon" size={16} />
        <span className="status-label">CPU</span>
        <span className={`status-value ${info.cpuUsage > 80 ? 'warning' : ''}`}>
          {info.cpuUsage?.toFixed(1) || 0}%
        </span>
        <div className="status-progress">
          <div className="progress-bar" style={{ width: `${Math.min(info.cpuUsage || 0, 100)}%` }} />
        </div>
      </div>
      <div className="status-item">
        <HardDrive className="status-icon" size={16} />
        <span className="status-label">内存</span>
        <span className={`status-value ${info.memPercent > 80 ? 'warning' : ''}`}>
          {formatBytes(info.memUsed)} / {formatBytes(info.memTotal)} ({info.memPercent?.toFixed(0)}%)
        </span>
        <div className="status-progress">
          <div className="progress-bar memory" style={{ width: `${Math.min(info.memPercent || 0, 100)}%` }} />
        </div>
      </div>
      {type === 'ssh' && info.netRx !== undefined && (
        <div className="status-item">
          <Globe className="status-icon" size={16} />
          <span className="status-label">网络</span>
          <span className="status-value">
            ↓{formatBytes(info.netRx)} ↑{formatBytes(info.netTx)}
          </span>
        </div>
      )}
      {type === 'local' && info.loadavg && (
        <div className="status-item">
          <BarChart3 className="status-icon" size={16} />
          <span className="status-label">负载</span>
          <span className="status-value">
            {info.loadavg.map(l => l.toFixed(2)).join(' / ')}
          </span>
        </div>
      )}
      <div className="status-item">
        <Clock className="status-icon" size={16} />
        <span className="status-label">运行</span>
        <span className="status-value">
          {type === 'local' ? formatUptime(info.uptime) : info.uptime}
        </span>
      </div>
    </div>
  );
};

// AI Agent系统提示词
const AGENT_SYSTEM_PROMPT = `你是一个终端AI助手，可以帮助用户执行命令和管理系统。

当用户请求执行某些任务时，你应该：
1. 分析用户需求
2. 生成需要执行的命令
3. 使用 [EXECUTE] 标记来执行命令

命令格式：
[EXECUTE]命令内容[/EXECUTE]

例如：
- 用户说"列出当前目录文件"，你应该回复：
  好的，我来列出当前目录的文件：
  [EXECUTE]ls -la[/EXECUTE]

- 用户说"查看系统内存"，你应该回复：
  我来查看系统内存使用情况：
  [EXECUTE]free -h[/EXECUTE]
  或Mac上：
  [EXECUTE]vm_stat[/EXECUTE]

注意：
- 危险命令（如rm -rf /）需要先警告用户
- 一次可以执行多个命令
- 执行完命令后分析结果并给出建议`;

function App() {
  const [activeTab, setActiveTab] = useState('local');
  const [activeSessionId, setActiveSessionId] = useState(null);

  // SSH 会话管理
  const [sshSessions, setSshSessions] = useState([]);
  const sshTerminals = useRef(new Map()); // sessionId -> { term, fitAddon, containerRef }

  // 保存的连接配置 - 作为会话模板
  const [savedConnections, setSavedConnections] = useState(() => {
    const saved = localStorage.getItem('ssh_saved_connections');
    return saved ? JSON.parse(saved) : [];
  });

  // 右键菜单
  const [contextMenu, setContextMenu] = useState(null);

  // 侧边栏折叠状态
  const [sidebarCollapsed, setSidebarCollapsed] = useState(() => {
    const saved = localStorage.getItem('sidebar_collapsed');
    return saved ? JSON.parse(saved) : false;
  });

  // Toast提示
  const [toast, setToast] = useState(null);

  // 当前编辑的连接配置
  const [editingConfig, setEditingConfig] = useState({
    name: '',
    host: '',
    port: '22',
    username: '',
    authType: 'password',
    password: '',
    privateKeyPath: '',
    passphrase: '',
    savePassword: false
  });

  const [showPasswordMap, setShowPasswordMap] = useState({});
  const [showSaveConnectionModal, setShowSaveConnectionModal] = useState(false);
  const [showConnectionDrawer, setShowConnectionDrawer] = useState(false);
  const [drawerConnectionConfig, setDrawerConnectionConfig] = useState({
    name: '',
    group: '',
    note: '',
    host: '',
    port: '22',
    username: '',
    authType: 'password',
    password: '',
    privateKeyPath: '',
    passphrase: ''
  });

  const [aiInput, setAiInput] = useState('');
  const [aiMessages, setAiMessages] = useState([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [apiKey, setApiKey] = useState(localStorage.getItem('openai_api_key') || '');
  const [showSettings, setShowSettings] = useState(false);
  const [knownHosts, setKnownHosts] = useState([]);
  const [terminalError, setTerminalError] = useState('');
  const [localSystemInfo, setLocalSystemInfo] = useState(null);
  const [theme, setTheme] = useState(() => localStorage.getItem('color_scheme') || 'midnight');

  // 应用主题：设置 data-theme（驱动 CSS 变量）、持久化、并热更新所有终端的 xterm 主题
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('color_scheme', theme);
    const xterm = getXtermTheme(theme);
    if (termInstance.current) termInstance.current.options.theme = xterm;
    sshTerminals.current.forEach((t) => { if (t.term) t.term.options.theme = xterm; });
  }, [theme]);

  const terminalRef = useRef(null);
  const termInstance = useRef(null);
  const fitAddon = useRef(null);
  const messagesEndRef = useRef(null);
  const sshContainerRef = useRef(null);

  // 滚动到最新消息
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  // 获取连接状态
  const getConnectionStatus = useCallback((connectionId) => {
    const session = sshSessions.find(s => s.connectionId === connectionId);
    if (!session) return 'disconnected';
    return session.status;
  }, [sshSessions]);

  useEffect(() => {
    scrollToBottom();
  }, [aiMessages]);

  // 初始化本地终端 - 组件挂载时就初始化
  useEffect(() => {
    if (terminalRef.current && !termInstance.current) {
      const term = new Terminal({
        theme: getXtermTheme(localStorage.getItem('color_scheme') || 'midnight'),
        fontSize: 14,
        fontFamily: 'Menlo, Monaco, "Courier New", monospace',
        cursorBlink: true,
        scrollback: 10000,
      });

      const fit = new FitAddon();
      fitAddon.current = fit;
      term.loadAddon(fit);
      term.open(terminalRef.current);

      setTimeout(() => fit.fit(), 100);

      termInstance.current = term;

      // 监听终端错误
      ipcRenderer.on('terminal-error', (event, error) => {
        setTerminalError(error);
        term.writeln(`\r\n\x1b[31m错误: ${error}\x1b[0m\r\n`);
      });

      ipcRenderer.on('terminal-ready', () => {
        setTerminalError('');
      });

      // 创建PTY进程
      ipcRenderer.send('terminal-create');

      // 接收终端输出
      ipcRenderer.on('terminal-data', (event, data) => {
        term.write(data);
      });

      // 发送终端输入
      term.onData((data) => {
        ipcRenderer.send('terminal-input', data);
      });

      // 处理窗口大小变化
      const handleResize = () => {
        if (fitAddon.current && termInstance.current) {
          fitAddon.current.fit();
          ipcRenderer.send('terminal-resize', {
            cols: termInstance.current.cols,
            rows: termInstance.current.rows,
          });
        }
      };

      window.addEventListener('resize', handleResize);
      setTimeout(handleResize, 200);

      return () => {
        window.removeEventListener('resize', handleResize);
      };
    }
  }, []);

  // SSH 数据和状态监听
  useEffect(() => {
    const handleSshData = (event, { sessionId, data }) => {
      const termData = sshTerminals.current.get(sessionId);
      if (termData && termData.term) {
        termData.term.write(data);
      }
    };

    const handleSshStatus = (event, { sessionId, status, message }) => {
      const termData = sshTerminals.current.get(sessionId);

      setSshSessions(prev => prev.map(session => {
        if (session.id === sessionId) {
          if (termData && termData.term) {
            if (status === 'connected') {
              termData.term.writeln('\x1b[32m✓ 连接成功\x1b[0m');
              termData.term.writeln('');
              // 不清空终端，让服务器的欢迎信息自然显示
            } else if (status === 'error') {
              termData.term.writeln('');
              termData.term.writeln(`\x1b[31m✗ 连接失败: ${message}\x1b[0m`);
              termData.term.writeln('');
              termData.term.writeln('\x1b[33mPress Enter to retry...\x1b[0m');
            } else if (status === 'disconnected') {
              termData.term.writeln('');
              termData.term.writeln(`\x1b[33m${message}\x1b[0m`);
              termData.term.writeln('');
            }
          }
          return { ...session, status, statusMessage: message };
        }
        return session;
      }));
    };

    ipcRenderer.on('ssh-data', handleSshData);
    ipcRenderer.on('ssh-status', handleSshStatus);

    return () => {
      ipcRenderer.removeListener('ssh-data', handleSshData);
      ipcRenderer.removeListener('ssh-status', handleSshStatus);
    };
  }, []);

  // 创建新的 SSH 会话终端
  const createSshTerminal = useCallback((sessionId, containerElement) => {
    if (!containerElement || sshTerminals.current.has(sessionId)) return;

    const term = new Terminal({
      theme: getXtermTheme(localStorage.getItem('color_scheme') || 'midnight'),
      fontSize: 14,
      fontFamily: 'Menlo, Monaco, "Courier New", monospace',
      cursorBlink: true,
      scrollback: 10000,
    });

    const fit = new FitAddon();
    term.loadAddon(fit);
    term.open(containerElement);
    setTimeout(() => fit.fit(), 100);

    term.writeln('\x1b[36m═══════════════════════════════════════════════════════════\x1b[0m');
    term.writeln('\x1b[36m                    SSH 终端已就绪\x1b[0m');
    term.writeln('\x1b[36m═══════════════════════════════════════════════════════════\x1b[0m');
    term.writeln('');
    term.writeln('\x1b[90m请配置连接信息后点击"连接"按钮，或点击侧边栏的\x1b[0m');
    term.writeln('\x1b[90m连接项右侧的 ▶ 按钮快速连接\x1b[0m');
    term.writeln('');

    term.onData((data) => {
      ipcRenderer.send('ssh-input', { sessionId, data });
    });

    sshTerminals.current.set(sessionId, { term, fitAddon: fit });

    return { term, fitAddon: fit };
  }, []);

  // 获取或创建会话（基于连接ID）
  const getOrCreateSession = useCallback((connectionId) => {
    const connection = savedConnections.find(c => c.id === connectionId);
    if (!connection) return null;

    let session = sshSessions.find(s => s.connectionId === connectionId);
    if (!session) {
      const newSessionId = generateId();
      session = {
        id: newSessionId,
        connectionId: connectionId,
        name: connection.name,
        config: {
          host: connection.host,
          port: connection.port,
          username: connection.username,
          authType: connection.authType,
          password: connection.password,
          privateKeyPath: connection.privateKeyPath,
          passphrase: connection.passphrase || ''
        },
        status: 'disconnected',
        statusMessage: '',
        systemInfo: null
      };
      setSshSessions(prev => [...prev, session]);
      return session;
    }
    return session;
  }, [savedConnections, sshSessions]);

  // 关闭会话（断开但不删除保存的连接）
  const closeSession = useCallback((sessionId) => {
    // 断开连接
    ipcRenderer.send('ssh-disconnect', sessionId);

    // 清理终端
    const termData = sshTerminals.current.get(sessionId);
    if (termData && termData.term) {
      termData.term.dispose();
    }
    sshTerminals.current.delete(sessionId);

    // 移除会话
    setSshSessions(prev => {
      const newSessions = prev.filter(s => s.id !== sessionId);
      if (activeSessionId === sessionId) {
        if (newSessions.length > 0) {
          setActiveSessionId(newSessions[0].id);
        } else {
          setActiveSessionId(null);
        }
      }
      return newSessions;
    });
  }, [activeSessionId]);

  // 删除保存的连接（会同时关闭相关会话）
  const deleteConnection = useCallback((connectionId) => {
    // 找到并关闭相关会话
    const session = sshSessions.find(s => s.connectionId === connectionId);
    if (session) {
      closeSession(session.id);
    }

    // 删除保存的连接
    const newSavedConnections = savedConnections.filter(c => c.id !== connectionId);
    setSavedConnections(newSavedConnections);
    localStorage.setItem('ssh_saved_connections', JSON.stringify(newSavedConnections));
  }, [savedConnections, sshSessions, closeSession]);

  // 更新会话配置
  const updateSessionConfig = useCallback((sessionId, updates) => {
    setSshSessions(prev => prev.map(session =>
      session.id === sessionId
        ? { ...session, config: { ...session.config, ...updates } }
        : session
    ));
  }, []);

  // SSH 连接
  const handleSSHConnect = useCallback((sessionIdOrSession) => {
    let session;
    if (typeof sessionIdOrSession === 'string') {
      session = sshSessions.find(s => s.id === sessionIdOrSession);
      if (!session) {
        console.error('Session not found:', sessionIdOrSession);
        return;
      }
    } else {
      session = sessionIdOrSession;
    }

    const { config } = session;

    // 验证配置
    if (!config || !config.host || !config.username) {
      console.error('Invalid config:', config);
      setSshSessions(prev => prev.map(s =>
        s.id === session.id
          ? { ...s, status: 'error', statusMessage: '配置无效：请填写主机地址和用户名' }
          : s
      ));
      return;
    }

    // 验证认证信息
    if (config.authType === 'password' && !config.password) {
      console.error('Password is required but not provided');
      setSshSessions(prev => prev.map(s =>
        s.id === session.id
          ? { ...s, status: 'error', statusMessage: '密码认证需要提供密码' }
          : s
      ));
      return;
    }

    if (config.authType === 'privateKey' && !config.privateKeyPath) {
      console.error('Private key path is required but not provided');
      setSshSessions(prev => prev.map(s =>
        s.id === session.id
          ? { ...s, status: 'error', statusMessage: '私钥认证需要提供私钥文件路径' }
          : s
      ));
      return;
    }

    console.log('Connecting to SSH with config:', {
      sessionId: session.id,
      host: config.host,
      port: config.port,
      username: config.username,
      authType: config.authType
    });

    // 在终端中显示连接信息
    const termData = sshTerminals.current.get(session.id);
    if (termData && termData.term) {
      termData.term.clear();
      termData.term.writeln('\x1b[36m正在连接中...\x1b[0m');
      termData.term.writeln(`\x1b[36m正在连接到 ${config.username}@${config.host}:${config.port}\x1b[0m`);
      termData.term.writeln(`\x1b[90m认证方式: ${config.authType === 'password' ? '密码认证' : '私钥认证'}\x1b[0m`);
      termData.term.writeln('');
    }

    setSshSessions(prev => prev.map(s =>
      s.id === session.id
        ? { ...s, status: 'connecting', statusMessage: '正在连接...' }
        : s
    ));

    ipcRenderer.send('ssh-connect', {
      sessionId: session.id,
      config: {
        host: config.host,
        port: parseInt(config.port) || 22,
        username: config.username,
        authType: config.authType,
        password: config.password || '',
        privateKeyPath: config.privateKeyPath || '',
        passphrase: config.passphrase || ''
      }
    });
  }, [sshSessions]);

  // SSH 断开
  const handleSSHDisconnect = useCallback((sessionId) => {
    ipcRenderer.send('ssh-disconnect', sessionId);
  }, []);

  // 切换侧边栏折叠状态
  const toggleSidebar = useCallback(() => {
    setSidebarCollapsed(prev => {
      const newState = !prev;
      localStorage.setItem('sidebar_collapsed', JSON.stringify(newState));
      return newState;
    });
  }, []);

  // 显示Toast提示
  const showToast = useCallback((message, type = 'success') => {
    setToast({ message, type });
    setTimeout(() => {
      setToast(null);
    }, 3000);
  }, []);

  // 保存连接配置
  const saveConnection = useCallback(() => {
    const session = sshSessions.find(s => s.id === activeSessionId);
    if (!session) return;

    const newConnection = {
      id: generateId(),
      name: editingConfig.name || `${session.config.host}`,
      host: session.config.host,
      port: session.config.port,
      username: session.config.username,
      authType: session.config.authType,
      password: editingConfig.savePassword ? session.config.password : '',
      privateKeyPath: session.config.privateKeyPath,
      passphrase: ''
    };

    const newSavedConnections = [...savedConnections, newConnection];
    setSavedConnections(newSavedConnections);
    localStorage.setItem('ssh_saved_connections', JSON.stringify(newSavedConnections));
    setShowSaveConnectionModal(false);
    setEditingConfig({ ...editingConfig, name: '', savePassword: false });
  }, [activeSessionId, sshSessions, savedConnections, editingConfig]);

  // 连接到保存的连接
  const connectToSavedConnection = useCallback((connectionId) => {
    const connection = savedConnections.find(c => c.id === connectionId);
    if (!connection) {
      console.error('Connection not found:', connectionId);
      return;
    }

    let session = sshSessions.find(s => s.connectionId === connectionId);

    if (!session) {
      // 创建新会话
      const newSessionId = generateId();
      const newSession = {
        id: newSessionId,
        connectionId: connectionId,
        name: connection.name,
        config: {
          host: connection.host,
          port: connection.port,
          username: connection.username,
          authType: connection.authType,
          password: connection.password,
          privateKeyPath: connection.privateKeyPath,
          passphrase: connection.passphrase || ''
        },
        status: 'disconnected',
        statusMessage: '',
        systemInfo: null
      };

      setSshSessions(prev => [...prev, newSession]);
      setActiveSessionId(newSessionId);
      setActiveTab('ssh');

      // 延迟确保会话创建完成 - 增加到500ms
      setTimeout(() => {
        handleSSHConnect(newSessionId);
      }, 500);
    } else {
      // 如果会话已存在但在连接中，不要重复连接
      if (session.status === 'connecting') {
        setActiveSessionId(session.id);
        setActiveTab('ssh');
        return;
      }

      // 如果已连接，先断开再重连
      if (session.status === 'connected') {
        ipcRenderer.send('ssh-disconnect', session.id);
        // 等待断开完成 - 增加到1000ms
        setTimeout(() => {
          setActiveSessionId(session.id);
          setActiveTab('ssh');
          handleSSHConnect(session.id);
        }, 1000);
      } else {
        setActiveSessionId(session.id);
        setActiveTab('ssh');
        // 即使是断开状态也加一点延迟
        setTimeout(() => {
          handleSSHConnect(session.id);
        }, 300);
      }
    }
  }, [savedConnections, sshSessions, handleSSHConnect]);

  // 切换密码显示/隐藏
  const togglePasswordVisibility = useCallback((fieldId) => {
    setShowPasswordMap(prev => ({ ...prev, [fieldId]: !prev[fieldId] }));
  }, []);

  // 右键菜单处理
  const handleContextMenu = useCallback((e, connectionId) => {
    e.preventDefault();
    const connection = savedConnections.find(c => c.id === connectionId);
    const session = sshSessions.find(s => s.connectionId === connectionId);

    setContextMenu({
      x: e.clientX,
      y: e.clientY,
      connectionId,
      connection,
      session
    });
  }, [savedConnections, sshSessions]);

  // 关闭右键菜单
  const closeContextMenu = useCallback(() => {
    setContextMenu(null);
  }, []);

  // 编辑连接配置
  const editConnection = useCallback((connectionId) => {
    const connection = savedConnections.find(c => c.id === connectionId);
    if (connection) {
      setDrawerConnectionConfig({
        connectionId: connectionId,
        sessionId: null,
        name: connection.name,
        host: connection.host,
        port: connection.port,
        username: connection.username,
        authType: connection.authType,
        password: connection.password,
        privateKeyPath: connection.privateKeyPath,
        passphrase: connection.passphrase || ''
      });
      setShowConnectionDrawer(true);
    }
    closeContextMenu();
  }, [savedConnections, closeContextMenu]);

  // 打开连接抽屉 - 为新建会话或编辑现有会话
  const openConnectionDrawer = useCallback((connectionId = null) => {
    if (connectionId) {
      const connection = savedConnections.find(c => c.id === connectionId);
      if (connection) {
        setDrawerConnectionConfig({
          connectionId: connectionId,
          sessionId: null,
          name: connection.name,
          group: connection.group || '',
          note: connection.note || '',
          host: connection.host,
          port: connection.port,
          username: connection.username,
          authType: connection.authType,
          password: connection.password,
          privateKeyPath: connection.privateKeyPath,
          passphrase: connection.passphrase || ''
        });
      }
    } else {
      // 新建连接
      setDrawerConnectionConfig({
        connectionId: null,
        sessionId: null,
        name: '',
        group: '',
        note: '',
        host: '',
        port: '22',
        username: '',
        authType: 'password',
        password: '',
        privateKeyPath: '',
        passphrase: ''
      });
    }
    setShowConnectionDrawer(true);
    setActiveTab('ssh');
  }, [savedConnections]);

  // 从抽屉直接连接
  const handleDrawerConnect = useCallback(() => {
    if (!drawerConnectionConfig.host || !drawerConnectionConfig.username) {
      alert('请填写主机地址和用户名');
      return;
    }

    const { connectionId, sessionId: _, ...config } = drawerConnectionConfig;

    if (connectionId) {
      // 编辑现有连接
      const updatedConnection = {
        id: connectionId,
        name: config.name || `${config.username}@${config.host}`,
        group: config.group || '',
        host: config.host,
        port: config.port,
        username: config.username,
        authType: config.authType,
        password: config.password,
        privateKeyPath: config.privateKeyPath,
        passphrase: config.passphrase
      };

      // 先更新保存的连接
      const newSavedConnections = savedConnections.map(c =>
        c.id === connectionId ? updatedConnection : c
      );
      setSavedConnections(newSavedConnections);
      localStorage.setItem('ssh_saved_connections', JSON.stringify(newSavedConnections));

      // 查找现有会话
      let session = sshSessions.find(s => s.connectionId === connectionId);

      if (session) {
        // 如果已连接，先断开
        if (session.status === 'connected' || session.status === 'connecting') {
          ipcRenderer.send('ssh-disconnect', session.id);
        }

        // 更新会话配置
        setSshSessions(prev => prev.map(s =>
          s.connectionId === connectionId
            ? {
                ...s,
                name: updatedConnection.name,
                config: {
                  host: config.host,
                  port: config.port,
                  username: config.username,
                  authType: config.authType,
                  password: config.password,
                  privateKeyPath: config.privateKeyPath,
                  passphrase: config.passphrase
                },
                status: 'disconnected',
                statusMessage: ''
              }
            : s
        ));

        setActiveSessionId(session.id);
        setActiveTab('ssh');

        // 延迟一下确保状态更新完成 - 增加到500ms
        setTimeout(() => {
          handleSSHConnect(session.id);
        }, 500);
      } else {
        // 创建新会话
        const newSessionId = generateId();
        const newSession = {
          id: newSessionId,
          connectionId: connectionId,
          name: updatedConnection.name,
          config: {
            host: config.host,
            port: config.port,
            username: config.username,
            authType: config.authType,
            password: config.password,
            privateKeyPath: config.privateKeyPath,
            passphrase: config.passphrase
          },
          status: 'disconnected',
          statusMessage: '',
          systemInfo: null
        };

        setSshSessions(prev => [...prev, newSession]);
        setActiveSessionId(newSessionId);
        setActiveTab('ssh');

        setTimeout(() => {
          handleSSHConnect(newSessionId);
        }, 200);
      }
    } else {
      // 创建新连接
      const newConnectionId = generateId();
      const newConnection = {
        id: newConnectionId,
        name: config.name || `${config.username}@${config.host}`,
        host: config.host,
        port: config.port,
        username: config.username,
        authType: config.authType,
        password: config.password,
        privateKeyPath: config.privateKeyPath,
        passphrase: config.passphrase
      };

      const newSavedConnections = [...savedConnections, newConnection];
      setSavedConnections(newSavedConnections);
      localStorage.setItem('ssh_saved_connections', JSON.stringify(newSavedConnections));

      // 创建新会话
      const newSessionId = generateId();
      const newSession = {
        id: newSessionId,
        connectionId: newConnectionId,
        name: newConnection.name,
        config: {
          host: config.host,
          port: config.port,
          username: config.username,
          authType: config.authType,
          password: config.password,
          privateKeyPath: config.privateKeyPath,
          passphrase: config.passphrase
        },
        status: 'disconnected',
        statusMessage: '',
        systemInfo: null
      };

      setSshSessions(prev => [...prev, newSession]);
      setActiveSessionId(newSessionId);
      setActiveTab('ssh');

      setTimeout(() => {
        handleSSHConnect(newSessionId);
      }, 200);
    }

    setShowConnectionDrawer(false);
  }, [drawerConnectionConfig, savedConnections, sshSessions, handleSSHConnect]);

  // 从抽屉保存连接配置（统一的保存操作）
  const handleDrawerSave = useCallback(() => {
    const { connectionId, sessionId, ...config } = drawerConnectionConfig;
    // 去首尾空白，避免「生产 」与「生产」分裂、字段带多余空格
    const host = (config.host || '').trim();
    const username = (config.username || '').trim();
    const name = (config.name || '').trim() || `${username}@${host}`;
    const group = (config.group || '').trim();
    const note = (config.note || '').trim();

    if (!host || !username) {
      showToast('请填写主机地址和用户名', 'error');
      return;
    }

    if (connectionId) {
      // 更新现有连接
      const updatedConnection = {
        id: connectionId,
        name,
        group,
        note,
        host,
        port: config.port,
        username,
        authType: config.authType,
        password: config.password,
        privateKeyPath: config.privateKeyPath,
        passphrase: config.passphrase
      };

      const newSavedConnections = savedConnections.map(c =>
        c.id === connectionId ? updatedConnection : c
      );
      setSavedConnections(newSavedConnections);
      localStorage.setItem('ssh_saved_connections', JSON.stringify(newSavedConnections));

      // 更新现有会话配置（如果存在）
      setSshSessions(prev => prev.map(s =>
        s.connectionId === connectionId
          ? { ...s, name: updatedConnection.name, config: { ...config, host, username } }
          : s
      ));

      showToast('连接配置已更新', 'success');
    } else {
      // 新建连接
      const newConnection = {
        id: generateId(),
        name,
        group,
        note,
        host,
        port: config.port,
        username,
        authType: config.authType,
        password: config.password,
        privateKeyPath: config.privateKeyPath,
        passphrase: config.passphrase
      };

      const newSavedConnections = [...savedConnections, newConnection];
      setSavedConnections(newSavedConnections);
      localStorage.setItem('ssh_saved_connections', JSON.stringify(newSavedConnections));

      showToast('连接配置已保存', 'success');
    }

    setShowConnectionDrawer(false);
  }, [drawerConnectionConfig, savedConnections, showToast]);

  // 从抽屉保存并连接
  const handleDrawerSaveAndConnect = useCallback(() => {
    handleDrawerSave();
    handleDrawerConnect();
  }, [handleDrawerSave, handleDrawerConnect]);

  // 从抽屉选择私钥
  const handleDrawerSelectPrivateKey = useCallback(async () => {
    const filePath = await ipcRenderer.invoke('select-private-key');
    if (filePath) {
      setDrawerConnectionConfig(prev => ({ ...prev, privateKeyPath: filePath }));
    }
  }, []);

  // 切换tab时重新调整终端大小
  useEffect(() => {
    setTimeout(() => {
      if (activeTab === 'local' && fitAddon.current && termInstance.current) {
        fitAddon.current.fit();
        ipcRenderer.send('terminal-resize', {
          cols: termInstance.current.cols,
          rows: termInstance.current.rows,
        });
      } else if (activeTab === 'ssh' && activeSessionId) {
        const termData = sshTerminals.current.get(activeSessionId);
        if (termData && termData.fitAddon && termData.term) {
          termData.fitAddon.fit();
          ipcRenderer.send('ssh-resize', {
            sessionId: activeSessionId,
            cols: termData.term.cols,
            rows: termData.term.rows,
          });
        }
      }
    }, 50);
  }, [activeTab, activeSessionId]);

  // 获取本地系统信息
  useEffect(() => {
    const fetchLocalInfo = async () => {
      try {
        const info = await ipcRenderer.invoke('local-system-info');
        setLocalSystemInfo(info);
      } catch (e) {
        console.error('获取本地系统信息失败:', e);
      }
    };

    fetchLocalInfo();
    const interval = setInterval(fetchLocalInfo, 3000);
    return () => clearInterval(interval);
  }, []);

  // 获取SSH服务器系统信息
  useEffect(() => {
    const intervals = new Map();

    sshSessions.forEach(session => {
      if (session.status === 'connected' && !intervals.has(session.id)) {
        const fetchSSHInfo = async () => {
          try {
            const [cpuResult, memResult, netResult, uptimeResult, hostnameResult] = await Promise.all([
              ipcRenderer.invoke('ssh-exec', { sessionId: session.id, command: "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1" }),
              ipcRenderer.invoke('ssh-exec', { sessionId: session.id, command: "free -b | awk 'NR==2{printf \"%d %d %.1f\", $2, $3, $3*100/$2}'" }),
              ipcRenderer.invoke('ssh-exec', { sessionId: session.id, command: "cat /proc/net/dev | awk 'NR>2{rx+=$2;tx+=$10}END{print rx,tx}'" }),
              ipcRenderer.invoke('ssh-exec', { sessionId: session.id, command: "uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}'" }),
              ipcRenderer.invoke('ssh-exec', { sessionId: session.id, command: "hostname" }),
            ]);

            const memParts = memResult.output.split(' ');
            const netParts = netResult.output.split(' ');

            setSshSessions(prev => prev.map(s =>
              s.id === session.id
                ? {
                    ...s,
                    systemInfo: {
                      hostname: hostnameResult.output || session.config.host,
                      cpuUsage: parseFloat(cpuResult.output) || 0,
                      memTotal: parseInt(memParts[0]) || 0,
                      memUsed: parseInt(memParts[1]) || 0,
                      memPercent: parseFloat(memParts[2]) || 0,
                      netRx: parseInt(netParts[0]) || 0,
                      netTx: parseInt(netParts[1]) || 0,
                      uptime: uptimeResult.output || '-',
                    }
                  }
                : s
            ));
          } catch (e) {
            console.error('获取SSH系统信息失败:', e);
          }
        };

        fetchSSHInfo();
        const interval = setInterval(fetchSSHInfo, 3000);
        intervals.set(session.id, interval);
      }
    });

    return () => {
      intervals.forEach(interval => clearInterval(interval));
    };
  }, [sshSessions.map(s => `${s.id}-${s.status}`).join(',')]);

  // 监听点击关闭右键菜单
  useEffect(() => {
    if (contextMenu) {
      document.addEventListener('click', closeContextMenu);
      return () => {
        document.removeEventListener('click', closeContextMenu);
      };
    }
  }, [contextMenu, closeContextMenu]);

  // SSH连接 - 已移至上方的 handleSSHConnect

  // 执行命令（AI Agent用）
  const executeCommand = useCallback(async (command) => {
    return await ipcRenderer.invoke('agent-execute', command);
  }, []);

  // 解析AI响应中的命令（高危命令执行前二次确认，只拦 AI 自动执行路径）
  const parseAndExecuteCommands = useCallback(async (text) => {
    const regex = /\[EXECUTE\]([\s\S]*?)\[\/EXECUTE\]/g;
    let match;
    const results = [];

    while ((match = regex.exec(text)) !== null) {
      const command = match[1].trim();
      if (command) {
        if (isDangerousCommand(command) &&
            !confirm(`⚠️ 检测到高危命令：\n${command}\n\n确定要执行吗？`)) {
          results.push({ command, success: false, output: '已跳过高危命令（用户取消）' });
          continue;
        }
        const result = await executeCommand(command);
        results.push({ command, ...result });
      }
    }

    return results;
  }, [executeCommand]);

  // AI对话处理
  const handleAISend = async () => {
    if (!aiInput.trim() || isProcessing) return;

    const userMessage = { role: 'user', content: aiInput };
    setAiMessages((prev) => [...prev, userMessage]);
    setAiInput('');
    setIsProcessing(true);

    try {
      // 使用OpenAI API
      if (!apiKey) {
        setAiMessages((prev) => [
          ...prev,
          {
            role: 'assistant',
            content: '请先在设置中配置API Key。点击右上角的设置按钮。',
          },
        ]);
        setIsProcessing(false);
        return;
      }

      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: 'gpt-4',
          messages: [
            { role: 'system', content: AGENT_SYSTEM_PROMPT },
            ...aiMessages.filter((m) => m.role !== 'system' && m.role !== 'result'),
            userMessage,
          ],
          temperature: 0.7,
        }),
      });

      if (!response.ok) {
        throw new Error(`API错误: ${response.status}`);
      }

      const data = await response.json();
      const aiContent = data.choices[0].message.content;

      setAiMessages((prev) => [...prev, { role: 'assistant', content: aiContent }]);

      // 解析并执行命令
      const commandResults = await parseAndExecuteCommands(aiContent);
      if (commandResults.length > 0) {
        for (const result of commandResults) {
          setAiMessages((prev) => [
            ...prev,
            {
              role: 'result',
              command: result.command,
              output: result.output,
              success: result.success,
            },
          ]);
        }
      }
    } catch (error) {
      setAiMessages((prev) => [
        ...prev,
        { role: 'assistant', content: `错误: ${error.message}` },
      ]);
    } finally {
      setIsProcessing(false);
    }
  };

  // 保存API Key
  const saveApiKey = () => {
    localStorage.setItem('openai_api_key', apiKey);
    setShowSettings(false);
  };

  // 单条连接 → 跨端可移植对象（默认不含密码）
  const connToPortable = (c, includeSecrets = false) => ({
    name: c.name || '',
    host: c.host || '',
    port: Number(c.port) || 22,
    username: c.username || '',
    authType: c.authType || 'password',
    ...((c.group || '').trim() ? { group: (c.group || '').trim() } : {}),
    ...((c.note || '').trim() ? { note: (c.note || '').trim() } : {}),
    ...(includeSecrets && c.password ? { password: c.password } : {}),
    ...(includeSecrets && c.passphrase ? { passphrase: c.passphrase } : {}),
  });

  // 复制单条连接配置到剪贴板（不含密码，对齐原生 N3）
  const copyConnectionConfig = (conn) => {
    if (!conn) return;
    const data = {
      format: 'ai-terminal-connections',
      version: 1,
      connections: [connToPortable(conn, false)],
    };
    const text = JSON.stringify(data, null, 2);
    Promise.resolve(navigator.clipboard?.writeText(text)).catch(() => {});
    showToast('已复制连接配置（不含密码）', 'success');
  };

  // 克隆连接（复制一份，换新 id、name 加「副本」，对齐原生 cloneConnection）
  const cloneConnection = (conn) => {
    if (!conn) return;
    const cloned = {
      ...conn,
      id: generateId(),
      name: (conn.name || `${conn.username}@${conn.host}`) + ' 副本',
    };
    const merged = [...savedConnections, cloned];
    setSavedConnections(merged);
    localStorage.setItem('ssh_saved_connections', JSON.stringify(merged));
    showToast('已克隆连接', 'success');
  };

  // 连接导出（跨端通用 JSON 格式，默认不含密码）
  const exportConnections = (includeSecrets = false) => {
    const data = {
      format: 'ai-terminal-connections',
      version: 1,
      connections: savedConnections.map((c) => connToPortable(c, includeSecrets)),
    };
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'ai-terminal-connections.json';
    a.click();
    URL.revokeObjectURL(url);
  };

  // 连接导入（合并，按 host+username+port 去重）
  const importConnections = (event) => {
    const file = event.target.files && event.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const data = JSON.parse(reader.result);
        if (data.format !== 'ai-terminal-connections') { showToast('文件格式无效'); return; }
        const incoming = (data.connections || []).map((c) => ({
          id: generateId(),
          name: c.name || '',
          group: c.group || '',
          note: c.note || '',
          host: c.host || '',
          port: String(c.port || 22),
          username: c.username || '',
          authType: c.authType || 'password',
          password: c.password || '',
          privateKeyPath: '',
          passphrase: c.passphrase || '',
        }));
        const merged = [...savedConnections];
        let added = 0;
        incoming.forEach((c) => {
          const dup = merged.some((e) => e.host === c.host && e.username === c.username && String(e.port) === String(c.port));
          if (!dup) { merged.push(c); added += 1; }
        });
        setSavedConnections(merged);
        localStorage.setItem('ssh_saved_connections', JSON.stringify(merged));
        showToast(added > 0 ? `已导入 ${added} 个连接` : '无新连接');
      } catch (err) {
        showToast('导入失败：' + err.message);
      }
      event.target.value = '';
    };
    reader.readAsText(file);
  };

  // 已知主机（TOFU）管理
  const reloadKnownHosts = async () => {
    try {
      const list = await ipcRenderer.invoke('known-hosts-list');
      setKnownHosts(Array.isArray(list) ? list : []);
    } catch {
      setKnownHosts([]);
    }
  };
  const removeKnownHost = async (host) => {
    await ipcRenderer.invoke('known-hosts-remove', host);
    reloadKnownHosts();
  };
  const clearKnownHosts = async () => {
    await ipcRenderer.invoke('known-hosts-clear');
    reloadKnownHosts();
    showToast('已清除全部已知主机');
  };

  // 快捷执行命令
  const quickExecute = async (command) => {
    // 高危命令统一二次确认（防未来扩展，与 AI 自动执行路径一致）
    if (isDangerousCommand(command) &&
        !confirm(`⚠️ 检测到高危命令：\n${command}\n\n确定要执行吗？`)) {
      return;
    }
    setAiMessages((prev) => [...prev, { role: 'user', content: `执行: ${command}` }]);
    setIsProcessing(true);

    const result = await executeCommand(command);
    setAiMessages((prev) => [
      ...prev,
      {
        role: 'result',
        command: command,
        output: result.output,
        success: result.success,
      },
    ]);

    setIsProcessing(false);
  };

  return (
    <div className="app">
      <div className={`sidebar ${sidebarCollapsed ? 'collapsed' : ''}`}>
        <div className="logo">
          <Zap className="logo-icon" size={20} />
          {!sidebarCollapsed && 'AI Terminal'}
        </div>
        <button className="sidebar-toggle" onClick={toggleSidebar} title={sidebarCollapsed ? '展开侧边栏' : '折叠侧边栏'}>
          {sidebarCollapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
        </button>
        <nav className="nav">
          <button
            className={`nav-item ${activeTab === 'local' ? 'active' : ''}`}
            onClick={() => setActiveTab('local')}
            title="本地终端"
          >
            <Laptop className="nav-icon" size={18} />
            {!sidebarCollapsed && '本地终端'}
          </button>

          {/* SSH 会话列表 */}
          <div className="nav-section">
            <div className="nav-section-header">
              <Lock className="nav-icon" size={18} />
              {!sidebarCollapsed && <span>SSH连接</span>}
              <button className="add-session-btn" onClick={() => openConnectionDrawer()} title="新建SSH连接">
                <Plus size={14} />
              </button>
            </div>
            {(() => {
            const groupOf = (c) => (c.group || '').trim();
            const renderConnItem = (conn) => {
              const status = getConnectionStatus(conn.id);
              let session = sshSessions.find(s => s.connectionId === conn.id);

              // 如果没有会话，临时创建一个用于显示
              if (!session) {
                session = {
                  id: `temp-${conn.id}`,
                  connectionId: conn.id,
                  name: conn.name,
                  config: {
                    host: conn.host,
                    port: conn.port,
                    username: conn.username,
                    authType: conn.authType,
                    password: conn.password,
                    privateKeyPath: conn.privateKeyPath,
                    passphrase: conn.passphrase || ''
                  },
                  status: 'disconnected',
                  statusMessage: '',
                  systemInfo: null
                };
              }

              const isActive = activeSessionId === session.id;

              return (
                <div
                  key={conn.id}
                  className={`nav-item ssh-session-item ${isActive ? 'active' : ''}`}
                  onClick={() => {
                    // 获取或创建会话
                    const actualSession = getOrCreateSession(conn.id);
                    if (actualSession) {
                      setActiveTab('ssh');
                      setActiveSessionId(actualSession.id);
                    }
                  }}
                  onContextMenu={(e) => handleContextMenu(e, conn.id)}
                  title={sidebarCollapsed ? `${conn.name}\n${conn.username}@${conn.host}:${conn.port}` : ''}
                >
                  <span className={`session-status-dot ${status}`}></span>
                  {!sidebarCollapsed && (
                    <div className="session-info-wrapper">
                      <span className="session-name">{conn.name}</span>
                      <span className="session-host">{conn.username}@{conn.host}:{conn.port}</span>
                      {(conn.note || '').trim() && (
                        <span className="session-note" title={conn.note}>{conn.note}</span>
                      )}
                    </div>
                  )}
                  {!sidebarCollapsed && status === 'disconnected' && (
                    <button
                      className="session-action-btn connect"
                      onClick={(e) => {
                        e.stopPropagation();
                        connectToSavedConnection(conn.id);
                      }}
                      title="连接"
                    >
                      <Play size={14} />
                    </button>
                  )}
                  {!sidebarCollapsed && status === 'connected' && (
                    <button
                      className="session-action-btn disconnect"
                      onClick={(e) => {
                        e.stopPropagation();
                        if (session) handleSSHDisconnect(session.id);
                      }}
                      title="断开连接"
                    >
                      <Square size={14} />
                    </button>
                  )}
                  {!sidebarCollapsed && status === 'connecting' && (
                    <span className="session-status-text">连接中...</span>
                  )}
                </div>
              );
            };
            const ungrouped = savedConnections.filter(c => !groupOf(c));
            const groupNames = [...new Set(savedConnections.map(groupOf).filter(Boolean))].sort();
            return (
              <>
                {ungrouped.map(renderConnItem)}
                {groupNames.map(g => (
                  <React.Fragment key={`grp-${g}`}>
                    {!sidebarCollapsed && (
                      <div className="nav-group-header">
                        <Folder size={13} />
                        <span>{g}</span>
                      </div>
                    )}
                    {savedConnections.filter(c => groupOf(c) === g).map(renderConnItem)}
                  </React.Fragment>
                ))}
              </>
            );
            })()}
            {savedConnections.length === 0 && (
              <div className="nav-item-hint" onClick={() => openConnectionDrawer()}>
                点击 <Plus size={12} style={{display: 'inline', verticalAlign: 'middle'}} /> 添加SSH连接
              </div>
            )}
          </div>

          <button
            className={`nav-item ${activeTab === 'ai' ? 'active' : ''}`}
            onClick={() => setActiveTab('ai')}
            title="AI Agent"
          >
            <Bot className="nav-icon" size={18} />
            {!sidebarCollapsed && 'AI Agent'}
          </button>
        </nav>

        {/* 保存的连接 */}
        {/* 已移到上方SSH连接列表中 */}

        <div className="sidebar-footer">
          <button className="settings-btn" onClick={() => { setShowSettings(true); reloadKnownHosts(); }} title="设置">
            <Settings size={18} />
            {!sidebarCollapsed && ' 设置'}
          </button>
        </div>
      </div>

      <div className="main-content">
        {/* 本地终端 - 使用CSS隐藏而非条件渲染 */}
        <div className="terminal-container" style={{ display: activeTab === 'local' ? 'flex' : 'none' }}>
          <div className="terminal-header">
            <span>本地终端</span>
            {terminalError && <span className="error-badge">{terminalError}</span>}
          </div>
          <div ref={terminalRef} className="terminal" />
          <StatusBar info={localSystemInfo} type="local" />
        </div>

        {/* SSH终端 - 多会话支持 */}
        <div className="ssh-container" style={{ display: activeTab === 'ssh' ? 'flex' : 'none' }}>
          {sshSessions.length > 0 ? (
            <>
              {sshSessions.map(session => (
                <div
                  key={session.id}
                  className="ssh-session-view"
                  style={{ display: activeSessionId === session.id ? 'flex' : 'none' }}
                >
                  <div className="ssh-header">
                    <div className="ssh-header-bar">
                      <div className="ssh-info">
                        <span className={`connection-status ${session.status}`}>
                          {session.status === 'connected' ? '已连接' :
                           session.status === 'connecting' ? '连接中...' :
                           session.status === 'error' ? '连接失败' : '未连接'}
                        </span>
                        {session.config.host && (
                          <span className="connection-info">
                            {session.config.username}@{session.config.host}:{session.config.port}
                          </span>
                        )}
                        {(() => {
                          // 最稳：从 savedConnections 按 connectionId 查 note（不假设 session.config 带 note）
                          const conn = savedConnections.find(c => c.id === session.connectionId);
                          const note = (conn?.note || '').trim();
                          return note ? <span className="connection-note" title={note}>📝 {note}</span> : null;
                        })()}
                      </div>
                      <div className="ssh-actions">
                        {session.status !== 'connected' && session.status !== 'connecting' && (
                          <button className="ssh-action-btn primary" onClick={() => editConnection(session.connectionId)}>
                            <Settings size={14} /> 配置连接
                          </button>
                        )}
                        {session.status === 'connected' && (
                          <button className="ssh-action-btn danger" onClick={() => handleSSHDisconnect(session.id)}>
                            断开连接
                          </button>
                        )}
                      </div>
                    </div>
                    {session.statusMessage && (
                      <div className={`ssh-status-message ${session.status}`}>
                        {session.statusMessage}
                      </div>
                    )}
                  </div>
                  <div
                    ref={(el) => {
                      if (el && !sshTerminals.current.has(session.id)) {
                        createSshTerminal(session.id, el);
                      }
                    }}
                    className="terminal"
                  />
                  <StatusBar info={session.systemInfo} type="ssh" host={session.config.host} />
                </div>
              ))}
            </>
          ) : (
            <div className="ssh-empty-state">
              <Lock size={48} className="empty-icon" />
              <h3>没有活动的SSH会话</h3>
              <p>点击侧边栏的 <Plus size={12} style={{display: 'inline', verticalAlign: 'middle'}} /> 按钮添加新的SSH连接</p>
              <button className="add-session-btn-large" onClick={() => openConnectionDrawer()}>
                <Plus size={16} /> 新建SSH会话
              </button>
            </div>
          )}
        </div>

        {/* AI Agent - 使用CSS隐藏而非条件渲染 */}
        <div className="ai-panel" style={{ display: activeTab === 'ai' ? 'flex' : 'none' }}>
            <div className="ai-header">
              <h2><Bot size={20} style={{display: 'inline', verticalAlign: 'middle'}} /> AI Agent</h2>
              <p>让AI帮你执行终端命令，支持自然语言交互</p>
            </div>

            <div className="quick-commands">
              <span>快捷命令:</span>
              <button onClick={() => quickExecute('ls -la')}>列出文件</button>
              <button onClick={() => quickExecute('pwd')}>当前目录</button>
              <button onClick={() => quickExecute('df -h')}>磁盘空间</button>
              <button onClick={() => quickExecute('ps aux | head -20')}>进程列表</button>
            </div>

            <div className="ai-messages">
              {aiMessages.length === 0 && (
                <div className="ai-welcome">
                  <h3>欢迎使用 AI Agent</h3>
                  <p>你可以用自然语言让我帮你执行终端命令，例如：</p>
                  <ul>
                    <li>"列出当前目录的所有文件"</li>
                    <li>"查看系统内存使用情况"</li>
                    <li>"创建一个名为test的文件夹"</li>
                    <li>"查找所有.js文件"</li>
                  </ul>
                  {/* 当前 AI 服务商/模型（对齐原生 T1）。模型来源：renderer fetch openai /v1/chat/completions model:'gpt-4' */}
                  <p className="ai-model-badge">
                    <Cpu size={12} style={{ display: 'inline', verticalAlign: 'middle', marginRight: 4 }} />
                    当前：OpenAI · gpt-4
                  </p>
                </div>
              )}
              {aiMessages.map((msg, idx) => (
                <div key={idx} className={`message ${msg.role}`}>
                  {msg.role === 'user' && (
                    <div className="message-content user-message">{msg.content}</div>
                  )}
                  {msg.role === 'assistant' && (
                    <div className="message-content assistant-message">
                      <pre>{msg.content}</pre>
                    </div>
                  )}
                  {msg.role === 'result' && (
                    <div className={`message-content result-message ${msg.success ? 'success' : 'error'}`}>
                      <div className="result-header">
                        {msg.success ? <Check className="result-icon" size={16} /> : <X className="result-icon" size={16} />}
                        <code>{msg.command}</code>
                      </div>
                      <pre className="result-output">{msg.output}</pre>
                    </div>
                  )}
                </div>
              ))}
              {isProcessing && (
                <div className="message assistant">
                  <div className="message-content loading">
                    <span className="loading-dots">思考中...</span>
                  </div>
                </div>
              )}
              <div ref={messagesEndRef} />
            </div>

            <div className="ai-input-area">
              <textarea
                value={aiInput}
                onChange={(e) => setAiInput(e.target.value)}
                placeholder="输入你想执行的任务，例如：'帮我查看系统信息'"
                disabled={isProcessing}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    handleAISend();
                  }
                }}
              />
              <button onClick={handleAISend} disabled={isProcessing || !aiInput.trim()}>
                {isProcessing ? '执行中...' : '发送'}
              </button>
            </div>
          </div>
        </div>

      {/* 设置弹窗 */}
      {showSettings && (
        <div className="modal-overlay" onClick={() => setShowSettings(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h2>设置</h2>
            <div className="form-group">
              <label>配色主题</label>
              <select
                value={theme}
                onChange={(e) => setTheme(e.target.value)}
                className="theme-select"
              >
                {Object.entries(THEMES).map(([id, t]) => (
                  <option key={id} value={id}>{t.name}</option>
                ))}
              </select>
              <small>应用到界面与终端配色</small>
            </div>
            <div className="form-group">
              <label>OpenAI API Key</label>
              <input
                type="password"
                value={apiKey}
                onChange={(e) => setApiKey(e.target.value)}
                placeholder="sk-..."
              />
              <small>用于AI Agent功能，支持GPT-4模型</small>
            </div>
            <div className="form-group">
              <label>连接备份</label>
              <div style={{ display: 'flex', gap: '8px' }}>
                <button className="btn-save" style={{ flex: 1 }} onClick={() => exportConnections(false)}>导出连接</button>
                <button className="btn-save" style={{ flex: 1, background: 'var(--surface-light)' }}
                  onClick={() => document.getElementById('import-conn-input').click()}>导入连接</button>
              </div>
              <input id="import-conn-input" type="file" accept="application/json,.json"
                style={{ display: 'none' }} onChange={importConnections} />
              <small>跨端通用 JSON 格式（docs/connection-format.md）。默认不导出密码。</small>
            </div>
            <div className="form-group">
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <label style={{ margin: 0 }}>已知主机（TOFU）</label>
                {knownHosts.length > 0 && (
                  <button className="btn-save" style={{ background: 'var(--danger)', padding: '4px 10px', fontSize: '12px' }}
                    onClick={clearKnownHosts}>全部清除</button>
                )}
              </div>
              {knownHosts.length === 0 ? (
                <small>暂无已知主机。首次连接 SSH 后会记录其指纹用于 TOFU 校验。</small>
              ) : (
                <div className="known-hosts-list">
                  {knownHosts.map((h) => (
                    <div key={h.host} className="known-host-row">
                      <div className="known-host-info">
                        <span className="known-host-name">{h.host}</span>
                        <span className="known-host-fp" title={h.fingerprint}>{h.fingerprint}</span>
                      </div>
                      <button className="known-host-del" title="删除" onClick={() => removeKnownHost(h.host)}>
                        <Trash2 size={14} />
                      </button>
                    </div>
                  ))}
                </div>
              )}
              <small>删除某主机后，下次连接会重新信任并记录其指纹。</small>
            </div>
            <div className="modal-actions">
              <button className="btn-cancel" onClick={() => setShowSettings(false)}>
                取消
              </button>
              <button className="btn-save" onClick={saveApiKey}>
                保存
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 保存连接弹窗 */}
      {showSaveConnectionModal && (
        <div className="modal-overlay" onClick={() => setShowSaveConnectionModal(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h2>保存连接</h2>
            <div className="form-group">
              <label>连接名称</label>
              <input
                type="text"
                value={editingConfig.name}
                onChange={(e) => setEditingConfig({ ...editingConfig, name: e.target.value })}
                placeholder="例如: 生产服务器"
              />
            </div>
            <div className="form-group checkbox-group">
              <label>
                <input
                  type="checkbox"
                  checked={editingConfig.savePassword}
                  onChange={(e) => setEditingConfig({ ...editingConfig, savePassword: e.target.checked })}
                />
                保存密码
              </label>
              <small>注意：密码将以明文形式保存在本地</small>
            </div>
            <div className="modal-actions">
              <button className="btn-cancel" onClick={() => setShowSaveConnectionModal(false)}>
                取消
              </button>
              <button className="btn-save" onClick={saveConnection}>
                保存
              </button>
            </div>
          </div>
        </div>
      )}

      {/* SSH连接配置抽屉 */}
      {showConnectionDrawer && (
        <>
          <div className="drawer-overlay" onClick={() => setShowConnectionDrawer(false)} />
          <div className="drawer">
            <div className="drawer-header">
              <h2>{drawerConnectionConfig.connectionId ? '编辑SSH连接' : '新建SSH连接'}</h2>
              <button className="drawer-close" onClick={() => setShowConnectionDrawer(false)}>
                <X size={20} />
              </button>
            </div>

            <div className="drawer-content">
              <div className="drawer-notice">
                <Lock size={16} style={{display: 'inline', verticalAlign: 'middle'}} /> 所有认证信息仅保存在本地，不会上传到任何服务器
              </div>

              <div className="form-group">
                <label>连接名称（可选）</label>
                <input
                  type="text"
                  value={drawerConnectionConfig.name}
                  onChange={(e) => setDrawerConnectionConfig({ ...drawerConnectionConfig, name: e.target.value })}
                  placeholder="例如: 生产服务器"
                  className="drawer-input"
                />
              </div>

              <div className="form-group">
                <label>分组（可选）</label>
                <input
                  type="text"
                  value={drawerConnectionConfig.group || ''}
                  onChange={(e) => setDrawerConnectionConfig({ ...drawerConnectionConfig, group: e.target.value })}
                  placeholder="例如: 生产 / 测试"
                  className="drawer-input"
                />
              </div>

              <div className="form-group">
                <label>备注（可选）</label>
                <input
                  type="text"
                  value={drawerConnectionConfig.note || ''}
                  onChange={(e) => setDrawerConnectionConfig({ ...drawerConnectionConfig, note: e.target.value })}
                  placeholder="例如: 数据库主库 / 跳板用"
                  className="drawer-input"
                />
              </div>

              <div className="form-group">
                <label>主机地址 *</label>
                <input
                  type="text"
                  value={drawerConnectionConfig.host}
                  onChange={(e) => setDrawerConnectionConfig({ ...drawerConnectionConfig, host: e.target.value })}
                  placeholder="例如: 192.168.1.100"
                  className="drawer-input"
                />
              </div>

              <div className="form-group-row">
                <div className="form-group" style={{ flex: 1 }}>
                  <label>端口</label>
                  <input
                    type="text"
                    value={drawerConnectionConfig.port}
                    onChange={(e) => setDrawerConnectionConfig({ ...drawerConnectionConfig, port: e.target.value })}
                    placeholder="22"
                    className="drawer-input"
                  />
                </div>
                <div className="form-group" style={{ flex: 2 }}>
                  <label>用户名 *</label>
                  <input
                    type="text"
                    value={drawerConnectionConfig.username}
                    onChange={(e) => setDrawerConnectionConfig({ ...drawerConnectionConfig, username: e.target.value })}
                    placeholder="例如: root"
                    className="drawer-input"
                  />
                </div>
              </div>

              <div className="form-group">
                <label>认证方式</label>
                <select
                  value={drawerConnectionConfig.authType}
                  onChange={(e) => setDrawerConnectionConfig({ ...drawerConnectionConfig, authType: e.target.value })}
                  className="drawer-input"
                >
                  <option value="password">密码认证</option>
                  <option value="privateKey">私钥认证</option>
                </select>
              </div>

              {drawerConnectionConfig.authType === 'password' ? (
                <div className="form-group">
                  <label>密码 *</label>
                  <div className="password-input-wrapper">
                    <input
                      type={showPasswordMap['drawer-pwd'] ? 'text' : 'password'}
                      value={drawerConnectionConfig.password}
                      onChange={(e) => setDrawerConnectionConfig({ ...drawerConnectionConfig, password: e.target.value })}
                      placeholder="输入密码"
                      className="drawer-input"
                    />
                    <button
                      type="button"
                      className="toggle-password-btn"
                      onClick={() => togglePasswordVisibility('drawer-pwd')}
                      title={showPasswordMap['drawer-pwd'] ? '隐藏密码' : '显示密码'}
                    >
                      {showPasswordMap['drawer-pwd'] ? <Eye size={16} /> : <EyeOff size={16} />}
                    </button>
                  </div>
                </div>
              ) : (
                <>
                  <div className="form-group">
                    <label>私钥文件 *</label>
                    <div className="file-input-group">
                      <input
                        type="text"
                        value={drawerConnectionConfig.privateKeyPath}
                        placeholder="选择私钥文件"
                        className="drawer-input"
                        readOnly
                      />
                      <button
                        type="button"
                        className="file-select-btn"
                        onClick={handleDrawerSelectPrivateKey}
                      >
                        选择文件
                      </button>
                    </div>
                  </div>
                  <div className="form-group">
                    <label>私钥密码（可选）</label>
                    <div className="password-input-wrapper">
                      <input
                        type={showPasswordMap['drawer-passphrase'] ? 'text' : 'password'}
                        value={drawerConnectionConfig.passphrase}
                        onChange={(e) => setDrawerConnectionConfig({ ...drawerConnectionConfig, passphrase: e.target.value })}
                        placeholder="如果私钥有密码，请输入"
                        className="drawer-input"
                      />
                      <button
                        type="button"
                        className="toggle-password-btn"
                        onClick={() => togglePasswordVisibility('drawer-passphrase')}
                      >
                        {showPasswordMap['drawer-passphrase'] ? <Eye size={16} /> : <EyeOff size={16} />}
                      </button>
                    </div>
                  </div>
                </>
              )}
            </div>

            <div className="drawer-footer">
              <button className="drawer-btn primary full-width" onClick={handleDrawerSave}>
                <Save size={16} /> 保存配置
              </button>
            </div>
          </div>
        </>
      )}

      {/* 右键菜单 */}
      {contextMenu && (
        <div
          className="context-menu"
          style={{ left: contextMenu.x, top: contextMenu.y }}
          onClick={(e) => e.stopPropagation()}
        >
          {contextMenu.session && contextMenu.session.status === 'disconnected' && (
            <div className="context-menu-item" onClick={() => {
              connectToSavedConnection(contextMenu.connectionId);
              closeContextMenu();
            }}>
              <Play className="context-menu-icon" size={14} />
              连接
            </div>
          )}
          {contextMenu.session && contextMenu.session.status === 'connected' && (
            <div className="context-menu-item" onClick={() => {
              handleSSHDisconnect(contextMenu.session.id);
              closeContextMenu();
            }}>
              <Square className="context-menu-icon" size={14} />
              断开连接
            </div>
          )}
          <div className="context-menu-item" onClick={() => {
            editConnection(contextMenu.connectionId);
          }}>
            <Edit className="context-menu-icon" size={14} />
            编辑配置
          </div>
          <div className="context-menu-item" onClick={() => {
            cloneConnection(contextMenu.connection);
            closeContextMenu();
          }}>
            <Files className="context-menu-icon" size={14} />
            克隆连接
          </div>
          <div className="context-menu-item" onClick={() => {
            copyConnectionConfig(contextMenu.connection);
            closeContextMenu();
          }}>
            <Copy className="context-menu-icon" size={14} />
            复制配置
          </div>
          <div className="context-menu-divider"></div>
          <div className="context-menu-item danger" onClick={() => {
            if (confirm(`确定要删除连接 "${contextMenu.connection.name}" 吗？`)) {
              deleteConnection(contextMenu.connectionId);
              closeContextMenu();
            }
          }}>
            <Trash2 className="context-menu-icon" size={14} />
            删除连接
          </div>
        </div>
      )}

      {/* Toast提示 */}
      {toast && (
        <div className={`toast ${toast.type}`}>
          {toast.type === 'success' ? <Check className="toast-icon" size={16} /> :
           toast.type === 'error' ? <X className="toast-icon" size={16} /> :
           <Info className="toast-icon" size={16} />}
          <span className="toast-message">{toast.message}</span>
        </div>
      )}
    </div>
  );
}

export default App;
