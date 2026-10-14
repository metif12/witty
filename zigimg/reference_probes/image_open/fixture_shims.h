#ifndef WITTY_IMAGE_OPEN_FIXTURES_H
#define WITTY_IMAGE_OPEN_FIXTURES_H
#include <stddef.h>
#include <stdint.h>
#ifdef WITTY_IMAGE_OPEN_DECLARATIONS
int witty_image_open_setup(const char *, int, const unsigned char *, size_t);
int witty_image_open_cleanup(const char *);
int witty_image_open_mask(int);
int witty_image_open_mode(const char *);
int witty_image_open_kind(const char *);
ptrdiff_t witty_image_open_bytes(const char *, unsigned char *, size_t);
int witty_image_open_find(const char *);
int witty_image_open_flag(int, int);
int witty_image_open_exec(const char *, int);
int witty_image_open_child(int, uint64_t, uint64_t);
int witty_image_open_watch(const char *, const char *, const char *);
#else
#ifdef WITTY_IMAGE_OPEN_NATIVE
#define WITTY_IMAGE_OPEN_LINKAGE
#else
#define WITTY_IMAGE_OPEN_LINKAGE static
#endif
#ifndef _WIN32
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_setup(const char *root, int kind, const unsigned char *seed, size_t len) {
    char target[4096], backing[4096];
    if (mkdir(root, 0700) != 0) return -1;
    snprintf(target, sizeof(target), "%s/target", root);
    snprintf(backing, sizeof(backing), "%s/seed", root);
    if (kind == 0) return 0;
    const char *name = kind == 1 ? target : backing;
    int fd = open(name, O_WRONLY | O_CREAT | O_EXCL, 0640);
    if (fd < 0 || write(fd, seed, len) != (ptrdiff_t)len || fchmod(fd, 0640) != 0) return -1;
    close(fd);
    if (kind == 2 && symlink("seed", target) != 0) return -1;
    if (kind == 3 && link(backing, target) != 0) return -1;
    return 0;
}
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_cleanup(const char *root) {
    char path[4096];
    snprintf(path, sizeof(path), "%s/target", root);
    if (unlink(path) != 0 && errno != ENOENT) return -1;
    snprintf(path, sizeof(path), "%s/seed", root);
    if (unlink(path) != 0 && errno != ENOENT) return -1;
    return rmdir(root);
}
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_mask(int mode) { return (int)umask((mode_t)mode); }
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_mode(const char *path) {
    struct stat st;
    return stat(path, &st) == 0 ? st.st_mode & 0777 : -1;
}
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_kind(const char *path) {
    struct stat st;
    if (lstat(path, &st) != 0) return -1;
    return S_ISLNK(st.st_mode) ? 1 : S_ISREG(st.st_mode) ? 0 : 2;
}
WITTY_IMAGE_OPEN_LINKAGE ptrdiff_t witty_image_open_bytes(const char *path, unsigned char *buf, size_t cap) {
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    ptrdiff_t n = read(fd, buf, cap); close(fd); return n;
}
/* Find only the owned target's inode; transient observer files are opened later. */
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_find(const char *path) {
    struct stat target, st;
    if (stat(path, &target) != 0) return -1;
    int result = -1;
    for (int fd = 3; fd < 128; ++fd) {
        if (fstat(fd, &st) == 0 && st.st_dev == target.st_dev && st.st_ino == target.st_ino) {
            if (result != -1) return -2;
            result = fd;
        }
    }
    return result;
}
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_flag(int fd, int which) {
    int value = fcntl(fd, which == 0 ? F_GETFD : F_GETFL);
    if (value < 0) return -1;
    if (which == 0) return (value & FD_CLOEXEC) != 0;
    if (which == 1) return (value & O_ACCMODE) == O_RDONLY ? 0 : (value & O_ACCMODE) == O_WRONLY ? 1 : 2;
    return (value & O_NONBLOCK) != 0;
}
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_child(int fd, uint64_t device, uint64_t inode) {
    struct stat st;
    if (fstat(fd, &st) != 0) return errno == EBADF ? 0 : 2;
    return st.st_dev == device && st.st_ino == inode ? 1 : 0;
}
/* Prepare argv before fork; child performs only async-signal-safe exec/_exit. */
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_exec(const char *exe, int fd) {
    struct stat st;
    if (fstat(fd, &st) != 0) return -1;
    char number[32], device[32], inode[32];
    snprintf(number, sizeof(number), "%d", fd);
    snprintf(device, sizeof(device), "%llu", (unsigned long long)st.st_dev);
    snprintf(inode, sizeof(inode), "%llu", (unsigned long long)st.st_ino);
    char *argv[] = {(char *)exe, "--child", number, device, inode, NULL};
    pid_t child = fork();
    if (child < 0) return -1;
    if (child == 0) { execv(exe, argv); _exit(2); }
    int status;
    while (waitpid(child, &status, 0) < 0) if (errno != EINTR) return -1;
    return WIFEXITED(status) && WEXITSTATUS(status) <= 1 ? WEXITSTATUS(status) : -1;
}
static char witty_image_open_watch_path[4096], witty_image_open_watch_ready[4096], witty_image_open_watch_exe[4096];
static void *witty_image_open_watch_thread(void *unused) {
    (void)unused;
    for (int i = 0; i < 10000; ++i) {
        int fd = witty_image_open_find(witty_image_open_watch_path);
        if (fd >= 0) {
            int clo = witty_image_open_flag(fd, 0), access = witty_image_open_flag(fd, 1), nonblock = witty_image_open_flag(fd, 2);
            int inherited = witty_image_open_exec(witty_image_open_watch_exe, fd);
            char state[128];
            int len = snprintf(state, sizeof(state), "%d:%d:%d:%d|%d:%d", clo, access, nonblock, inherited, witty_image_open_kind(witty_image_open_watch_path), witty_image_open_mode(witty_image_open_watch_path));
            int out = open(witty_image_open_watch_ready, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
            if (out >= 0) { write(out, state, (size_t)len); close(out); }
            return NULL;
        }
        usleep(1000);
    }
    return NULL;
}
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_watch(const char *path, const char *ready, const char *exe) {
    if (strlen(path) >= 4096 || strlen(ready) >= 4096 || strlen(exe) >= 4096) return -1;
    strcpy(witty_image_open_watch_path, path); strcpy(witty_image_open_watch_ready, ready); strcpy(witty_image_open_watch_exe, exe);
    pthread_t thread;
    return pthread_create(&thread, NULL, witty_image_open_watch_thread, NULL) == 0 ? pthread_detach(thread) : -1;
}
#else
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_setup(const char *root, int kind, const unsigned char *seed, size_t len) { (void)root; (void)kind; (void)seed; (void)len; return -1; }
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_cleanup(const char *root) { (void)root; return -1; }
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_mask(int mode) { (void)mode; return -1; }
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_mode(const char *path) { (void)path; return -1; }
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_kind(const char *path) { (void)path; return -1; }
WITTY_IMAGE_OPEN_LINKAGE ptrdiff_t witty_image_open_bytes(const char *path, unsigned char *buf, size_t cap) { (void)path; (void)buf; (void)cap; return -1; }
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_find(const char *path) { (void)path; return -1; }
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_flag(int fd, int which) { (void)fd; (void)which; return -1; }
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_exec(const char *exe, int fd) { (void)exe; (void)fd; return -1; }
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_child(int fd, uint64_t device, uint64_t inode) { (void)fd; (void)device; (void)inode; return 2; }
WITTY_IMAGE_OPEN_LINKAGE int witty_image_open_watch(const char *path, const char *ready, const char *exe) { (void)path; (void)ready; (void)exe; return -1; }
#endif
#undef WITTY_IMAGE_OPEN_LINKAGE
#endif
#endif
