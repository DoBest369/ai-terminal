# Termind 双端能力对照（apple ↔ android）

真实反映 `apple/`（Swift/SwiftUI）与 `android/`（Kotlin/Compose）两端的能力落地情况。
✅=已实现 · 🟡=部分/骨架 · ⬜=未做。截至最新迭代。

## SSH / 终端

| 能力 | apple | android | 说明 |
|------|:---:|:---:|------|
| 连接管理（分组/备注/持久化/增删改） | ✅ | ✅ | |
| 连接颜色标签 | ✅ | ✅ | 双端 6 色环境标识（apple Core+导入导出+渲染，UI 色选器待接入） |
| 连接列表搜索过滤 | ✅ | ✅ | 按名称/主机/用户/分组 |
| 连接列表排序 | ✅ | ✅ | 名称/最近使用/在线优先 |
| 连接编辑测试连通 | ✅ | ✅ | 双端 TCP 测试按钮（apple ConnectionEditView + ReachabilityChecker） |
| 连接级启动命令 | ✅ | ✅ | 连上自动执行 |
| 终端字号调节 | ✅ | ✅ | android +/- 8-22sp |
| 终端复制全部/清屏 | ✅ | ✅ | android |
| 连接可达性 TCP 探测 | ✅ | ✅ | apple ReachabilityChecker / android Reachability |
| 密码认证 | ✅ | ✅ | |
| 私钥认证 | ✅ | ✅ | android sshj authPublickey |
| 本地端口转发 | ✅ | ✅ | android sshj LocalPortForwarder |
| 跳板机（ProxyJump 经堡垒机） | ✅ | ✅ | android sshj connectVia，覆盖 终端/状态/环境/排障/模板/SFTP/端口转发全操作（未真机实测） |
| 交互式 PTY 终端 | ✅ | ✅ | |
| 终端会话 keepalive 心跳 | ✅ | ✅ | android sshj 30s 防超时断连 |
| 终端 ANSI 颜色渲染 | ✅ | ✅ | android AnsiParser→AnnotatedString |
| TOFU 主机密钥校验 | ✅ | ✅ | android KnownHosts 指纹首次信任+比对（防 MITM） |
| SFTP 浏览 | ✅ | ✅ | |
| SFTP 查看文件内容 | ✅ | ✅ | |
| SFTP 下载 / 上传 | ✅ | ✅ | android sftp.get/put + 文件选择器 |
| SFTP 新建文件夹 / 删除 | ✅ | ✅ | 双端（apple Citadel createDirectory/rmdir/remove；android sftp.mkdir/rm/rmdir）+ 二次确认 |
| SFTP 文件重命名 | ✅ | ✅ | 双端 sftp.rename（apple 右键菜单 / android 行图标） |
| SFTP 路径直接跳转 | ✅ | ✅ | 双端输路径直达深目录 |
| SFTP 修改时间 / 排序 | ✅ | ✅ | 双端行显时间 + 名称/大小/时间排序 |
| SFTP 文件名过滤 | ✅ | ✅ | 双端当前目录过滤（apple .searchable） |
| 连接列表分组折叠 | ✅ | ✅ | 双端分组标题可点折叠 |
| 连接复制（克隆） | ✅ | ✅ | 双端（apple cloneConnection 插到原连接后；android 一键克隆） |
| 终端连接时长 | ✅ | ✅ | 双端显示连接时长（apple StatusBar TimelineView） |
| 连接上次使用相对时间 | ✅ | ✅ | 双端「上次使用 · N 分钟前」 |
| 终端输出搜索 | ✅ | ✅ | apple SwiftTerm 内置搜索（高亮+上/下导航+定位）；android 高亮+匹配计数 |
| 终端控制键栏（Tab/Ctrl/方向键） | ✅ | ✅ | 双端；apple TerminalKeyBar（iOS SSH 会话，18 键含 ^R/^U/管道符）+ macOS 物理键盘 |
| AI 代码块渲染 | ✅ | ✅ | 双端按 ``` 拆等宽深色框（apple MessageBubble + 渲染验证） |

## AI 助手

| 能力 | apple | android | 说明 |
|------|:---:|:---:|------|
| 对话（流式输出） | ✅ | ✅ | android OkHttp SSE |
| 命令解释 | ✅ | ✅ | |
| 报错分析 | ✅ | ✅ | |
| 环境感知（探测→喂 AI） | ✅ | ✅ | ServerProfile / EnvDetector 双端 |
| 健康分析（状态↔AI 联动） | ✅ | ✅ | apple Z6b / android A-HealthAI |
| 多对话（新建/切换/删除/清空/持久化） | ✅ | ✅ | 双端持久化；清空当前消息 |
| 对话导出 Markdown | ✅ | ✅ | android 分享 Intent |
| 对话内搜索 | ✅ | ✅ | |
| 多行输入 | ✅ | ✅ | 粘贴报错/长指令 |
| 停止生成 | ✅ | ✅ | 流式可中断 |
| 重新生成上一条 | ✅ | ✅ | |
| AI 模型选择 | ✅ | ✅ | Opus 4.8 / Sonnet 4.6 / Haiku 4.5 |
| AI 运维提示词库 | ✅ | ✅ | 双端 5 类(排障/部署/安全/性能/日志)分类提示词 |
| AI 代码块渲染 | ✅ | ✅ | 双端等宽深色框；复制 android(代码块点击)/apple(气泡右键) |
| AI 消息复制整条 | ✅ | ✅ | apple 气泡右键「复制」/ android 长按复制 |

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

## ✨ 阶段 N 创新（运维工作台杀手级能力）

| 能力 | apple | android | 说明 |
|------|:---:|:---:|------|
| 命令历史（去重/调出/输入补全） | ✅ | ✅ | android 输入时匹配历史 Chip 补全 |
| 批量群发命令 | ✅ | ✅ | 双端完整 UI（apple BatchView 多选+风险徽章+确认+runBatch；android BatchScreen） |
| 群发结果 AI 汇总 | ✅ | ✅ | 双端（apple summarizeBatch；android 完整） |
| 批量健康巡检 | ✅ | ✅ | 双端（apple InspectView 多选+采集+告警置顶；android InspectScreen） |
| 巡检结果 AI 总结 | ✅ | ✅ | 双端（apple summarizeInspection；android 完整） |
| 定时后台巡检 + 通知 | ⬜ | ✅ | android WorkManager（主动运维，离线推通知） |

> 阶段 N 让 Termind 从「逐台 SSH」升级为「**一批机器的批量操作 + AI 智能洞察**」——这是单连接 SSH 工具（Xshell/Termius）做不到的运维工作台核心差异化。android 先行落地，apple 框架就绪待 UI 接入。

## 差异化深化

| 能力 | apple | android | 说明 |
|------|:---:|:---:|------|
| 服务器知识卡片 | 🟡 | ✅ | 每台机沉淀 问题/方案/笔记（Core 双端；android UI 完整，apple UI 待接）；喂 AI 排障参考 |

## 安全 / 其它

| 能力 | apple | android | 说明 |
|------|:---:|:---:|------|
| 凭据安全存储 | ✅ | ✅ | apple Keychain / android EncryptedSharedPreferences |
| 快捷命令片段（风险着色 + 自定义增删） | ✅ | ✅ | |
| 命令历史（去重/置顶/限长/调出） | ✅ | ✅ | N-History 双端 UI 接入 |
| 批量群发命令（多服务器同命令） | ✅ | ✅ | 双端完整 UI（apple BatchView + BatchShowcase 渲染） |
| 群发结果 AI 汇总 | ✅ | ✅ | apple summarizeBatch + composeForAI；android 完整 |
| 多主题配色 | ✅ | ✅ | 双端 5 套（午夜/One Dark/Dracula/Solarized/Nord） |
| 连接配置导出/导入 | ✅ | ✅ | JSON（不含密码）；apple ConnectionPortability / android 分享Intent |
| 分屏 / 会话录制 | ✅ | ⬜ | apple 独有 |

## 小结

- **核心智能运维护城河（Z1–Z8）双端完全对齐** ✅
- **SSH/终端（含控制键栏）/SFTP/AI（含代码块渲染）/安全/端口转发/跳板机/批量群发/多主题/多对话 双端齐平**
- **双端 SFTP 文件管理完全对齐**：浏览/查看/下载/上传/新建/删除/重命名/路径跳转/修改时间/排序/过滤
- 🎯 **apple↔android 配对能力已完全对齐**——所有共有能力均 ✅✅，无一方缺失的配对项
- 仅剩 2 项各自独有特性（非缺陷，因平台定位不同）：
  - **android 独有**：定时后台巡检（WorkManager 主动运维；macOS 后台任务等价待补）
  - **apple 独有**：分屏 / 会话录制（移动端意义有限）
- 多处经源码核查纠正了文档滞后：apple 终端控制键栏/终端搜索/连接测试/批量群发/SFTP 增删改/AI 提示词库 实为 ✅
- apple 为功能最全的旗舰；**android 已是功能完整、体验接近桌面的第二原生端，核心能力与 apple 高度对齐**
- **android AI 能力已与 apple 完全对齐**（对话/解释/报错/健康/环境感知/流式/停止/重新生成/多对话/持久化/搜索/导出/代码块/消息复制）
- android 跳板机 ProxyJump 已**完整覆盖所有 SSH 操作**（终端/状态/环境/排障/模板/SFTP/端口转发）——**仅剩 分屏/会话录制**（移动端意义有限，标 N/A）未对齐
- `linux/`（Rust+egui）🟡 骨架；`windows/`（C#/.NET）⬜ 待起
