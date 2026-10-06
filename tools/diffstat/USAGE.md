# diffstat —— diff 统计（每个文件改了多少行）

读 `diff`（含 `diff -u`、`git diff`）的输出，产出"每个文件 +/- 行数"的直方图。
审查补丁、日报变更量、CI 摘要的常用件。

## 推荐用法

```sh
# 1) 给 diff 管道加统计
diff -ruN old/ new/ | diffstat

# 2) git 工作区改动统计
git diff | diffstat
git diff --cached | diffstat

# 3) 直接读补丁文件
diffstat fix.patch

# 4) 彩色输出（配 strip-ansi 或终端直接看）
diffstat -C fix.patch

# 5) 只看文件名清单 / 合并改名
diffstat -l fix.patch
diffstat -k fix.patch

# 6) 版本
diffstat --version      # diffstat version 1.69
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-f NUM` | 格式：0=简洁 1=常规 2=填充 4=纯数值 |
| `-C` | 直方图带 ANSI 颜色 |
| `-p NUM` | 文件名剥掉 NUM 层路径前缀 |
| `-l` | 只列文件名 |
| `-k` | 不改名合并（默认会把重命名合并） |
| `-m` | 插入/删除按块合并为"修改行数" |
| `-q` | 空 diff 不打印 "0 files changed" |
| `-b` | 忽略 "Binary files differ" 行 |
| `-n NUM` / `-N NUM` | 文件名列最小/最大宽度 |
| `-o FILE` / `-e FILE` | stdout / stderr 重定向 |

## 退出码 / 错误处理

- 0 成功；非 0 失败（输入不是 diff 等）。
- 输入为管道时按流式处理，超大 diff 也稳。

## iSH 注意事项

- 本套件为**自编译静态**（Dickey 原版）；真机可用。
- `-C` 的彩色转义在管道/存文件时是垃圾——要么去掉 `-C`，要么再接
  `strip-ansi` 洗一遍。

## 相关工具

- `patch` —— 应用补丁（diffstat 看规模，patch 干实际活）
- `strip-ansi` —— 洗掉 `-C` 的颜色转义
- `xxhsum` —— 补丁前后做文件校验
