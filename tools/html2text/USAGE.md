# html2text —— HTML 转纯文本

把网页/HTML 转成可读纯文本（C++ 实现，grobian 版）。喂给 Agent、存档、做 diff 都合适。
注意：默认会用 `***`/`_` 之类的**字符画**渲染加粗和链接（见示例），要干净文本加 `-nobs`。

## 推荐用法

```sh
# 1) 从 stdin / 文件
curl -s https://example.com | html2text
html2text page.html

# 2) 干净文本（推荐给 Agent / 存档）：关掉强调字符
  
  hmm 保持简单下行
  html2text -nobs < page.html

# 3) 附上链接清单（把 <a href> 收集到文末）
html2text -links < page.html

# 4) 调整行宽（默认 79）
html2text -width 120 < page.html

# 5) 编码控制
html2text -utf8 < page.html          # 输入输出都按 UTF-8
html2text -ascii < page.html         # 输出纯 ASCII（transliterate）

# 6) 输出到文件 / 版本
html2text -o out.txt page.html
html2text -version                   # 2.3.0
```

默认渲染示例（`<h1>T</h1><a href="u">L</a>`）：

```
****** T ******
L
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-nobs` | 不渲染加粗/下划线/颜色（得到干净纯文本） |
| `-links` | 生成引用链接清单 |
| `-width W` | 输出宽度（默认 79） |
| `-utf8` | 输入输出 UTF-8 |
| `-ascii` | 输出 ASCII（非 ASCII 转写） |
| `-from_encoding` / `-to_encoding` | 精细编码控制 |
| `-rcfile F` | 用 F 替代 `~/.html2textrc` |
| `-check` | 只做 HTML 语法检查 |
| `-o FILE` | 输出重定向 |
| `-help` / `-version` | 帮助 / 版本（注意是单横杠长选项） |

## 退出码 / 错误处理

- 0 成功；非 0 失败（打不开输入文件、解析错误等）。
- 输入为畸形 HTML 时尽力而为（它不是浏览器，不做网络请求）。

## iSH 注意事项

- 本套件为**自编译静态**（C++ 走 zig 工具链）；真机可跑。
- 默认会把强调渲染成星号——**给 Agent 前建议 `-nobs`**。
- 与 `strip-ansi` 区分：html2text 是 HTML→文本；strip-ansi 是摘 ANSI 转义。

## 相关工具

- `hxselect` —— 只要 HTML 里某个 CSS 选择器命中的元素片段
- `lowdown` —— 反方向/另一路：Markdown → HTML / 终端文本
- `strip-ansi` —— 输出里带了终端转义序列时再用它洗一遍
