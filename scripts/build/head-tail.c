/* head-tail.c —— 长日志折叠：超长输入压成"头 30 行 + 尾 30 行"（v1.0）
 * 用法: head-tail < big.log
 *
 * 用途：给 Agent 看的长日志降噪 —— 60 行以内原样输出；超出时输出
 *       前 30 行 + 折叠提示 + 后 30 行（省 Context Token，不丢头尾现场）。
 *
 * 实现要点（相对参考稿的修正）：
 *   - 缓冲区 static（BSS）：60×4096=240KB，放栈上会压爆 musl 默认 128KB 栈
 *   - 拷贝带精确长度 + 显式 NUL 终止（参考稿 strncpy 不保证终止）
 *   - 折叠计数、环形索引用插入序输出（与参考稿语义一致）
 */
#include <stdio.h>
#include <string.h>

#define MAX_HEAD 30
#define MAX_TAIL 30
#define LINE_BUF 4096
#define HT_VERSION "1.0"

static char head_buf[MAX_HEAD][LINE_BUF];
static char tail_buf[MAX_TAIL][LINE_BUF];

/* 长度感知整行拷贝（保证 NUL 终止） */
static void copy_line(char *dst, const char *src) {
    size_t n = 0;
    while (n < LINE_BUF - 1 && src[n] != '\0') n++;
    memcpy(dst, src, n);
    dst[n] = '\0';
}

int main(int argc, char **argv) {
    if (argc > 1) {
        if (!strcmp(argv[1], "--version")) { puts("head-tail " HT_VERSION); return 0; }
        if (!strcmp(argv[1], "-h") || !strcmp(argv[1], "--help")) {
            puts("Usage: head-tail [--version]\n"
                 "Collapses long stdin logs: passthrough when <= 60 lines, else\n"
                 "first 30 lines + fold notice + last 30 lines (saves context tokens).");
            return 0;
        }
    }

    char buf[LINE_BUF];
    int total = 0, tail_idx = 0, i;

    while (fgets(buf, sizeof buf, stdin) != NULL) {
        if (total < MAX_HEAD) {
            copy_line(head_buf[total], buf);
        } else {
            copy_line(tail_buf[tail_idx % MAX_TAIL], buf);
            tail_idx++;
        }
        total++;
    }

    if (total <= MAX_HEAD + MAX_TAIL) {
        /* 不够折：原样全出（头段 + 已接力到 tail 的后续行） */
        for (i = 0; i < MAX_HEAD && i < total; i++) fputs(head_buf[i], stdout);
        for (i = 0; i < tail_idx; i++) fputs(tail_buf[i], stdout);
    } else {
        for (i = 0; i < MAX_HEAD; i++) fputs(head_buf[i], stdout);
        printf("\n... [已自动折叠 %d 行长日志以节省 Context Token] ...\n\n",
               total - MAX_HEAD - MAX_TAIL);
        /* 环形缓冲按插入序枚举最后 30 行：(tail_idx + i) % MAX_TAIL */
        for (i = 0; i < MAX_TAIL; i++) fputs(tail_buf[(tail_idx + i) % MAX_TAIL], stdout);
    }

    if (fflush(stdout) != 0 || ferror(stdout)) return 1;
    return 0;
}
