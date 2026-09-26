module xev

// Process management, such as waiting for process exit.
//
// V translation of libxev's src/watcher/process.zig ProcessPidFd, the
// Process of the io_uring backend (pinned 34fa508).

// The callback of Process.wait. The error is a WaitError (xev.Sys.PollError
// or InvalidChild); on success the exit code is supplied.
pub type IoUringProcessCallback = fn (ud voidptr, l &IoUringLoop, c &IoUringCompletion, r ?ErrorKind, exit_code u32) CallbackAction

// Process implementation using pidfd (Linux).
pub struct IoUringProcess {
pub mut:
	// pidfd file descriptor
	fd int
}

// Create a new process watcher for the given pid.
pub fn IoUringProcess.init(pid int) !IoUringProcess {
	// Note: SOCK_NONBLOCK == PIDFD_NONBLOCK but we should PR that
	// over to Zig.
	res := linux_pidfd_open(pid, sock_nonblock)
	mut fd := 0
	match linux_errno(res) {
		0 { fd = int(res) }
		C.EINVAL { return new_error(.invalid_argument) }
		C.EMFILE { return new_error(.process_fd_quota_exceeded) }
		C.ENFILE { return new_error(.system_fd_quota_exceeded) }
		C.ENODEV { return new_error(.system_resources) }
		C.ENOMEM { return new_error(.system_resources) }
		else { return unexpected_errno(linux_errno(res)) }
	}

	return IoUringProcess{
		fd: fd
	}
}

// Clean up the process watcher.
pub fn (mut self IoUringProcess) deinit() {
	posix_close(self.fd)
}

// Wait for the process to exit. This will automatically call
// `waitpid` or equivalent and report the exit status.
pub fn (self &IoUringProcess) wait(mut loop IoUringLoop, c &IoUringCompletion, userdata voidptr, cb IoUringProcessCallback) {
	events := linux_poll_in

	mut completion := unsafe { c }
	unsafe {
		*completion = IoUringCompletion{
			op: IoUringPollOp{
				fd: self.fd
				events: events
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, r IoUringResult) CallbackAction {
				mut arg_err := ?ErrorKind(none)
				mut arg_code := u32(0)
				if err := r.err {
					// If our poll failed, report that error.
					arg_err = err
				} else {
					// We need to wait on the pidfd because it is noted as ready
					fd := (c_inner.op as IoUringPollOp).fd
					mut info := C.siginfo_t{}
					res := linux_waitid(.pidfd, fd, &info, u32(int(C.WEXITED)))

					match linux_errno(res) {
						0 {
							status := info.si_status
							assert status >= 0 // @intCast safety check
							arg_code = u32(status)
						}
						C.ECHILD {
							arg_err = .invalid_child
						}
						// The fd isn't ready to read, I guess?
						C.EAGAIN {
							return .rearm
						}
						else {
							eprintln('warning: unexpected process wait errno=${linux_errno(res)}')
							arg_err = .unexpected
						}
					}
				}

				return cb(ud, l_inner, c_inner, arg_err, arg_code)
			}
		}
	}
	loop.add(completion)
}
