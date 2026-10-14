#ifndef WITTY_IMAGE_FIFO_FIXTURES_H
#define WITTY_IMAGE_FIFO_FIXTURES_H
#include <stddef.h>
#ifndef _WIN32
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/stat.h>
/* The keeper lets public blocking path opens finish without another process. */
static int witty_image_fifo_open(const char *path) {
    if (mkfifo(path, 0600) != 0) return -1;
    int fd = open(path, O_RDWR | O_NONBLOCK);
    if (fd >= 0 && fd < 128) return fd;
    if (fd >= 0) close(fd);
    unlink(path); return -1;
}
static int witty_image_fifo_close(int fd) { return close(fd); }
static int witty_image_fifo_remove(const char *path) { return unlink(path); }
static int witty_image_fifo_valid(int fd) { return fcntl(fd, F_GETFD) < 0 ? 0 : 1; }
static int witty_image_fifo_kind(const char *path) {
    struct stat st;
    return stat(path, &st) == 0 && S_ISFIFO(st.st_mode) ? 1 : 0;
}
/* Isolated fixtures use descriptors below 128. Compare inode references, not IDs. */
static int witty_image_fifo_refs(int keeper) {
    struct stat target, st;
    if (fstat(keeper, &target) != 0) return -1;
    int count = 0;
    for (int fd = 0; fd < 128; ++fd)
        if (fstat(fd, &st) == 0 && st.st_dev == target.st_dev && st.st_ino == target.st_ino) ++count;
    return count;
}
static ptrdiff_t witty_image_fifo_write(int fd, const unsigned char *data, size_t len) { return write(fd, data, len); }
static ptrdiff_t witty_image_fifo_read(int fd, unsigned char *data, size_t len) {
    ptrdiff_t n = read(fd, data, len);
    if (n >= 0) return n;
    return errno == EAGAIN || errno == EWOULDBLOCK ? -1 : -2;
}
#else
static int witty_image_fifo_open(const char *path) { (void)path; return -1; }
static int witty_image_fifo_close(int fd) { (void)fd; return -1; }
static int witty_image_fifo_remove(const char *path) { (void)path; return -1; }
static int witty_image_fifo_valid(int fd) { (void)fd; return 0; }
static int witty_image_fifo_kind(const char *path) { (void)path; return 0; }
static int witty_image_fifo_refs(int fd) { (void)fd; return -1; }
static ptrdiff_t witty_image_fifo_write(int fd, const unsigned char *data, size_t len) { (void)fd; (void)data; (void)len; return -1; }
static ptrdiff_t witty_image_fifo_read(int fd, unsigned char *data, size_t len) { (void)fd; (void)data; (void)len; return -2; }
#endif
#endif
