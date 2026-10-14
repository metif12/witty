#ifndef WITTY_IMAGE_PATH_FIXTURES_H
#define WITTY_IMAGE_PATH_FIXTURES_H
#include <stddef.h>
#ifdef WITTY_IMAGE_PATH_DECLARATIONS
int witty_image_path_permissions(void);
int witty_image_path_count(void);
int witty_image_path_setup(const char *, int, const unsigned char *, size_t);
int witty_image_path_valid(int);
int witty_image_path_mode(int);
ptrdiff_t witty_image_path_bytes(int, unsigned char *, size_t);
int witty_image_path_cleanup(const char *, int);
#else
#ifdef WITTY_IMAGE_PATH_NATIVE
#define WITTY_IMAGE_PATH_LINKAGE
#else
#define WITTY_IMAGE_PATH_LINKAGE static
#endif
#ifndef _WIN32
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <stdio.h>
#include <string.h>
WITTY_IMAGE_PATH_LINKAGE int witty_image_path_permissions(void) { return geteuid() != 0; }
WITTY_IMAGE_PATH_LINKAGE int witty_image_path_count(void) {
    int count = 0;
    for (int fd = 0; fd < 128; ++fd) if (fcntl(fd, F_GETFD) >= 0) ++count;
    return count;
}
WITTY_IMAGE_PATH_LINKAGE int witty_image_path_setup(const char *root, int kind, const unsigned char *seed, size_t len) {
    char path[4096], target[4096];
    if (mkdir(root, 0700) != 0) return -1;
    snprintf(path, sizeof(path), "%s/seed", root);
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (fd < 0 || write(fd, seed, len) != (ptrdiff_t)len) return -1;
    close(fd);
    int keeper = open(path, O_RDONLY);
    if (keeper < 0 || keeper >= 128) return -1;
    if (kind == 3 && chmod(path, 0000) != 0) return -1;
    snprintf(path, sizeof(path), "%s/dir", root);
    if (mkdir(path, 0700) != 0) return -1;
    snprintf(path, sizeof(path), "%s/denied", root);
    if (mkdir(path, kind == 4 ? 0000 : 0700) != 0) return -1;
    snprintf(path, sizeof(path), "%s/loop", root);
    if (symlink("loop", path) != 0) return -1;
    snprintf(path, sizeof(path), "%s/dangling", root);
    snprintf(target, sizeof(target), "%s/missing/child", root);
    if (symlink(target, path) != 0) return -1;
    return keeper;
}
WITTY_IMAGE_PATH_LINKAGE int witty_image_path_valid(int fd) { return fcntl(fd, F_GETFD) < 0 ? 0 : 1; }
WITTY_IMAGE_PATH_LINKAGE int witty_image_path_mode(int fd) {
    struct stat st;
    return fstat(fd, &st) == 0 ? st.st_mode & 0777 : -1;
}
WITTY_IMAGE_PATH_LINKAGE ptrdiff_t witty_image_path_bytes(int fd, unsigned char *bytes, size_t cap) { return pread(fd, bytes, cap, 0); }
WITTY_IMAGE_PATH_LINKAGE int witty_image_path_cleanup(const char *root, int fd) {
    char path[4096];
    close(fd);
    snprintf(path, sizeof(path), "%s/seed", root); chmod(path, 0600); if (unlink(path) != 0) return -1;
    snprintf(path, sizeof(path), "%s/loop", root); if (unlink(path) != 0) return -1;
    snprintf(path, sizeof(path), "%s/dangling", root); if (unlink(path) != 0) return -1;
    snprintf(path, sizeof(path), "%s/dir", root); if (rmdir(path) != 0) return -1;
    snprintf(path, sizeof(path), "%s/denied", root); chmod(path, 0700); if (rmdir(path) != 0) return -1;
    return rmdir(root);
}
#else
WITTY_IMAGE_PATH_LINKAGE int witty_image_path_permissions(void) { return 0; }
WITTY_IMAGE_PATH_LINKAGE int witty_image_path_count(void) { return 0; }
WITTY_IMAGE_PATH_LINKAGE int witty_image_path_setup(const char *root, int kind, const unsigned char *seed, size_t len) { (void)root; (void)kind; (void)seed; (void)len; return -1; }
WITTY_IMAGE_PATH_LINKAGE int witty_image_path_valid(int fd) { (void)fd; return 0; }
WITTY_IMAGE_PATH_LINKAGE int witty_image_path_mode(int fd) { (void)fd; return -1; }
WITTY_IMAGE_PATH_LINKAGE ptrdiff_t witty_image_path_bytes(int fd, unsigned char *bytes, size_t cap) { (void)fd; (void)bytes; (void)cap; return -1; }
WITTY_IMAGE_PATH_LINKAGE int witty_image_path_cleanup(const char *root, int fd) { (void)root; (void)fd; return -1; }
#endif
#undef WITTY_IMAGE_PATH_LINKAGE
#endif
#endif
