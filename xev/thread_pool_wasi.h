#ifndef WITTY_XEV_THREAD_POOL_WASI_H
#define WITTY_XEV_THREAD_POOL_WASI_H
/* std.ThreadPool.Thread.current's source threadlocal pointer. */
static _Thread_local void *witty_xev_thread_current;
static inline void *witty_xev_thread_current_get(void) {
    return witty_xev_thread_current;
}
static inline void witty_xev_thread_current_set(void *value) {
    witty_xev_thread_current = value;
}
#endif
