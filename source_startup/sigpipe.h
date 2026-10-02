#ifndef WITTY_SOURCE_STARTUP_SIGPIPE_H
#define WITTY_SOURCE_STARTUP_SIGPIPE_H
#if defined(__linux__) || defined(__APPLE__) || defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__) || defined(__DragonFly__) || defined(__sun) || defined(__HAIKU__)
#include <signal.h>
static void witty_source_startup_sigpipe_handler(int signal_number) { (void)signal_number; }
static int witty_source_startup_sigpipe(void) {
    /* Zig 0.15.2 std/start.zig: do not use SIG_IGN, which survives exec. */
    struct sigaction action = {0};
    action.sa_handler = witty_source_startup_sigpipe_handler;
    sigemptyset(&action.sa_mask);
    return sigaction(SIGPIPE, &action, NULL);
}
#else
static int witty_source_startup_sigpipe(void) { return 0; }
#endif
#endif
