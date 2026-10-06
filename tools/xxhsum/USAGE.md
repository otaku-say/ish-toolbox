# xxhsum —— xxHash 校验和（快、非加密）

xxHash 官方 CLI：生成/校验文件的 xxHash 值。比 md5/sha 快一个数量级的
**非加密**散列，适合大文件完整性、管道校验、去重指纹。

## 推荐用法

```sh
# 1) 单文件（默认 XXH64）
xxhsum big.iso
#   输出：<hash>  big.iso

# 2) 选择算法
xxhsum -H0 file     # XXH32
xxhsum -H2 file     # XXH128
xxhsum -H3 file     # XXH3（最新，最快）

# 3) 批量 + 校验
find . -type f -exec xxhsum {} + > SUMS
xxhsum -c SUMS      # 逐条校验并汇总 OK/FAILED

# 4) 管道
tar czf - dir/ | xxhsum

# 5) BSD 风格输出（--tag）
xxhsum --tag file

# 6) 版本
xxhsum --version    # xxhsum 0.8.4
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-H0/1/2/3` | XXH32 / XXH64（默认）/ XXH128 / XXH3 |
| `-c`, `--check` | 读取校验和文件并校验 |
| `--tag` | BSD 风格（`XXH64 (file) = hash`） |
| `-` | 强制 stdin（即使终端） |
| `-h` / `--help` | 长帮助（含高级选项） |
| `-V` / `--version` | 版本 |

## 退出码 / 错误处理

- 0 全部成功；非 0 有失败项（校验不匹配等）。
- ⚠️ **非加密哈希**：防意外损坏可以，不防恶意篡改。安全场景用 `openssl dgst -sha256`。

## iSH 注意事项

- 本套件为**自编译静态**（官方 v0.8.4 源码）；真机可用。
- 输出格式与 coreutils 的 `*sum` 工具不同（无 `*`/` ` 指示符差异要注意）；
  交换场景优先 `--tag` 或直接贴 hash 列。

## 相关工具

- `openssl` —— 需要加密哈希（SHA-256 等）或签名时用它
- `diffstat` / `patch` —— 补丁工作流前后固化文件指纹
- `curl` / `scp` —— 传输前后各跑一次对比
