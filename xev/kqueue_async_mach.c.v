module xev

$if macos || ios {
	// "Wake up" an event loop from any thread using an async completion.
	//
	// V translation of libxev's src/watcher/async.zig AsyncMachPort, the Async
	// implementation of the kqueue backend on Darwin (pinned 34fa508).

	type C.ipc_space_t = u32
	type C.kern_return_t = i32

	fn C.mach_port_allocate(task u32, right u32, name &u32) i32
	fn C.mach_port_insert_right(task u32, name u32, poly u32, poly_poly u32) i32

	// Missing Mach APIs from Zig stdlib. Data from xnu: osfmk/mach/port.h
	struct MachPortLimits {
	mut:
		mpl_qlimit u32
	}

	const mach_port_limits_info = 1

	fn C.mach_port_set_attributes(task u32, name u32, flavor int, info voidptr, count u32) i32
	fn C.mach_port_destroy(task u32, name u32) i32

	// Watcher callbacks. Zig generates a callback per comptime Userdata type and
	// function; V passes the caller's untyped userdata pointer and captures the
	// watcher callback in a closure. The error is the watcher's error set member,
	// if any.
	pub type KqueueWatcherCallback = fn (ud voidptr, l &KqueueLoop, c &KqueueCompletion, r ?ErrorKind) CallbackAction

	// Async implementation using mach ports (Darwin).
	//
	// This allocates a mach port per async request and sends to that mach
	// port to wake up the loop and trigger the completion.
	pub struct KqueueAsync {
	pub mut:
		// The mach port
		port u32
	}

	// Create a new async. An async can be assigned to exactly one loop
	// to be woken up. The completion must be allocated in advance.
	pub fn KqueueAsync.init() !KqueueAsync {
		mach_self := mach_task_self()

		// Allocate the port
		mut mach_port := u32(0)
		match get_kern_error(C.mach_port_allocate(mach_self, u32(C.MACH_PORT_RIGHT_RECEIVE),
			&mach_port)) {
			.success {} // Success
			else {
				return new_error(.mach_port_alloc_failed)
			}
		}

		// Insert a send right into the port since we also use this to send
		match get_kern_error(C.mach_port_insert_right(mach_self, mach_port, mach_port,
			u32(C.MACH_MSG_TYPE_MAKE_SEND))) {
			.success {} // Success
			else {
				_ = C.mach_port_destroy(mach_self, mach_port)
				return new_error(.mach_port_alloc_failed)
			}
		}

		// Modify the port queue size to be 1 because we are only
		// using it for notifications and not for any other purpose.
		mut limits := MachPortLimits{
			mpl_qlimit: 1
		}
		match get_kern_error(C.mach_port_set_attributes(mach_self, mach_port,
			mach_port_limits_info, &limits, u32(sizeof(MachPortLimits)))) {
			.success {} // Success
			else {
				_ = C.mach_port_destroy(mach_self, mach_port)
				return new_error(.mach_port_alloc_failed)
			}
		}

		return KqueueAsync{
			port: mach_port
		}
	}

	// Clean up the async. This will forcibly deinitialize any resources
	// and may result in erroneous wait callbacks to be fired.
	pub fn (mut self KqueueAsync) deinit() {
		_ = C.mach_port_destroy(mach_task_self(), self.port)
	}

	// Wait for a message on this async. The callback error is a MachPortError.
	// Note that async messages may be
	// coalesced (or they may not be) so you should not expect a 1:1 mapping
	// between send and wait.
	//
	// Just like the rest of libxev, the wait must be re-queued if you want
	// to continue to be notified of async events.
	//
	// You should NOT register an async with multiple loops (the same loop
	// is fine -- but unnecessary). The behavior when waiting on multiple
	// loops is undefined.
	pub fn (self &KqueueAsync) wait(mut loop KqueueLoop, c &KqueueCompletion, userdata voidptr, cb KqueueWatcherCallback) {
		mut completion := unsafe { c }
		unsafe {
			*completion = KqueueCompletion{
				op:       KqueueMachPortOp{
					port:   self.port
					buffer: KqueueReadBuffer(ReadBufferArray{})
				}
				userdata: userdata
				callback: fn [cb] (ud voidptr, l_inner &KqueueLoop, c_inner &KqueueCompletion, r KqueueResult) CallbackAction {
					// Drain the mach port so that we only fire one
					// notification even if many are queued.
					kqueue_async_drain((c_inner.op as KqueueMachPortOp).port)

					return cb(ud, l_inner, c_inner, r.err)
				}
			}
		}
		loop.add(completion)
	}

	// Drain the given mach port. All message bodies are discarded.
	fn kqueue_async_drain(port u32) {
		mut message := MachMsgHeader{}

		for {
			e := get_mach_msg_error(mach_msg(&message, i32(mach_rcv_msg | mach_rcv_timeout), 0,
				u32(sizeof(MachMsgHeader)), port, mach_msg_timeout_none, mach_port_null))
			match e {
				// This means a read would've blocked, so we drained.
				.rcv_timed_out {
					return
				}
				// We dequeued, so we want to loop again.
				.success {}
				// We dequeued but the message had a body. We ignore
				// message bodies for async so we are happy to discard
				// it and continue.
				.rcv_too_large {}
				else {
					eprintln('mach msg drain err, may duplicate async wakeups err=${e}')
					return
				}
			}
		}
	}

	// Notify a loop to wake up synchronously. This should never block forever
	// (it will always EVENTUALLY succeed regardless of if the loop is currently
	// ticking or not).
	pub fn (self &KqueueAsync) notify() ! {
		// This constructs an empty mach message. It has no data.
		mut msg := MachMsgHeader{
			// We use COPY_SEND which will not increment any send ref
			// counts because it'll reuse the existing send right.
			msgh_bits:        u32(C.MACH_MSG_TYPE_COPY_SEND)
			msgh_size:        u32(sizeof(MachMsgHeader))
			msgh_remote_port: self.port
			msgh_local_port:  mach_port_null
		}

		e := get_mach_msg_error(mach_msg(&msg, i32(mach_send_msg | mach_send_timeout),
			msg.msgh_size, 0, mach_port_null, 0, mach_port_null))
		match e {
			.success {}
			// This is okay because it means that there was no more buffer
			// space meaning that the port will wake up.
			.send_no_buffer {}
			// This means that the send would've blocked because the
			// queue is full. We assume success because the port is full.
			.send_timed_out {}
			else {
				eprintln('mach msg err=${e}')
				return new_error(.mach_msg_failed)
			}
		}
	}
}
