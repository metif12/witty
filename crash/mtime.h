#ifndef WITTY_CRASH_MTIME_H
#define WITTY_CRASH_MTIME_H

#include <stdint.h>
#include <sys/stat.h>

static inline int witty_crash_file_mtime_ns(
    const char *path,
    int64_t *value
) {
#if defined(_WIN32)
    struct _stat64 stat_value;
    if (_stat64(path, &stat_value) != 0) return -1;
    *value = (int64_t)stat_value.st_mtime * INT64_C(1000000000);
#else
    struct stat stat_value;
    if (stat(path, &stat_value) != 0) return -1;
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

#endif
