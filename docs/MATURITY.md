# Termind 产品成熟度总览

> 截至 PARITY 100 项里程碑（双端共有能力 100 项全对齐，🟡=0）。
> 本文档如实记录当前能力与边界，定位见 [PRODUCT.md](PRODUCT.md)，配对明细见 [PARITY.md](PARITY.md)。

> 🎯 **2026-06-28 里程碑：用户全部需求实现**。智能运维全平台落地（windows/linux 双端全模块真实，能力达 apple 标杆）+ AI 三模式（Chat/Agent/Auto 自主闭环，五端）+ AI 接管终端 + 系统级运维提示词 + 护城河（Z1-Z3 一键真闭环/风险四级/batch 批量，五端一致）+ SFTP 全覆盖（windows/linux 浏览/导航/预览/下载/上传/删除/新建目录/重命名）+ 连接 CRUD + 终端 ANSI 彩色 + 配置全持久化 + **UI 品质 U1-U4 全完成五端**（U1 图标库去 emoji / U2 配色协调 / U3 主题切换 apple 5套·linux 4套·windows 4套实时+持久化 / U4 字号可调+持久化）。CHANGELOG 23 阶段，884 提交。

> 📊 **2026-06-28 运维监控套件成型**（windows/linux 双端）：状态条实时聚合（CPU/内存/磁盘/负载 SSH 取 + 30s 定时刷新 + >90% 超阈值告警 + 服务 systemctl 状态）→ 异常时一键下钻明细：进程 Top（ps 高占用，windows 可右键 kill）/ 网络端口（ss 监听 + 进程）/ 磁盘分区（df 全分区）。配合服务管理（点击启停/重启）、运维快捷入口（Z1 解释/Z2 报错/Z3 巡检一键真闭环）、批量群发、搜索（连接/终端/AI）、导出（终端/AI）、定制（快捷命令/追问），构成完整智能运维监控-诊断-处置链路。CHANGELOG 35 阶段，958 提交。

## ① 平台覆盖

> 🏆 2026-06-27 更新：**五端全平台本机编译全部打通**（本机 Xcode 26.4 / Rust 1.96 / .NET 9.0.315 齐全，关键是系统代理端口 1082 走国外 + 用国外官方源）。

| 平台 | 技术栈 | 状态 | 说明 |
|------|--------|------|------|
| macOS | Swift/SwiftUI + Citadel + SwiftTerm | ✅ **xcodebuild 出 .app** | `swift build` + 18 自测 + `xcodebuild` BUILD SUCCEEDED 出 `AITerminal.app` 并 `open` 运行成功 |
| iOS/iPadOS | 同上 | ✅ 可构建 | 共用 apple/ 源码 + 同 xcodeproj（scheme `AITerminal (iOS)`）；真机需签名 |
| Android | Kotlin/Compose + sshj + OkHttp | ✅ 出 APK | `gradle assembleDebug` 出 ~21MB APK，**零 deprecated/零 warning** |
| Linux | Rust + egui/eframe | ✅ **cargo 编译** | `cargo build` 出 `termind` 15MB 二进制；三栏工作台 UI；真机运行验证留 CI/真 Linux（egui icrate 在 macOS 26 有兼容 bug） |
| Windows | C#/.NET 9 + Avalonia | ✅ **dotnet 编译+运行** | `dotnet build` 0 错误 + `dotnet run` 在 mac 上运行真界面（Avalonia 跨平台）；三栏工作台 UI |

## ② 主线能力（双端齐平）

- **SSH/终端**：密码 + 私钥认证 · 交互式彩色 PTY · 18 键工具栏 · 终端搜索 · 字号调节 · ANSI 渲染 · 自动滚动 · 跳板机 · 端口转发
- **SFTP**：浏览 · 查看 · 上传 · 下载 · 增删改 · 批量删除/下载 · 排序过滤
- **AI 对话**：流式 + 停止 + 重生成 + 重发 · 多对话（新建/切换/删除/清空/**重命名**/全局搜索）· 消息时间戳 · 提示词 25 条 · 解释/报错/健康分析
- **连接管理（18+ 维度）**：增删改 · 分组/折叠 · 颜色标签 · 端口/必填校验 · 批量编辑 · 多选 · 最近使用 · 克隆 · 导入导出 · SSH config 导入 · 二维码 · 复制配置 · 复制连接串 · 可达性探测 · 启动命令

## ③ 护城河 Z1–Z8（差异化核心，双端齐）

| 项 | 能力 |
|----|------|
| Z1 命令解释 | 执行前解释命令意图 |
| Z2 报错分析 | 结合输出分析报错 |
| Z3 环境感知 | 探测 OS/服务/项目类型 |
| Z4 排障工作流 | **11 场景**：网站/磁盘/SSL/Nginx/Docker/内存/端口/服务/定时任务/日志异常/防火墙 |
| Z5 操作回滚 | 关键配置改动前备份 + 时间线回滚 |
| Z6 状态面板 | CPU/内存/磁盘/负载/运行时长/服务 6 维 |
| Z7 风险分级/脱敏 | 命令四级风险 + 敏感信息脱敏 |
| Z8 初始化模板 | **11 模板**：Ubuntu Web/Docker/Node/静态站/LNMP/Redis/PostgreSQL/Python/MongoDB/Caddy/监控 |

护城河特性：所有 AI 路径都**结合本机真实环境 + 历史知识卡片**给针对性结论；诊断命令只读、部署命令风险标注 + 执行前预览。

## ④ 批量运维（运维工作台杀手级，单连接工具做不到）

- 命令历史（去重/置顶/收藏）
- 批量群发命令（并发 + 成功/失败统计 + 导出 + AI 汇总）
- 批量健康巡检（并发采集 + 告警置顶 + 统计 + **仅告警筛选** + 导出 + AI 总结）
- 定时后台巡检（android WorkManager 可达性通知）

## ⑤ 知识沉淀闭环（护城河核心）

- **录入（全入口）**：手动（类型 + 标签）· 随手记 · AI 结论存方案（覆盖全 AI 路径：对话/解释/报错/排障/健康）· 任意消息存卡片
- **检索（三维）**：类型筛选 + 标签筛选 + 关键词搜索
- **应用**：喂 AI 全路径（注入本机历史）
- **流转**：导入导出对称（连接配置 JSON / 知识卡片 Markdown / 快捷命令 Markdown）

## ⑥ 质量

- **双端配对能力 100 项全对齐**（PARITY 🟡=0；仅余 2 项各自独有：android 定时后台巡检 / apple 分屏录制，平台定位差异非缺陷）
- **18 项自测基线**：连接/AI/持久化/巡检/排障/模板/回滚/风险/指标/收藏/知识卡片，每轮回归
- apple `swift build` 必过 + android `gradle` 零 deprecated/零 warning

## ⑦ 已知边界（如实）

- 五端**编译**已全部本机打通，**UI 设计语言高度一致**（47+ 项 UI 现代化，多数五端对齐）。windows/linux 端 UI 已对齐 apple/android **全功能区**（连接列表[色条/状态点/名称/地址/备注/可达/最近使用] + 状态面板[CPU/内存进度条/服务状态点] + 终端区[快捷命令栏/可滚动输出] + AI 面板[角色标签/气泡/代码块/快捷追问/输入框/多轮] + 设置页[主题/AI服务商/API Key/模型] + SFTP 文件浏览[类型图标/大小]）。
- **🎯 智能运维全平台真实落地（2026-06-27 更新）**：windows/linux 已从「完整 UI + mock」→ **真实 AI（windows HttpClient / linux ureq 调 Anthropic 兼容接口）+ 真实 SSH（windows SSH.NET / linux ssh2 连真实服务器 exec）+ AI 三模式（Chat/Agent/Auto）+ Z3 环境感知 + 危险命令拦截**，能力体系与 apple/android 一致，端到端验证（真实 AI 接口 + 真实测试服务器）。apple/android 仍最完整（护城河 Z1-Z8 + 批量运维 + 知识沉淀闭环）。
- **AI 三模式五端对齐**：Chat（纯聊天）/ Agent（每条确认放行）/ Auto（自主闭环 agent loop，读输出→决策→执行→回喂），安全梯度——危险命令各端强制确认不被 Auto 绕过。windows 更有 Auto 自主闭环。
- **边界**：windows/linux 整 app 真机运行验证：windows mac 上 dotnet run 已端到端跑通；linux 因 egui/icrate macOS 26 兼容 bug 在 mac 不能整体 run，但真实 AI/SSH 逻辑已在 mac 独立端到端验证，等真 Linux/CI 整体运行。
- iOS 真机/上架需 Apple 开发者签名；linux 端真机运行验证留 CI/真 Linux（egui 依赖 icrate 0.0.4 在 macOS 26 有 NSScreen 兼容 bug，仅影响 mac 上运行，不影响编译与真 Linux）。
- 工具链下载依赖系统代理（端口 1082 走国外）+ 国外官方源；无代理或仅国内镜像时大文件下载会失败。
- 移动/网页 SSH 中继（`relay/`）需自托管，仅可信网络。
- 私钥/密码临时输入**不持久化**；导出**不含密码**；诊断命令**只读**。
