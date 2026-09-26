module xev

// GenericStreamTests from libxev src/watcher/stream.zig (pinned 34fa508), for
// the kqueue Stream.

#include <util.h>

// Redeclare this winsize struct so we can just use a Zig struct. This
// layout should be correct on all tested platforms.
struct StreamTestWinsize {
	ws_row    u16
	ws_col    u16
	ws_xpixel u16
	ws_ypixel u16
}

// libc pty.h
fn C.openpty(parent &int, child &int, name &u8, termios voidptr, winsize voidptr) int

// Helper to open a pty. This isn't exposed as a public API this is only
// used for tests.
struct StreamTestPty {
	// The file descriptors for the parent/child side of the pty. This refers
	// to the master/slave side respectively, and while that terminology is
	// the officially used terminology of the syscall, I will use parent/child
	// here.
	parent int
	child  int
}

fn StreamTestPty.init() !StreamTestPty {
	// Reasonable size
	size := StreamTestWinsize{
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

	return StreamTestPty{
		parent: parent_fd
		child: child_fd
	}
}

fn (mut self StreamTestPty) deinit() {
	posix_close(self.parent)
	posix_close(self.child)
}

struct StreamTestLen {
mut:
	value ?usize
}

fn kqueue_stream_test_read(ud voidptr, _ &KqueueLoop, _ &KqueueCompletion, _ KqueueStream, _ KqueueReadBuffer, r ?ErrorKind, n usize) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut len := unsafe { &StreamTestLen(ud) }
	len.value = n
	return .disarm
}

fn kqueue_stream_test_write(_ voidptr, _ &KqueueLoop, _ &KqueueCompletion, _ KqueueStream, _ KqueueWriteBuffer, r ?ErrorKind, _ usize) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	return .disarm
}

struct StreamTestCompletion {
mut:
	value &KqueueCompletion = unsafe { nil }
}

fn kqueue_stream_test_write_record(ud voidptr, _ &KqueueLoop, c &KqueueCompletion, _ KqueueStream, _ KqueueWriteBuffer, r ?ErrorKind, _ usize) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut result := unsafe { &StreamTestCompletion(ud) }
	result.value = unsafe { c }
	return .disarm
}

fn test_kqueue_stream_pty_child_to_parent() ! {
	// Create the pty parent/child side.
	mut pty := StreamTestPty.init()!
	defer {
		pty.deinit()
	}

	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	parent := KqueueStream.init_fd(pty.parent)
	child := KqueueStream.init_fd(pty.child)

	// Read
	mut read_buf := []u8{len: 128}
	mut read_len := StreamTestLen{}
	c_read := &KqueueCompletion{}
	parent.read(mut loop, c_read, KqueueReadBuffer(ReadBufferSlice{ slice: read_buf }), &read_len,
		kqueue_stream_test_read)

	// This should not block!
	loop.run(.no_wait)!
	assert read_len.value == none

	// Send
	send_buf := 'hello, world!'.bytes()
	c_write := &KqueueCompletion{}
	child.write(mut loop, c_write, KqueueWriteBuffer(WriteBufferSlice{ slice: send_buf }), unsafe { nil },
		kqueue_stream_test_write)

	// The write and read should trigger
	loop.run(.until_done)!
	assert read_len.value != none
	assert send_buf == read_buf[..int(read_len.value?)]
}

fn test_kqueue_stream_pty_parent_to_child() ! {
	// Create the pty parent/child side.
	mut pty := StreamTestPty.init()!
	defer {
		pty.deinit()
	}

	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	parent := KqueueStream.init_fd(pty.parent)
	child := KqueueStream.init_fd(pty.child)

	// Read
	mut read_buf := []u8{len: 128}
	mut read_len := StreamTestLen{}
	c_read := &KqueueCompletion{}
	child.read(mut loop, c_read, KqueueReadBuffer(ReadBufferSlice{ slice: read_buf }), &read_len,
		kqueue_stream_test_read)

	// This should not block!
	loop.run(.no_wait)!
	assert read_len.value == none

	// Send (note the newline at the end of the buf is important
	// since we're in cooked mode)
	send_buf := 'hello, world!\n'.bytes()
	c_write := &KqueueCompletion{}
	parent.write(mut loop, c_write, KqueueWriteBuffer(WriteBufferSlice{ slice: send_buf }), unsafe { nil },
		kqueue_stream_test_write)

	// The write and read should trigger
	loop.run(.until_done)!
	assert read_len.value != none
	assert send_buf == read_buf[..int(read_len.value?)]
}

fn test_kqueue_stream_pty_queued_writes() ! {
	// Create the pty parent/child side.
	mut pty := StreamTestPty.init()!
	defer {
		pty.deinit()
	}

	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	parent := KqueueStream.init_fd(pty.parent)
	child := KqueueStream.init_fd(pty.child)

	// Read
	mut read_buf := []u8{len: 128}
	mut read_len := StreamTestLen{}
	c_read := &KqueueCompletion{}
	child.read(mut loop, c_read, KqueueReadBuffer(ReadBufferSlice{ slice: read_buf }), &read_len,
		kqueue_stream_test_read)

	// This should not block!
	loop.run(.no_wait)!
	assert read_len.value == none

	write_queue := &KqueueWriteQueue{}
	write_req := [&KqueueWriteRequest{}, &KqueueWriteRequest{}]

	// Send (note the newline at the end of the buf is important
	// since we're in cooked mode)
	parent.queue_write(mut loop, write_queue, write_req[0], KqueueWriteBuffer(WriteBufferSlice{ slice: 'hello, '.bytes() }), unsafe { nil }, kqueue_stream_test_write)

	mut c_result := StreamTestCompletion{}
	parent.queue_write(mut loop, write_queue, write_req[1], KqueueWriteBuffer(WriteBufferSlice{ slice: 'world!\n'.bytes() }), &c_result, kqueue_stream_test_write_record)

	// The write and read should trigger
	loop.run(.until_done)!
	assert read_len.value != none
	assert 'hello, world!\n'.bytes() == read_buf[..int(read_len.value?)]

	// Verify our completion is equal to our request
	assert KqueueWriteRequest.from(c_result.value) == write_req[1]
}
