# FN Caddy Manager 0.1.0

本版本已重建为真正的 Caddy 架构：HTTP/HTTPS、WebSocket、SSE 和自动 HTTPS 由官方标准版 Caddy 2.11.4 提供；MySQL、PostgreSQL、Redis、SSH 和自定义协议由内置 Go 原始 TCP 代理处理，不依赖实验性的 caddy-l4。

## 默认端口

- 管理页面：18088
- Caddy Admin API：127.0.0.1:20191
- Caddy HTTP：9080
- Caddy HTTPS：9443

## 已完成验证

- Go 单元测试和 go vet
- JavaScript、Python、Shell 静态检查
- 真实 Caddy HTTP、手动 HTTPS、管理 API 和 TCP 回显联调
- 配置验证、应用、Admin 地址切换和失败回滚
- x86_64 FPK 生命周期模拟
- x86_64 与 ARM64 FPK 的 manifest、app.tgz MD5、脚本权限及 ELF 架构校验

## 真机边界

ARM64 包已完成 ELF64 AArch64 和包结构校验，但未在本次构建会话中原生运行。两个 FPK 都仍需在真实 fnOS 应用中心做最终安装确认。公网自动 HTTPS 需要公网 80/443 正确到达 Caddy 的内部端口；标准 Caddy 构建没有 DNS Provider 插件，因此本版本拒绝通配符自动证书配置，手动通配符证书不受影响。
