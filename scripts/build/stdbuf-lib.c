/* libstdbuf.so —— stdbuf 的注入库（ish-toolbox 轻量实现）
 *
 * 由 stdbuf 启动器通过 LD_PRELOAD 注入目标进程；构造函数在 main() 之前
 * 执行，按 _STDBUF_{I,O,E} 对 stdin/stdout/stderr 调用 setvbuf：
 *   L = 行缓冲，0 = 无缓冲，数字 = 全缓冲指定字节数。
 */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void apply(FILE *f, const char *envname) {
    const char *m = getenv(envname);
    if (!m || !*m) return;
    if (!strcmp(m, "L")) {
        setvbuf(f, NULL, _IOLBF, 0);
    } else if (!strcmp(m, "0")) {
        setvbuf(f, NULL, _IONBF, 0);
    } else {
        long sz = strtol(m, NULL, 10);
        if (sz > 0) setvbuf(f, NULL, _IOFBF, (size_t)sz);
    }
}

__attribute__((constructor)) static void stdbuf_ctor(void) {
    apply(stdin,  "_STDBUF_I");
    apply(stdout, "_STDBUF_O");
    apply(stderr, "_STDBUF_E");
}
