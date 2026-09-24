module xev

// GenericStreamTests from libxev src/watcher/stream.zig (pinned 34fa508), for
// the epoll Stream.

#include <pty.h>

// Redeclare this winsize struct so we can just use a Zig struct. This
// layout should be correct on all tested platforms.
struct EpollStreamTestWinsize {
	ws_row    u16
	ws_col    u16
	ws_xpixel u16
	ws_ypixel u16
}

// libc pty.h
fn C.openpty(parent &int, child &int, name &u8, termios voidptr, winsize voidptr) int

// Helper to open a pty. This isn't exposed as a public API this is only
// used for tests.
struct EpollStreamTestPty {
	// The file descriptors for the parent/child side of the pty. This refers
	// to the master/slave side respectively, and while that terminology is
	// the officially used terminology of the syscall, I will use parent/child
	// here.
	parent int
	child  int
}

fn EpollStreamTestPty.init() !EpollStreamTestPty {
	// Reasonable size
	size := EpollStreamTestWinsize{
		ws_row:    80
		ws_col:    80
		ws_xpixel: 800
		ws_ypixel: 600
	}

	mut parent_fd := int(0)
	mut child_fd := int(0)
	if C.openpty(&parent_fd, &child_fd, unsafe { nil }, unsafe { nil }, &size) < 0 {
		return error('OpenptyFailed')
	}

	return EpollStreamTestPty{
		parent: parent_fd
		child:  child_fd
	}
}

fn (mut self EpollStreamTestPty) deinit() {
	posix_close(self.parent)
	posix_close(self.child)
}

struct EpollStreamTestLen {
mut:
	value ?usize
}

fn epoll_stream_test_read(ud voidptr, _ &EpollLoop, _ &EpollCompletion, _ EpollStream, _ EpollReadBuffer, r ?ErrorKind, n usize) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut len := unsafe { &EpollStreamTestLen(ud) }
	len.value = n
	return .disarm
}

fn epoll_stream_test_write(_ voidptr, _ &EpollLoop, _ &EpollCompletion, _ EpollStream, _ EpollWriteBuffer, r ?ErrorKind, _ usize) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	return .disarm
}

struct EpollStreamTestCompletion {
mut:
	value &EpollCompletion = unsafe { nil }
}

fn epoll_stream_test_write_record(ud voidptr, _ &EpollLoop, c &EpollCompletion, _ EpollStream, _ EpollWriteBuffer, r ?ErrorKind, _ usize) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut result := unsafe { &EpollStreamTestCompletion(ud) }
	result.value = unsafe { c }
	return .disarm
}

fn test_epoll_stream_decls() {
	// Zig checks at compile time that every public decl of the stream's
	// mixin (close, poll, read, writeInit, write, queueWrite) is also a decl
	// of the stream type.
	mut names := []string{}
	$for method in EpollStream.methods {
		names << method.name
	}
	for decl in ['close', 'poll', 'read', 'write_init', 'write', 'queue_write'] {
		assert decl in names, 'missing decl: ${decl}'
	}
}

fn test_epoll_stream_pty_child_to_parent() ! {
	// Create the pty parent/child side.
	mut pty := EpollStreamTestPty.init()!
	defer {
		pty.deinit()
	}

	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	parent := EpollStream.init_fd(pty.parent)
	child := EpollStream.init_fd(pty.child)

	// Read
	mut read_buf := []u8{len: 128}
	mut read_len := EpollStreamTestLen{}
	c_read := &EpollCompletion{}
	parent.read(mut loop, c_read, EpollReadBuffer{ kind: .slice, slice: read_buf }, &read_len,
		epoll_stream_test_read)

	// This should not block!
	loop.run(.no_wait)!
	assert read_len.value == none

	// Send
	send_buf := 'hello, world!'.bytes()
	c_write := &EpollCompletion{}
	child.write(mut loop, c_write, EpollWriteBuffer{ kind: .slice, slice: send_buf }, unsafe { nil },
		epoll_stream_test_write)

	// The write and read should trigger
	loop.run(.until_done)!
	assert read_len.value != none
	assert send_buf == read_buf[..int(read_len.value?)]
}

fn test_epoll_stream_pty_parent_to_child() ! {
	// Create the pty parent/child side.
	mut pty := EpollStreamTestPty.init()!
	defer {
		pty.deinit()
	}

	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	parent := EpollStream.init_fd(pty.parent)
	child := EpollStream.init_fd(pty.child)

	// Read
	mut read_buf := []u8{len: 128}
	mut read_len := EpollStreamTestLen{}
	c_read := &EpollCompletion{}
	child.read(mut loop, c_read, EpollReadBuffer{ kind: .slice, slice: read_buf }, &read_len,
		epoll_stream_test_read)

	// This should not block!
	loop.run(.no_wait)!
	assert read_len.value == none

	// Send (note the newline at the end of the buf is important
	// since we're in cooked mode)
	send_buf := 'hello, world!\n'.bytes()
	c_write := &EpollCompletion{}
	parent.write(mut loop, c_write, EpollWriteBuffer{ kind: .slice, slice: send_buf }, unsafe { nil },
		epoll_stream_test_write)

	// The write and read should trigger
	loop.run(.until_done)!
	assert read_len.value != none
	assert send_buf == read_buf[..int(read_len.value?)]
}

fn test_epoll_stream_pty_queued_writes() ! {
	// Create the pty parent/child side.
	mut pty := EpollStreamTestPty.init()!
	defer {
		pty.deinit()
	}

	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	parent := EpollStream.init_fd(pty.parent)
	child := EpollStream.init_fd(pty.child)

	// Read
	mut read_buf := []u8{len: 128}
	mut read_len := EpollStreamTestLen{}
	c_read := &EpollCompletion{}
	child.read(mut loop, c_read, EpollReadBuffer{ kind: .slice, slice: read_buf }, &read_len,
		epoll_stream_test_read)

	// This should not block!
	loop.run(.no_wait)!
	assert read_len.value == none

	write_queue := &EpollWriteQueue{}
	write_req := [&EpollWriteRequest{}, &EpollWriteRequest{}]

	// Send (note the newline at the end of the buf is important
	// since we're in cooked mode)
	parent.queue_write(mut loop, write_queue, write_req[0], EpollWriteBuffer{
		kind:  .slice
		slice: 'hello, '.bytes()
	}, unsafe { nil }, epoll_stream_test_write)

	mut c_result := EpollStreamTestCompletion{}
	parent.queue_write(mut loop, write_queue, write_req[1], EpollWriteBuffer{
		kind:  .slice
		slice: 'world!\n'.bytes()
	}, &c_result, epoll_stream_test_write_record)

	// The write and read should trigger
	loop.run(.until_done)!
	assert read_len.value != none
	assert 'hello, world!\n'.bytes() == read_buf[..int(read_len.value?)]

	// Verify our completion is equal to our request
	assert EpollWriteRequest.from(c_result.value) == write_req[1]
}
