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
| 本地端口转发 | ✅ | ✅ | android sshj LocalPortForwarder |
| 跳板机（多跳串联） | ✅ | ⬜ | apple 独有 |
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
| 多对话（新建/切换/删除/持久化） | ✅ | ✅ | 双端持久化 |
| 对话导出 Markdown | ✅ | ✅ | android 分享 Intent |
| 对话内搜索 | ✅ | ✅ | |

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
| 命令历史（去重/置顶/限长/调出） | ✅ | ✅ | N-History 双端 UI 接入 |
| 批量群发命令（多服务器同命令） | 🟡 | ✅ | apple Core BatchRunner 框架 + BatchShowcase 界面渲染；真实 SSH 接入 TODO |
| 群发结果 AI 汇总 | 🟡 | ✅ | apple composeForAI 框架 + UI 入口；android 完整 |
| 多主题配色 | ✅ | ✅ | 双端 5 套（午夜/One Dark/Dracula/Solarized/Nord） |
| 分屏 / 会话录制 | ✅ | ⬜ | apple 独有 |

## 小结

- **核心智能运维护城河（Z1–Z8）双端完全对齐** ✅
- **SSH/终端/SFTP/AI/安全/端口转发/多主题/多对话 双端齐平**；android 仅差 跳板机多跳串联、AI 对话搜索/导出、分屏/录制 等 apple 增强项（多为移动端意义有限或锦上添花）
- apple 为功能最全的旗舰；**android 已是功能完整、体验接近桌面的第二原生端，核心能力与 apple 高度对齐**
- **android AI 能力已与 apple 完全对齐**（对话/解释/报错/健康/环境感知/流式/多对话/持久化/搜索/导出）
- android 仅剩 **跳板机多跳串联**（可后续）、**分屏/录制**（移动端意义有限，标 N/A）未对齐——**双端核心 + 增强能力实质全对齐**
- `linux/`（Rust+egui）🟡 骨架；`windows/`（C#/.NET）⬜ 待起
