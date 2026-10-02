/* Translation of Zig 0.15.2 std.heap.CAllocator's libc operations. */
#ifndef WITTY_LIB_C_ALLOCATOR_H
#define WITTY_LIB_C_ALLOCATOR_H
#include <stdlib.h>
#include <stdint.h>
#if defined(_MSC_VER)
#define witty_c_type_alignment(value) __alignof(*(value))
#else
#define witty_c_type_alignment(value) __alignof__(__typeof__(*(value)))
#endif
#if defined(__APPLE__)
#include <malloc/malloc.h>
#elif defined(__linux__) || defined(__FreeBSD__) || defined(_WIN32)
#include <malloc.h>
#endif

#if defined(__unix__) || defined(__APPLE__)
#define WITTY_HAS_POSIX_MEMALIGN 1
#else
#define WITTY_HAS_POSIX_MEMALIGN 0
#endif

static void *witty_c_aligned_alloc(size_t len, uint8_t alignment) {
    if (alignment >= sizeof(size_t) * 8) return NULL;
    const size_t bytes = (size_t)1 << alignment;
#if WITTY_HAS_POSIX_MEMALIGN
    void *ptr = NULL;
    const size_t effective = bytes > sizeof(size_t) ? bytes : sizeof(size_t);
    return posix_memalign(&ptr, effective, len) == 0 ? ptr : NULL;
#else
    if (len > SIZE_MAX - bytes + 1 - sizeof(size_t)) return NULL;
    void *raw = malloc(len + bytes - 1 + sizeof(size_t));
    if (!raw) return NULL;
    uintptr_t address = ((uintptr_t)raw + sizeof(size_t) + bytes - 1) & ~(bytes - 1);
    ((void **)address)[-1] = raw;
    return (void *)address;
#endif
}

static void witty_c_aligned_free(void *ptr) {
#if WITTY_HAS_POSIX_MEMALIGN
    free(ptr);
#else
    free(((void **)ptr)[-1]);
#endif
}

static size_t witty_c_aligned_size(void *ptr) {
#if !WITTY_HAS_POSIX_MEMALIGN
    void *raw = ((void **)ptr)[-1];
    size_t delta = (uintptr_t)ptr - (uintptr_t)raw;
#else
    void *raw = ptr;
    size_t delta = 0;
#endif
#if defined(__APPLE__)
    return malloc_size(raw) - delta;
#elif defined(__linux__) || defined(__FreeBSD__)
    return malloc_usable_size(raw) - delta;
#elif defined(_WIN32)
    return _msize(raw) - delta;
#else
    (void)raw; (void)delta;
    return 0;
#endif
}
#endif
