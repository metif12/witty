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
static int witty_image_file_seek(int fd, uint64_t pos) {
    LARGE_INTEGER offset;
    offset.QuadPart = (LONGLONG)pos;
    if (SetFilePointerEx((HANDLE)_get_osfhandle(fd), offset, NULL, FILE_BEGIN)) return 0;
    DWORD err = GetLastError();
    if (err == ERROR_ACCESS_DENIED) return 2;
    if (err == ERROR_INVALID_FUNCTION || err == ERROR_INVALID_PARAMETER) return 1;
    return 3;
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
#include <limits.h>
#include <fcntl.h>
/* Match fs.Dir's default open/create flags at the actual descriptor open. */
static int witty_image_file_open(const char *path, int writing, int *saved_error) {
    int flags = writing ? O_WRONLY | O_CREAT | O_TRUNC : O_RDONLY;
#ifdef O_CLOEXEC
    flags |= O_CLOEXEC;
#endif
#ifdef O_LARGEFILE
    flags |= O_LARGEFILE;
#endif
#ifdef O_NOCTTY
    if (!writing) flags |= O_NOCTTY;
#endif
    int fd = open(path, flags, 0666);
    *saved_error = fd < 0 ? errno : 0;
    return fd;
}
static int witty_image_file_close(int fd) {
    if (close(fd) == 0) return 0;
    return errno == EBADF ? 4 : -1;
}
/* Pinned std.posix pread/pwrite map these errors to Unseekable. */
static int witty_image_file_unseekable(int code) {
    return code == ESPIPE || code == ENXIO || code == EOVERFLOW;
}
static int witty_image_file_path_max(void) { return PATH_MAX; }
static int witty_image_file_open_interrupted(int code) { return code == EINTR; }
/* Names from pinned std.posix.openatZ; use the saved error code, not errno. */
static const char *witty_image_file_open_error(int code) {
    switch (code) {
        case EFAULT: case EBADF: return "_Unreachable";
        case EINVAL: return "BadPathName";
        case EACCES: return "AccessDenied";
        case EFBIG: case EOVERFLOW: return "FileTooBig";
        case EISDIR: return "IsDir";
        case ELOOP: return "SymLinkLoop";
        case EMFILE: return "ProcessFdQuotaExceeded";
        case ENAMETOOLONG: return "NameTooLong";
        case ENFILE: return "SystemFdQuotaExceeded";
        case ENODEV: case ENXIO: return "NoDevice";
        case ENOENT: return "FileNotFound";
        case ESRCH: return "ProcessNotFound";
        case ENOMEM: return "SystemResources";
        case ENOSPC: return "NoSpaceLeft";
        case ENOTDIR: return "NotDir";
        case EPERM: return "PermissionDenied";
        case EEXIST: return "PathAlreadyExists";
        case EBUSY: return "DeviceBusy";
        case EOPNOTSUPP: return "FileLocksNotSupported";
        case EAGAIN: return "WouldBlock";
        case ETXTBSY: return "FileBusy";
        default: return "Unexpected";
    }
}
static int witty_image_file_size(int fd, uint64_t *size) {
    struct stat st;
    if (fstat(fd, &st) != 0) return errno == EBADF ? 4 : -1;
    if (!S_ISREG(st.st_mode)) return 1;
    *size = st.st_size;
    return 0;
}
static int witty_image_file_seek(int fd, uint64_t pos) {
    if (lseek(fd, (off_t)pos, SEEK_SET) >= 0) return 0;
    if (errno == ESPIPE || errno == EINVAL || errno == EOVERFLOW || errno == ENXIO) return 1;
    if (errno == EBADF) return 4;
    return 3;
}
/* File.Reader first tries a relative seek before discarding a forward offset. */
static int witty_image_file_seek_by(int fd, uint64_t pos) {
    if (lseek(fd, (off_t)pos, SEEK_CUR) >= 0) return 0;
    if (errno == ESPIPE || errno == EINVAL || errno == EOVERFLOW || errno == ENXIO) return 1;
    return errno == EBADF ? 4 : 3;
}
static intptr_t witty_image_file_read(int fd, uint64_t pos, unsigned char *buf, size_t count, int *streaming) {
    ssize_t n;
    do {
        n = *streaming ? read(fd, buf, count) : pread(fd, buf, count, (off_t)pos);
    } while (n < 0 && errno == EINTR);
    if (n < 0 && witty_image_file_unseekable(errno) && !*streaming) {
        *streaming = 1;
        if (pos != 0) return -3; /* Reader must reconcile the logical offset. */
        do { n = read(fd, buf, count); } while (n < 0 && errno == EINTR);
    }
    return n;
}
static intptr_t witty_image_file_read_vec(int fd, uint64_t pos, unsigned char *a, size_t alen, unsigned char *b, size_t blen, int *streaming) {
    struct iovec vectors[2] = {{a, alen}, {b, blen}};
    ssize_t n;
    do {
        if (*streaming) {
            n = readv(fd, vectors, 2);
        } else {
#if defined(__APPLE__) || defined(__HAIKU__) || defined(__serenity__)
            /* Zig 0.15.2's std.posix.preadv reads only its first vector on
               targets without the native positional vector operation. */
            n = pread(fd, alen ? a : b, alen ? alen : blen, (off_t)pos);
#else
            n = preadv(fd, vectors, 2, (off_t)pos);
#endif
        }
    }
    while (n < 0 && errno == EINTR);
    if (n < 0 && witty_image_file_unseekable(errno) && !*streaming) {
        *streaming = 1;
        if (pos != 0) return -3; /* Reader must reconcile the logical offset. */
        do { n = readv(fd, vectors, 2); } while (n < 0 && errno == EINTR);
    }
    return n;
}
static intptr_t witty_image_file_write(int fd, uint64_t pos, const unsigned char *a, size_t alen, const unsigned char *b, size_t blen, int *streaming) {
    if (*streaming < 0) return -1;
    struct iovec vectors[2] = {{(void *)a, alen}, {(void *)b, blen}};
    ssize_t n;
    do {
        if (*streaming) {
            n = writev(fd, vectors, 2);
        } else {
#if defined(__APPLE__) || defined(__HAIKU__)
            /* Zig 0.15.2's std.posix.pwritev uses pwrite on these targets and
               deliberately returns after the first nonempty vector. */
            n = pwrite(fd, alen ? a : b, alen ? alen : blen, (off_t)pos);
#else
            n = pwritev(fd, vectors, 2, (off_t)pos);
#endif
        }
    } while (n < 0 && errno == EINTR);
    if (n < 0 && witty_image_file_unseekable(errno) && !*streaming) {
        *streaming = 1;
        if (pos != 0 && lseek(fd, (off_t)pos, SEEK_SET) < 0) {
            *streaming = -1;
            return -1;
        }
        /* The source exposes this zero-progress mode transition to write(). */
        return 0;
    }
    return n;
}
#endif
#endif
