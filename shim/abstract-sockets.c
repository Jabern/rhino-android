/* LD_PRELOAD shim: AF_UNIX path sockets -> abstract sockets.
 *
 * The adb shell's SELinux domain may not create socket files, but may use
 * abstract sockets. wineserver binds "socket" relative to its server dir, so
 * relative paths are made absolute first; every process maps the same path
 * to the same abstract name. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

static void make_marker(const struct sockaddr *addr);

static int to_abstract(const struct sockaddr *addr, socklen_t len,
                       struct sockaddr_un *out, socklen_t *out_len)
{
    const struct sockaddr_un *un = (const struct sockaddr_un *)addr;
    char path[4096];

    if (!addr || addr->sa_family != AF_UNIX || len <= offsetof(struct sockaddr_un, sun_path)
        || !un->sun_path[0])
        return 0;
    if (un->sun_path[0] == '/')
        strncpy(path, un->sun_path, sizeof(path) - 1);
    else
    {
        if (!getcwd(path, sizeof(path) - 200)) return 0;
        strcat(path, "/");
        strncat(path, un->sun_path, sizeof(un->sun_path));
    }
    path[sizeof(path) - 1] = 0;

    memset(out, 0, sizeof(*out));
    out->sun_family = AF_UNIX;
    /* keep the tail if the path is longer than an abstract name can be */
    size_t n = strlen(path), max = sizeof(out->sun_path) - 1;
    const char *p = n > max ? path + n - max : path;
    memcpy(out->sun_path + 1, p, strlen(p));
    *out_len = offsetof(struct sockaddr_un, sun_path) + 1 + strlen(p);
    return 1;
}

int bind(int fd, const struct sockaddr *addr, socklen_t len)
{
    static int (*real)(int, const struct sockaddr *, socklen_t);
    struct sockaddr_un un;
    socklen_t un_len;

    if (!real) real = dlsym(RTLD_NEXT, "bind");
    if (to_abstract(addr, len, &un, &un_len))
    {
        int ret = real(fd, (struct sockaddr *)&un, un_len);
        if (!ret) make_marker(addr);
        return ret;
    }
    return real(fd, addr, len);
}

int connect(int fd, const struct sockaddr *addr, socklen_t len)
{
    static int (*real)(int, const struct sockaddr *, socklen_t);
    struct sockaddr_un un;
    socklen_t un_len;

    if (!real) real = dlsym(RTLD_NEXT, "connect");
    if (to_abstract(addr, len, &un, &un_len)) return real(fd, (struct sockaddr *)&un, un_len);
    return real(fd, addr, len);
}

/* ntdll checks that wineserver's socket exists with lstat() before it
 * connects. The shell may not create socket or FIFO files, so bind() leaves a
 * regular marker file and lstat() reports it as a socket. */
#include <fcntl.h>
#include <sys/stat.h>

static int is_server_socket(const char *path)
{
    const char *name = strrchr(path, '/');
    char cwd[4096];

    name = name ? name + 1 : path;
    if (strcmp(name, "socket")) return 0;
    if (name != path) return strstr(path, "/server-") != NULL;
    return getcwd(cwd, sizeof(cwd)) && strstr(cwd, "/server-");
}

int lstat(const char *path, struct stat *st)
{
    static int (*real)(const char *, struct stat *);
    int ret;

    if (!real) real = dlsym(RTLD_NEXT, "lstat");
    ret = real(path, st);
    if (!ret && S_ISREG(st->st_mode) && is_server_socket(path))
        st->st_mode = S_IFSOCK | (st->st_mode & 07777);
    return ret;
}

static void make_marker(const struct sockaddr *addr)
{
    const struct sockaddr_un *un = (const struct sockaddr_un *)addr;
    int fd;

    if (!is_server_socket(un->sun_path)) return;
    if ((fd = open(un->sun_path, O_CREAT | O_WRONLY | O_TRUNC, 0600)) != -1) close(fd);
}

/* SELinux denies the shell "execmod": file pages that were written (Wine
 * applies PE relocations in place) can't be made executable. Anonymous
 * executable memory is allowed, so move the range into anonymous memory at
 * the same address and retry. */
#include <errno.h>
#include <stdlib.h>
#include <sys/mman.h>

int mprotect(void *addr, size_t len, int prot)
{
    static int (*real)(void *, size_t, int);
    void *copy;
    int ret;

    if (!real) real = dlsym(RTLD_NEXT, "mprotect");
    ret = real(addr, len, prot);
    if (!ret || errno != EACCES || !(prot & PROT_EXEC) || !len) return ret;

    /* the old protection may not allow reading; make it readable first */
    if (real(addr, len, PROT_READ)) { errno = EACCES; return -1; }
    if (!(copy = malloc(len))) { errno = ENOMEM; return -1; }
    memcpy(copy, addr, len);
    if (mmap(addr, len, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0) == MAP_FAILED)
    {
        free(copy);
        errno = ENOMEM;
        return -1;
    }
    memcpy(addr, copy, len);
    free(copy);
    return real(addr, len, prot);
}

