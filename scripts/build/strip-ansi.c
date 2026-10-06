/* strip-ansi.c —— 过滤 ANSI 转义序列，只留纯文本（v1.0）
 * 用法: strip-ansi < in > out
 *
 * 处理范围（字节级状态机；非 ESC 字节一律原样透传 → UTF-8 安全）：
 *   - CSI:  ESC [ ... 参数/中间字节吞掉，终止于 0x40-0x7E（颜色/光标/清屏等）
 *   - OSC:  ESC ] ... 终止于 BEL(0x07) 或 ST(ESC \)（窗口标题/超链接）
 *   - DCS/SOS/PM/APC: ESC P/X/^/_ ... 终止于 ST(ESC \)
 *   - 带中间字节的序列: ESC + [0x20-0x2F]+ + 终止字节[0x30-0x7E]（如 ESC(B、ESC#8）
 *   - 其他两字节序列: ESC + 终止字节（ESC M、ESC 7、ESC c 等）
 *
 * 说明：
 *   - 不处理 0x9B 单字节 CSI —— 它会和 UTF-8 续字节(0x80-0xBF)撞车，误吞正文；
 *     本工具只认 ESC(0x1B) 起始的序列，对 UTF-8 文本零误伤。
 *   - 参考实现中的 \e(B 消费后状态未复位（会多吃一个字符）是 bug，此处已修正。
 */
#include <stdio.h>
#include <string.h>

#define STRIP_ANSI_VERSION "1.0"

enum state { ST_TEXT, ST_ESC, ST_CSI, ST_OSC, ST_STR };

int main(int argc, char **argv) {
    if (argc > 1) {
        if (!strcmp(argv[1], "--version")) { puts("strip-ansi " STRIP_ANSI_VERSION); return 0; }
        if (!strcmp(argv[1], "-h") || !strcmp(argv[1], "--help")) {
            puts("Usage: strip-ansi [--version]\n"
                 "Removes ANSI escape sequences (CSI/OSC/DCS/charset/two-byte)\n"
                 "from stdin; all other bytes pass through unchanged (UTF-8 safe).");
            return 0;
        }
    }

    int c;
    enum state st = ST_TEXT;
    while ((c = getchar()) != EOF) {
        switch (st) {
        case ST_TEXT:
            if (c == 0x1B) st = ST_ESC;
            else putchar(c);
            break;

        case ST_ESC:
            if (c == '[') {
                st = ST_CSI;                                    /* CSI */
            } else if (c == ']') {
                st = ST_OSC;                                    /* OSC */
            } else if (c == 'P' || c == 'X' || c == '^' || c == '_') {
                st = ST_STR;                                    /* DCS / SOS / PM / APC */
            } else if (c >= 0x20 && c <= 0x2F) {
                /* 中间字节（一个或多个）+ 终止字节，如 ESC( B、ESC# 8 */
                for (;;) {
                    int d = getchar();
                    if (d == EOF) return 0;
                    if (d >= 0x30 && d <= 0x7E) break;          /* 终止字节：完成 */
                    if (!(d >= 0x20 && d <= 0x2F)) break;       /* 异常字节：收手 */
                }
                st = ST_TEXT;
            } else {
                st = ST_TEXT;                                   /* 两字节序列：本字节吞掉即完成 */
            }
            break;

        case ST_CSI:
            if (c >= 0x40 && c <= 0x7E) st = ST_TEXT;           /* 参数与中间字节直接吞 */
            break;

        case ST_OSC:
            if (c == 0x07) {                                    /* BEL 终止 */
                st = ST_TEXT;
            } else if (c == 0x1B) {                             /* 可能是 ST(ESC \) */
                int d = getchar();
                if (d == EOF) return 0;
                if (d == '\\') st = ST_TEXT;
                /* 非 "\"：OSC 内嵌 ESC 的怪例，留在 OSC 继续等终止（吞 d） */
            }
            break;

        case ST_STR:
            if (c == 0x1B) {                                    /* 只认 ST 终止 */
                int d = getchar();
                if (d == EOF) return 0;
                if (d == '\\') st = ST_TEXT;
            }
            break;
        }
    }
    return 0;
}
