#ifndef WITTY_MACH_MEMORY_H
#define WITTY_MACH_MEMORY_H

#include <stdint.h>
#include <stddef.h>
#include <sys/mman.h>
#include <unistd.h>

#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif

static inline size_t witty_tagged_page_size(void) {
    const long value = sysconf(_SC_PAGESIZE);
    return value > 0 ? (size_t)value : (size_t)4096;
}

static inline size_t witty_tagged_page_align_forward(size_t value, size_t alignment) {
    const size_t remainder = value % alignment;
    return remainder == 0 ? value : value + alignment - remainder;
}

static inline void *witty_tagged_page_map(
    size_t length,
    size_t alignment,
    int32_t tag,
    size_t *mapped_length
) {
    const size_t page_size = witty_tagged_page_size();
    if (length == 0 || length > SIZE_MAX - page_size) return NULL;
    if (alignment < page_size) alignment = page_size;
    if ((alignment & (alignment - 1)) != 0) return NULL;

    const size_t aligned_length = witty_tagged_page_align_forward(length, page_size);
    const size_t max_drop = alignment - page_size;
    size_t overalloc_length = aligned_length;
    if (max_drop > aligned_length - length) {
        if (aligned_length > SIZE_MAX - max_drop) return NULL;
        overalloc_length = witty_tagged_page_align_forward(
            aligned_length + max_drop,
            page_size
        );
    }

#if defined(__APPLE__)
    const int descriptor = tag;
#else
    (void)tag;
    const int descriptor = -1;
#endif
    void *const base = mmap(
        NULL,
        overalloc_length,
        PROT_READ | PROT_WRITE,
        MAP_PRIVATE | MAP_ANONYMOUS,
        descriptor,
        0
    );
    if (base == MAP_FAILED) return NULL;

    const uintptr_t base_address = (uintptr_t)base;
    const uintptr_t result_address = (base_address + alignment - 1)
        & ~(uintptr_t)(alignment - 1);
    const size_t prefix = (size_t)(result_address - base_address);
    if (prefix != 0) munmap(base, prefix);

    const size_t remaining = overalloc_length - prefix;
    if (remaining > aligned_length) {
        munmap((void *)(result_address + aligned_length), remaining - aligned_length);
    }

    *mapped_length = aligned_length;
    return (void *)result_address;
}

static inline void *witty_tagged_page_realloc(
    void *memory,
    size_t old_mapped_length,
    size_t new_length,
    int may_move,
    size_t *new_mapped_length
) {
    (void)may_move;
    const size_t page_size = witty_tagged_page_size();
    const size_t aligned_new = witty_tagged_page_align_forward(new_length, page_size);
    if (aligned_new == old_mapped_length) {
        *new_mapped_length = old_mapped_length;
        return memory;
    }
    if (aligned_new < old_mapped_length) {
        void *const tail = (void *)((uintptr_t)memory + aligned_new);
        if (munmap(tail, old_mapped_length - aligned_new) != 0) return NULL;
        *new_mapped_length = aligned_new;
        return memory;
    }
    return NULL;
}

static inline void witty_tagged_page_unmap(void *memory, size_t mapped_length) {
    if (memory != NULL && mapped_length != 0) munmap(memory, mapped_length);
}

#endif
