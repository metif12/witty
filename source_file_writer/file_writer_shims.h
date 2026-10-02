#ifndef WITTY_SYNTHETIC_FILE_WRITER_SHIMS_H
#define WITTY_SYNTHETIC_FILE_WRITER_SHIMS_H
#include <stdint.h>
#include <stddef.h>
#ifdef _WIN32
#include <windows.h>
#include <io.h>
static int witty_synthetic_seek(int fd, uint64_t offset) { return _lseeki64(fd, (int64_t)offset, SEEK_SET) < 0 ? -1 : 0; }
static intptr_t witty_synthetic_file_drain(int fd, int positional, uint64_t offset,
    const void *prefix, size_t prefix_len, const void *data, size_t data_len,
    int *unseekable) {
    HANDLE handle = (HANDLE)_get_osfhandle(fd);
    const void *bytes = prefix_len ? prefix : data;
    size_t len = prefix_len ? prefix_len : data_len;
    if (!len) return 0;
    OVERLAPPED overlapped = {0};
    overlapped.Offset = (DWORD)offset;
    overlapped.OffsetHigh = (DWORD)(offset >> 32);
    DWORD count = 0;
    if (!WriteFile(handle, bytes, len > UINT32_MAX ? UINT32_MAX : (DWORD)len,
                   &count, positional ? &overlapped : NULL)) {
        DWORD err = GetLastError();
        *unseekable = positional && (err == ERROR_INVALID_PARAMETER || err == ERROR_INVALID_FUNCTION);
        return -1;
    }
    return count;
}
#else
#include <errno.h>
#include <unistd.h>
#include <sys/uio.h>
static int witty_synthetic_seek(int fd, uint64_t offset) { return lseek(fd, (off_t)offset, SEEK_SET) < 0 ? -1 : 0; }
// ABI adaptation for fs.File.Writer.drain + posix.{pwritev,writev}; only two
// vectors occur in the generator's write/flush calls. Retry EINTR as source.
static intptr_t witty_synthetic_file_drain(int fd, int positional, uint64_t offset,
    const void *prefix, size_t prefix_len, const void *data, size_t data_len,
    int *unseekable) {
    struct iovec vectors[2];
    int len = 0;
    if (prefix_len) vectors[len++] = (struct iovec){(void *)prefix, prefix_len};
    if (data_len) vectors[len++] = (struct iovec){(void *)data, data_len};
    if (!len) return 0;
    ssize_t count;
    do {
#if defined(__APPLE__) || defined(__HAIKU__)
        // Zig std.posix.pwritev on these targets writes the first vector.
        count = positional ? pwrite(fd, vectors[0].iov_base, vectors[0].iov_len, (off_t)offset)
                           : writev(fd, vectors, len);
#else
        count = positional ? pwritev(fd, vectors, len, (off_t)offset) : writev(fd, vectors, len);
#endif
    } while (count < 0 && errno == EINTR);
    if (count < 0) *unseekable = positional && (errno == ESPIPE || errno == ENXIO || errno == EOVERFLOW);
    return count;
}
#endif
#endif
