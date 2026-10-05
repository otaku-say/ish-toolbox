/* stdbuf 启动器 —— GNU stdbuf 的轻量兼容实现（ish-toolbox 自建）
 *
 * 语义：解析 [-i|-o|-e MODE]（MODE：L=行缓冲 / 0=无缓冲 / 数字=全缓冲字节数，
 * 支持 -oL / -o L / --output= 三种写法），把 MODE 写入 _STDBUF_{I,O,E}
 * 环境变量，并将“与本程序同目录的 libstdbuf.so”前置到 LD_PRELOAD，
 * 然后 exec 目标命令。
 * 说明：静态目标程序无动态加载器、无法被注入；动态 musl 程序（busybox 等）可用。
 */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define LIB_NAME "libstdbuf.so"

static void die(const char *m) { fprintf(stderr, "stdbuf: %s\n", m); exit(125); }

static int valid_mode(const char *m) {
    size_t i;
    if (!*m) return 0;
    if (!strcmp(m, "L") || !strcmp(m, "0")) return 1;
    for (i = 0; m[i]; i++) if (m[i] < '0' || m[i] > '9') return 0;
    return 1;
}

int main(int argc, char **argv) {
    int i;
    char self[4096], lib[4096];
    ssize_t n;

    for (i = 1; i < argc; i++) {
        char *a = argv[i], *m = NULL;
        const char *var = NULL;

        if (a[0] == '-' && a[1] && strchr("ioe", a[1])) {
            var = (a[1] == 'i') ? "_STDBUF_I" : (a[1] == 'o' ? "_STDBUF_O" : "_STDBUF_E");
            if (a[2]) m = a + 2;                      /* -oL */
            else if (i + 1 < argc) m = argv[++i];     /* -o L */
            else die("missing operand");
        } else if (!strncmp(a, "--input=", 8))  { var = "_STDBUF_I"; m = a + 8; }
        else if (!strncmp(a, "--output=", 9))   { var = "_STDBUF_O"; m = a + 9; }
        else if (!strncmp(a, "--error=", 8))    { var = "_STDBUF_E"; m = a + 8; }
        else if (!strcmp(a, "--help")) {
            fputs("Usage: stdbuf [-i MODE] [-o MODE] [-e MODE] COMMAND [ARGS]...\n"
                  "  MODE: L=line buffered, 0=unbuffered, N=fully buffered N bytes\n", stdout);
            return 0;
        }
        else if (!strcmp(a, "--version")) {
            fputs("stdbuf (ish-toolbox mini) - GNU stdbuf compatible\n", stdout);
            return 0;
        }
        else break;

        if (var) {
            if (!valid_mode(m)) die("invalid mode");
            setenv(var, m, 1);
        }
    }

    if (i >= argc) die("missing operand");

    /* 与自身同目录查找 libstdbuf.so，并前置到 LD_PRELOAD */
    n = readlink("/proc/self/exe", self, sizeof(self) - 1);
    if (n > 0) {
        char *s;
        self[n] = '\0';
        s = strrchr(self, '/');
        if (s) {
            const char *old;
            snprintf(lib, sizeof(lib), "%.*s%s", (int)(s - self + 1), self, LIB_NAME);
            old = getenv("LD_PRELOAD");
            if (old && *old) {
                char nb[8192];
                snprintf(nb, sizeof(nb), "%s %s", lib, old);
                setenv("LD_PRELOAD", nb, 1);
            } else {
                setenv("LD_PRELOAD", lib, 1);
            }
        }
    }

    execvp(argv[i], &argv[i]);
    die("failed to run command");
    return 125;
}
