# CI 在线编译配置

本目录暂存 GitHub Actions workflow（[`github-actions-ci.yml`](github-actions-ci.yml)）。

## 为什么不直接放 `.github/workflows/`

当前 git 凭据的 OAuth token 只有 `repo` scope，**缺 `workflow` scope**，GitHub 拒绝推送 `.github/workflows/` 下的文件：

```
! [remote rejected] refusing to allow an OAuth App to create or update workflow
  `.github/workflows/ci.yml` without `workflow` scope
```

## 激活步骤（需用户授权一次）

1. 授权 `workflow` scope（在本会话用 `!` 前缀运行，会弹设备码授权）：
   ```
   gh auth refresh -s workflow
   ```
2. 授权后告诉我，我会把 `ci/github-actions-ci.yml` 移到 `.github/workflows/ci.yml` 并推送。
3. 之后用 tag 触发在线编译：
   ```
   git tag ci-100 && git push origin ci-100   # 每 100 迭代打一个 ci-N tag
   ```
   或在 GitHub Actions 页面手动 `Run workflow`。

## CI 覆盖（matrix）

| Job | Runner | 内容 |
|-----|--------|------|
| apple | macos-latest | `swift build`（Core + App）+ 8 项核心自测 |
| android | ubuntu-latest | gradle 8.13 `assembleDebug` + 上传 APK 产物 |
| linux | ubuntu-latest | Rust `cargo build --release`（骨架阶段 continue-on-error）|
| windows | windows-latest | `.NET build`（待 `windows/` 端建立后启用，当前注释）|

## 「每 100 迭代 CI 一次」节奏

按用户要求：**全平台（mac/iOS/Linux/Windows/Android）开发对齐后打节点**，从节点起每 100 次迭代推一个 `ci-N` tag 触发在线编译，监控结果，无报错继续迭代。
