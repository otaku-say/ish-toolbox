# curl —— HTTP(S) 客户端（内嵌 CA，随工具箱分发）

curl 8.22.0 + LibreSSL 4.3.3，内嵌 CA 证书 121 张（`--dump-ca-embed` 可导出），不依赖系统证书目录；支持 HTTP/2、代理、brotli/zstd。默认不跟随重定向、对 4xx/5xx 也返回 0——脚本里注意按需 `-L` / `-f`。

## 推荐用法

```sh
# 1) 探活：只看状态码/耗时（-o /dev/null 丢掉正文）
curl -s -o /dev/null -w 'code=%{http_code} time=%{time_total}\n' https://example.com
# code=200 time=0.53...（网络波动）

# 2) 跟随重定向（默认不跟），并看到最终 URL
curl -sL -o /dev/null -w '%{url_effective}\n' http://github.com/
# → https://github.com/

# 3) 4xx/5xx 当失败处理：-f 时 404 → 退出码 22
curl -sf -o /dev/null https://example.com/nope404; echo $?
# 22

# 4) 只取响应头
curl -sI https://example.com | head -5

# 5) POST 表单（-d 自动 Content-Type: form-urlencoded）
curl -s -d 'name=minis' -H 'X-Test: yes' https://httpbingo.org/post

# 6) 限时：-m 秒（--max-time 等价），超时退出码 28
curl -s -m 3 -o /dev/null http://10.255.255.1/; echo $?
# 28
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-s` | 静默（去进度/错误信息） |
| `-o FILE` | 输出到文件；丢内容用 `/dev/null` |
| `-w FMT` | 输出格式化信息（`%{http_code}`、`%{time_total}`、`%{url_effective}`） |
| `-L` | 跟随重定向 |
| `-f` | HTTP ≥400 视为失败（退出码 22） |
| `-I` | 只取响应头（HEAD 请求） |
| `-d DATA` | POST 表单数据 |
| `-H 'K: V'` | 自定义请求头 |
| `-m N` / `--max-time N` | 整个请求最长 N 秒 |
| `-q` | 不读 `.curlrc`（脚本里建议明确加上） |
| `--dump-ca-embed` | 导出内嵌 CA（实测 121 张） |

## 退出码 / 错误处理

- `0` = HTTP 事务完成（**包括 404**，除非加 `-f`）
- `6` = DNS 解析失败；`7` = 连接被拒；`22` = `-f` 下 HTTP ≥400；`28` = `--max-time` 超时（均为实测）
- 更多错误码参考 `curl --help all`

## iSH 注意事项

- HTTPS 直接可用：CA 是内嵌的（约 121 张），**不要动系统证书目录**、也不用配 `--cacert`。
- 两个默认行为是脚本惯犯陷阱：不跟重定向（要 `-L`）、404 也退 0（要 `-f`）。
- `-q` 禁用 `.curlrc`；本机 HOME=/root 下无 .curlrc（实测），加上 `-q` 无副作用、防未来配置干扰。
- 下载大文件用 `-o` 落盘，别打屏；iSH 单核 IO，大文件慢。

## 相关工具

- `doggo` —— HTTP 之前先做 DNS 查询
- `openssl s_client` —— 查证书链/到期时间
