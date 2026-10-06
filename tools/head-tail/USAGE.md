# head-tail —— 长日志折叠：头 30 行 + 尾 30 行（省 Context Token）

读 stdin：**60 行以内原样输出**；超过时输出前 30 行 + 折叠提示 + 后 30 行。
给 Agent 看长日志的标准前处理——不爆上下文，又不丢头尾关键现场。

折叠提示行格式（前后各一空行）：

```
... [已自动折叠 N 行长日志以节省 Context Token] ...
```

## 推荐用法

```sh
# 1) 长输出直接折叠
some_cmd | head-tail

# 2) 折叠已有日志文件
head-tail < big.log

# 3) 与 chronic 组合：成功静默 / 失败回放 / 输出折叠
chronic timeout 30s sh -c 'big_job' < /dev/null | head-tail

# 4) 与 strip-ansi 串联：先洗 ANSI 再折叠
strip-ansi < raw.log | head-tail

# 5) 60 行以内不受影响（原样透传，rc=0）
seq 1 60 | head-tail

# 6) 版本 / 帮助
head-tail --version                               # head-tail 1.0
head-tail --help
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `--version` | 打印版本（rc=0） |
| `-h` / `--help` | 帮助（rc=0） |

固定 30/30 行、无其他参数——保持"永远同样的折叠行为"，便于 Agent 预判输出规模。

## 退出码 / 错误处理

- 正常 rc=0；stdout 写失败 rc=1。
- 60 行及以内：输出与输入**逐字节一致**（可直接重定向存档）。

## iSH 注意事项

- 行缓冲 4096 字节：**超长行（>4095 字节）会被切块计作多"行"**（日志通常不会这么长；
  二进制大文件不要用本工具）。
- 二进制**禁用了 UPX**：arm64 压缩版在 iSH 上会段错误（未压缩版正常，体积 +6KB 可忽略）。
- 内存固定约 240KB（static 缓冲、零动态分配），任意大输入不会 OOM。
- 环形缓冲按插入序回放，尾部 30 行顺序正确（有 1000 行折叠的逐行断言测试）。

## 相关工具

- `strip-ansi` —— 先洗 ANSI 转义再折叠（推荐串联：`strip-ansi < raw | head-tail`）
- `chronic` —— 管"失败才回放"；本工具管"成功了但输出太长"
- `tini` —— 需要信号转发/守候时用它
