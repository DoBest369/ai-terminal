# 连接配置交换格式（全端通用）

用于在 **原生版（apple/）/ Electron 版（src/）/ 移动版（mobile/）** 之间搬运 SSH 连接。
各端的「导出连接」生成此格式 JSON，「导入连接」读取此格式合并进本地连接列表。

## 格式

```json
{
  "format": "ai-terminal-connections",
  "version": 1,
  "connections": [
    {
      "name": "生产服务器",
      "host": "192.168.1.10",
      "port": 22,
      "username": "root",
      "authType": "password"
    },
    {
      "name": "开发机",
      "host": "dev.example.com",
      "port": 2222,
      "username": "deploy",
      "authType": "privateKey"
    }
  ]
}
```

## 字段

| 字段 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `name` | string | 否 | 显示名称（空则用 user@host） |
| `host` | string | 是 | 主机地址 |
| `port` | number | 否 | 端口，默认 22 |
| `username` | string | 是 | 用户名 |
| `authType` | string | 是 | `"password"` 或 `"privateKey"` |
| `group` | string | 否 | 分组名（侧边栏归类用）；空/缺省表示未分组 |
| `startupCommands` | string | 否 | 启动命令（多行，每行一条）；SSH 就绪后自动依次执行。**仅原生版** |
| `fontSizeOverride` | number | 否 | 该连接的终端字号（8–32）；缺省用全局字号。**仅原生版** |
| `note` | string | 否 | 自由文本备注（如「数据库主库」「先连 VPN」） |
| `password` | string | 否 | **敏感**，默认不导出；导入端按需写入安全存储 |
| `passphrase` | string | 否 | **敏感**，私钥口令，默认不导出 |

> ℹ️ **端差异**：`name/host/port/username/authType/group/note` 及敏感字段三端通用。`startupCommands` / `fontSizeOverride` 目前**仅原生版（apple/）导出与识别**；Electron / 移动版导入这两个字段会被忽略（不报错，仅不应用），导出也不会写出——但 JSON 里出现它们不影响互通。

## 安全约定

- **默认导出不含 `password` / `passphrase`**（也不含私钥内容、私钥文件路径——后者是设备相关的）。导入后需在对应端重新填写密钥/密码。
- 仅当用户显式选择「包含密码导出」时才写入 `password`/`passphrase`，且应提示该文件含明文凭据、注意妥善保管。
- 原生版（apple/）的本地存储里，敏感字段走系统 Keychain（见 `apple/AITerminalCore/.../KeychainStore.swift`）；导入只把非敏感字段落地，密码留空待用户补填（除非导入文件显式带 `password`）。

## 各端入口

- 原生版：设置 → 连接备份 → 导出 / 导入
- Electron 版：设置 → 连接备份 → 导出 / 导入
- 移动版：复用同格式（后续接入）
