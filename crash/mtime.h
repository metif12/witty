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

static inline witty_crash_thread_state_s *witty_crash_thread_state_slot(void) {
    return &witty_crash_thread_state;
}
#else
/* A pthread key rather than _Thread_local: tcc, which is V's default C backend
 * for debug and test builds, miscompiles thread locals on macOS arm64. It emits
 * a direct TPIDR_EL0 plus static offset access, but Darwin resolves thread
 * locals dynamically, so the first write segfaults. Every supported toolchain
 * implements pthread keys correctly. */
#include <pthread.h>
#include <stdlib.h>

static pthread_key_t witty_crash_thread_state_key;
static pthread_once_t witty_crash_thread_state_once = PTHREAD_ONCE_INIT;

static void witty_crash_thread_state_destroy(void *value) {
    free(value);
}

static void witty_crash_thread_state_init(void) {
    pthread_key_create(&witty_crash_thread_state_key, witty_crash_thread_state_destroy);
}

static inline witty_crash_thread_state_s *witty_crash_thread_state_slot(void) {
    pthread_once(&witty_crash_thread_state_once, witty_crash_thread_state_init);
    witty_crash_thread_state_s *state =
        (witty_crash_thread_state_s *)pthread_getspecific(witty_crash_thread_state_key);
    if (!state) {
        state = (witty_crash_thread_state_s *)calloc(1, sizeof(*state));
        if (!state) return NULL;
        pthread_setspecific(witty_crash_thread_state_key, state);
    }
    return state;
}
#endif

static inline void witty_crash_thread_state_set(int kind, void *surface) {
    witty_crash_thread_state_s *state = witty_crash_thread_state_slot();
    if (!state) return;
    state->active = 1;
    state->kind = kind;
    state->surface = surface;
}

static inline void witty_crash_thread_state_clear(void) {
    witty_crash_thread_state_s *state = witty_crash_thread_state_slot();
    if (!state) return;
    state->active = 0;
    state->kind = 0;
    state->surface = NULL;
}

static inline int witty_crash_thread_state_get(int *kind, void **surface) {
    witty_crash_thread_state_s *state = witty_crash_thread_state_slot();
    if (!state || !state->active) return 0;
    *kind = state->kind;
    *surface = state->surface;
    return 1;
}

#endif
