#ifndef WITTY_GLOBAL_STATE_SHIMS_H
#define WITTY_GLOBAL_STATE_SHIMS_H

#ifndef _WIN32
#include <signal.h>

static inline void witty_ignore_sigpipe(void) {
    signal(SIGPIPE, SIG_IGN);
}
#else
static inline void witty_ignore_sigpipe(void) {}
#endif

#endif
