# sqlite3 —— SQLite 命令行客户端（3.53.4）

建库、查询、导入导出 SQLite 数据库。脚本里推荐「直接传 SQL 参数」；点命令（`.tables` 等）走 stdin。
本机编译带 `SQLITE_OMIT_LOAD_EXTENSION`：**`.load` 动态扩展不可用**（实测报错）。

## 推荐用法

```sh
# 建表+插入（一个参数里多条语句，分号分隔）
sqlite3 t.db "create table u(id integer primary key, name text); insert into u(name) values('alice'),('bob');"

# 查询：默认 | 分隔
sqlite3 t.db "select * from u;"

# 表头+对齐 / CSV / JSON / 单列式 / 表格框
sqlite3 -header -column t.db "select * from u;"
sqlite3 -csv t.db "select * from u;"
sqlite3 -json t.db "select * from u;"
sqlite3 -line t.db "select * from u;"
sqlite3 -table t.db "select * from u;"

# 点命令走 stdin（.tables / .schema / .mode / .dump）
printf '.tables\n.schema u\n' | sqlite3 t.db
printf '.mode json\nselect * from u;\n' | sqlite3 t.db

# 导出备份（还原：sqlite3 new.db < backup.sql）
sqlite3 t.db .dump > backup.sql

# 只读打开 / 遇错即停
sqlite3 -readonly t.db "select count(*) from u;"
sqlite3 -bail t.db "select * from nope;"
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-header` | 输出列名 |
| `-column` | 对齐列模式 |
| `-csv` / `-json` | CSV / JSON 输出 |
| `-line` / `-table` | 单列式 / 表格框输出 |
| `-separator S` | 列分隔符 |
| `-bail` | 遇错停止（stdin 批处理下默认继续） |
| `-readonly` | 只读打开（写操作报错） |
| `-cmd CMD` / `-echo` | 预设命令 / 回显输入（未实测） |

## 退出码

- `0` = 成功
- `1` = SQL/IO 出错（命令行参数的语句一错就停；stdin 批处理默认继续执行）

## iSH 注意事项

- **`.load` 不可用**：实测 `.load /tmp/x.so` → `Error: unknown command or invalid arguments: "load"`（无动态扩展）。
- stdin 批处理**默认遇错继续**（rc 仍为 1）；要「出错即停」加 `-bail`（实测对比：默认会打印错误后的下一条结果，`-bail` 不打印）。
- 非 tty 下自动批处理模式：脚本里总是显式传 SQL 或重定向 stdin，别依赖交互。
- 全静态 aarch64 二进制，不依赖 apk 包。

## 相关工具

- `jaq` —— 接 `-json` 输出继续加工：`sqlite3 -json t.db "select * from u;" | jaq '.[].name'`
- `micropython` —— 没有 sqlite3 模块，需要库操作时走本 CLI
- `rg` —— 在 .sql 转储文本里搜
