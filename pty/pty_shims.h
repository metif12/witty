#ifndef WITTY_PTY_SHIMS_H
#define WITTY_PTY_SHIMS_H

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <string.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

#if defined(__APPLE__)
#include <util.h>
#else
#include <pty.h>
#endif

static inline int witty_pty_enable_utf8(int fd) {
    struct termios attrs;
    if (tcgetattr(fd, &attrs) != 0) return -1;
#ifdef IUTF8
    attrs.c_iflag |= IUTF8;
#endif
    return tcsetattr(fd, TCSANOW, &attrs);
}

static inline int witty_pty_get_mode(int fd, int *canonical, int *echo) {
    struct termios attrs;
    if (tcgetattr(fd, &attrs) != 0) return -1;
    *canonical = (attrs.c_lflag & ICANON) != 0;
    *echo = (attrs.c_lflag & ECHO) != 0;
    return 0;
}

static inline int witty_pty_get_size(int fd, uint16_t *row, uint16_t *col,
                                     uint16_t *xpixel, uint16_t *ypixel) {
    struct winsize ws;
    memset(&ws, 0, sizeof(ws));
    if (ioctl(fd, TIOCGWINSZ, &ws) != 0) return -1;
    *row = ws.ws_row;
    *col = ws.ws_col;
    *xpixel = ws.ws_xpixel;
    *ypixel = ws.ws_ypixel;
    return 0;
}

static inline int witty_pty_set_size(int fd, uint16_t row, uint16_t col,
                                     uint16_t xpixel, uint16_t ypixel) {
    struct winsize ws;
    memset(&ws, 0, sizeof(ws));
    ws.ws_row = row;
    ws.ws_col = col;
    ws.ws_xpixel = xpixel;
    ws.ws_ypixel = ypixel;
    return ioctl(fd, TIOCSWINSZ, &ws);
}

static inline int witty_pty_set_controlling_terminal(int fd) {
    return ioctl(fd, TIOCSCTTY, 0);
}

static inline int witty_pty_reset_signals(void) {
    static const int signals[] = {
        SIGABRT, SIGALRM, SIGBUS, SIGCHLD, SIGFPE, SIGHUP, SIGILL,
        SIGINT, SIGPIPE, SIGSEGV, SIGTRAP, SIGTERM, SIGQUIT,
    };
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = SIG_DFL;
    sigemptyset(&action.sa_mask);
    for (size_t i = 0; i < sizeof(signals) / sizeof(signals[0]); ++i) {
        if (sigaction(signals[i], &action, NULL) != 0) return -1;
    }
    return 0;
}

#endif
