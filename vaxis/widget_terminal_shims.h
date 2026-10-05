#ifndef WITTY_VAXIS_TERMINAL_SHIMS_H
#define WITTY_VAXIS_TERMINAL_SHIMS_H
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <unistd.h>

static _Atomic(void *) witty_terminal_globals_ptr;
static pthread_mutex_t witty_terminal_globals_lock = PTHREAD_MUTEX_INITIALIZER;
static inline void witty_terminal_globals_lock_init(void) { pthread_mutex_lock(&witty_terminal_globals_lock); }
static inline void witty_terminal_globals_unlock_init(void) { pthread_mutex_unlock(&witty_terminal_globals_lock); }
static inline void *witty_terminal_globals_get(void) { return atomic_load_explicit(&witty_terminal_globals_ptr, memory_order_acquire); }
static inline void witty_terminal_globals_set(void *ptr) { atomic_store_explicit(&witty_terminal_globals_ptr, ptr, memory_order_release); }
static inline int witty_terminal_errno(void) { return errno; }
static inline int witty_terminal_close(int fd) { return close(fd); }
static inline long witty_terminal_eot(int fd) {
    const unsigned char byte = 4;
    long result;
    do { result = write(fd, &byte, 1); } while (result < 0 && errno == EINTR);
    return result;
}
static inline int witty_terminal_kill(int pid) { return kill(pid, SIGTERM); }
static inline int witty_terminal_waitpid(void) {
    int status, pid;
    do { pid = waitpid(-1, &status, 0); } while (pid < 0 && errno == EINTR);
    return pid;
}
static inline int witty_terminal_sigchild(void (*entry)(int)) {
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = entry;
    sigemptyset(&action.sa_mask);
    return sigaction(SIGCHLD, &action, NULL);
}
static inline void *witty_terminal_thread_start(void *(*entry)(void *), void *context, int *result) {
    pthread_t *handle = malloc(sizeof(pthread_t));
    if (!handle) { *result = -1; return NULL; }
    pthread_attr_t attrs;
    *result = pthread_attr_init(&attrs);
    if (*result) { *result = -2; free(handle); return NULL; }
    if (pthread_attr_setstacksize(&attrs, 16 * 1024 * 1024) != 0 ||
        pthread_attr_setguardsize(&attrs, (size_t)getpagesize()) != 0) abort();
    *result = pthread_create(handle, &attrs, entry, context);
    if (pthread_attr_destroy(&attrs) != 0) abort();
    if (*result) { free(handle); return NULL; }
    return handle;
}
static inline int witty_terminal_thread_join(void *handle) {
    int result = pthread_join(*(pthread_t *)handle, NULL);
    free(handle);
    return result;
}
#ifdef __linux__
static inline int witty_terminal_open(const char *path) {
    int fd;
    do { fd = open(path, O_RDWR | O_NOCTTY); } while (fd < 0 && errno == EINTR);
    return fd;
}
static inline int witty_terminal_unlockpt(int fd) {
    unsigned n = 0;
    return ioctl(fd, TIOCSPTLCK, &n);
}
static inline int witty_terminal_ptsname(int fd, unsigned *number) { return ioctl(fd, TIOCGPTN, number); }
static inline int witty_terminal_set_size(int fd, uint16_t rows, uint16_t cols, uint16_t xp, uint16_t yp) {
    struct winsize ws = {rows, cols, xp, yp};
    return ioctl(fd, TIOCSWINSZ, &ws);
}
static inline int witty_terminal_control_tty(int fd) {
    unsigned n = STDIN_FILENO;
    return ioctl(fd, TIOCSCTTY, &n);
}
static inline int witty_terminal_fork(void) { return fork(); }
static inline int witty_terminal_setsid(void) { return setsid(); }
static inline int witty_terminal_dup2(int from, int to) {
    int result;
    do { result = dup2(from, to); } while (result < 0 && (errno == EINTR || errno == EBUSY));
    return result;
}
static inline int witty_terminal_chdir(const char *path) { return chdir(path); }
// Zig's execvpe ignores empty PATH segments, does not expand argv[0], and
// returns an exec error without launching a shell. The caller retains that
// source error-ignoring fallthrough.
static inline void witty_terminal_exec(char *const *argv, char *const *envp) {
    const char *file = argv[0];
    if (!file) abort();
    if (strchr(file, '/')) { execve(file, argv, envp); return; }
    const char *path = getenv("PATH");
    if (!path) path = "/usr/local/bin:/bin/:/usr/bin";
    char candidate[4096];
    int access_denied = 0;
    while (*path) {
        while (*path == ':') ++path;
        if (!*path) break;
        const char *end = strchr(path, ':');
        if (!end) end = path + strlen(path);
        size_t length = (size_t)(end - path), file_length = strlen(file);
        if (length + file_length + 2 > sizeof(candidate)) return;
        memcpy(candidate, path, length);
        candidate[length] = '/';
        memcpy(candidate + length + 1, file, file_length + 1);
        execve(candidate, argv, envp);
        if (errno == EACCES) access_denied = 1;
        else if (errno != ENOENT && errno != ENOTDIR) return;
        path = end;
    }
    if (access_denied) errno = EACCES;
}
static inline long witty_terminal_cwd_path(unsigned char *bytes, size_t length) {
    // std.fs.cwd().fd is AT_FDCWD; getFdPath does not special-case it.
    return readlink("/proc/self/fd/-100", (char *)bytes, length);
}
#endif
#endif
