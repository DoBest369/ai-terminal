# Termind 双端能力对照（apple ↔ android）

真实反映 `apple/`（Swift/SwiftUI）与 `android/`（Kotlin/Compose）两端的能力落地情况。
✅=已实现 · 🟡=部分/骨架 · ⬜=未做。截至最新迭代。

## SSH / 终端

| 能力 | apple | android | 说明 |
|------|:---:|:---:|------|
| 连接管理（分组/备注/持久化/增删改） | ✅ | ✅ | |
| 连接可达性 TCP 探测 | ✅ | ✅ | apple ReachabilityChecker / android Reachability |
| 密码认证 | ✅ | ✅ | |
| 私钥认证 | ✅ | ✅ | android sshj authPublickey |
| 跳板机 / 端口转发 | ✅ | ⬜ | apple PortForward |
| 交互式 PTY 终端 | ✅ | ✅ | |
| 终端 ANSI 颜色渲染 | ✅ | ✅ | android AnsiParser→AnnotatedString |
| TOFU 主机密钥校验 | ✅ | ✅ | android KnownHosts 指纹首次信任+比对（防 MITM） |
| SFTP 浏览 | ✅ | ✅ | |
| SFTP 查看文件内容 | ✅ | ✅ | |
| SFTP 下载 / 上传 | ✅ | ✅ | android sftp.get/put + 文件选择器 |

## AI 助手

| 能力 | apple | android | 说明 |
|------|:---:|:---:|------|
| 对话（流式输出） | ✅ | ✅ | android OkHttp SSE |
| 命令解释 | ✅ | ✅ | |
| 报错分析 | ✅ | ✅ | |
| 环境感知（探测→喂 AI） | ✅ | ✅ | ServerProfile / EnvDetector 双端 |
| 健康分析（状态↔AI 联动） | ✅ | ✅ | apple Z6b / android A-HealthAI |
| 多对话 / 搜索 / 导出 | ✅ | ⬜ | apple 独有 |

## 智能运维护城河（阶段 Z）

| 能力 | apple | android | 说明 |
|------|:---:|:---:|------|
| Z1 命令解释 | ✅ | ✅ | |
| Z2 报错分析 | ✅ | ✅ | |
| Z3 环境感知 | ✅ | ✅ | |
| Z4 排障工作流（真执行+AI 总结） | ✅ | ✅ | 5 内置工作流双端 |
| Z5 操作回滚（备份+时间线） | ✅ | ✅ | OpRollback 双端 |
| Z6 服务器状态面板 | ✅ | ✅ | CPU/内存/磁盘+服务/告警 |
| Z7 风险分级 + 脱敏 | ✅ | ✅ | CommandRisk 四级 + Redactor 双端 |
| Z8 初始化模板（真执行） | ✅ | ✅ | 5 内置模板双端 |

## 安全 / 其它

| 能力 | apple | android | 说明 |
|------|:---:|:---:|------|
| 凭据安全存储 | ✅ | ✅ | apple Keychain / android EncryptedSharedPreferences |
| 快捷命令片段（风险着色） | ✅ | ✅ | |
| 多主题配色 | ✅ | ✅ | 双端 5 套（午夜/One Dark/Dracula/Solarized/Nord） |
| 分屏 / 会话录制 | ✅ | ⬜ | apple 独有 |

## 小结

- **核心智能运维护城河（Z1–Z8）双端完全对齐** ✅
- **SSH/终端/SFTP/AI 主线双端齐平**；android 仅差 跳板机/端口转发、TOFU、多对话管理、多主题、分屏录制等 apple 既有的增强项
- apple 为功能最全的旗舰；android 已是功能完整、体验接近桌面的第二原生端
- `linux/`（Rust+egui）🟡 骨架；`windows/`（C#/.NET）⬜ 待起
