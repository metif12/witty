module xev

// Process management, such as waiting for process exit.
//
// V translation of libxev's src/watcher/process.zig ProcessPidFd, the
// Process of the epoll backend (pinned 34fa508).

// The callback of Process.wait. The error is a WaitError (the backend's
// PollError or InvalidChild); on success the exit code is supplied.
pub type EpollProcessCallback = fn (ud voidptr, l &EpollLoop, c &EpollCompletion, r ?ErrorKind, exit_code u32) CallbackAction

// Process implementation using pidfd (Linux).
pub struct EpollProcess {
pub mut:
	// pidfd file descriptor
	fd int
}

// Create a new process watcher for the given pid.
pub fn EpollProcess.init(pid int) !EpollProcess {
	// Note: SOCK_NONBLOCK == PIDFD_NONBLOCK but we should PR that
	// over to Zig.
	res := linux_pidfd_open(pid, sock_nonblock)
	mut fd := 0
	match linux_errno(res) {
		0 {
			fd = int(res)
		}
		C.EINVAL {
			return new_error(.invalid_argument)
		}
		C.EMFILE {
			return new_error(.process_fd_quota_exceeded)
		}
		C.ENFILE {
			return new_error(.system_fd_quota_exceeded)
		}
		C.ENODEV {
			return new_error(.system_resources)
		}
		C.ENOMEM {
			return new_error(.system_resources)
		}
		else {
			return unexpected_errno(linux_errno(res))
		}
	}

	return EpollProcess{
		fd: fd
	}
}

// Clean up the process watcher.
pub fn (mut self EpollProcess) deinit() {
	posix_close(self.fd)
}

// Wait for the process to exit. This will automatically call
// `waitpid` or equivalent and report the exit status.
pub fn (self &EpollProcess) wait(mut loop EpollLoop, c &EpollCompletion, userdata voidptr, cb EpollProcessCallback) {
	// The `.epoll` branch of the source's comptime switch on the backend.
	events := epoll_in

	mut completion := unsafe { c }
	unsafe {
		*completion = EpollCompletion{
			op:       EpollPollOp{
				fd:     self.fd
				events: events
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, r EpollResult) CallbackAction {
				mut arg_err := ?ErrorKind(none)
				mut arg_code := u32(0)
				if err := r.err {
					// If our poll failed, report that error.
					arg_err = err
				} else {
					// We need to wait on the pidfd because it is noted as ready
					fd := (c_inner.op as EpollPollOp).fd
					mut info := C.siginfo_t{}
					res := linux_waitid(.pidfd, fd, &info, u32(int(C.WEXITED)))

					match linux_errno(res) {
						0 {
							assert info.si_status >= 0 // @intCast safety check
							arg_code = u32(info.si_status)
						}
						C.ECHILD {
							arg_err = .invalid_child
						}
						// The fd isn't ready to read, I guess?
						C.EAGAIN {
							return .rearm
						}
						else {
							eprintln('unexpected process wait errno=${linux_errno(res)}')
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
