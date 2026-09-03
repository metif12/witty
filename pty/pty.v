module pty

// Pty is a pseudo-terminal abstraction. This provides a cross-platform
// interface for creating and managing pseudo-terminals (PTYs).
//
// On POSIX systems, this wraps the openpty/ioctl/tcgetattr family of
// calls. On Windows, this would wrap the ConPTY API (XTODO).
//
// The PTY is used to connect a terminal emulator to a subprocess (shell).
// The master side is read/written by the terminal emulator, and the slave
// side is connected to the child process's stdin/stdout/stderr.

// C interop declarations.
// We declare the C functions we need for PTY management. These are
// available on macOS (via <util.h>) and Linux (via <pty.h>).
#include <sys/ioctl.h>

#include <termios.h>

#include <fcntl.h>

#include <util.h>

fn C.openpty(master &int, slave &int, name &char, termp voidptr, winp voidptr) int

fn C.close(fd int) int

fn C.ioctl(fd i32, request u64, args ...voidptr) i32

fn C.tcgetattr(fd int, termios_p voidptr) int

fn C.tcsetattr(fd int, optional_actions int, termios_p voidptr) int

fn C.setsid() int

fn C.fcntl(fd int, cmd int, arg int) int

// ioctl request codes. These are platform-specific constants.
// On macOS they differ from Linux due to ioctl encoding differences.
// https://github.com/ziglang/zig/issues/13277
// macOS values are hardcoded; on Linux these come from C headers.
const tiocswinsz = u64(0x80087467) // macOS: _IOW('t', 103, struct winsize)
const tiocgwinsz = u64(0x40087468) // macOS: _IOR('t', 104, struct winsize)
const tiocsctty = u64(0x20007461) // macOS: _IO('t', 97)

// termios constants (macOS values).
// On macOS these are unsigned long values.
const tcsanow = 0
const iutf8 = u64(0x00004000)
const icanon = u64(0x00000100)
const echo_flag = u64(0x00000008)

// fcntl constants
const f_getfd = 1
const f_setfd = 2
const fd_cloexec = 1

// Redeclare this winsize struct so we can just use a V struct. This
// layout should be correct on all tested platforms. The defaults on this
// are some reasonable screen size but you should probably not use them.
pub struct Winsize {
pub mut:
	ws_row    u16 = 100
	ws_col    u16 = 80
	ws_xpixel u16 = 800
	ws_ypixel u16 = 600
}

// The modes of a pty. Not all of these modes are supported on
// all platforms but all platforms share the same mode struct.
//
// The default values of fields in this struct are set to the
// most typical values for a pty. This makes it easier for cross-platform
// code which doesn't support all of the modes to work correctly.
pub struct Mode {
pub:
	// ICANON on POSIX. When set, input is processed line by line.
	canonical bool = true
	// ECHO on POSIX. When set, input characters are echoed back.
	echo bool = true
}

// Pty represents the pseudo-terminal with master and slave file descriptors.
//
// The file descriptors for the master and slave side of the pty.
// The slave side is never closed automatically by this struct
// so the caller is responsible for closing it if things go wrong.
pub struct Pty {
pub mut:
	// The master file descriptor (read/write end for the parent process).
	master int = -1
	// The slave file descriptor (connected to the child process).
	slave int = -1
}

// Fd is a file descriptor type alias.
pub type Fd = int

// Termios is a representation of the POSIX termios struct.
// On macOS, the flags are `unsigned long` (u64 on 64-bit), and the
// struct is 72 bytes total. On Linux, flags are `unsigned int` (u32).
// We use the macOS layout here since this is our target platform.
// XTODO: Add Linux layout support via $if.
//
// macOS layout (72 bytes):
//   offset 0:  c_iflag  (u64)
//   offset 8:  c_oflag  (u64)
//   offset 16: c_cflag  (u64)
//   offset 24: c_lflag  (u64)
//   offset 32: c_cc     ([20]u8)
//   offset 52: padding  (4 bytes)
//   offset 56: c_ispeed (u64)
//   offset 64: c_ospeed (u64)
struct Termios {
mut:
	c_iflag  u64
	c_oflag  u64
	c_cflag  u64
	c_lflag  u64
	c_cc     [20]u8
	pad0     u32
	c_ispeed u64
	c_ospeed u64
}

// open creates a new PTY with the given initial size.
//
// This uses the POSIX openpty() call to create a master/slave pair,
// then sets CLOEXEC on the master fd (only the slave should be inherited
// by the child process), and enables UTF-8 mode via IUTF8.
pub fn Pty.open(size Winsize) !Pty {
	// Need to copy so that it becomes non-const for the C call.
	mut size_copy := size

	mut master_fd := -1
	mut slave_fd := -1
	if C.openpty(&master_fd, &slave_fd, unsafe { nil }, voidptr(0), voidptr(&size_copy)) < 0 {
		return error('openpty failed')
	}

	// Set CLOEXEC on the master fd, only the slave fd should be inherited
	// by the child process (shell/command).
	flags := C.fcntl(master_fd, f_getfd, 0)
	if flags >= 0 {
		C.fcntl(master_fd, f_setfd, flags | fd_cloexec)
	}

	// Enable UTF-8 mode. This is on by default on Linux but it
	// is NOT on by default on macOS so we ensure that it is always set.
	mut attrs := Termios{}
	if C.tcgetattr(master_fd, voidptr(&attrs)) == 0 {
		attrs.c_iflag |= iutf8
		C.tcsetattr(master_fd, tcsanow, voidptr(&attrs))
	}

	return Pty{
		master: master_fd
		slave: slave_fd
	}
}

// deinit closes the master file descriptor of the pty.
// The caller is responsible for having already closed the slave fd
// if needed (typically the child process inherits and closes it).
pub fn (mut self Pty) deinit() {
	if self.master >= 0 {
		C.close(self.master)
		self.master = -1
	}
}

// close_slave closes the slave file descriptor.
// This is typically called after the child process has been forked
// and the slave fd is no longer needed in the parent.
pub fn (mut self Pty) close_slave() {
	if self.slave >= 0 {
		C.close(self.slave)
		self.slave = -1
	}
}

// get_mode reads the current termios mode from the pty master.
// Returns the simplified Mode struct with canonical and echo flags.
pub fn (self Pty) get_mode() !Mode {
	mut attrs := Termios{}
	if C.tcgetattr(self.master, voidptr(&attrs)) != 0 {
		return error('tcgetattr failed')
	}

	return Mode{
		canonical: (attrs.c_lflag & icanon) != 0
		echo: (attrs.c_lflag & echo_flag) != 0
	}
}

// get_size returns the current size of the pty.
// Uses the TIOCGWINSZ ioctl to query the kernel for the current
// terminal window size.
pub fn (self Pty) get_size() !Winsize {
	mut ws := Winsize{}
	if C.ioctl(self.master, tiocgwinsz, voidptr(&ws)) < 0 {
		return error('ioctl TIOCGWINSZ failed')
	}
	return ws
}

// set_size updates the pty window size.
// Uses the TIOCSWINSZ ioctl to inform the kernel of the new
// terminal window size. This will cause a SIGWINCH signal to be
// sent to the foreground process group of the terminal.
pub fn (mut self Pty) set_size(size Winsize) ! {
	mut size_copy := size
	if C.ioctl(self.master, tiocswinsz, voidptr(&size_copy)) < 0 {
		return error('ioctl TIOCSWINSZ failed')
	}
}

// child_pre_exec performs child-side pty setup after fork, before exec.
//
// This should be called prior to exec in the forked child process
// in order to setup the tty properly. It:
//   1. Creates a new session via setsid() (so the child is a session leader)
//   2. Sets the slave fd as the controlling terminal via TIOCSCTTY
//   3. Closes both the master and slave fds (they're no longer needed
//      in the child after dup2 has been called for stdin/stdout/stderr)
//
// XTODO: Signal resetting (sigaction for SIGABRT, SIGCHLD, etc.)
// is not yet implemented. The Zig version resets ~13 signals to SIG_DFL.
pub fn (self Pty) child_pre_exec() ! {
	// Create a new process group / session.
	if C.setsid() < 0 {
		return error('setsid failed')
	}

	// Set controlling terminal. The slave fd becomes the controlling
	// terminal for the new session.
	if C.ioctl(self.slave, tiocsctty, voidptr(u64(0))) < 0 {
		return error('ioctl TIOCSCTTY failed: could not set controlling terminal')
	}

	// Can close master/slave pair now. The child process has already
	// had its stdin/stdout/stderr redirected to the slave fd via dup2
	// in the Command.start() call.
	C.close(self.slave)
	C.close(self.master)
}
