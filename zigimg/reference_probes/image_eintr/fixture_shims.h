#ifndef WITTY_IMAGE_EINTR_FIXTURES_H
#define WITTY_IMAGE_EINTR_FIXTURES_H
#include <stddef.h>
#ifdef WITTY_IMAGE_EINTR_DECLARATIONS
int witty_image_eintr_remove(const char *);
int witty_image_eintr_close(int);
int witty_image_eintr_kind(const char *);
int witty_image_eintr_valid(int);
int witty_image_eintr_refs(int);
ptrdiff_t witty_image_eintr_read(int, unsigned char *, size_t);
int witty_image_eintr_create(const char *);
int witty_image_eintr_begin(const char *, int, const unsigned char *, size_t);
int witty_image_eintr_finish(void);
int witty_image_eintr_metric(int);
int witty_image_eintr_raw(const char *, int);
#else
#ifdef WITTY_IMAGE_EINTR_NATIVE
#define WITTY_IMAGE_EINTR_LINKAGE
#else
#define WITTY_IMAGE_EINTR_LINKAGE static
#endif
#ifndef _WIN32
#include <unistd.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <string.h>
#include <time.h>
#include <errno.h>
#include <sys/stat.h>
/* Only this isolated fixture's calling thread receives SIGUSR1. The worker
   releases the FIFO after acknowledged deliveries; no image syscall is wrapped. */
static pthread_t witty_image_eintr_caller, witty_image_eintr_worker;
static struct sigaction witty_image_eintr_previous_action;
static sigset_t witty_image_eintr_previous_mask;
static const char *witty_image_eintr_path;
static const unsigned char *witty_image_eintr_seed;
static size_t witty_image_eintr_seed_len;
static int witty_image_eintr_signals, witty_image_eintr_count, witty_image_eintr_done;
static int witty_image_eintr_metrics[6], witty_image_eintr_keeper, witty_image_eintr_running;
static void witty_image_eintr_handler(int signal_number) {
    (void)signal_number;
    __atomic_fetch_add(&witty_image_eintr_count, 1, __ATOMIC_RELAXED);
}
static void witty_image_eintr_pause(long nanoseconds) {
    struct timespec remaining = {0, nanoseconds};
    while (nanosleep(&remaining, &remaining) != 0 && errno == EINTR) {}
}
static int witty_image_eintr_path_refs(const char *path) {
    struct stat target, st;
    if (stat(path, &target) != 0) return -1;
    int refs = 0;
    for (int fd = 0; fd < 128; ++fd)
        if (fstat(fd, &st) == 0 && st.st_dev == target.st_dev && st.st_ino == target.st_ino) ++refs;
    return refs;
}
static void *witty_image_eintr_release(void *unused) {
    (void)unused;
    witty_image_eintr_pause(20000000);
    for (int i = 1; i <= witty_image_eintr_signals; ++i) {
        if (__atomic_load_n(&witty_image_eintr_done, __ATOMIC_ACQUIRE)) witty_image_eintr_metrics[1] = 1;
        if (pthread_kill(witty_image_eintr_caller, SIGUSR1) != 0) witty_image_eintr_metrics[5] = 1;
        int wait = 0;
        while (__atomic_load_n(&witty_image_eintr_count, __ATOMIC_RELAXED) < i && wait++ < 1000)
            witty_image_eintr_pause(1000000);
        if (wait >= 1000) witty_image_eintr_metrics[5] = 2;
        witty_image_eintr_pause(2000000);
    }
    if (__atomic_load_n(&witty_image_eintr_done, __ATOMIC_ACQUIRE)) witty_image_eintr_metrics[1] = 1;
    witty_image_eintr_metrics[2] = witty_image_eintr_path_refs(witty_image_eintr_path);
    witty_image_eintr_keeper = open(witty_image_eintr_path, O_RDWR | O_NONBLOCK | O_CLOEXEC);
    if (witty_image_eintr_keeper < 0 || witty_image_eintr_keeper >= 128) witty_image_eintr_metrics[5] = 3;
    if (witty_image_eintr_seed_len && write(witty_image_eintr_keeper, witty_image_eintr_seed, witty_image_eintr_seed_len) != (ptrdiff_t)witty_image_eintr_seed_len)
        witty_image_eintr_metrics[5] = 4;
    return NULL;
}
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_remove(const char *path) { return unlink(path); }
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_close(int fd) { return close(fd); }
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_kind(const char *path) {
    struct stat st; return stat(path, &st) == 0 && S_ISFIFO(st.st_mode);
}
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_valid(int fd) { return fcntl(fd, F_GETFD) >= 0; }
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_refs(int keeper) {
    struct stat target, st;
    if (fstat(keeper, &target) != 0) return -1;
    int refs = 0;
    for (int fd = 0; fd < 128; ++fd)
        if (fstat(fd, &st) == 0 && st.st_dev == target.st_dev && st.st_ino == target.st_ino) ++refs;
    return refs;
}
WITTY_IMAGE_EINTR_LINKAGE ptrdiff_t witty_image_eintr_read(int fd, unsigned char *data, size_t len) {
    ptrdiff_t n = read(fd, data, len);
    if (n >= 0) return n;
    return errno == EAGAIN || errno == EWOULDBLOCK ? -1 : -2;
}
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_create(const char *path) { return mkfifo(path, 0600); }
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_begin(const char *path, int signals, const unsigned char *seed, size_t seed_len) {
    if (witty_image_eintr_running || (signals != 1 && signals != 3) || !__atomic_always_lock_free(sizeof(int), 0)) return -1;
    memset(witty_image_eintr_metrics, 0, sizeof(witty_image_eintr_metrics));
    __atomic_store_n(&witty_image_eintr_count, 0, __ATOMIC_RELAXED);
    __atomic_store_n(&witty_image_eintr_done, 0, __ATOMIC_RELAXED);
    witty_image_eintr_path = path; witty_image_eintr_seed = seed; witty_image_eintr_seed_len = seed_len;
    witty_image_eintr_signals = signals; witty_image_eintr_keeper = -1;
    witty_image_eintr_caller = pthread_self();
    struct sigaction action; memset(&action, 0, sizeof(action));
    action.sa_handler = witty_image_eintr_handler; sigemptyset(&action.sa_mask);
    /* flags deliberately omit SA_RESTART. */
    if (sigaction(SIGUSR1, &action, &witty_image_eintr_previous_action) != 0) return -1;
    sigset_t unblocked; sigemptyset(&unblocked); sigaddset(&unblocked, SIGUSR1);
    if (pthread_sigmask(SIG_UNBLOCK, &unblocked, &witty_image_eintr_previous_mask) != 0) {
        sigaction(SIGUSR1, &witty_image_eintr_previous_action, NULL); return -1;
    }
    if (pthread_create(&witty_image_eintr_worker, NULL, witty_image_eintr_release, NULL) != 0) {
        pthread_sigmask(SIG_SETMASK, &witty_image_eintr_previous_mask, NULL);
        sigaction(SIGUSR1, &witty_image_eintr_previous_action, NULL); return -1;
    }
    witty_image_eintr_running = 1; return 0;
}
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_finish(void) {
    if (!witty_image_eintr_running) return witty_image_eintr_keeper;
    __atomic_store_n(&witty_image_eintr_done, 1, __ATOMIC_RELEASE);
    if (pthread_join(witty_image_eintr_worker, NULL) != 0) witty_image_eintr_metrics[5] = 5;
    witty_image_eintr_metrics[0] = __atomic_load_n(&witty_image_eintr_count, __ATOMIC_RELAXED);
    if (sigaction(SIGUSR1, &witty_image_eintr_previous_action, NULL) != 0 || pthread_sigmask(SIG_SETMASK, &witty_image_eintr_previous_mask, NULL) != 0)
        witty_image_eintr_metrics[5] = 6;
    struct sigaction action; sigset_t mask;
    if (sigaction(SIGUSR1, NULL, &action) != 0 || pthread_sigmask(SIG_SETMASK, NULL, &mask) != 0) witty_image_eintr_metrics[5] = 7;
    else {
        witty_image_eintr_metrics[3] = action.sa_handler == witty_image_eintr_previous_action.sa_handler && (action.sa_flags & SA_RESTART) == (witty_image_eintr_previous_action.sa_flags & SA_RESTART);
        witty_image_eintr_metrics[4] = sigismember(&mask, SIGUSR1) == sigismember(&witty_image_eintr_previous_mask, SIGUSR1);
    }
    witty_image_eintr_running = 0; return witty_image_eintr_keeper;
}
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_metric(int metric) { return metric >= 0 && metric < 6 ? witty_image_eintr_metrics[metric] : -1; }
/* Calibration is one actual libc open, without retry, under the same worker.
   Its normalized return must establish EINTR; it does not substitute public IO. */
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_raw(const char *path, int writing) {
    int fd = open(path, writing ? O_WRONLY : O_RDONLY);
    int interrupted = fd < 0 && errno == EINTR;
    if (fd >= 0) close(fd);
    return interrupted;
}
#else
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_remove(const char *p) { (void)p; return -1; }
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_close(int f) { (void)f; return -1; }
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_kind(const char *p) { (void)p; return 0; }
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_valid(int f) { (void)f; return 0; }
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_refs(int f) { (void)f; return -1; }
WITTY_IMAGE_EINTR_LINKAGE ptrdiff_t witty_image_eintr_read(int f, unsigned char *b, size_t n) { (void)f; (void)b; (void)n; return -2; }
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_create(const char *p) { (void)p; return -1; }
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_begin(const char *p, int s, const unsigned char *b, size_t n) { (void)p; (void)s; (void)b; (void)n; return -1; }
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_finish(void) { return -1; }
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_metric(int m) { (void)m; return -1; }
WITTY_IMAGE_EINTR_LINKAGE int witty_image_eintr_raw(const char *p, int w) { (void)p; (void)w; return -1; }
#endif
#endif
#endif
