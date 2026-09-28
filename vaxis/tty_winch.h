#ifndef WITTY_VAXIS_TTY_WINCH_H
#define WITTY_VAXIS_TTY_WINCH_H

#include <pthread.h>
#include <signal.h>
#include <string.h>

typedef void (*witty_vaxis_winch_callback)(void *);

struct witty_vaxis_winch_handler {
    void *context;
    witty_vaxis_winch_callback callback;
};

static struct witty_vaxis_winch_handler witty_vaxis_winch_handlers[8];
static pthread_mutex_t witty_vaxis_winch_mutex = PTHREAD_MUTEX_INITIALIZER;
static unsigned int witty_vaxis_winch_handler_idx = 0;
static int witty_vaxis_winch_installed = 0;

static void witty_vaxis_handle_winch(int signal_number) {
    (void)signal_number;
    pthread_mutex_lock(&witty_vaxis_winch_mutex);
    for (unsigned int i = 0; i < witty_vaxis_winch_handler_idx; i++) {
        struct witty_vaxis_winch_handler handler = witty_vaxis_winch_handlers[i];
        handler.callback(handler.context);
    }
    pthread_mutex_unlock(&witty_vaxis_winch_mutex);
}

static void witty_vaxis_install_winch(void) {
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = witty_vaxis_handle_winch;
    sigemptyset(&action.sa_mask);
    action.sa_flags = 0;
    sigaction(SIGWINCH, &action, NULL);
    witty_vaxis_winch_installed = 1;
}

static void witty_vaxis_reset_winch(void) {
    if (!witty_vaxis_winch_installed) return;
    witty_vaxis_winch_installed = 0;
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = SIG_DFL;
    sigemptyset(&action.sa_mask);
    action.sa_flags = 0;
    sigaction(SIGWINCH, &action, NULL);
}

static int witty_vaxis_notify_winch(void *context, witty_vaxis_winch_callback callback) {
    pthread_mutex_lock(&witty_vaxis_winch_mutex);
    if (witty_vaxis_winch_handler_idx == 8) {
        pthread_mutex_unlock(&witty_vaxis_winch_mutex);
        return 0;
    }
    witty_vaxis_winch_handlers[witty_vaxis_winch_handler_idx].context = context;
    witty_vaxis_winch_handlers[witty_vaxis_winch_handler_idx].callback = callback;
    witty_vaxis_winch_handler_idx++;
    pthread_mutex_unlock(&witty_vaxis_winch_mutex);
    return 1;
}

#endif
