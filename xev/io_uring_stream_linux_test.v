module xev

// GenericStreamTests from libxev src/watcher/stream.zig (pinned 34fa508), for
// the io_uring Stream. The "Stream decls" test is a comptime check that every
// declaration of the Stream mixin is re-exported; the V IoUringStream declares
// the methods directly, so it is not translated.

#include <pty.h>

// Redeclare this winsize struct so we can just use a Zig struct. This
// layout should be correct on all tested platforms.
struct IoUringStreamTestWinsize {
	ws_row    u16
	ws_col    u16
	ws_xpixel u16
	ws_ypixel u16
}

// libc pty.h
fn C.openpty(parent &int, child &int, name &u8, termios voidptr, winsize voidptr) int

// Helper to open a pty. This isn't exposed as a public API this is only
// used for tests.
struct IoUringStreamTestPty {
	// The file descriptors for the parent/child side of the pty. This refers
	// to the master/slave side respectively, and while that terminology is
	// the officially used terminology of the syscall, I will use parent/child
	// here.
	parent int
	child  int
}

fn IoUringStreamTestPty.init() !IoUringStreamTestPty {
	// Reasonable size
	size := IoUringStreamTestWinsize{
		ws_row: 80
		ws_col: 80
		ws_xpixel: 800
		ws_ypixel: 600
	}

	mut parent_fd := int(0)
	mut child_fd := int(0)
	if C.openpty(&parent_fd, &child_fd, unsafe { nil }, unsafe { nil }, &size) < 0 {
		return error('OpenptyFailed')
	}

	return IoUringStreamTestPty{
		parent: parent_fd
		child: child_fd
	}
}

fn (mut self IoUringStreamTestPty) deinit() {
	posix_close(self.parent)
	posix_close(self.child)
}

struct IoUringStreamTestLen {
mut:
	value ?usize
}

fn io_uring_stream_test_read(ud voidptr, _ &IoUringLoop, _ &IoUringCompletion, _ IoUringStream, _ IoUringReadBuffer, r ?ErrorKind, n usize) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut len := unsafe { &IoUringStreamTestLen(ud) }
	len.value = n
	return .disarm
}

fn io_uring_stream_test_write(_ voidptr, _ &IoUringLoop, _ &IoUringCompletion, _ IoUringStream, _ IoUringWriteBuffer, r ?ErrorKind, _ usize) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	return .disarm
}

struct IoUringStreamTestCompletion {
mut:
	value &IoUringCompletion = unsafe { nil }
}

fn io_uring_stream_test_write_record(ud voidptr, _ &IoUringLoop, c &IoUringCompletion, _ IoUringStream, _ IoUringWriteBuffer, r ?ErrorKind, _ usize) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut result := unsafe { &IoUringStreamTestCompletion(ud) }
	result.value = unsafe { c }
	return .disarm
}

fn test_io_uring_stream_pty_child_to_parent() ! {
	// Create the pty parent/child side.
	mut pty := IoUringStreamTestPty.init()!
	defer {
		pty.deinit()
	}

	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	parent := IoUringStream.init_fd(pty.parent)
	child := IoUringStream.init_fd(pty.child)

	// Read
	mut read_buf := []u8{len: 128}
	mut read_len := IoUringStreamTestLen{}
	c_read := &IoUringCompletion{}
	parent.read(mut loop, c_read, IoUringReadBuffer{ kind: .slice, slice: read_buf }, &read_len,
		io_uring_stream_test_read)

	// This should not block!
	loop.run(.no_wait)!
	assert read_len.value == none

	// Send
	send_buf := 'hello, world!'.bytes()
	c_write := &IoUringCompletion{}
	child.write(mut loop, c_write, IoUringWriteBuffer{ kind: .slice, slice: send_buf }, unsafe { nil },
		io_uring_stream_test_write)

	// The write and read should trigger
	loop.run(.until_done)!
	assert read_len.value != none
	assert send_buf == read_buf[..int(read_len.value?)]
}

fn test_io_uring_stream_pty_parent_to_child() ! {
	// Create the pty parent/child side.
	mut pty := IoUringStreamTestPty.init()!
	defer {
		pty.deinit()
	}

	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	parent := IoUringStream.init_fd(pty.parent)
	child := IoUringStream.init_fd(pty.child)

	// Read
	mut read_buf := []u8{len: 128}
	mut read_len := IoUringStreamTestLen{}
	c_read := &IoUringCompletion{}
	child.read(mut loop, c_read, IoUringReadBuffer{ kind: .slice, slice: read_buf }, &read_len,
		io_uring_stream_test_read)

	// This should not block!
	loop.run(.no_wait)!
	assert read_len.value == none

	// Send (note the newline at the end of the buf is important
	// since we're in cooked mode)
	send_buf := 'hello, world!\n'.bytes()
	c_write := &IoUringCompletion{}
	parent.write(mut loop, c_write, IoUringWriteBuffer{ kind: .slice, slice: send_buf }, unsafe { nil },
		io_uring_stream_test_write)

	// The write and read should trigger
	loop.run(.until_done)!
	assert read_len.value != none
	assert send_buf == read_buf[..int(read_len.value?)]
}

fn test_io_uring_stream_pty_queued_writes() ! {
	// Create the pty parent/child side.
	mut pty := IoUringStreamTestPty.init()!
	defer {
		pty.deinit()
	}

	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	parent := IoUringStream.init_fd(pty.parent)
	child := IoUringStream.init_fd(pty.child)

	// Read
	mut read_buf := []u8{len: 128}
	mut read_len := IoUringStreamTestLen{}
	c_read := &IoUringCompletion{}
	child.read(mut loop, c_read, IoUringReadBuffer{ kind: .slice, slice: read_buf }, &read_len,
		io_uring_stream_test_read)

	// This should not block!
	loop.run(.no_wait)!
	assert read_len.value == none

	write_queue := &IoUringWriteQueue{}
	write_req := [&IoUringWriteRequest{}, &IoUringWriteRequest{}]

	// Send (note the newline at the end of the buf is important
	// since we're in cooked mode)
	parent.queue_write(mut loop, write_queue, write_req[0], IoUringWriteBuffer{
		kind: .slice
		slice: 'hello, '.bytes()
	}, unsafe { nil }, io_uring_stream_test_write)

	mut c_result := IoUringStreamTestCompletion{}
	parent.queue_write(mut loop, write_queue, write_req[1], IoUringWriteBuffer{
		kind: .slice
		slice: 'world!\n'.bytes()
	}, &c_result, io_uring_stream_test_write_record)

	// The write and read should trigger
	loop.run(.until_done)!
	assert read_len.value != none
	assert 'hello, world!\n'.bytes() == read_buf[..int(read_len.value?)]

	// Verify our completion is equal to our request
	assert IoUringWriteRequest.from(c_result.value) == write_req[1]
}
