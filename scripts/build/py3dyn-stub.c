/*
 * py3dyn-stub.c — ish-toolbox「python3-dyn」自解压壳（静态，C）
 * 布局: [本壳静态 ELF][xz 压缩载荷][56B 尾部记录]
 *   尾部(72B): magic[16] + id[16] + name[16] + u64 pay_off + u64 pay_size + u64 out_size
 * 行为: 缓存未命中 → 解压载荷到 $PY3DYN_CACHE_DIR-<id>（默认 /tmp/.ish-py3dyn-<id>）
 *       → execv 缓存中的真实 python3（动态 musl 单文件）
 * 自定位: /proc/self/exe → argv[0] → PATH 搜索；候选逐一校验尾部 magic 选用真身
 * 调试: PY3DYN_DEBUG=1 输出诊断
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>
#include "xz.h"

/* xz-embedded userspace 必需：解码前初始化 CRC 查表 */
void xz_crc32_init(void);
#ifdef XZ_USE_CRC64
void xz_crc64_init(void);
#endif
#ifdef XZ_DEC_CONCATENATED
enum xz_ret xz_dec_catrun(struct xz_dec *s, struct xz_buf *b, int finish);
#endif

#define TRAILER_SIZE 72
#define CHUNK (64 * 1024)

static const char MAGIC[16] = "ISH-PY3DYN-PAYL1";
static int dbg_on = 0;

static void dbg(const char *fmt, ...)
{
    va_list ap;
    if (!dbg_on) return;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
}

static void die(const char *what)
{
    fprintf(stderr, "python3-dyn: %s: %s\n", what, strerror(errno));
    _exit(127);
}

static uint64_t rd64(const unsigned char *p)
{
    uint64_t v = 0;
    int i;
    for (i = 0; i < 8; i++) v |= (uint64_t)p[i] << (8 * i);
    return v;
}

/* 打开候选路径并校验尾部 magic；成功返回 fd 并回填 st */
static int open_and_check(const char *p, struct stat *st_out)
{
    int fd = open(p, O_RDONLY);
    if (fd < 0) { dbg("[dbg] try %s: open fail (%s)\n", p, strerror(errno)); return -1; }
    struct stat st;
    if (fstat(fd, &st) != 0) { dbg("[dbg] try %s: fstat fail (%s)\n", p, strerror(errno)); close(fd); return -1; }
    if (st.st_size < TRAILER_SIZE) { dbg("[dbg] try %s: too small %lld\n", p, (long long)st.st_size); close(fd); return -1; }
    unsigned char tr[16];
    ssize_t got = pread(fd, tr, 16, (off_t)(st.st_size - TRAILER_SIZE));
    if (got != 16) { dbg("[dbg] try %s: trailer read got=%zd (%s)\n", p, got, strerror(errno)); close(fd); return -1; }
    if (memcmp(tr, MAGIC, 16) != 0) {
        dbg("[dbg] try %s: magic mismatch [%02x%02x%02x%02x] size=%lld\n",
            p, tr[0], tr[1], tr[2], tr[3], (long long)st.st_size);
        close(fd);
        return -1;
    }
    dbg("[dbg] self ok: %s (size=%lld)\n", p, (long long)st.st_size);
    *st_out = st;
    return fd;
}

int main(int argc, char **argv)
{
    (void)argc;
    dbg_on = getenv("PY3DYN_DEBUG") != NULL;

    int fd = -1;
    struct stat st;
    char self[4096];
    int round;

    /* 候选定位 + 重试（应对个别环境下的短暂文件状态异常） */
    for (round = 0; round < 5 && fd < 0; round++) {
        if (round > 0) { dbg("[dbg] retry %d\n", round); usleep(150000); }

        ssize_t n = readlink("/proc/self/exe", self, sizeof(self) - 1);
        if (n > 0) {
            self[n] = 0;
            dbg("[dbg] readlink(/proc/self/exe) -> %s\n", self);
            fd = open_and_check(self, &st);
        } else {
            dbg("[dbg] readlink(/proc/self/exe) rc=%zd (%s)\n", n, strerror(errno));
        }
        if (fd < 0 && argv[0] && argv[0][0] && strchr(argv[0], '/')) {
            dbg("[dbg] fallback argv0: %s\n", argv[0]);
            fd = open_and_check(argv[0], &st);
            if (fd >= 0) snprintf(self, sizeof(self), "%s", argv[0]);
        }
        if (fd < 0 && argv[0] && argv[0][0] && !strchr(argv[0], '/')) {
            const char *p = getenv("PATH");
            while (p && *p) {
                const char *e = strchr(p, ':');
                size_t len = e ? (size_t)(e - p) : strlen(p);
                if (len > 0 && len < sizeof(self) - 2) {
                    snprintf(self, sizeof(self), "%.*s/%s", (int)len, p, argv[0]);
                    fd = open_and_check(self, &st);
                    if (fd >= 0) break;
                }
                if (!e) break;
                p = e + 1;
            }
        }
    }
    if (fd < 0) {
        errno = ENOENT;
        die("cannot locate self");
    }

    unsigned char tr[TRAILER_SIZE];
    if (pread(fd, tr, TRAILER_SIZE, (off_t)(st.st_size - TRAILER_SIZE)) != TRAILER_SIZE)
        die("read trailer");
    char id[17], name[17];
    memcpy(id, tr + 16, 16); id[16] = 0;
    memcpy(name, tr + 32, 16); name[16] = 0;
    uint64_t pay_off  = rd64(tr + 48);
    uint64_t pay_size = rd64(tr + 56);
    uint64_t out_size = rd64(tr + 64);
    if (!name[0] || strspn(name, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-") != strlen(name))
        snprintf(name, sizeof(name), "%s", "tool");
    dbg("[dbg] id=%s name=%s off=%llu psz=%llu osz=%llu\n", id, name,
        (unsigned long long)pay_off, (unsigned long long)pay_size, (unsigned long long)out_size);

    /* 缓存目录：PY3DYN_CACHE_DIR → /tmp → /var/tmp → 自身旁边 */
    char dir[4096], cache[4096], tmp[4300];
    const char *bases[3];
    int nb = 0, ok = 0, i;
    const char *env = getenv("PY3DYN_CACHE_DIR");
    if (env && *env) bases[nb++] = env;
    bases[nb++] = "/tmp/.ish-py3dyn";
    bases[nb++] = "/var/tmp/.ish-py3dyn";
    for (i = 0; i < nb; i++) {
        snprintf(dir, sizeof(dir), "%s-%s", bases[i], id);
        if (mkdir(dir, 0755) == 0 || errno == EEXIST) { ok = 1; break; }
    }
    if (!ok) {
        snprintf(dir, sizeof(dir), "%s.cache", self);
        if (mkdir(dir, 0755) != 0 && errno != EEXIST) die("mkdir cache");
    }
    snprintf(cache, sizeof(cache), "%s/%s", dir, name[0] ? name : "tool");
    dbg("[dbg] cache=%s\n", cache);

    struct stat cs;
    if (!(stat(cache, &cs) == 0 && (uint64_t)cs.st_size == out_size)) {
        /* 解压载荷（对齐 xzminidec：DYNALLOC + catrun(finish)；CRC 表须先初始化） */
        struct xz_dec *s;
        int stall = 0;
        xz_crc32_init();
#ifdef XZ_USE_CRC64
        xz_crc64_init();
#endif
        s = xz_dec_init(XZ_DYNALLOC, (uint32_t)1 << 27);
        if (!s) { errno = ENOMEM; die("xz init"); }
        snprintf(tmp, sizeof(tmp), "%s/python3.tmp-%d", dir, (int)getpid());
        int out = open(tmp, O_WRONLY | O_CREAT | O_TRUNC, 0755);
        if (out < 0) die("create cache");

        static unsigned char ibuf[CHUNK], obuf[CHUNK];
        struct xz_buf b;
        uint64_t remaining = pay_size, produced = 0;
        off_t off = (off_t)pay_off;
        long iter = 0;

        b.in = ibuf; b.in_pos = 0; b.in_size = 0;
        b.out = obuf; b.out_pos = 0; b.out_size = CHUNK;

        for (;;) {
            uint64_t out_prev;
            enum xz_ret r;
            if (++iter > 1000000) {
                fprintf(stderr, "python3-dyn: decode stalled\n");
                _exit(1);
            }
            if (b.in_pos == b.in_size) {
                size_t want = remaining < CHUNK ? (size_t)remaining : CHUNK;
                ssize_t k = 0;
                if (want) {
                    k = pread(fd, ibuf, want, off);
                    if (k < 0) die("read payload");
                    off += k; remaining -= (uint64_t)k;
                }
                b.in_pos = 0; b.in_size = (size_t)k;
            }
            out_prev = produced + b.out_pos;
            r = xz_dec_catrun(s, &b, b.in_size == 0);
            if (b.out_pos == b.out_size) {
                if (write(out, obuf, b.out_pos) != (ssize_t)b.out_pos) die("write cache");
                produced += b.out_pos; b.out_pos = 0;
            }
            if (r == XZ_STREAM_END) break;
            if (r == XZ_OK) {
                if (b.in_size == 0 && (produced + b.out_pos) == out_prev) {
                    if (++stall > 4) {
                        fprintf(stderr, "python3-dyn: truncated payload\n");
                        _exit(1);
                    }
                } else {
                    stall = 0;
                }
                continue;
            }
#ifdef XZ_DEC_ANY_CHECK
            if (r == XZ_UNSUPPORTED_CHECK) continue;
#endif
            fprintf(stderr, "python3-dyn: xz error %d\n", (int)r);
            _exit(1);
        }
        if (b.out_pos) {
            if (write(out, obuf, b.out_pos) != (ssize_t)b.out_pos) die("write cache");
            produced += b.out_pos; b.out_pos = 0;
        }
        xz_dec_end(s);
        if (produced != out_size) {
            fprintf(stderr, "python3-dyn: size mismatch %llu != %llu\n",
                    (unsigned long long)produced, (unsigned long long)out_size);
            _exit(1);
        }
        close(out);
        if (rename(tmp, cache) != 0) die("rename cache");
        chmod(cache, 0755);
        dbg("[dbg] extracted ok\n");
    }
    close(fd);

    /* 环境适配：multiprocessing 需要 /dev/shm；部分环境（如 iSH）默认没有 */
    if (access("/dev/shm", F_OK) != 0) {
        if (mkdir("/dev/shm", 01777) == 0) chmod("/dev/shm", 01777);
    }

    argv[0] = cache;
    execv(cache, argv);
    die("exec payload");
    return 127;
}
