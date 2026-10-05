/* chronic.c - 极简 chronic（v1.1）：命令成功则静默，失败才回放输出
 * 用法: chronic [-h|--help|--version] cmd [args...]
 * 稳定性要点：
 *   - waitpid 遇 EINTR 重试；真失败显式报错（status 预初始化）
 *   - 回放走全量写循环（EINTR/短写不丢输出）
 *   - 支持 TMPDIR（默认 /tmp）
 *   - 信号致死退出 128+signum（镜像 shell 约定）
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
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

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <cmd> [args...]\n", argv[0]);
        return 1;
    }
    if (!strcmp(argv[1], "-h") || !strcmp(argv[1], "--help")) {
        printf("Usage: %s <cmd> [args...]\n"
               "Runs <cmd> capturing stdout+stderr; replays them to stderr on failure.\n"
               "Exit code passed through (signal death -> 128+signum).\n", argv[0]);
        return 0;
    }
    if (!strcmp(argv[1], "--version")) { puts("chronic 1.1"); return 0; }

    const char *dir = getenv("TMPDIR");
    if (!dir || !*dir) dir = "/tmp";
    char path[256];
    if (snprintf(path, sizeof(path), "%s/chronic.XXXXXX", dir) >= (int)sizeof(path)) {
        fprintf(stderr, "chronic: TMPDIR too long\n");
        return 1;
    }
    int fd = mkstemp(path);
    if (fd < 0) { perror("chronic: mkstemp"); return 1; }
    unlink(path); /* 解除链接，进程退出后内核自动释放空间 */

    pid_t pid = fork();
    if (pid < 0) { perror("chronic: fork"); return 1; }

    if (pid == 0) {
        /* 子进程：stdout/stderr 重定向到暂存文件 */
        if (dup2(fd, STDOUT_FILENO) < 0 || dup2(fd, STDERR_FILENO) < 0) {
            perror("chronic: dup2"); _exit(127);
        }
        close(fd);
        execvp(argv[1], &argv[1]);
        fprintf(stderr, "chronic: %s: %s\n", argv[1], strerror(errno));
        _exit(127);
    }

    /* 父进程：等命令结束（EINTR 重试；真失败显式报错） */
    int status = 0, code;
    pid_t w;
    while ((w = waitpid(pid, &status, 0)) < 0 && errno == EINTR) {}
    if (w < 0) { perror("chronic: waitpid"); return 1; }
    if (WIFEXITED(status))       code = WEXITSTATUS(status);
    else if (WIFSIGNALED(status)) code = 128 + WTERMSIG(status);
    else                          code = 1;

    /* 失败才回放（写 stderr，全量写循环防短写丢输出） */
    if (code != 0 && lseek(fd, 0, SEEK_SET) != (off_t)-1) {
        char buf[4096];
        ssize_t n;
        while ((n = read(fd, buf, sizeof(buf))) > 0) {
            if (write_all(STDERR_FILENO, buf, (size_t)n) < 0) break;
        }
    }
    close(fd);
    return code;
}
