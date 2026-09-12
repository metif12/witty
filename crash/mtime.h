#ifndef WITTY_CRASH_MTIME_H
#define WITTY_CRASH_MTIME_H

#include <stddef.h>
#include <stdint.h>
#include <errno.h>
#include <sys/stat.h>

static inline int witty_crash_file_info(
    const char *path,
    int *regular,
    int64_t *value
) {
#if defined(_WIN32)
    struct _stat64 stat_value;
    if (_stat64(path, &stat_value) != 0) return errno != 0 ? errno : EIO;
    *regular = (stat_value.st_mode & _S_IFMT) == _S_IFREG;
    *value = (int64_t)stat_value.st_mtime * INT64_C(1000000000);
#else
    struct stat stat_value;
    if (lstat(path, &stat_value) != 0) return errno != 0 ? errno : EIO;
    *regular = S_ISREG(stat_value.st_mode);
#if defined(__APPLE__)
    *value = (int64_t)stat_value.st_mtimespec.tv_sec * INT64_C(1000000000)
        + (int64_t)stat_value.st_mtimespec.tv_nsec;
#else
    *value = (int64_t)stat_value.st_mtim.tv_sec * INT64_C(1000000000)
        + (int64_t)stat_value.st_mtim.tv_nsec;
#endif
#endif
    return 0;
}

typedef struct witty_crash_thread_state_s {
    int active;
    int kind;
    void *surface;
} witty_crash_thread_state_s;

#if defined(_MSC_VER)
static __declspec(thread) witty_crash_thread_state_s witty_crash_thread_state;
#elif defined(__cplusplus)
static thread_local witty_crash_thread_state_s witty_crash_thread_state;
#else
static _Thread_local witty_crash_thread_state_s witty_crash_thread_state;
#endif

static inline void witty_crash_thread_state_set(int kind, void *surface) {
    witty_crash_thread_state.active = 1;
    witty_crash_thread_state.kind = kind;
    witty_crash_thread_state.surface = surface;
}

static inline void witty_crash_thread_state_clear(void) {
    witty_crash_thread_state.active = 0;
    witty_crash_thread_state.kind = 0;
    witty_crash_thread_state.surface = NULL;
}

static inline int witty_crash_thread_state_get(int *kind, void **surface) {
    if (!witty_crash_thread_state.active) return 0;
    *kind = witty_crash_thread_state.kind;
    *surface = witty_crash_thread_state.surface;
    return 1;
}

#endif
