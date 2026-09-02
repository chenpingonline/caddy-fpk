# FnProxy 0.1.0

FnProxy 是一个面向飞牛 fnOS 的原生 Nginx 反向代理可视化管理应用。

它自带独立的 Nginx Open Source 1.30.4，不读取、不修改、也不会重启飞牛系统 Nginx；不依赖 Docker，管理后台通过 fnOS 统一网关和 Unix Socket 提供。

## 首版能力

- HTTP 与手动证书 HTTPS 反向代理
- 多域名、独立监听端口、默认站点 `*`
- WebSocket、SSE/流式传输、大文件请求体
- 上游 HTTP/HTTPS、上游 TLS 校验开关
- Nginx 配置生成与 `nginx -t` 预检
- 原子替换、平滑 reload、激活失败自动回滚
- 配置历史与恢复为草稿
- Nginx 访问日志、错误日志、管理服务日志
- 管理员 Header 校验与变更请求标识
- 普通 `fnproxy` package 用户运行
- x86_64 原生 FPK，不依赖 Docker

## 安装

1. 下载 `fnproxy-0.1.0-x86.fpk`。
2. 在 fnOS 应用中心选择手动安装。
3. 安装完成后，从桌面打开 FnProxy。
4. 添加代理规则并点击“保存并应用”。

默认无规则时，独立 Nginx 监听 `9080` 并返回 404。第一版仅允许配置 `1024–65535` 端口，因此不需要 root 权限。

需要公网标准端口时，可在路由器中配置：

```text
公网 80  -> NAS 9080（或自定义 HTTP 高位端口）
公网 443 -> NAS 9443（或自定义 HTTPS 高位端口）
```

## 与系统 Nginx 的隔离

FnProxy 只使用自己的目录：

```text
TRIM_APPDEST/bin/nginx          独立 Nginx 二进制
TRIM_PKGETC/nginx/              生成的 Nginx 配置
TRIM_PKGVAR/nginx/              PID 与兼容运行目录
TRIM_PKGVAR/certificates/       证书与私钥
TRIM_PKGVAR/logs/               应用日志
TRIM_PKGTMP/nginx/              代理临时文件
TRIM_APPDEST/app.sock           fnOS 统一网关 Socket
```

不会访问：

```text
/etc/nginx
/usr/trim/nginx
/var/run/nginx.pid
systemctl restart nginx
```

## 当前限制

- 首版只提供 x86_64 包。
- 不直接监听 80/443，不申请 root 或 `CAP_NET_BIND_SERVICE`。
- HTTPS 证书目前需要手动导入 PEM；尚未内置 ACME 自动申请与续签。
- 尚未提供 TCP/UDP Stream、复杂 location、正则 rewrite、缓存和任意原始 Nginx 指令编辑。
- 内置 Nginx 为 Debian 12 x86_64 构建，动态依赖 `libcrypt.so.1`、PCRE2、OpenSSL 3、zlib、zstd 和 glibc。安装回调会预检二进制及配置，缺少运行库时会停止安装并给出日志，而不会调用系统 Nginx。

## 本地构建

要求：Go 1.22+、GNU tar、Python 3、Linux x86_64（用于完整集成测试）。

```bash
./scripts/build.sh
```

输出：

```text
dist/fnproxy-0.1.0-x86.fpk
```

完整集成测试：

```bash
./tests/integration.sh
```

测试会启动临时管理服务、独立 Nginx、HTTP 上游，生成临时自签名证书，并验证 HTTP 与 HTTPS 反向代理、配置应用、历史版本和 `nginx -t`。

## 重建 Nginx

在 Debian 12 amd64 环境中执行：

```bash
./scripts/build-nginx.sh
```

脚本从 Nginx 官方站点下载 `nginx-1.30.4.tar.gz`，启用 SSL、HTTP/2、realip、stub_status、auth_request 和 PCRE JIT。更换二进制后，需要同步更新 `scripts/build.sh` 中的 SHA-256 固定值。

## 安全说明

- 管理 API 仅通过 fnOS 统一网关访问，后端只监听 Unix Socket。
- 非本地开发模式下，API 要求 `X-Trim-Isadmin` 管理员标识。
- 所有修改请求还要求 `X-FnProxy-Request: 1`。
- 证书私钥不会通过查询接口返回；目录权限为 0700，文件权限为 0600。
- 网页只接收结构化配置，不允许直接执行用户输入的 Shell 或任意 Nginx 指令。
- 保存配置时先在隔离目录执行 `nginx -t`，再原子切换并平滑重载。

## 许可证

FnProxy 源码使用 MIT License。Nginx Open Source 使用两条款 BSD 许可证，详见 `NGINX_LICENSE` 和 `THIRD_PARTY_LICENSES.md`。
