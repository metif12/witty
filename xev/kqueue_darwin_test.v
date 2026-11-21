module xev

import os

// Tests translated from libxev src/backend/kqueue.zig (pinned 34fa508).

fn test_kqueue_operation_and_timer_tags_match_source() {
	assert sizeof(KqueueOperationType) == 1
	assert u8(KqueueOperationType.noop) == 0
	assert u8(KqueueOperationType.accept) == 1
	assert u8(KqueueOperationType.connect) == 2
	assert u8(KqueueOperationType.read) == 3
	assert u8(KqueueOperationType.write) == 4
	assert u8(KqueueOperationType.pread) == 5
	assert u8(KqueueOperationType.pwrite) == 6
	assert u8(KqueueOperationType.send) == 7
	assert u8(KqueueOperationType.recv) == 8
	assert u8(KqueueOperationType.sendto) == 9
	assert u8(KqueueOperationType.recvfrom) == 10
	assert u8(KqueueOperationType.close) == 11
	assert u8(KqueueOperationType.shutdown) == 12
	assert u8(KqueueOperationType.timer) == 13
	assert u8(KqueueOperationType.cancel) == 14
	assert u8(KqueueOperationType.machport) == 15
	assert u8(KqueueOperationType.proc) == 16

	assert sizeof(KqueueTimerTrigger) == 1
	assert u8(KqueueTimerTrigger.request) == 0
	assert u8(KqueueTimerTrigger.expiration) == 1
	assert u8(KqueueTimerTrigger.cancel) == 2
}

fn test_kqueue_start_action_keeps_result_payload() {
	actions := [KqueueStartAction(KqueueStartKevent{}), KqueueStartTimer{}, KqueueStartCancel{},
		KqueueStartThreadpool{}, KqueueStartResult{
		value: -37
	}]
	assert actions[0] is KqueueStartKevent
	assert actions[1] is KqueueStartTimer
	assert actions[2] is KqueueStartCancel
	assert actions[3] is KqueueStartThreadpool
	assert actions[4] is KqueueStartResult
	if actions[4] is KqueueStartResult {
		assert actions[4].value == -37
	} else {
		assert false
	}
}

fn kqueue_test_set_bool(ud voidptr, _ &KqueueLoop, _ &KqueueCompletion, _ KqueueResult) CallbackAction {
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = true
	}
	return .disarm
}

struct KqueueTestTrigger {
mut:
	value ?KqueueTimerTrigger
}

fn kqueue_test_record_trigger(ud voidptr, _ &KqueueLoop, _ &KqueueCompletion, r KqueueResult) CallbackAction {
	mut v := unsafe { &KqueueTestTrigger(ud) }
	if _ := r.err {
		panic('unreachable')
	}
	v.value = (r as KqueueTimerResult).timer
	return .disarm
}

fn kqueue_test_cancel_done(ud voidptr, _ &KqueueLoop, _ &KqueueCompletion, r KqueueResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	mut ptr := unsafe { &bool(ud) }
	unsafe {
		*ptr = true
	}
	return .disarm
}

fn test_kqueue_loop_time() ! {
	mut loop := KqueueLoop.init(Options{})!
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

fn test_kqueue_stop() ! {
	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut called := false
	mut c1 := &KqueueCompletion{}
	loop.timer(c1, 1_000_000, &called, kqueue_test_set_bool)

	// Tick
	loop.run(.no_wait)!
	assert !called

	// Stop
	loop.stop()
	loop.run(.until_done)!
	assert !called
}

fn test_kqueue_timer() ! {
	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut called := false
	mut c1 := &KqueueCompletion{}
	loop.timer(c1, 1, &called, kqueue_test_set_bool)

	// Add another timer
	mut called2 := false
	mut c2 := &KqueueCompletion{}
	loop.timer(c2, 100_000, &called2, kqueue_test_set_bool)

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

fn test_kqueue_timer_reset() ! {
	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut trigger := KqueueTestTrigger{}
	mut c1 := &KqueueCompletion{}
	loop.timer(c1, 100_000, &trigger, kqueue_test_record_trigger)

	// We know timer won't be called from the timer test previously.
	loop.run(.no_wait)!
	assert trigger.value == none

	// Reset the timer
	mut c_cancel := &KqueueCompletion{}
	loop.timer_reset(c1, c_cancel, 1, &trigger, kqueue_test_record_trigger)
	assert c1.state() == .active
	assert c_cancel.state() == .active

	// Run
	loop.run(.until_done)!
	assert trigger.value? == .expiration
	assert c1.state() == .dead
	assert c_cancel.state() == .dead
}

fn test_kqueue_timer_reset_before_tick() ! {
	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut trigger := KqueueTestTrigger{}
	mut c1 := &KqueueCompletion{}
	loop.timer(c1, 100_000, &trigger, kqueue_test_record_trigger)

	// Reset the timer
	mut c_cancel := &KqueueCompletion{}
	loop.timer_reset(c1, c_cancel, 1, &trigger, kqueue_test_record_trigger)
	assert c1.state() == .active
	assert c_cancel.state() == .dead

	// Run
	loop.run(.until_done)!
	assert trigger.value? == .expiration
	assert c1.state() == .dead
	assert c_cancel.state() == .dead
}

fn test_kqueue_timer_reset_after_trigger() ! {
	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut trigger := KqueueTestTrigger{}
	mut c1 := &KqueueCompletion{}
	loop.timer(c1, 1, &trigger, kqueue_test_record_trigger)

	// Run the timer
	loop.run(.until_done)!
	assert trigger.value? == .expiration
	assert c1.state() == .dead
	trigger.value = none

	// Reset the timer
	mut c_cancel := &KqueueCompletion{}
	loop.timer_reset(c1, c_cancel, 1, &trigger, kqueue_test_record_trigger)
	assert c1.state() == .active
	assert c_cancel.state() == .dead

	// Run
	loop.run(.until_done)!
	assert trigger.value? == .expiration
	assert c1.state() == .dead
	assert c_cancel.state() == .dead
}

fn test_kqueue_timer_cancellation() ! {
	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut trigger := KqueueTestTrigger{}
	mut c1 := &KqueueCompletion{}
	loop.timer(c1, 100_000, &trigger, kqueue_test_record_trigger)

	// Tick and verify we're not called.
	loop.run(.no_wait)!
	assert trigger.value == none

	// Cancel the timer
	mut called := false
	mut c_cancel := &KqueueCompletion{
		op: KqueueCancelOp{
			c: c1
		}
		userdata: &called
		callback: kqueue_test_cancel_done
	}
	loop.add(c_cancel)

	// Tick
	loop.run(.until_done)!
	assert called
	assert trigger.value? == .cancel
}

fn test_kqueue_canceling_a_completed_operation() ! {
	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Add the timer
	mut trigger := KqueueTestTrigger{}
	mut c1 := &KqueueCompletion{}
	loop.timer(c1, 1, &trigger, kqueue_test_record_trigger)

	// Tick and verify we're not called.
	loop.run(.until_done)!
	assert trigger.value? == .expiration

	// Cancel the timer
	mut called := false
	mut c_cancel := &KqueueCompletion{
		op: KqueueCancelOp{
			c: c1
		}
		userdata: &called
		callback: kqueue_test_cancel_done
	}
	loop.add(c_cancel)

	// Tick
	loop.run(.until_done)!
	assert called
	assert trigger.value? == .expiration
}

fn C.mach_port_deallocate(task u32, name u32) i32

fn kqueue_test_accept(ud voidptr, _ &KqueueLoop, _ &KqueueCompletion, r KqueueResult) CallbackAction {
	mut conn := unsafe { &int(ud) }
	if _ := r.err {
		panic('unreachable')
	}
	unsafe {
		*conn = (r as KqueueAcceptResult).socket
	}
	return .disarm
}

fn kqueue_test_ok_set_bool(ud voidptr, _ &KqueueLoop, _ &KqueueCompletion, r KqueueResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = true
	}
	return .disarm
}

fn kqueue_test_send(_ voidptr, _ &KqueueLoop, _ &KqueueCompletion, r KqueueResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	return .disarm
}

fn kqueue_test_recv(ud voidptr, _ &KqueueLoop, _ &KqueueCompletion, r KqueueResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	mut ptr := unsafe { &uint(ud) }
	unsafe {
		*ptr = (r as KqueueRecvResult).n
	}
	return .disarm
}

fn kqueue_test_read(ud voidptr, _ &KqueueLoop, _ &KqueueCompletion, r KqueueResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	mut ptr := unsafe { &uint(ud) }
	unsafe {
		*ptr = (r as KqueueReadResult).n
	}
	return .disarm
}

struct KqueueTestEof {
mut:
	value ?bool
}

fn kqueue_test_recv_eof(ud voidptr, _ &KqueueLoop, _ &KqueueCompletion, r KqueueResult) CallbackAction {
	mut ptr := unsafe { &KqueueTestEof(ud) }
	ptr.value = if e := r.err { e == .eof } else { false }
	return .disarm
}

fn kqueue_test_close_zero(ud voidptr, _ &KqueueLoop, _ &KqueueCompletion, r KqueueResult) CallbackAction {
	if _ := r.err {
		panic('unreachable')
	}
	mut ptr := unsafe { &int(ud) }
	unsafe {
		*ptr = 0
	}
	return .disarm
}

fn kqueue_test_listener(address NetAddress) !int {
	kernel_backlog := u32(1)
	family := u32(unsafe { address.any_.family })
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

fn test_kqueue_socket_accept_connect_send_recv_close() ! {
	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Create a TCP server socket
	address := NetAddress.init_ip4([u8(127), 0, 0, 1]!, 3131)
	mut ln := kqueue_test_listener(address)!

	// Create a TCP client socket
	family := u32(unsafe { address.any_.family })
	mut client_conn := posix_socket(family, sock_nonblock | u32(C.SOCK_STREAM) | sock_cloexec,
		0) or {
		posix_close(ln)
		return err
	}

	// Accept
	mut server_conn := int(0)
	mut c_accept := &KqueueCompletion{
		op: KqueueAcceptOp{
			socket: ln
		}
		userdata: &server_conn
		callback: kqueue_test_accept
	}
	loop.add(c_accept)

	// Connect
	mut connected := false
	mut c_connect := &KqueueCompletion{
		op: KqueueConnectOp{
			socket: client_conn
			addr: address
		}
		userdata: &connected
		callback: kqueue_test_ok_set_bool
	}
	loop.add(c_connect)

	// Wait for the connection to be established
	loop.run(.until_done)!
	assert server_conn > 0
	assert connected

	// Send
	mut c_send := &KqueueCompletion{
		op: KqueueSendOp{
			fd: client_conn
			buffer: KqueueWriteBuffer(WriteBufferSlice{ slice: [u8(1), 1, 2, 3, 5, 8, 13] })
		}
		callback: kqueue_test_send
	}
	loop.add(c_send)

	// Receive
	mut recv_buf := []u8{len: 128}
	mut recv_len := uint(0)
	mut c_recv := &KqueueCompletion{
		op: KqueueRecvOp{
			fd: server_conn
			buffer: KqueueReadBuffer(ReadBufferSlice{ slice: recv_buf })
		}
		userdata: &recv_len
		callback: kqueue_test_recv
	}
	loop.add(c_recv)

	// Wait for the send/receive
	loop.run(.until_done)!
	assert (c_send.op as KqueueSendOp).buffer.slice == recv_buf[..int(recv_len)]

	// Shutdown
	mut shutdown := false
	mut c_client_shutdown := &KqueueCompletion{
		op: KqueueShutdownOp{
			socket: client_conn
		}
		userdata: &shutdown
		callback: kqueue_test_ok_set_bool
	}
	loop.add(c_client_shutdown)
	loop.run(.until_done)!
	assert shutdown

	// Read should be EOF
	mut eof := KqueueTestEof{}
	unsafe {
		*c_recv = KqueueCompletion{
			op: KqueueRecvOp{
				fd: server_conn
				buffer: KqueueReadBuffer(ReadBufferSlice{ slice: recv_buf })
			}
			userdata: &eof
			callback: kqueue_test_recv_eof
		}
	}
	loop.add(c_recv)

	loop.run(.until_done)!
	assert eof.value? == true

	// Close
	mut c_client_close := &KqueueCompletion{
		op: KqueueCloseOp{
			fd: client_conn
		}
		userdata: &client_conn
		callback: kqueue_test_close_zero
	}
	loop.add(c_client_close)

	mut c_server_close := &KqueueCompletion{
		op: KqueueCloseOp{
			fd: ln
		}
		userdata: &ln
		callback: kqueue_test_close_zero
	}
	loop.add(c_server_close)

	// Wait for the sockets to close
	loop.run(.until_done)!
	assert ln == 0
	assert client_conn == 0
}

fn C.fsync(fd int) int

fn test_kqueue_file_io_on_thread_pool() ! {
	mut tpool := ThreadPool.init()
	defer {
		tpool.deinit()
	}
	defer {
		tpool.shutdown()
	}
	mut loop := KqueueLoop.init(Options{ thread_pool: &tpool })!
	defer {
		loop.deinit()
	}

	// Create our file
	path := 'test_watcher_file'
	mut f := os.open_file(path, 'w+')!
	defer {
		f.close()
	}
	defer {
		os.rm(path) or {}
	}

	// Perform a write and then a read
	write_buf := [u8(1), 1, 2, 3, 5, 8, 13]
	mut c_write := &KqueueCompletion{
		op: KqueueWriteOp{
			fd: f.fd
			buffer: KqueueWriteBuffer(WriteBufferSlice{ slice: write_buf })
		}
		callback: kqueue_test_send
	}
	c_write.flags.set_threadpool(true)
	loop.add(c_write)

	// Wait for the write
	loop.run(.until_done)!

	// Make sure the data is on disk
	assert C.fsync(f.fd) == 0

	mut f2 := os.open(path)!
	defer {
		f2.close()
	}

	// Read
	mut read_buf := []u8{len: 128}
	mut read_len := uint(0)
	mut c_read := &KqueueCompletion{
		op: KqueueReadOp{
			fd: f2.fd
			buffer: KqueueReadBuffer(ReadBufferSlice{ slice: read_buf })
		}
		userdata: &read_len
		callback: kqueue_test_read
	}
	c_read.flags.set_threadpool(true)
	loop.add(c_read)

	// Wait for the send/receive
	loop.run(.until_done)!
	assert write_buf == read_buf[..read_len]
}

// std.c.mach_port_deallocate(task, name). vlib's runtime module declares the
// C function with opaque task_t/host_t parameters, which are mach port names.
fn kqueue_test_mach_port_deallocate(task u32, name u32) i32 {
	return C.mach_port_deallocate(unsafe { *(&C.task_t(voidptr(&task))) }, unsafe { *(&C.host_t(voidptr(&name))) })
}

fn test_kqueue_mach_port() ! {
	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Allocate the port
	mach_self := mach_task_self()
	mut mach_port := u32(0)
	assert KernE.success == get_kern_error(C.mach_port_allocate(mach_self, u32(C.MACH_PORT_RIGHT_RECEIVE),
		&mach_port))
	defer {
		_ = kqueue_test_mach_port_deallocate(mach_self, mach_port)
	}

	// Add the waiter
	mut called := false
	mut c_wait := &KqueueCompletion{
		op: KqueueMachPortOp{
			port: mach_port
			buffer: KqueueReadBuffer(ReadBufferArray{})
		}
		userdata: &called
		callback: kqueue_test_ok_set_bool
	}
	loop.add(c_wait)

	// Tick so we submit... should not call since we never sent.
	loop.run(.no_wait)!
	assert !called

	// Send a message to the port
	mut msg := MachMsgHeader{
		msgh_bits: u32(C.MACH_MSG_TYPE_MAKE_SEND_ONCE)
		msgh_size: u32(sizeof(MachMsgHeader))
		msgh_remote_port: mach_port
		msgh_local_port: mach_port_null
	}
	assert MachMsgE.success == get_mach_msg_error(mach_msg(&msg, i32(mach_send_msg), msg.msgh_size,
		0, mach_port_null, mach_msg_timeout_none, mach_port_null))

	// We should receive now!
	loop.run(.until_done)!
	assert called

	// We should not receive again
	called = false
	loop.add(c_wait)

	// Tick so we submit... should not call since we never sent.
	loop.run(.no_wait)!
	assert !called
}

fn kqueue_test_accept_canceled(_ voidptr, _ &KqueueLoop, _ &KqueueCompletion, r KqueueResult) CallbackAction {
	if e := r.err {
		if e != .canceled {
			panic('wrong')
		}
	}
	return .disarm
}

fn test_kqueue_socket_accept_cancel_cancellation_should_decrease_active_count() ! {
	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	// Create a TCP server socket
	address := NetAddress.init_ip4([u8(127), 0, 0, 1]!, 3131)
	mut ln := kqueue_test_listener(address)!

	// Accept
	mut server_conn := int(0)
	mut c_accept := &KqueueCompletion{
		op: KqueueAcceptOp{
			socket: ln
		}
		userdata: &server_conn
		callback: kqueue_test_accept_canceled
	}
	loop.add(c_accept)
	loop.run(.no_wait)!
	assert uint(1) == loop.active

	mut cancel_called := false
	mut c_cancel := &KqueueCompletion{
		op: KqueueCancelOp{
			c: c_accept
		}
		userdata: &cancel_called
		callback: kqueue_test_cancel_done
	}
	loop.add(c_cancel)

	assert uint(2) == loop.active
	loop.run(.once)!
	assert cancel_called

	// Both callbacks are called active count should be 0
	assert uint(0) == loop.active

	mut c_server_close := &KqueueCompletion{
		op: KqueueCloseOp{
			fd: ln
		}
		userdata: &ln
		callback: kqueue_test_close_zero
	}
	loop.add(c_server_close)

	// Wait for the sockets to close
	loop.run(.until_done)!
	assert ln == 0
}
