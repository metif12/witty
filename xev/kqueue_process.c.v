module xev

$if macos || ios || freebsd {
	// Process management, such as waiting for process exit.
	//
	// V translation of libxev's src/watcher/process.zig ProcessKqueue, the
	// Process of the kqueue backend (pinned 34fa508).

	// The callback of Process.wait. The error is a ProcError (WaitError); on
	// success the exit code is supplied.
	pub type KqueueProcessCallback = fn (ud voidptr, l &KqueueLoop, c &KqueueCompletion, r ?ErrorKind, exit_code u32) CallbackAction

	pub struct KqueueProcess {
	pub mut:
		// The pid to watch.
		pid int
	}

	// Create a new process watcher for the given pid.
	pub fn KqueueProcess.init(pid int) !KqueueProcess {
		return KqueueProcess{
			pid: pid
		}
	}

	// Does nothing for Kqueue.
	pub fn (mut self KqueueProcess) deinit() {
		_ = self
	}

	// Wait for the process to exit. This will automatically call
	// `waitpid` or equivalent and report the exit status.
	pub fn (self &KqueueProcess) wait(mut loop KqueueLoop, c &KqueueCompletion, userdata voidptr, cb KqueueProcessCallback) {
		mut completion := unsafe { c }
		unsafe {
			*completion = KqueueCompletion{
				op:       KqueueProcOp{
					pid:   self.pid
					flags: kqueue_note_exit_flags
				}
				userdata: userdata
				callback: fn [cb] (ud voidptr, l_inner &KqueueLoop, c_inner &KqueueCompletion, r KqueueResult) CallbackAction {
					// Reap the process. We do this because our xev.Process
					// docs note that this is the equivalent of calling
					// `wait` on a process. The Linux side (pidfd) does this
					// automatically since the `waitid` syscall is used.
					if r.err == none {
						_ = posix_waitpid((c_inner.op as KqueueProcOp).pid, 0)
					}

					return cb(ud, l_inner, c_inner, r.err, (r as KqueueProcResult).exit_code)
				}
			}
		}
		loop.add(completion)
	}
}
