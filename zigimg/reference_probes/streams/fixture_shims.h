#ifndef WITTY_STREAM_FIXTURES_H
#define WITTY_STREAM_FIXTURES_H
#include <stddef.h>
#ifndef _WIN32
#include <unistd.h>
#include <fcntl.h>
static int witty_stream_probe_pipe(int *fds) {
    if (pipe(fds) != 0) return -1;
    if (fcntl(fds[0], F_SETFL, O_NONBLOCK) >= 0) return 0;
    close(fds[0]);
    close(fds[1]);
    return -1;
}
static int witty_stream_probe_close(int fd) { return close(fd); }
static ptrdiff_t witty_stream_probe_read(int fd, unsigned char *bytes, size_t len) {
    return read(fd, bytes, len);
}
#else
/* Runtime pipe comparisons are native POSIX checks. Keep Windows test builds
   valid while retaining the regular-file coverage on that target. */
static int witty_stream_probe_pipe(int *fds) { (void)fds; return -1; }
static int witty_stream_probe_close(int fd) { (void)fd; return -1; }
static ptrdiff_t witty_stream_probe_read(int fd, unsigned char *bytes, size_t len) {
    (void)fd; (void)bytes; (void)len; return -1;
}
#endif
#endif
