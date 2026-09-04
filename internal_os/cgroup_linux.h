#ifndef WITTY_INTERNAL_OS_CGROUP_LINUX_H
#define WITTY_INTERNAL_OS_CGROUP_LINUX_H

#include <errno.h>
#include <fcntl.h>
#include <linux/sched.h>
#include <signal.h>
#include <stdint.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <unistd.h>

#ifndef CLONE_INTO_CGROUP
#define CLONE_INTO_CGROUP (1ULL << 33)
#endif

#ifndef O_PATH
#define O_PATH 010000000
#endif

static inline pid_t witty_clone_into_cgroup(const char *path, int *error_code) {
    int fd = open(path, O_PATH | O_DIRECTORY | O_CLOEXEC);
    if (fd < 0) {
        *error_code = errno;
        return -1;
    }

    struct clone_args args = {0};
    args.flags = CLONE_INTO_CGROUP;
    args.exit_signal = SIGCHLD;
    args.cgroup = (uint64_t)fd;
    pid_t pid = (pid_t)syscall(SYS_clone3, &args, sizeof(args));
    if (pid < 0) {
        *error_code = errno;
    }
    close(fd);
    return pid;
}

#endif
