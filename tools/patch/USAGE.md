# patch —— 按 diff 补丁就地修改文件

GNU patch 2.8（全静态 aarch64）。把 `diff` 生成的补丁**就地**打进工作目录，支持先干跑、可反向撤销、失败片段单独存 `.rej`。改几行代码/配置时用它；单文件纯字符串替换用 `sd` 更直接。

## 推荐用法

```sh
# 1) 生成标准补丁：-ruN = 递归 + 含新文件 + 统一格式
#    （有差异时 diff 退出码是 1，这是正常信号，不是错误）
diff -ruN old new > change.patch

# 2) 干跑：在 old 的副本目录里试打，只打印会做什么、不动文件
cp -r old work && cd work
patch -p1 --dry-run < ../change.patch     # 输出 "checking file a.txt"

# 3) 正式打：目录差了一层用 -p1，剥掉 old//new/ 前缀
patch -p1 < ../change.patch               # 输出 "patching file a.txt"
cat a.txt

# 4) 用 -i 指定补丁文件（不打 stdin 时）
patch -p0 -i fix.patch

# 5) 打错了？-R 反向撤销
patch -R -p1 -i change.patch
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-p NUM` | 剥掉路径前 NUM 层（`diff -ruN old new` 出的补丁配 `-p1`；手工补丁配 `-p0`） |
| `-i FILE` | 从 FILE 读补丁（默认读 stdin） |
| `--dry-run` | 只检查不落盘，先跑这个 |
| `-R` | 反向应用（撤销已打的补丁） |
| `<ORIGFILE [PATCHFILE]>` | 位置参数：目标文件 + 补丁文件 |

## 退出码 / 错误处理

- `0` = 成功（`--dry-run` 全部可打也是 0）
- `1` = 有 hunk 打不上：会打印 `Hunk #1 FAILED at 1.`，并把拒绝片段存成 `xxx.rej`，原文件保持不动
- 生成端注意：`diff -ruN` 在"有差异"时退出码也是 1，判断生成是否出错要看输出

## iSH 注意事项

- 补丁层级要配对：`diff -ruN old new` 生成、在 old 副本里打 → `-p1`；手工写的 `--- f.txt +++ f.txt` → `-p0`（两者均本机实测）。
- 逐 hunk 匹配：源文件被改过就会 FAILED，先 `--dry-run` 基本能避免半途踩坑。
- 目录树的补丁输出较长，先干跑、确认"checking file"行数量再打。
- 无已知平台坑；GNU patch 是全静态二进制，不依赖 apk。

## 相关工具

- `diff` —— 生成补丁的源头（busybox 版 `-ruN` 实测可用）
- `sd` —— 简单正则替换直接改文件，不用绕补丁
- `sponge` —— 管道就地落盘（配合 grep/sed 改文件）
