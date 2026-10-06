# envsubst —— 环境变量替换（模板渲染）

GNU gettext 出品的小工具：把输入中的 `$VAR` / `${VAR}` 替换为环境变量的值。
写配置文件模板（nginx.conf、CI 变量、部署脚本）时最常用的一步。

## 推荐用法

```sh
# 1) 全部替换（所有 $VAR/${VAR} 都吃环境变量）
export DOMAIN=example.com PORT=8080
printf 'server %s:%s\n' '$DOMAIN' '$PORT' | envsubst    # server example.com:8080

# 2) 模板文件 → 产物
export DOMAIN=example.com
envsubst < nginx.conf.tmpl > nginx.conf

# 3) 只替换指定变量（最安全——给出白名单 SHELL-FORMAT）
envsubst '$DOMAIN $PORT' < tmpl > out
#    只列进来的变量会被替换，模板里其它 $ 字面量原样保留

# 4) 列出模板里用到的变量名（不替换）
envsubst --variables < tmpl

# 5) 版本
envsubst --version          # envsubst (GNU gettext-runtime) 0.26
```

## 常用参数

| 参数 | 作用 |
|---|---|
| 无参数 | 替换输入中所有 `$VAR` / `${VAR}` |
| `SHELL-FORMAT` | 白名单：只替换其中出现的变量（如 `'$A $B'`） |
| `-v` / `--variables` | 只列出变量名（不替换） |
| `-h` / `--help` / `-V` / `--version` | 帮助 / 版本 |

## 退出码 / 错误处理

- 0 成功；非 0 失败（用法错误等）。
- **不存在的变量替换为空串**（与 shell 行为不同，不会报错）——模板里要小心。

## iSH 注意事项

- 本套件为**自编译静态**（gettext-runtime 子包单独构建）；真机可用。
- **裸用有风险**：不给定 SHELL-FORMAT 时，输入里*所有* `$xxx` 都会被吃
  （包括你本想保留的字面量）。模板含正文 `$` 时务必给白名单格式串。
- 默认只认环境变量（不含 shell 函数/别名）；`export` 过的才可见。

## 相关工具

- `jo` —— 生成 JSON 配置；envsubst 管模板文本
- `faketty` / `chronic` —— 部署脚本里组合用于安静执行
- `sed` / `sd` —— 更复杂的替换逻辑用它们（envsubst 只管环境变量）
