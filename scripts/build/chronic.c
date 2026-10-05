/* chronic.c - 极简 chronic（v1.3）：命令成功则静默，失败才回放输出
 * 用法: chronic [-ev] [--] cmd [args...]
 *
 * 与 moreutils chronic(0.70, Perl) 对齐的语义：
 *   - 捕获分离：stdout→暂存1，stderr→暂存2；回放时各归各的流
 *   - -v 冗长：失败展示加 STDOUT/STDERR 分段标签并报告 RETVAL
 *   - -e 触发：命令成功但 stderr 非空 → 回放并以 2 退出
 *   - 选项仅识别于 COMMAND 之前；支持组合（-ve）与 "--" 终止
 *
 * 本地加固（相对上游的有意增强，已注释）：
 *   - waitpid EINTR 重试；回放全量写循环（EINTR/短写不丢）
 *   - 回放前屏蔽 SIGPIPE（下游早退以 EPIPE 收手，不炸成 141）
 *   - 信号致死退出 128+signum（上游为 1，此处更贴近 shell 惯例）
 *   - TMPDIR 支持（默认 /tmp）；--help/--version
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <errno.h>

static int write_all(int fd, const char *buf, size_t len) {
    while (len > 0) {
        ssize_t n = write(fd, buf, len);
        if (n < 0) { if (errno == EINTR) continue; return -1; }
        buf += n; len -= (size_t)n;
    }
    return 0;
}

/* 建匿名暂存文件（mkstemp + 立即 unlink），返回 fd 或 -1 */
static int make_tmp(char *path, size_t pathsz) {
    const char *dir = getenv("TMPDIR");
    if (!dir || !*dir) dir = "/tmp";
    if (snprintf(path, pathsz, "%s/chronic.XXXXXX", dir) >= (int)pathsz) {
        fprintf(stderr, "chronic: TMPDIR too long\n");
        return -1;
    }
    int fd = mkstemp(path);
    if (fd < 0) { perror("chronic: mkstemp"); return -1; }
    unlink(path); /* 解除链接，进程退出后内核自动释放空间 */
    return fd;
}

static void replay_to(int fd, int out_fd) {
    char buf[4096];
    ssize_t n;
    if (lseek(fd, 0, SEEK_SET) == (off_t)-1) return;
    while ((n = read(fd, buf, sizeof(buf))) > 0) {
        if (write_all(out_fd, buf, (size_t)n) < 0) break;
    }
}

int main(int argc, char *argv[]) {
    int i = 1, verbose = 0, trigger_err = 0;

    if (argc < 2) {
        fprintf(stderr, "Usage: %s [-ev] [--] <cmd> [args...]\n", argv[0]);
        return 1;
    }
    if (!strcmp(argv[1], "-h") || !strcmp(argv[1], "--help")) {
        printf("Usage: %s [-ev] [--] <cmd> [args...]\n"
               "Runs <cmd>; captures stdout/stderr and shows them only on failure\n"
               "(or when -e triggers on non-empty stderr; then exit is 2).\n"
               "  -v  label STDOUT/STDERR sections and report RETVAL\n"
               "  -e  also trigger when the command wrote to stderr but succeeded\n"
               "Exit: command's code; 128+N if killed by signal N.\n", argv[0]);
        return 0;
    }
    if (!strcmp(argv[1], "--version")) { puts("chronic 1.3"); return 0; }

    /* 选项：仅 COMMAND 之前；支持组合（-ve）；"--" 终止 */
    while (i < argc) {
        const char *a = argv[i];
        if (!strcmp(a, "--")) { i++; break; }
        if (a[0] != '-' || a[1] == '\0') break; /* "-" 或普通词 → 命令开始 */
        int good = 1;
        for (const char *p = a + 1; *p; p++)
            if (*p != 'v' && *p != 'e') { good = 0; break; }
        if (!good) break; /* 含未知字符 → 视作命令名 */
        for (const char *p = a + 1; *p; p++) {
            if (*p == 'v') verbose = 1;
            else           trigger_err = 1;
        }
        i++;
    }
    if (i >= argc) {
        fprintf(stderr, "Usage: %s [-ev] [--] <cmd> [args...]\n", argv[0]);
        return 1;
    }

    char path[256];
    int fd_out = make_tmp(path, sizeof(path));
    int fd_err = -1;
    if (fd_out >= 0) fd_err = make_tmp(path, sizeof(path));
    if (fd_out < 0 || fd_err < 0) { if (fd_out >= 0) close(fd_out); return 1; }

    pid_t pid = fork();
    if (pid < 0) { perror("chronic: fork"); return 1; }

    if (pid == 0) {
        /* 子进程：stdout/stderr 分别重定向到两个暂存文件 */
        if (dup2(fd_out, STDOUT_FILENO) < 0 || dup2(fd_err, STDERR_FILENO) < 0) {
            perror("chronic: dup2"); _exit(127);
        }
        close(fd_out);
        close(fd_err);
        execvp(argv[i], &argv[i]);
        fprintf(stderr, "chronic: %s: %s\n", argv[i], strerror(errno));
        _exit(127);
    }

    /* 父进程：等命令结束（EINTR 重试；真失败显式报错） */
    int status = 0, code;
    pid_t w;
    while ((w = waitpid(pid, &status, 0)) < 0 && errno == EINTR) {}
    if (w < 0) { perror("chronic: waitpid"); return 1; }
    if (WIFEXITED(status))        code = WEXITSTATUS(status);
    else if (WIFSIGNALED(status)) code = 128 + WTERMSIG(status);
    else                          code = 1;

    /* 触发判定：失败 → 回放；-e 且 stderr 非空（即便成功）→ 回放并以 2 退出 */
    int show = 0, out_code = code;
    if (code != 0) {
        show = 1;
    } else if (trigger_err) {
        struct stat st;
        if (fstat(fd_err, &st) == 0 && st.st_size > 0) { show = 1; out_code = 2; }
    }

    if (show) {
        /* 屏蔽 SIGPIPE：下游早退时以 EPIPE 静默收手，不炸成 141 */
        sigset_t block;
        sigemptyset(&block);
        sigaddset(&block, SIGPIPE);
        sigprocmask(SIG_BLOCK, &block, NULL);

        if (verbose) write_all(STDOUT_FILENO, "STDOUT:\n", 8);
        replay_to(fd_out, STDOUT_FILENO);
        if (verbose) write_all(STDOUT_FILENO, "\nSTDERR:\n", 9);
        replay_to(fd_err, STDERR_FILENO);
        if (verbose) {
            char tail[64];
            int rl = snprintf(tail, sizeof(tail), "\nRETVAL: %d\n", code);
            if (rl > 0) write_all(STDOUT_FILENO, tail, (size_t)rl);
        }
    }
    close(fd_out);
    close(fd_err);
    return out_code;
}
