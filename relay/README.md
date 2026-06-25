# AI Terminal — WebSocket → SSH 中继

让移动端（Capacitor）/ 纯网页也能连 SSH：浏览器经 WebSocket 连到本中继，中继用 `ssh2` 连到目标主机并双向桥接字节。

## 运行

```bash
cd relay
npm install        # 安装 ws + ssh2
npm start          # 默认监听 ws://localhost:8022（PORT 可改）
```

然后在 `mobile/www/terminal.html`（或部署后的 App）里填中继地址 `ws://<你的主机>:8022` + 目标 host/port/user/password 即可连。

## 协议（JSON 文本帧）

- client → relay：
  - `{"t":"open","host","port","username","password"|"privateKey","cols","rows"}`
  - `{"t":"data","d":"<utf8 输入>"}`
  - `{"t":"resize","cols","rows"}`
- relay → client：
  - `{"t":"status","s":"connecting|connected|error|closed","msg"?}`
  - `{"t":"data","d":"<base64 输出>"}`

## ⚠️ 安全须知（务必阅读）

本中继**会接收客户端传来的 SSH 凭据并代为连接**。默认实现没有鉴权、没有 TLS，**只可用于自托管 / 本机 / 可信内网**。公网部署前至少要做：

1. **wss（TLS）**：放在反向代理（nginx/caddy）后或用 `https.createServer` + 证书，避免凭据明文走网络。
2. **鉴权**：给中继加 token / 账号校验，防止被人当跳板。
3. **目标白名单**：限制可连的 host/端口，防 SSRF。
4. 不要把中继暴露到公网而不加以上防护。

移动端 SSH 的另一条路线是 **Capacitor 原生插件**（Android JSch/sshj、iOS Citadel），无需中继但要写原生代码；中继方案的优点是纯 JS、跨端一致、易自托管。
