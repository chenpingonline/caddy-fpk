# ARM64 Nginx core

The executable is intentionally not committed to the source repository.

Build it natively on an ARM64/AArch64 Debian/Ubuntu host:

```bash
./scripts/build-nginx.sh arm64
```

Expected output path:

```text
third_party/nginx/arm64/nginx
```

The FnProxy 0.1.0 ARM64 test package used a statically linked Nginx 1.30.4 binary with:

```text
SHA-1:   2b0552b6c640711768836d61dc7282c0066a08ac
SHA-256: 3c7d9e6776b1bbeb1e125a6e25a98578de7d0dff2b0939c5b3b9d590efb9ee8e
```

See `NGINX_ARM64_SOURCES.txt` for the exact source-input list embedded in that package.
