# sd —— 正则查找替换（sed 的 s/// 替代，v1.0.0）

`sd '查找' '替换' [文件...]`，查找是正则（`-F` 改字面量），替换里可用 `$1` 捕获组。
**行为分两种**：不带文件参数时读 stdin 写 stdout（当过滤器）；带文件参数时**默认就地改写**。
注意本机 v1.0.0 没有 `-i` 选项，就地改写也**没有备份**。

## 推荐用法

```sh
# stdin → stdout（过滤器，不动文件）
printf 'hello\n' | sd 'hell' 'yell'

# 预览：只打印替换后的结果，不改文件
sd -p 'cat' 'dog' notes.txt

# 就地改写（先 -p 预览，或先 cp 备份）
cp notes.txt notes.txt.bak
sd 'cat' 'dog' notes.txt

# 字面量替换（. * [ ] 不当正则）
printf 'a.b.c\n' | sd -F '.' '!'

# 忽略大小写 / 整词匹配（-f 可组合，如 c e i m s w）
sd -f i 'cat' 'dog' f.txt
sd -f w 'cat' 'dog' f.txt

# 捕获组（$1）
sd 'name=(\w+)' 'user:$1' f.txt

# 限制每文件替换次数 / 跨行匹配
sd -n 2 'x' 'y' f.txt
sd -A 'a\nb' 'AB' f.txt
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-p` | 预览替换结果（不改文件） |
| `-F` | 查找/替换按字面量处理 |
| `-n N` | 每文件最多替换 N 次（0 = 不限） |
| `-f FLAGS` | 正则旗标：`i` 忽略大小写、`w` 整词、`m` 多行等 |
| `-A` | 把整个输入当整体匹配（可跨行） |
| `-h` / `-V` | 帮助 / 版本 |

## 退出码

- `0` = 执行完成（**包括没有匹配**，实测）
- 选项用错（如旧教程里的 `-i`）→ 报 `unexpected argument` 后退出（实测 rc=2）

## iSH 注意事项

- **本机 v1.0.0 没有 `-i`**：`sd -i ...` 直接报 `error: unexpected argument '-i' found`（实测）。
  旧版 sd「默认输出 stdout、要 `-i` 才就地改」的教程不适用本机——**传文件就就地改**。
- 就地改写不留备份、失败了没得恢复：先 `-p` 预览或先 `cp`。
- 写文件模式下 stdout 是空的，属正常；只有 stdin 模式才往 stdout 打印结果。
- 全静态 aarch64 二进制，不依赖 apk 包。

## 相关工具

- `rg` —— 替换前先定位
- `jaq` —— 改 JSON 里的值而不是盲替换文本
- `busybox sed` —— 只做简单替换时的备胎
