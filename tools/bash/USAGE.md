# bash（5.3，全静态）

> 一行定位：GNU Bash——完整版 shell；脚本兼容性兜底（数组、`[[ ]]`、进程替换、here-string 全可用）。

## 推荐用法（可原样复制）

```sh
bash                        # 进入交互 shell
bash script.sh              # 执行脚本
bash -c 'echo $((6*7))'     # 单行执行
bash -x script.sh           # 调试（逐行回显）
bash -n script.sh           # 语法检查（不执行）
```

脚本 shebang 建议 `#!/usr/bin/env bash`（iSH 默认 shell 是 BusyBox ash，bash 在 `/usr/local/bin`）。

## 常用参数

| 参数 | 说明 |
|---|---|
| `-c <串>` | 执行字符串 |
| `-x` / `-n` | 跟踪执行 / 只查语法 |
| `-e` / `-u` | 出错即退 / 未定义变量报错 |
| `-i` | 强制交互模式 |
| `--noprofile --norc` | 跳过启动文件（干净环境跑） |

## 退出码与错误处理

- 随脚本/命令：`127`=命令不存在、`126`=不可执行；`bash -n` 语法错 rc=2
- 脚本头部建议 `set -euo pipefail` 三板斧（出错即停 + 未定义变量即停 + 管道任一段失败即停）

## iSH 注意事项

- iSH 默认 shell 是 BusyBox ash：**要用 bash 特性必须显式 `bash xxx.sh` 或写 shebang**，别依赖当前 shell 已是 bash
- 本构建 readline 内建（交互编辑/历史/Ctrl-R 可用）；终端能力经 ncurses 的 terminfo fallback 兜底（xterm-256color 等常驻内嵌）
- 无 iSH 专属补丁（纯上游 5.3；配置：`--enable-static-link --without-bash-malloc --with-curses --disable-nls`）

## 相关工具

`faketty`（PTY 伪装）、`tini`/`chronic`（进程监管与日志降噪）、`patch`（应用补丁）。
