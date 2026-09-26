module xev

// Tests translated from libxev src/backend/io_uring.zig (pinned 34fa508).
//
// The source's "Completion size" test (expecting @sizeOf(Completion) == 152)
// is not translated: the V Completion flattens the Operation union into a
// record, so its size is not comparable.

fn io_uring_test_set_bool(ud voidptr, _ &IoUringLoop, _ &IoUringCompletion, _ IoUringResult) CallbackAction {
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = true
	}
	return .disarm
}

struct IoUringTestTrigger {
mut:
	value ?IoUringTimerTrigger
}

fn io_uring_test_record_trigger(ud voidptr, _ &IoUringLoop, _ &IoUringCompletion, r IoUringResult) CallbackAction {
	mut v := unsafe { &IoUringTestTrigger(ud) }
	if _ := r.err {
		panic('unreachable')
	}
	v.value = (r as IoUringTimerResult).timer
	return .disarm
}

fn test_io_uring_available() {
	assert io_uring_available()
}

fn test_io_uring_overflow_entries_count() ! {
	{
		mut loop := IoUringLoop.init(Options{})!
		defer {
			loop.deinit()
		}
	}

	{
		// std.math.pow(u14, 2, 13)
		if mut loop := IoUringLoop.init(Options{
			entries: 1 << 13
		})
		{
			loop.deinit()
			assert false, 'expected error.TooManyEntries'
		} else {
			assert error_kind(err) == .too_many_entries
		}
	}
}

fn test_io_uring_default_completion() ! {
	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Due to implementation details, we need to have an ongoing completion to test that the noop operation works properly
	mut timer_called := false
	mut c1 := &IoUringCompletion{}
	loop.timer(c1, 1, &timer_called, io_uring_test_set_bool)

	mut c := &IoUringCompletion{}
	loop.add(c)

	// Tick
	loop.run(.until_done)!

	// Completion should have been called and be dead.
	assert c.state() == .dead
	assert timer_called
}

fn test_io_uring_timerfd() ! {
	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// We'll try with a simple timerfd
	t := Timerfd.init(.monotonic, LinuxTfd{})!
	defer {
		t.deinit()
	}
	t.set(LinuxTfdTimer{}, &TimerfdSpec{
		value: TimerfdTimeSpec{
			nanoseconds: 1
		}
	}, unsafe { nil })!

	// Add the timer
	mut called := false
	mut c := &IoUringCompletion{
		// Note: we should be able to use `read` here but on
		// Kernel 6.15.4 there is a bug that prevents the read
		// from ever firing with io_uring. I don't know why. I changed
		// this to a poll so tests pass, which should also be fine!
		op: IoUringPollOp{
			fd: int(t.fd)
		}
		userdata: &called
		callback: io_uring_test_set_bool
	}
	loop.add(c)

	// Verify states
	assert c.state() == .active

	// Tick
	loop.run(.until_done)!
	assert called
	assert c.state() == .dead
}

fn test_io_uring_timer() ! {
	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut called := false
	mut c1 := &IoUringCompletion{}
	loop.timer(c1, 1, &called, io_uring_test_set_bool)

	// Add another timer
	mut called2 := false
	mut c2 := &IoUringCompletion{}
	loop.timer(c2, 100_000, &called2, io_uring_test_set_bool)

	// State checking
	assert c1.state() == .active
	assert c2.state() == .active

	// Tick
	for !called {
		loop.run(.no_wait)!
	}
	assert called
	assert !called2

	// State checking
	assert c1.state() == .dead
	assert c2.state() == .active
}

fn test_io_uring_timer_reset() ! {
	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut trigger := IoUringTestTrigger{}
	mut c1 := &IoUringCompletion{}
	loop.timer(c1, 100_000, &trigger, io_uring_test_record_trigger)

	// We know timer won't be called from the timer test previously.
	loop.run(.no_wait)!
	assert trigger.value == none

	// Reset the timer
	mut c_cancel := &IoUringCompletion{}
	loop.timer_reset(c1, c_cancel, 1, &trigger, io_uring_test_record_trigger)
	assert c1.state() == .active
	assert c_cancel.state() == .active

	// Run
	loop.run(.until_done)!
	assert trigger.value? == .expiration
	assert c1.state() == .dead
	assert c_cancel.state() == .dead
}

fn test_io_uring_stop() ! {
	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut called := false
	mut c1 := &IoUringCompletion{}
	loop.timer(c1, 1_000_000, &called, io_uring_test_set_bool)

	// Tick
	loop.run(.no_wait)!
	assert !called

	// Stop
	loop.stop()
	loop.run(.until_done)!
	assert !called
}

fn test_io_uring_loop_time() ! {
	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// should never init zero
	now := loop.now()
	assert now > 0

	// should update on a loop tick
	for now == loop.now() {
		loop.run(.no_wait)!
	}
}

fn io_uring_test_timer_remove_done(_ voidptr, _ &IoUringLoop, _ &IoUringCompletion, r IoUringResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	return .disarm
}

fn test_io_uring_timer_remove() ! {
	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut trigger := IoUringTestTrigger{}
	mut c1 := &IoUringCompletion{}
	loop.timer(c1, 100_000, &trigger, io_uring_test_record_trigger)

	// Remove it
	mut c_remove := &IoUringCompletion{
		op: IoUringTimerRemoveOp{
			timer: c1
		}
		userdata: unsafe { nil }
		callback: io_uring_test_timer_remove_done
	}
	loop.add(c_remove)

	// Tick
	loop.run(.until_done)!
	assert trigger.value? == .cancel
}

fn io_uring_test_accept(ud voidptr, _ &IoUringLoop, _ &IoUringCompletion, r IoUringResult) CallbackAction {
	mut conn := unsafe { &int(ud) }
	if _ := r.err {
		panic('unreachable')
	}
	unsafe {
		*conn = (r as IoUringAcceptResult).socket
	}
	return .disarm
}

fn io_uring_test_ok_set_bool(ud voidptr, _ &IoUringLoop, _ &IoUringCompletion, r IoUringResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = true
	}
	return .disarm
}

fn io_uring_test_ok(_ voidptr, _ &IoUringLoop, _ &IoUringCompletion, r IoUringResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	return .disarm
}

fn io_uring_test_recv(ud voidptr, _ &IoUringLoop, _ &IoUringCompletion, r IoUringResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	mut ptr := unsafe { &usize(ud) }
	unsafe {
		*ptr = (r as IoUringRecvResult).n
	}
	return .disarm
}

fn io_uring_test_recvmsg(ud voidptr, _ &IoUringLoop, _ &IoUringCompletion, r IoUringResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	mut ptr := unsafe { &usize(ud) }
	unsafe {
		*ptr = (r as IoUringRecvMsgResult).n
	}
	return .disarm
}

struct IoUringTestEof {
mut:
	value ?bool
}

fn io_uring_test_recv_eof(ud voidptr, _ &IoUringLoop, _ &IoUringCompletion, r IoUringResult) CallbackAction {
	mut ptr := unsafe { &IoUringTestEof(ud) }
	ptr.value = if e := r.err { e == .eof } else { false }
	return .disarm
}

fn io_uring_test_close_zero(ud voidptr, _ &IoUringLoop, _ &IoUringCompletion, r IoUringResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	mut ptr := unsafe { &int(ud) }
	unsafe {
		*ptr = 0
	}
	return .disarm
}

fn test_io_uring_socket_accept_connect_send_recv_close() ! {
	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Create a TCP server socket
	address := NetAddress.init_ip4([u8(127), 0, 0, 1]!, 3131)
	family := u32(unsafe { address.any_.family })
	kernel_backlog := u32(1)
	mut ln := posix_socket(family, u32(C.SOCK_STREAM) | sock_cloexec, 0)!
	mut one := int(1)
	posix_setsockopt(ln, C.SOL_SOCKET, u32(C.SO_REUSEADDR), unsafe { (&u8(&one)).vbytes(int(sizeof(int))) }) or {
		posix_close(ln)
		return err
	}
	posix_bind(ln, address.any(), address.get_os_sock_len()) or {
		posix_close(ln)
		return err
	}
	posix_listen(ln, kernel_backlog) or {
		posix_close(ln)
		return err
	}

	// Create a TCP client socket
	mut client_conn := posix_socket(family, u32(C.SOCK_STREAM) | sock_cloexec, 0) or {
		posix_close(ln)
		return err
	}

	// Accept
	mut server_conn := int(0)
	mut c_accept := &IoUringCompletion{
		op: IoUringAcceptOp{
			socket: ln
		}
		userdata: &server_conn
		callback: io_uring_test_accept
	}
	loop.add(c_accept)

	// Connect
	mut connected := false
	mut c_connect := &IoUringCompletion{
		op: IoUringConnectOp{
			socket: client_conn
			addr: address
		}
		userdata: &connected
		callback: io_uring_test_ok_set_bool
	}
	loop.add(c_connect)

	// Wait for the connection to be established
	loop.run(.until_done)!
	assert server_conn > 0
	assert connected

	// Send
	mut c_send := &IoUringCompletion{
		op: IoUringSendOp{
			fd: client_conn
			buffer: IoUringWriteBuffer(WriteBufferSlice{ slice: [u8(1), 1, 2, 3, 5, 8, 13] })
		}
		callback: io_uring_test_ok
	}
	loop.add(c_send)

	// Receive
	mut recv_buf := []u8{len: 128}
	mut recv_len := usize(0)
	mut c_recv := &IoUringCompletion{
		op: IoUringRecvOp{
			fd: server_conn
			buffer: IoUringReadBuffer(ReadBufferSlice{ slice: recv_buf })
		}
		userdata: &recv_len
		callback: io_uring_test_recv
	}
	loop.add(c_recv)

	// Wait for the send/receive
	loop.run(.until_done)!
	assert (c_send.op as IoUringSendOp).buffer.slice == recv_buf[..int(recv_len)]

	// Shutdown
	mut shutdown := false
	mut c_client_shutdown := &IoUringCompletion{
		op: IoUringShutdownOp{
			socket: client_conn
		}
		userdata: &shutdown
		callback: io_uring_test_ok_set_bool
	}
	loop.add(c_client_shutdown)
	loop.run(.until_done)!
	assert shutdown

	// Read should be EOF
	mut eof := IoUringTestEof{}
	unsafe {
		*c_recv = IoUringCompletion{
			op: IoUringRecvOp{
				fd: server_conn
				buffer: IoUringReadBuffer(ReadBufferSlice{ slice: recv_buf })
			}
			userdata: &eof
			callback: io_uring_test_recv_eof
		}
	}
	loop.add(c_recv)

	loop.run(.until_done)!
	assert eof.value? == true

	// Close
	mut c_client_close := &IoUringCompletion{
		op: IoUringCloseOp{
			fd: client_conn
		}
		userdata: &client_conn
		callback: io_uring_test_close_zero
	}
	loop.add(c_client_close)

	mut c_server_close := &IoUringCompletion{
		op: IoUringCloseOp{
			fd: ln
		}
		userdata: &ln
		callback: io_uring_test_close_zero
	}
	loop.add(c_server_close)

	// Wait for the sockets to close
	loop.run(.until_done)!
	assert ln == 0
	assert client_conn == 0
}

// std.posix.iovec / iovec_const. C.iovec declares no fields, so the tests
// build the Zig extern struct.
struct IoUringTestIovec {
	base voidptr
	len  usize
}

// std.os.linux.msghdr / msghdr_const. C.msghdr declares no fields, so the
// tests build the Zig extern struct.
struct IoUringTestMsghdr {
	name       voidptr
	namelen    u32
	iov        voidptr
	iovlen     usize
	control    voidptr
	controllen usize
	flags      u32
}

fn test_io_uring_sendmsg_recvmsg() ! {
	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Create a TCP server socket
	address := NetAddress.init_ip4([u8(127), 0, 0, 1]!, 3131)
	family := u32(unsafe { address.any_.family })
	server := posix_socket(family, u32(C.SOCK_DGRAM), 0)!
	defer {
		posix_close(server)
	}
	mut one := int(1)
	posix_setsockopt(server, C.SOL_SOCKET, u32(C.SO_REUSEPORT), unsafe { (&u8(&one)).vbytes(int(sizeof(int))) })!
	posix_setsockopt(server, C.SOL_SOCKET, u32(C.SO_REUSEADDR), unsafe { (&u8(&one)).vbytes(int(sizeof(int))) })!
	posix_bind(server, address.any(), address.get_os_sock_len())!

	client := posix_socket(family, u32(C.SOCK_DGRAM), 0)!
	defer {
		posix_close(client)
	}

	// Send
	buffer_send := []u8{len: 128, init: 42}
	iovecs_send := [
		IoUringTestIovec{
			base: buffer_send.data
			len: usize(buffer_send.len)
		},
	]!
	mut msg_send := IoUringTestMsghdr{
		name: address.any()
		namelen: address.get_os_sock_len()
		iov: unsafe { &iovecs_send[0] }
		iovlen: 1
		control: unsafe { nil }
		controllen: 0
		flags: 0
	}
	mut c_sendmsg := &IoUringCompletion{
		op: IoUringSendMsgOp{
			fd: client
			msghdr: unsafe { &C.msghdr(&msg_send) }
		}
		callback: io_uring_test_ok
	}
	loop.add(c_sendmsg)

	// Recv

	mut buffer_recv := []u8{len: 128, init: 0}
	mut iovecs_recv := [
		IoUringTestIovec{
			base: buffer_recv.data
			len: usize(buffer_recv.len)
		},
	]!
	mut address_recv := NetAddress.init_ip4([u8(0), 0, 0, 0]!, 0)
	mut msg_recv := IoUringTestMsghdr{
		name: address_recv.any()
		namelen: address_recv.get_os_sock_len()
		iov: unsafe { &iovecs_recv[0] }
		iovlen: 1
		control: unsafe { nil }
		controllen: 0
		flags: 0
	}
	mut recv_size := usize(0)
	mut c_recvmsg := &IoUringCompletion{
		op: IoUringRecvMsgOp{
			fd: server
			msghdr: unsafe { &C.msghdr(&msg_recv) }
		}
		userdata: &recv_size
		callback: io_uring_test_recvmsg
	}
	loop.add(c_recvmsg)

	// Wait for the sockets to close
	loop.run(.until_done)!
	assert recv_size == usize(buffer_recv.len)
	assert buffer_send[..buffer_recv.len] == buffer_recv
}

fn io_uring_test_store_result(ud voidptr, _ &IoUringLoop, _ &IoUringCompletion, r IoUringResult) CallbackAction {
	mut ptr := unsafe { &IoUringResult(ud) }
	unsafe {
		*ptr = r
	}
	return .disarm
}

fn io_uring_test_cancel_ok(_ voidptr, _ &IoUringLoop, _ &IoUringCompletion, r ?ErrorKind) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	return .disarm
}

fn test_io_uring_socket_read_cancellation() ! {
	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Create a UDP server socket
	address := NetAddress.init_ip4([u8(127), 0, 0, 1]!, 3131)
	family := u32(unsafe { address.any_.family })
	socket := posix_socket(family, u32(C.SOCK_DGRAM) | sock_cloexec, 0)!
	mut one := int(1)
	posix_setsockopt(socket, C.SOL_SOCKET, u32(C.SO_REUSEADDR), unsafe { (&u8(&one)).vbytes(int(sizeof(int))) }) or {
		posix_close(socket)
		return err
	}
	posix_bind(socket, address.any(), address.get_os_sock_len()) or {
		posix_close(socket)
		return err
	}

	// Read
	mut read_result := IoUringResult(IoUringReadResult{})
	mut c_read := &IoUringCompletion{
		op: IoUringReadOp{
			fd: socket
			buffer: IoUringReadBuffer(ReadBufferArray{})
		}
		userdata: &read_result
		callback: io_uring_test_store_result
	}
	loop.add(c_read)

	// Cancellation
	mut c_read_cancel := &IoUringCompletion{}
	loop.cancel(c_read, c_read_cancel, unsafe { nil }, io_uring_test_cancel_ok)
	loop.add(c_read_cancel)

	// Wait for the read to be cancelled
	loop.run(.until_done)!
	assert IoUringOperationType.read == read_result.tag()
	assert read_result.err? == .canceled
}
