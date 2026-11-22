#ifndef WITTY_METAL_GC_THREAD_H
#define WITTY_METAL_GC_THREAD_H

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
#include <stdbool.h>
#include <gc/gc.h>

static inline bool witty_metal_register_gc_thread(void) {
    struct GC_stack_base base;
    return GC_get_stack_base(&base) == GC_SUCCESS &&
           GC_register_my_thread(&base) == GC_SUCCESS;
}

static inline void witty_metal_unregister_gc_thread(void) {
    GC_unregister_my_thread();
}
#endif

#endif
