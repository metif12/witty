#ifndef WITTY_IMAGE_PIPE_FIXTURES_H
#define WITTY_IMAGE_PIPE_FIXTURES_H
#include <stddef.h>
#ifndef _WIN32
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
static int witty_image_pipe_open(int *fds) {
    if (pipe(fds) != 0) return -1;
    if (fcntl(fds[0], F_SETFL, O_NONBLOCK) >= 0) return 0;
    close(fds[0]); close(fds[1]); return -1;
}
static int witty_image_pipe_close(int fd) { return close(fd); }
static int witty_image_pipe_valid(int fd) { return fcntl(fd, F_GETFD) < 0 ? 0 : 1; }
static ptrdiff_t witty_image_pipe_write(int fd, const unsigned char *data, size_t len) { return write(fd, data, len); }
/* Distinguish an empty live pipe (-1) from a descriptor/read failure (-2). */
static ptrdiff_t witty_image_pipe_read(int fd, unsigned char *data, size_t len) {
    ptrdiff_t n = read(fd, data, len);
    if (n >= 0) return n;
    return errno == EAGAIN || errno == EWOULDBLOCK ? -1 : -2;
}
#else
static int witty_image_pipe_open(int *fds) { (void)fds; return -1; }
static int witty_image_pipe_close(int fd) { (void)fd; return -1; }
static int witty_image_pipe_valid(int fd) { (void)fd; return 0; }
static ptrdiff_t witty_image_pipe_write(int fd, const unsigned char *data, size_t len) { (void)fd; (void)data; (void)len; return -1; }
static ptrdiff_t witty_image_pipe_read(int fd, unsigned char *data, size_t len) { (void)fd; (void)data; (void)len; return -2; }
#endif
#endif
