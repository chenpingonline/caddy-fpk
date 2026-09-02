# FnProxy 0.1.0 for fnOS

> **项目状态说明**：此仓库当前提交对应已经生成的 **FnProxy 0.1.0** 安装包，代理内核是独立运行的 **Nginx Open Source 1.30.4**，并不是 Caddy。仓库名称虽然是 `caddy-fpk`，但当前代码不能被描述为 Caddy 版本。

FnProxy 是一个面向飞牛 fnOS 的原生 HTTP/HTTPS 反向代理可视化管理应用。它不读取、不修改、也不会重启飞牛系统自带的 Nginx；不依赖 Docker，管理后台通过 fnOS 统一网关和 Unix Socket 提供。

## 当前能力

- HTTP 与手动证书 HTTPS 反向代理
- 多域名、独立监听端口、默认站点 `*`
- WebSocket、SSE/流式传输、大文件请求体
- 上游 HTTP/HTTPS、上游 TLS 校验开关
- Nginx 配置生成与 `nginx -t` 预检
- 原子替换、平滑 reload、激活失败自动回滚
- 配置历史与恢复为草稿
- Nginx 访问日志、错误日志、管理服务日志
- 管理员 Header 校验与写操作请求标识
- 普通 `fnproxy` package 用户运行
- x86_64 与 ARM64/AArch64 FPK 构建入口

## 与系统 Nginx 隔离

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

不会操作：

```text
/etc/nginx
/usr/trim/nginx
/var/run/nginx.pid
systemctl restart nginx
```

## 构建环境

需要：

- Go 1.22+
- GNU tar
- Python 3
- `file`、`strings`、`sha256sum`
- 对应架构的 Nginx 1.30.4 可执行文件

第三方可执行文件和 `.fpk` 产物不提交到源码仓库。先在目标架构 Linux 主机上从 Nginx 官方源码构建内核：

```bash
# x86_64 主机
./scripts/build-nginx.sh x86

# ARM64/AArch64 主机
./scripts/build-nginx.sh arm64
```

然后构建 FPK：

```bash
./scripts/build.sh x86
./scripts/build.sh arm64
```

输出：

```text
dist/fnproxy-0.1.0-x86.fpk
dist/fnproxy-0.1.0-arm64.fpk
```

也可以提供已有的对应架构 Nginx：

```bash
FNPROXY_NGINX_BIN=/path/to/nginx ./scripts/build.sh arm64
```

## 测试

无需 Nginx 的检查：

```bash
go test ./...
node --check web/app.js
bash -n scripts/*.sh fnos/cmd/* tests/*.sh
```

x86_64 完整集成测试：

```bash
./tests/integration.sh
```

测试会启动临时管理服务、独立 Nginx、HTTP 上游，生成临时自签名证书，并验证 HTTP/HTTPS 反向代理、证书导入、配置应用、历史版本和 `nginx -t`。

## 当前限制

- 不直接监听 80/443，不申请 root 或 `CAP_NET_BIND_SERVICE`。
- HTTPS 证书需要手动导入 PEM，尚未内置 ACME 自动申请与续签。
- 当前管理界面尚未提供 TCP/UDP Stream、复杂 `location`、正则 rewrite、缓存和任意原始 Nginx 指令编辑。
- ARM64 包只支持 64 位 ARMv8/AArch64，不支持 ARMv7/32 位。
- ARM64 版本尚未在真实 ARM64 fnOS NAS 上完成安装验证。

## 安全设计

- 管理 API 仅通过 fnOS 统一网关访问，后端只监听 Unix Socket。
- 非本地开发模式下，API 要求 `X-Trim-Isadmin` 管理员标识。
- 所有修改请求要求 `X-FnProxy-Request: 1`。
- 证书私钥不会通过查询接口返回；目录权限为 0700，文件权限为 0600。
- 网页只接收结构化配置，不允许执行用户输入的 Shell 或任意 Nginx 指令。
- 保存配置时先在隔离目录执行 `nginx -t`，再原子切换并平滑重载。

## 许可证

FnProxy 源码使用 MIT License。Nginx Open Source 使用两条款 BSD 许可证，详见 `NGINX_LICENSE` 与 `THIRD_PARTY_LICENSES.md`。
