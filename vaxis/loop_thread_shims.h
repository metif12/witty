#ifndef WITTY_VAXIS_LOOP_THREAD_SHIMS_H
#define WITTY_VAXIS_LOOP_THREAD_SHIMS_H

#ifdef _WIN32
static inline void *witty_vaxis_create_thread(void *entry, void *context) {
    return CreateThread(NULL, 16 * 1024 * 1024,
                        (LPTHREAD_START_ROUTINE)entry, context, 0, NULL);
}
#else
static inline int witty_vaxis_pthread_join(pthread_t handle) {
    return pthread_join(handle, NULL);
}
#endif

#endif
