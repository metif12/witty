module xev

// GenericStreamTests from libxev src/watcher/stream.zig (pinned 34fa508), for
// the dynamic Stream. The pty tests run with the backend in use, so they are
// run twice: with the backend chosen by detect() (io_uring when available) and
// with epoll selected by prefer(.epoll).

#include <pty.h>

// Redeclare this winsize struct so we can just use a Zig struct. This
// layout should be correct on all tested platforms.
struct DynamicStreamTestWinsize {
	ws_row    u16
	ws_col    u16
	ws_xpixel u16
	ws_ypixel u16
}

// libc pty.h
fn C.openpty(parent &int, child &int, name &u8, termios voidptr, winsize voidptr) int

// Helper to open a pty. This isn't exposed as a public API this is only
// used for tests.
struct DynamicStreamTestPty {
	// The file descriptors for the parent/child side of the pty. This refers
	// to the master/slave side respectively, and while that terminology is
	// the officially used terminology of the syscall, I will use parent/child
	// here.
	parent int
	child  int
}

fn DynamicStreamTestPty.init() !DynamicStreamTestPty {
	// Reasonable size
	size := DynamicStreamTestWinsize{
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

	return DynamicStreamTestPty{
		parent: parent_fd
		child:  child_fd
	}
}

fn (mut self DynamicStreamTestPty) deinit() {
	posix_close(self.parent)
	posix_close(self.child)
}

struct DynamicStreamTestLen {
mut:
	value ?usize
}

// Zig's `.?`: `?` propagation needs an option-returning function.
fn dynamic_stream_test_unwrap(v ?usize) usize {
	return v or { panic('attempt to use null value') }
}

fn dynamic_stream_test_read(ud voidptr, _ &Loop, _ &Completion, _ Stream, _ ReadBuffer, r ?ErrorKind, n usize) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut len := unsafe { &DynamicStreamTestLen(ud) }
	len.value = n
	return .disarm
}

fn dynamic_stream_test_write(_ voidptr, _ &Loop, _ &Completion, _ Stream, _ WriteBuffer, r ?ErrorKind, _ usize) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	return .disarm
}

struct DynamicStreamTestCompletion {
mut:
	value &Completion = unsafe { nil }
}

fn dynamic_stream_test_write_record(ud voidptr, _ &Loop, c &Completion, _ Stream, _ WriteBuffer, r ?ErrorKind, _ usize) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut result := unsafe { &DynamicStreamTestCompletion(ud) }
	result.value = unsafe { c }
	return .disarm
}

fn test_dynamic_stream_decls() {
	// Zig checks at compile time that every public decl of the stream's
	// mixin that is not void (close, poll, read, write, queueWrite; writeInit
	// is void for the dynamic API) is also a decl of the stream type.
	mut names := []string{}
	$for method in Stream.methods {
		names << method.name
	}
	for decl in ['close', 'poll', 'read', 'write', 'queue_write'] {
		assert decl in names, 'missing decl: ${decl}'
	}
}

fn dynamic_stream_test_pty_child_to_parent() ! {
	// Create the pty parent/child side.
	mut pty := DynamicStreamTestPty.init()!
	defer {
		pty.deinit()
	}

	mut loop := Loop.init(Options{})!
	defer {
		loop.deinit()
	}

	parent := Stream.init_fd(pty.parent)
	child := Stream.init_fd(pty.child)

	// Read
	mut read_buf := []u8{len: 128}
	mut read_len := DynamicStreamTestLen{}
	c_read := &Completion{}
	parent.read(mut loop, c_read, ReadBuffer(ReadBufferSlice{ slice: read_buf }), &read_len,
		dynamic_stream_test_read)

	// This should not block!
	loop.run(.no_wait)!
	assert read_len.value == none

	// Send
	send_buf := 'hello, world!'.bytes()
	c_write := &Completion{}
	child.write(mut loop, c_write, WriteBuffer(WriteBufferSlice{ slice: send_buf }), unsafe { nil },
		dynamic_stream_test_write)

	// The write and read should trigger
	loop.run(.until_done)!
	assert read_len.value != none
	assert send_buf == read_buf[..int(dynamic_stream_test_unwrap(read_len.value))]
}

fn dynamic_stream_test_pty_parent_to_child() ! {
	// Create the pty parent/child side.
	mut pty := DynamicStreamTestPty.init()!
	defer {
		pty.deinit()
	}

	mut loop := Loop.init(Options{})!
	defer {
		loop.deinit()
	}

	parent := Stream.init_fd(pty.parent)
	child := Stream.init_fd(pty.child)

	// Read
	mut read_buf := []u8{len: 128}
	mut read_len := DynamicStreamTestLen{}
	c_read := &Completion{}
	child.read(mut loop, c_read, ReadBuffer(ReadBufferSlice{ slice: read_buf }), &read_len,
		dynamic_stream_test_read)

	// This should not block!
	loop.run(.no_wait)!
	assert read_len.value == none

	// Send (note the newline at the end of the buf is important
	// since we're in cooked mode)
	send_buf := 'hello, world!\n'.bytes()
	c_write := &Completion{}
	parent.write(mut loop, c_write, WriteBuffer(WriteBufferSlice{ slice: send_buf }), unsafe { nil },
		dynamic_stream_test_write)

	// The write and read should trigger
	loop.run(.until_done)!
	assert read_len.value != none
	assert send_buf == read_buf[..int(dynamic_stream_test_unwrap(read_len.value))]
}

fn dynamic_stream_test_pty_queued_writes() ! {
	// this test fails on x86_64 with a strange error but passes
	// on aarch64. for now, just let it go until we investigate.
	$if amd64 {
		return
	}

	// Create the pty parent/child side.
	mut pty := DynamicStreamTestPty.init()!
	defer {
		pty.deinit()
	}

	mut loop := Loop.init(Options{})!
	defer {
		loop.deinit()
	}

	parent := Stream.init_fd(pty.parent)
	child := Stream.init_fd(pty.child)

	// Read
	mut read_buf := []u8{len: 128}
	mut read_len := DynamicStreamTestLen{}
	c_read := &Completion{}
	child.read(mut loop, c_read, ReadBuffer(ReadBufferSlice{ slice: read_buf }), &read_len,
		dynamic_stream_test_read)

	// This should not block!
	loop.run(.no_wait)!
	assert read_len.value == none

	write_queue := &WriteQueue{}
	write_req := [&WriteRequest{}, &WriteRequest{}]

	// Send (note the newline at the end of the buf is important
	// since we're in cooked mode)
	parent.queue_write(mut loop, write_queue, write_req[0], WriteBuffer(WriteBufferSlice{ slice: 'hello, '.bytes() }), unsafe { nil }, dynamic_stream_test_write)

	mut c_result := DynamicStreamTestCompletion{}
	parent.queue_write(mut loop, write_queue, write_req[1], WriteBuffer(WriteBufferSlice{ slice: 'world!\n'.bytes() }), &c_result, dynamic_stream_test_write_record)

	// The write and read should trigger
	loop.run(.until_done)!
	assert read_len.value != none
	assert 'hello, world!\n'.bytes() == read_buf[..int(dynamic_stream_test_unwrap(read_len.value))]

	// Verify our completion is equal to our request. The source only checks
	// this for the static API (`if (!xev.dynamic)`); the dynamic WriteRequest
	// has no `from`.
}

fn dynamic_stream_tests() ! {
	dynamic_stream_test_pty_child_to_parent()!
	dynamic_stream_test_pty_parent_to_child()!
	dynamic_stream_test_pty_queued_writes()!
}

fn test_dynamic_stream_detect() ! {
	detect()!
	dynamic_stream_tests()!
}

fn test_dynamic_stream_prefer_epoll() ! {
	assert prefer(.epoll)
	dynamic_stream_tests()!
}
