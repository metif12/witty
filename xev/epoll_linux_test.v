module xev

// Tests translated from libxev src/backend/epoll.zig (pinned 34fa508).

fn epoll_test_set_bool(ud voidptr, _ &EpollLoop, _ &EpollCompletion, _ EpollResult) CallbackAction {
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = true
	}
	return .disarm
}

struct EpollTestTrigger {
mut:
	value ?EpollTimerTrigger
}

fn epoll_test_record_trigger(ud voidptr, _ &EpollLoop, _ &EpollCompletion, r EpollResult) CallbackAction {
	mut v := unsafe { &EpollTestTrigger(ud) }
	if _ := r.err {
		panic('unreachable')
	}
	v.value = r.timer
	return .disarm
}

fn epoll_test_cancel_done(ud voidptr, _ &EpollLoop, _ &EpollCompletion, r EpollResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	mut ptr := unsafe { &bool(ud) }
	unsafe {
		*ptr = true
	}
	return .disarm
}

fn test_epoll_completion_size() {
	// Just so we are aware when we change the size
	//
	// The Zig Completion is 208 bytes. The V completion flattens the
	// Operation and Result unions into records, so its own size is tracked.
	assert usize(1120) == sizeof(EpollCompletion)
}

fn test_epoll_default_completion() ! {
	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	c := &EpollCompletion{}
	loop.add(c)

	// Tick
	loop.run(.until_done)!

	// Completion should be dead.
	assert c.state() == .dead
}

fn test_epoll_loop_time() ! {
	mut loop := EpollLoop.init(Options{})!
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

fn test_epoll_stop() ! {
	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut called := false
	c1 := &EpollCompletion{}
	loop.timer(c1, 1_000_000, &called, epoll_test_set_bool)

	// Tick
	loop.run(.no_wait)!
	assert !called

	// Stop
	loop.stop()
	loop.run(.until_done)!
	assert !called
}

fn test_epoll_timer() ! {
	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut called := false
	c1 := &EpollCompletion{}
	loop.timer(c1, 1, &called, epoll_test_set_bool)

	// Add another timer
	mut called2 := false
	c2 := &EpollCompletion{}
	loop.timer(c2, 100_000, &called2, epoll_test_set_bool)

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

fn test_epoll_timer_reset() ! {
	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut trigger := EpollTestTrigger{}
	c1 := &EpollCompletion{}
	loop.timer(c1, 100_000, &trigger, epoll_test_record_trigger)

	// We know timer won't be called from the timer test previously.
	loop.run(.no_wait)!
	assert trigger.value == none

	// Reset the timer
	c_cancel := &EpollCompletion{}
	loop.timer_reset(c1, c_cancel, 1, &trigger, epoll_test_record_trigger)
	assert c1.state() == .active
	assert c_cancel.state() == .active

	// Run
	loop.run(.until_done)!
	assert trigger.value? == .expiration
	assert c1.state() == .dead
	assert c_cancel.state() == .dead
}

fn test_epoll_timer_reset_before_tick() ! {
	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut trigger := EpollTestTrigger{}
	c1 := &EpollCompletion{}
	loop.timer(c1, 100_000, &trigger, epoll_test_record_trigger)

	// Reset the timer
	c_cancel := &EpollCompletion{}
	loop.timer_reset(c1, c_cancel, 1, &trigger, epoll_test_record_trigger)
	assert c1.state() == .active
	assert c_cancel.state() == .dead

	// Run
	loop.run(.until_done)!
	assert trigger.value? == .expiration
	assert c1.state() == .dead
	assert c_cancel.state() == .dead
}

fn test_epoll_timer_reset_after_trigger() ! {
	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut trigger := EpollTestTrigger{}
	c1 := &EpollCompletion{}
	loop.timer(c1, 1, &trigger, epoll_test_record_trigger)

	// Run the timer
	loop.run(.until_done)!
	assert trigger.value? == .expiration
	assert c1.state() == .dead
	trigger.value = none

	// Reset the timer
	c_cancel := &EpollCompletion{}
	loop.timer_reset(c1, c_cancel, 1, &trigger, epoll_test_record_trigger)
	assert c1.state() == .active
	assert c_cancel.state() == .dead

	// Run
	loop.run(.until_done)!
	assert trigger.value? == .expiration
	assert c1.state() == .dead
	assert c_cancel.state() == .dead
}

fn epoll_test_timerfd_read(ud voidptr, _ &EpollLoop, _ &EpollCompletion, r EpollResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = true
	}
	return .disarm
}

fn test_epoll_timerfd() ! {
	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// We'll try with a simple timerfd
	mut t := Timerfd.init(.monotonic, LinuxTfd{})!
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
	c := &EpollCompletion{
		op:       EpollOperation{
			tag:  .read
			read: EpollReadOp{
				fd:     t.fd
				buffer: EpollReadBuffer{
					kind: .array
				}
			}
		}
		userdata: &called
		callback: epoll_test_timerfd_read
	}
	loop.add(c)

	// Tick
	loop.run(.until_done)!
	assert called
}

fn epoll_test_accept(ud voidptr, _ &EpollLoop, _ &EpollCompletion, r EpollResult) CallbackAction {
	mut conn := unsafe { &int(ud) }
	if _ := r.err {
		panic('unreachable')
	}
	unsafe {
		*conn = r.socket
	}
	return .disarm
}

fn epoll_test_ok_set_bool(ud voidptr, _ &EpollLoop, _ &EpollCompletion, r EpollResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = true
	}
	return .disarm
}

fn epoll_test_send(_ voidptr, _ &EpollLoop, _ &EpollCompletion, r EpollResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	return .disarm
}

fn epoll_test_recv(ud voidptr, _ &EpollLoop, _ &EpollCompletion, r EpollResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	mut ptr := unsafe { &usize(ud) }
	unsafe {
		*ptr = r.n
	}
	return .disarm
}

struct EpollTestEof {
mut:
	value ?bool
}

fn epoll_test_recv_eof(ud voidptr, _ &EpollLoop, _ &EpollCompletion, r EpollResult) CallbackAction {
	mut ptr := unsafe { &EpollTestEof(ud) }
	ptr.value = if e := r.err { e == .eof } else { false }
	return .disarm
}

fn epoll_test_close_zero(ud voidptr, _ &EpollLoop, _ &EpollCompletion, r EpollResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	mut ptr := unsafe { &int(ud) }
	unsafe {
		*ptr = 0
	}
	return .disarm
}

fn epoll_test_listener(address NetAddress) !int {
	kernel_backlog := u32(1)
	family := unsafe { u32((&C.sockaddr(address.any())).sa_family) }
	ln := posix_socket(family, u32(C.SOCK_STREAM) | sock_cloexec, 0)!
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
	return ln
}

fn test_epoll_socket_accept_connect_send_recv_close() ! {
	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Create a TCP server socket
	address := NetAddress.init_ip4([u8(127), 0, 0, 1]!, 3131)
	mut ln := epoll_test_listener(address)!

	// Create a TCP client socket
	family := unsafe { u32((&C.sockaddr(address.any())).sa_family) }
	mut client_conn := posix_socket(family, sock_nonblock | u32(C.SOCK_STREAM) | sock_cloexec,
		0) or {
		posix_close(ln)
		return err
	}

	// Accept
	mut server_conn := int(0)
	c_accept := &EpollCompletion{
		op:       EpollOperation{
			tag:    .accept
			accept: EpollAcceptOp{
				socket: ln
			}
		}
		userdata: &server_conn
		callback: epoll_test_accept
	}
	loop.add(c_accept)

	// Connect
	mut connected := false
	c_connect := &EpollCompletion{
		op:       EpollOperation{
			tag:     .connect
			connect: EpollConnectOp{
				socket: client_conn
				addr:   address
			}
		}
		userdata: &connected
		callback: epoll_test_ok_set_bool
	}
	loop.add(c_connect)

	// Wait for the connection to be established
	loop.run(.until_done)!
	assert server_conn > 0
	assert connected

	// Send
	c_send := &EpollCompletion{
		op:       EpollOperation{
			tag:  .send
			send: EpollWriteOp{
				fd:     client_conn
				buffer: EpollWriteBuffer{
					kind:  .slice
					slice: [u8(1), 1, 2, 3, 5, 8, 13]
				}
			}
		}
		callback: epoll_test_send
	}
	loop.add(c_send)

	// Receive
	mut recv_buf := []u8{len: 128}
	mut recv_len := usize(0)
	mut c_recv := &EpollCompletion{
		op:       EpollOperation{
			tag:  .recv
			recv: EpollReadOp{
				fd:     server_conn
				buffer: EpollReadBuffer{
					kind:  .slice
					slice: recv_buf
				}
			}
		}
		userdata: &recv_len
		callback: epoll_test_recv
	}
	loop.add(c_recv)

	// Wait for the send/receive
	loop.run(.until_done)!
	assert c_send.op.send.buffer.slice == recv_buf[..int(recv_len)]

	// Shutdown
	mut shutdown := false
	c_client_shutdown := &EpollCompletion{
		op:       EpollOperation{
			tag:      .shutdown
			shutdown: EpollShutdownOp{
				socket: client_conn
			}
		}
		userdata: &shutdown
		callback: epoll_test_ok_set_bool
	}
	loop.add(c_client_shutdown)
	loop.run(.until_done)!
	assert shutdown

	// Read should be EOF
	mut eof := EpollTestEof{}
	unsafe {
		*c_recv = EpollCompletion{
			op:       EpollOperation{
				tag:  .recv
				recv: EpollReadOp{
					fd:     server_conn
					buffer: EpollReadBuffer{
						kind:  .slice
						slice: recv_buf
					}
				}
			}
			userdata: &eof
			callback: epoll_test_recv_eof
		}
	}
	loop.add(c_recv)

	loop.run(.until_done)!
	assert eof.value? == true

	// Close
	c_client_close := &EpollCompletion{
		op:       EpollOperation{
			tag:   .close
			close: EpollCloseOp{
				fd: client_conn
			}
		}
		userdata: &client_conn
		callback: epoll_test_close_zero
	}
	loop.add(c_client_close)

	c_server_close := &EpollCompletion{
		op:       EpollOperation{
			tag:   .close
			close: EpollCloseOp{
				fd: ln
			}
		}
		userdata: &ln
		callback: epoll_test_close_zero
	}
	loop.add(c_server_close)

	// Wait for the sockets to close
	loop.run(.until_done)!
	assert ln == 0
	assert client_conn == 0
}

fn test_epoll_timer_cancellation() ! {
	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut trigger := EpollTestTrigger{}
	c1 := &EpollCompletion{}
	loop.timer(c1, 100_000, &trigger, epoll_test_record_trigger)

	// Tick and verify we're not called.
	loop.run(.no_wait)!
	assert trigger.value == none

	// Cancel the timer
	mut called := false
	c_cancel := &EpollCompletion{
		op:       EpollOperation{
			tag:    .cancel
			cancel: EpollCancelOp{
				c: c1
			}
		}
		userdata: &called
		callback: epoll_test_cancel_done
	}
	loop.add(c_cancel)

	// Tick
	loop.run(.until_done)!
	assert called
	assert trigger.value? == .cancel
}

fn test_epoll_canceling_a_completed_operation() ! {
	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut trigger := EpollTestTrigger{}
	c1 := &EpollCompletion{}
	loop.timer(c1, 1, &trigger, epoll_test_record_trigger)

	// Tick and verify we're not called.
	loop.run(.until_done)!
	assert trigger.value? == .expiration

	// Cancel the timer
	mut called := false
	c_cancel := &EpollCompletion{
		op:       EpollOperation{
			tag:    .cancel
			cancel: EpollCancelOp{
				c: c1
			}
		}
		userdata: &called
		callback: epoll_test_cancel_done
	}
	loop.add(c_cancel)

	// Tick
	loop.run(.until_done)!
	assert called
	assert trigger.value? == .expiration
}
