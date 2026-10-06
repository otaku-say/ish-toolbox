# hxselect —— 按 CSS 选择器从 HTML/XML 提取元素

从 stdin 读 HTML/XML，输出**匹配 CSS 选择器**的元素（或其内容）。
从网页里精确抠片段的利器（本工具替代了原 cascadia）。

## 推荐用法

```sh
# 1) 提取所有 <p class="x"> 的内容（-c：只要内容，不要标签）
curl -s https://example.com | hxselect -c 'p.x'

# 2) 只要元素的完整标签（默认行为：带起止标签）
curl -s https://example.com | hxselect 'div.main > ul'

# 3) 多个选择器（逗号分隔，任一命中都出）
hxselect -c 'h1, h2.title' < page.html

# 4) 大小写不敏感（HTML 常用）
hxselect -i -c 'A[href]' < page.html

# 5) 每个匹配后加空行（-s 接受 C 转义）
hxselect -c -s '\n\n' 'li' < page.html

# 6) 取属性值（实验性 ::attr）
hxselect 'a::attr(href)' < page.html

# 7) 版本 / 帮助
hxselect            # 裸执行打印用法
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-c` | 只输出内容（不带起止标签；选择属性时输出属性值） |
| `-i` | 大小写不敏感（ASCII 范围；对 HTML 友好） |
| `-s SEP` | 每个匹配后追加 SEP（支持 C 转义，如 `-s '\n\n'`） |
| `-l LANG` | 根元素无 `xml:lang` 时的默认语言 |
| `selector` | 一个或多个逗号分隔的 CSS3 选择器（不支持需交互/排版的伪类） |

## 退出码 / 错误处理

- 0 成功（**无匹配也是 0**，输出为空——脚本里靠输出判空，别靠退出码）。
- 输入必须是良构 XML/HTML；畸形 HTML 先用 `hxnormalize -x` 清洗（未随本套件分发，需要时从 html-xml-utils 源码包取）。

## iSH 注意事项

- 本套件为**自编译静态**（W3C html-xml-utils 8.8，只交付 hxselect 一个二进制）；真机可用。
- 纯流式处理；大页面可跑。class/id 选择器（`.foo`/`#bar`）按 `class`/`id` 属性解释。
- 与 `cascadia` 的差异：hxselect 输出**原始标记片段**（或 `-c` 纯内容），
  不负责 CSV 整形；要结构化输出可接 `hxselect -c` + `sed`/`awk`。

## 相关工具

- `html2text` —— 整页转纯文本（不做选择器）
- `lowdown` —— Markdown 方向的处理
- `curl` —— 抓取上游；本条管道：`curl -s | hxselect -c | ...`
