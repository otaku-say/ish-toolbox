/* chronic.c - 纯 C 语言极简版 chronic（命令成功则静默，失败才回放输出） */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <errno.h>

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <cmd> [args...]\n", argv[0]);
        return 1;
    }

    char template[] = "/tmp/chronic.XXXXXX";
    int fd = mkstemp(template);
    if (fd < 0) { perror("mkstemp"); return 1; }
    unlink(template); /* 解除链接，进程退出后内核自动释放空间 */

    pid_t pid = fork();
    if (pid < 0) { perror("fork"); return 1; }

    if (pid == 0) {
        /* 子进程：将 stdout 与 stderr 重定向到临时文件 */
        dup2(fd, STDOUT_FILENO);
        dup2(fd, STDERR_FILENO);
        close(fd);
        execvp(argv[1], &argv[1]);
        perror("execvp");
        _exit(127);
    }

    /* 父进程：等待命令结束（EINTR 重试 + status 预初始化，防信号打断读到垃圾值） */
    int status = 0;
    while (waitpid(pid, &status, 0) == -1 && errno == EINTR) {}

    /* 若命令执行失败，将暂存的内容打印到 stderr */
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        lseek(fd, 0, SEEK_SET);
        char buf[4096];
        ssize_t n;
        while ((n = read(fd, buf, sizeof(buf))) > 0) {
            write(STDERR_FILENO, buf, n);
        }
    }

    close(fd);
    return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}
