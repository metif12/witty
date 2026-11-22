#ifndef WITTY_IOCP_CLOCK_WINDOWS_H
#define WITTY_IOCP_CLOCK_WINDOWS_H

#include <stdint.h>
#include <windows.h>

/* Keep the SDK's LARGE_INTEGER out of V's module-wide C declarations. */
static inline int witty_iocp_query_performance_frequency(int64_t *frequency) {
    LARGE_INTEGER value;
    if (!QueryPerformanceFrequency(&value)) return 0;
    *frequency = value.QuadPart;
    return 1;
}

static inline int witty_iocp_query_performance_counter(int64_t *counter) {
    LARGE_INTEGER value;
    if (!QueryPerformanceCounter(&value)) return 0;
    *counter = value.QuadPart;
    return 1;
}

#endif
