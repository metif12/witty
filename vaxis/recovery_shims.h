#ifndef WITTY_VAXIS_RECOVERY_SHIMS_H
#define WITTY_VAXIS_RECOVERY_SHIMS_H

/* A static root retains the GC-owned value snapshot without requiring V globals.
 * Like Source global_tty, registration and recovery are not synchronization APIs. */
static void *witty_vaxis_recovery_tty_ptr;
static inline void *witty_vaxis_recovery_tty_get(void) {
    return witty_vaxis_recovery_tty_ptr;
}
static inline void witty_vaxis_recovery_tty_set(void *value) {
    witty_vaxis_recovery_tty_ptr = value;
}
#endif
