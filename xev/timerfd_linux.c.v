module xev

// V translation of libxev's src/linux/timerfd.zig (pinned 34fa508).

// Timerfd is a wrapper around the timerfd system calls. See the
// timerfd_create man page for information on timerfd and associated
// system calls.
//
// This is a small wrapper around timerfd to make it slightly more
// pleasant to use, but may not expose all available functionality.
// For maximum control you should use the syscalls directly.
pub struct Timerfd {
pub mut:
	// The timerfd file descriptor for use with poll, etc.
	fd i32
}

// timerfd_create
pub fn Timerfd.init(clock LinuxTimerfdClockid, flags LinuxTfd) !Timerfd {
	res := linux_timerfd_create(clock, flags)
	match linux_errno(res) {
		0 {
			assert res <= uint(max_i32) // @intCast safety check
			return Timerfd{
				fd: i32(res)
			}
		}
		else {
			return new_error(.unknown_error)
		}
	}
}

pub fn (self &Timerfd) deinit() {
	posix_close(self.fd)
}

// timerfd_settime. A null old_value is passed as nil.
pub fn (self &Timerfd) set(flags LinuxTfdTimer, new_value &TimerfdSpec, old_value &TimerfdSpec) ! {
	res := linux_timerfd_settime(self.fd, flags, unsafe { &C.itimerspec(new_value) }, unsafe { &C.itimerspec(old_value) })

	match linux_errno(res) {
		0 { return }
		else { return new_error(.unknown_error) }
	}
}

// timerfd_gettime
pub fn (self &Timerfd) get() !TimerfdSpec {
	mut out := TimerfdSpec{}
	res := linux_timerfd_gettime(self.fd, unsafe { &C.itimerspec(&out) })
	match linux_errno(res) {
		0 { return out }
		else { return new_error(.unknown_error) }
	}
}

// itimerspec
pub struct TimerfdSpec {
pub mut:
	interval TimerfdTimeSpec
	value    TimerfdTimeSpec
}

// timespec
pub struct TimerfdTimeSpec {
pub mut:
	seconds     int
	nanoseconds int
}
