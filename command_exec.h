#ifndef WITTY_COMMAND_EXEC_H
#define WITTY_COMMAND_EXEC_H

#include <unistd.h>

/*
 * POSIX only standardizes execvp (PATH search with the process environment)
 * and execve (an explicit environment without PATH search). Ghostty needs both
 * properties. Zig's execvpeZ supplies that combination on every POSIX target,
 * while macOS does not expose the GNU execvpe extension.
 *
 * This runs after fork, so replacing environ only affects the child. execvp
 * subsequently performs the same PATH lookup using the exact environment that
 * will be inherited by the executed program.
 */
static inline int witty_execvpe(
    const char *file,
    char *const argv[],
    char *const envp[]
) {
    extern char **environ;
    environ = (char **)envp;
    return execvp(file, argv);
}

#endif
