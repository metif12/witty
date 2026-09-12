#ifndef WITTY_COMMAND_EXEC_H
#define WITTY_COMMAND_EXEC_H

#ifdef _WIN32

#include <windows.h>
#include <io.h>
#include <stdint.h>

/*
 * Create a child using the same startup layout as Command.startWindows in
 * Ghostty. The V side owns UTF-16 conversion and environment construction;
 * this bridge only handles Win32 structures whose layout should remain owned
 * by the platform headers.
 */
static inline DWORD witty_command_start_windows(
    const WCHAR *application,
    WCHAR *command_line,
    WCHAR *environment,
    const WCHAR *cwd,
    int stdin_fd,
    int stdout_fd,
    int stderr_fd,
    void *pseudo_console,
    void **process_handle,
    DWORD *process_id
) {
    HANDLE null_handle = NULL;
    HANDLE stdin_handle = NULL;
    HANDLE stdout_handle = NULL;
    HANDLE stderr_handle = NULL;
    LPPROC_THREAD_ATTRIBUTE_LIST attributes = NULL;
    SIZE_T attributes_size = 0;
    STARTUPINFOEXW startup;
    PROCESS_INFORMATION process;
    DWORD flags = CREATE_UNICODE_ENVIRONMENT;
    BOOL inherit_handles = TRUE;
    DWORD err = ERROR_SUCCESS;

    ZeroMemory(&startup, sizeof(startup));
    ZeroMemory(&process, sizeof(process));

    if (pseudo_console != NULL) {
        InitializeProcThreadAttributeList(NULL, 1, 0, &attributes_size);
        attributes = (LPPROC_THREAD_ATTRIBUTE_LIST)HeapAlloc(
            GetProcessHeap(), 0, attributes_size);
        if (attributes == NULL) {
            return ERROR_NOT_ENOUGH_MEMORY;
        }
        if (!InitializeProcThreadAttributeList(
                attributes, 1, 0, &attributes_size)) {
            err = GetLastError();
            goto cleanup;
        }
        if (!UpdateProcThreadAttribute(
                attributes,
                0,
                PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE,
                pseudo_console,
                sizeof(void *),
                NULL,
                NULL)) {
            err = GetLastError();
            goto cleanup;
        }
        startup.lpAttributeList = attributes;
        startup.StartupInfo.cb = sizeof(STARTUPINFOEXW);
        flags |= EXTENDED_STARTUPINFO_PRESENT;
        inherit_handles = FALSE;
    } else {
        if (stdin_fd < 0 || stdout_fd < 0 || stderr_fd < 0) {
            null_handle = CreateFileW(
                L"NUL",
                GENERIC_READ,
                FILE_SHARE_READ,
                NULL,
                OPEN_EXISTING,
                FILE_ATTRIBUTE_NORMAL,
                NULL);
            if (null_handle == INVALID_HANDLE_VALUE) {
                err = GetLastError();
                null_handle = NULL;
                goto cleanup;
            }
        }

        stdin_handle = stdin_fd >= 0
            ? (HANDLE)_get_osfhandle(stdin_fd)
            : null_handle;
        stdout_handle = stdout_fd >= 0
            ? (HANDLE)_get_osfhandle(stdout_fd)
            : null_handle;
        stderr_handle = stderr_fd >= 0
            ? (HANDLE)_get_osfhandle(stderr_fd)
            : null_handle;
        if (stdin_handle == INVALID_HANDLE_VALUE ||
            stdout_handle == INVALID_HANDLE_VALUE ||
            stderr_handle == INVALID_HANDLE_VALUE) {
            err = ERROR_INVALID_HANDLE;
            goto cleanup;
        }

        startup.StartupInfo.cb = sizeof(STARTUPINFOW);
        startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
        startup.StartupInfo.hStdInput = stdin_handle;
        startup.StartupInfo.hStdOutput = stdout_handle;
        startup.StartupInfo.hStdError = stderr_handle;
    }

    if (!CreateProcessW(
            application,
            command_line,
            NULL,
            NULL,
            inherit_handles,
            flags,
            environment,
            cwd,
            &startup.StartupInfo,
            &process)) {
        err = GetLastError();
        goto cleanup;
    }

    CloseHandle(process.hThread);
    *process_handle = process.hProcess;
    *process_id = process.dwProcessId;

cleanup:
    if (attributes != NULL) {
        DeleteProcThreadAttributeList(attributes);
        HeapFree(GetProcessHeap(), 0, attributes);
    }
    if (null_handle != NULL) {
        CloseHandle(null_handle);
    }
    return err;
}

static inline DWORD witty_command_wait_windows(
    void *process_handle,
    DWORD *exit_code
) {
    if (WaitForSingleObject((HANDLE)process_handle, INFINITE) == WAIT_FAILED) {
        return GetLastError();
    }
    if (!GetExitCodeProcess((HANDLE)process_handle, exit_code)) {
        return GetLastError();
    }
    return ERROR_SUCCESS;
}

#else

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#if defined(__linux__)
extern int dup3(int oldfd, int newfd, int flags);
#endif

/* Translate Command.setupFd without exposing platform errno macros to V. */
static inline int witty_command_setup_fd(int src, int target) {
#if defined(__linux__)
    int result;
    do {
        result = dup3(src, target, 0);
    } while (result < 0 && errno == EINTR);
    return result < 0 ? errno : 0;
#elif defined(__APPLE__) || defined(__FreeBSD__)
    int flags = fcntl(src, F_GETFD, 0);
    if (flags < 0) return errno;
    if ((flags & FD_CLOEXEC) != 0 &&
        fcntl(src, F_SETFD, flags & ~FD_CLOEXEC) < 0) {
        return errno;
    }
    int result;
    do {
        result = dup2(src, target);
    } while (result < 0 && errno == EINTR);
    return result < 0 ? errno : 0;
#else
#error unsupported platform
#endif
}

/* Preserve Command.startPosix's child-side diagnostic without allocating. */
static inline void witty_command_write_exec_error(void) {
    int exec_errno = errno;
    if (exec_errno == ENOENT) {
        static const char message[] =
            "Requested executable not found. Please verify the command is on\n"
            "the PATH and try again.\n";
        (void)write(STDERR_FILENO, message, sizeof(message) - 1);
        return;
    }

    static const char prefix[] =
        "exec syscall failed with unexpected error: ";
    const char *message = strerror(exec_errno);
    (void)write(STDERR_FILENO, prefix, sizeof(prefix) - 1);
    (void)write(STDERR_FILENO, message, strlen(message));
    (void)write(STDERR_FILENO, "\n", 1);
}

/* Match std.posix.read: interrupted reads are retried before exposing errno. */
static inline ssize_t witty_read_retry(int fd, void *buf, size_t count) {
    ssize_t result;
    do {
        result = read(fd, buf, count);
    } while (result < 0 && errno == EINTR);
    return result;
}

/*
 * Classify the errno left by witty_read_retry. Ghostty handles WouldBlock by
 * polling again and treats EIO/EBADF as a closed PTY.
 */
static inline int witty_read_error_kind(void) {
    if (errno == EAGAIN || errno == EWOULDBLOCK) return 1;
    if (errno == EIO || errno == EBADF) return 2;
    return 0;
}

/* Match libxev's process watcher, including its EINTR handling. */
static inline pid_t witty_waitpid_retry(pid_t pid, int *status) {
    pid_t result;
    do {
        result = waitpid(pid, status, 0);
    } while (result < 0 && errno == EINTR);
    return result;
}

/*
 * Ghostty receives its status from libxev rather than directly from waitpid.
 * libxev reports a terminating signal on Linux, a normal exit status (and zero
 * for a signal) on Darwin, and zero on FreeBSD where NOTE_EXITSTATUS is absent.
 */
static inline uint32_t witty_process_exit_code(int status) {
#if defined(__linux__)
    if (WIFEXITED(status)) return (uint32_t)WEXITSTATUS(status);
    if (WIFSIGNALED(status)) return (uint32_t)WTERMSIG(status);
    return 0;
#elif defined(__APPLE__)
    if (WIFEXITED(status)) return (uint32_t)WEXITSTATUS(status);
    return 0;
#elif defined(__FreeBSD__)
    (void)status;
    return 0;
#else
    if (WIFEXITED(status)) return (uint32_t)WEXITSTATUS(status);
    return 0;
#endif
}

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

#endif
