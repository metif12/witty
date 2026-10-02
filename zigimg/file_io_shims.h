#ifndef WITTY_ZIGIMG_FILE_IO_H
#define WITTY_ZIGIMG_FILE_IO_H
#include <stdint.h>
#include <stddef.h>
#include <errno.h>
#ifdef _WIN32
#include <io.h>
#include <windows.h>
static int witty_image_file_size(int fd, uint64_t *size) {
    LARGE_INTEGER result;
    if (!GetFileSizeEx((HANDLE)_get_osfhandle(fd), &result)) return -1;
    *size = (uint64_t)result.QuadPart;
    return 0;
}
static intptr_t witty_image_file_read(int fd, uint64_t pos, unsigned char *buf, size_t count, int *streaming) {
    DWORD n;
    OVERLAPPED overlap = {0};
    overlap.Offset = (DWORD)pos;
    overlap.OffsetHigh = (DWORD)(pos >> 32);
    for (;;) {
        if (ReadFile((HANDLE)_get_osfhandle(fd), buf, count > UINT32_MAX ? UINT32_MAX : (DWORD)count, &n, *streaming ? NULL : &overlap)) return n;
        DWORD err = GetLastError();
        if (err == ERROR_OPERATION_ABORTED) continue;
        if (err == ERROR_BROKEN_PIPE || err == ERROR_HANDLE_EOF) return 0;
        return -1;
    }
}
static intptr_t witty_image_file_read_vec(int fd, uint64_t pos, unsigned char *a, size_t alen, unsigned char *b, size_t blen, int *streaming) {
    (void)b; (void)blen;
    return witty_image_file_read(fd, pos, a, alen, streaming);
}
static intptr_t witty_image_file_write(int fd, uint64_t pos, const unsigned char *a, size_t alen, const unsigned char *b, size_t blen, int *streaming) {
    DWORD n;
    OVERLAPPED overlap = {0};
    overlap.Offset = (DWORD)pos;
    overlap.OffsetHigh = (DWORD)(pos >> 32);
    const unsigned char *bytes = alen ? a : b;
    size_t count = alen ? alen : blen;
    if (!WriteFile((HANDLE)_get_osfhandle(fd), bytes, count > UINT32_MAX ? UINT32_MAX : (DWORD)count, &n, *streaming ? NULL : &overlap)) return -1;
    return n;
}
#else
#include <unistd.h>
#include <sys/stat.h>
#include <sys/uio.h>
static int witty_image_file_size(int fd, uint64_t *size) {
    struct stat st;
    if (fstat(fd, &st) != 0) return -1;
    if (!S_ISREG(st.st_mode)) return 1;
    *size = st.st_size;
    return 0;
}
static intptr_t witty_image_file_read(int fd, uint64_t pos, unsigned char *buf, size_t count, int *streaming) {
    ssize_t n;
    do {
        n = *streaming ? read(fd, buf, count) : pread(fd, buf, count, (off_t)pos);
    } while (n < 0 && errno == EINTR);
    if (n < 0 && errno == ESPIPE && !*streaming) {
        *streaming = 1;
        if (pos != 0) return -1;
        do { n = read(fd, buf, count); } while (n < 0 && errno == EINTR);
    }
    return n;
}
static intptr_t witty_image_file_read_vec(int fd, uint64_t pos, unsigned char *a, size_t alen, unsigned char *b, size_t blen, int *streaming) {
    struct iovec vectors[2] = {{a, alen}, {b, blen}};
    ssize_t n;
    do { n = *streaming ? readv(fd, vectors, 2) : preadv(fd, vectors, 2, (off_t)pos); }
    while (n < 0 && errno == EINTR);
    if (n < 0 && errno == ESPIPE && !*streaming) {
        *streaming = 1;
        if (pos != 0) return -1;
        do { n = readv(fd, vectors, 2); } while (n < 0 && errno == EINTR);
    }
    return n;
}
static intptr_t witty_image_file_write(int fd, uint64_t pos, const unsigned char *a, size_t alen, const unsigned char *b, size_t blen, int *streaming) {
    struct iovec vectors[2] = {{(void *)a, alen}, {(void *)b, blen}};
    ssize_t n;
    do {
        n = *streaming ? writev(fd, vectors, 2) : pwritev(fd, vectors, 2, (off_t)pos);
    } while (n < 0 && errno == EINTR);
    if (n < 0 && errno == ESPIPE && !*streaming) {
        *streaming = 1;
        if (pos != 0) return -1;
        do { n = writev(fd, vectors, 2); } while (n < 0 && errno == EINTR);
    }
    return n;
}
#endif
#endif
