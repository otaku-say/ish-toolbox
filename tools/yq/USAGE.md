# yq —— mikefarah/yq（yq-go）官方静态单文件

> 一行定位：YAML / JSON / XML / CSV 处理器（jq 语法体系）；官方 Go 静态二进制，**自动跟随上游最新版**（每日巡检，版本未变则不产生变更）。

## 推荐用法（可原样复制）

```sh
Y=/path/to/tools/yq/arm64/yq    # iSH/arm64；amd64 换 amd64 目录

"$Y" '.a.b' file.yaml               # 取值
"$Y" '.a.b = "x"' file.yaml         # 打印修改后结果（不落盘）
"$Y" -i '.a.b = "x"' file.yaml      # 原地修改（-i）
"$Y" -p yaml -o json file.yaml      # YAML → JSON
"$Y" -p json -o yaml file.json      # JSON → YAML
echo '{"a":{"b":1}}' | "$Y" '.a.b'  # 管道
"$Y" -e '.a == 1' file.yaml && echo ok   # 条件判断（-e：假/空时退出码非 0）
"$Y" --version
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-i` | 原地写回文件 |
| `-p FMT` / `-o FMT` | 输入/输出格式（yaml/json/xml/csv/tsv/props） |
| `-e` | 结果为 false/空时退出码非 0（脚本判断用） |
| `-n` | 不读输入（构造新文档） |
| `-r` | 字符串输出不加引号 |
| `-P` | 美化打印（pretty print） |

## 与 jaq / jq 的分工

- **YAML 场景** → yq；**纯 JSON 高频处理** → jaq（更快；本工具箱已含）。
- yq 表达式语法与 jq 基本一致：`.a.b`、`select`、`map`、管道等通用。

## 版本与更新（自动跟随）

- 来源：GitHub `mikefarah/yq` releases（资产：`yq_linux_amd64` / `yq_linux_arm64`）
- **自动跟随**：`跟随上游更新二进制` 工作流每日巡检上游 latest；拉取后经三判据
  （无 INTERP / 无 NEEDED / 架构正确）验证并入库存档（UPX 压缩）
- 形态：全静态、EXEC 非 PIE、单文件（UPX 后约 4–6MB）

## iSH 注意事项

- 全静态 aarch64/amd64 单文件、零依赖，直接运行
