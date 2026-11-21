module xev

$if macos || ios {
	// V translation of libxev's src/darwin.zig (pinned 34fa508): Darwin Mach
	// declarations missing from the Zig standard library.

	#include <mach/mach.h>

	pub const mach_send_msg = u32(0x00000001)
	pub const mach_rcv_msg = u32(0x00000002)
	pub const mach_send_timeout = u32(0x00000010)
	pub const mach_send_override = u32(0x00000020)
	pub const mach_send_interrupt = u32(0x00000040)
	pub const mach_send_notify = u32(0x00000080)
	pub const mach_send_always = u32(0x00010000)
	pub const mach_send_filter_nonfatal = u32(0x00010000)
	pub const mach_send_trailer = u32(0x00020000)
	pub const mach_send_noimportance = u32(0x00040000)
	pub const mach_send_nodenap = mach_send_noimportance
	pub const mach_send_importance = u32(0x00080000)
	pub const mach_send_sync_override = u32(0x00100000)
	pub const mach_send_propagate_qos = u32(0x00200000)
	pub const mach_send_sync_use_thrpri = mach_send_propagate_qos
	pub const mach_send_kernel = u32(0x00400000)
	pub const mach_send_sync_bootstrap_checkin = u32(0x00800000)
	pub const mach_rcv_timeout = u32(0x00000100)
	pub const mach_rcv_notify = u32(0x00000000)
	pub const mach_rcv_interrupt = u32(0x00000400)
	pub const mach_rcv_voucher = u32(0x00000800)
	pub const mach_rcv_overwrite = u32(0x00000000)
	pub const mach_rcv_guarded_desc = u32(0x00001000)
	pub const mach_rcv_sync_wait = u32(0x00004000)
	pub const mach_rcv_sync_peek = u32(0x00008000)
	pub const mach_port_null = u32(0)
	pub const mach_msg_timeout_none = u32(0)

	// The Zig declarations alias C integer types (natural_t, mach_port_t, ...);
	// V uses the equivalent fixed-width integers directly.

	pub struct MachMsgHeader {
	pub mut:
		msgh_bits         u32
		msgh_size         u32
		msgh_remote_port  u32
		msgh_local_port   u32
		msgh_voucher_port u32
		msgh_id           i32
	}

	// Translation of std.c.mach_task_self, which returns the mach_task_self_
	// global. Assigning it to a typed variable declares the C global to V.
	pub fn mach_task_self() u32 {
		mut port := u32(0)
		port = C.mach_task_self_
		return port
	}

	fn C.mach_msg(msg voidptr, option i32, send_size u32, rcv_size u32, rcv_name u32, timeout u32, notify u32) i32

	pub fn mach_msg(msg &MachMsgHeader, option i32, send_size u32, rcv_size u32, rcv_name u32, timeout u32, notify u32) i32 {
		return C.mach_msg(msg, option, send_size, rcv_size, rcv_name, timeout, notify)
	}

	pub fn get_kern_error(err i32) KernE {
		return unsafe { KernE(u32(uint(err))) }
	}

	pub enum KernE as u32 {
		success = 0
		// Specified address is not currently valid
		invalid_address = 1
		// Specified memory is valid, but does not permit the
		// required forms of access.
		protection_failure = 2
		// The address range specified is already in use, or
		// no address range of the size specified could be
		// found.
		no_space = 3
		// The function requested was not applicable to this
		// type of argument, or an argument is invalid
		invalid_argument = 4
		// The function could not be performed.  A catch-all.
		failure = 5
		// A system resource could not be allocated to fulfill
		// this request.  This failure may not be permanent.
		resource_shortage = 6
		// The task in question does not hold receive rights
		// for the port argument.
		not_receiver = 7
		// Bogus access restriction.
		no_access = 8
		// During a page fault, the target address refers to a
		// memory object that has been destroyed.  This
		// failure is permanent.
		memory_failure = 9
		// During a page fault, the memory object indicated
		// that the data could not be returned.  This failure
		// may be temporary; future attempts to access this
		// same data may succeed, as defined by the memory
		// object.
		memory_error = 10
		// The receive right is already a member of the portset.
		already_in_set = 11
		// The receive right is not a member of a port set.
		not_in_set = 12
		// The name already denotes a right in the task.
		name_exists = 13
		// The operation was aborted.  Ipc code will
		// catch this and reflect it as a message error.
		aborted = 14
		// The name doesn't denote a right in the task.
		invalid_name = 15
		// Target task isn't an active task.
		invalid_task = 16
		// The name denotes a right, but not an appropriate right.
		invalid_right = 17
		// A blatant range error.
		invalid_value = 18
		// Operation would overflow limit on user-references.
		urefs_overflow = 19
		// The supplied (port) capability is improper.
		invalid_capability = 20
		// The task already has send or receive rights
		// for the port under another name.
		right_exists = 21
		// Target host isn't actually a host.
		invalid_host = 22
		// An attempt was made to supply "precious" data
		// for memory that is already present in a
		// memory object.
		memory_present = 23
		// A page was requested of a memory manager via
		// memory_object_data_request for an object using
		// a MEMORY_OBJECT_COPY_CALL strategy, with the
		// VM_PROT_WANTS_COPY flag being used to specify
		// that the page desired is for a copy of the
		// object, and the memory manager has detected
		// the page was pushed into a copy of the object
		// while the kernel was walking the shadow chain
		// from the copy to the object. This error code
		// is delivered via memory_object_data_error
		// and is handled by the kernel (it forces the
		// kernel to restart the fault). It will not be
		// seen by users.
		memory_data_moved = 24
		// A strategic copy was attempted of an object
		// upon which a quicker copy is now possible.
		// The caller should retry the copy using
		// vm_object_copy_quickly. This error code
		// is seen only by the kernel.
		memory_restart_copy = 25
		// An argument applied to assert processor set privilege
		// was not a processor set control port.
		invalid_processor_set = 26
		// The specified scheduling attributes exceed the thread's
		// limits.
		policy_limit = 27
		// The specified scheduling policy is not currently
		// enabled for the processor set.
		invalid_policy = 28
		// The external memory manager failed to initialize the
		// memory object.
		invalid_object = 29
		// A thread is attempting to wait for an event for which
		// there is already a waiting thread.
		already_waiting = 30
		// An attempt was made to destroy the default processor
		// set.
		default_set = 31
		// An attempt was made to fetch an exception port that is
		// protected, or to abort a thread while processing a
		// protected exception.
		exception_protected = 32
		// A ledger was required but not supplied.
		invalid_ledger = 33
		// The port was not a memory cache control port.
		invalid_memory_control = 34
		// An argument supplied to assert security privilege
		// was not a host security port.
		invalid_security = 35
		// thread_depress_abort was called on a thread which
		// was not currently depressed.
		not_depressed = 36
		// Object has been terminated and is no longer available
		terminated = 37
		// Lock set has been destroyed and is no longer available.
		lock_set_destroyed = 38
		// The thread holding the lock terminated before releasing
		// the lock
		lock_unstable = 39
		// The lock is already owned by another thread
		lock_owned = 40
		// The lock is already owned by the calling thread
		lock_owned_self = 41
		// Semaphore has been destroyed and is no longer available.
		semaphore_destroyed = 42
		// Return from RPC indicating the target server was
		// terminated before it successfully replied
		rpc_server_terminated = 43
		// Terminate an orphaned activation.
		rpc_terminate_orphan = 44
		// Allow an orphaned activation to continue executing.
		rpc_continue_orphan = 45
		// Empty thread activation (No thread linked to it)
		not_supported = 46
		// Remote node down or inaccessible.
		node_down = 47
		// A signalled thread was not actually waiting.
		not_waiting = 48
		// Some thread-oriented operation (semaphore_wait) timed out
		operation_timed_out = 49
		// During a page fault, indicates that the page was rejected
		// as a result of a signature check.
		codesign_error = 50
		// The requested property cannot be changed at this time.
		policy_static = 51
		// The provided buffer is of insufficient size for the requested data.
		insufficient_buffer_size = 52
		// Denied by security policy
		denied = 53
		// The KC on which the function is operating is missing
		missing_kc = 54
		// The KC on which the function is operating is invalid
		invalid_kc = 55
		// A search or query operation did not return a result
		not_found = 56
	}

	pub fn get_mach_msg_error(err i32) MachMsgE {
		return unsafe { MachMsgE(u32(uint(err))) }
	}

	// Mach msg return values
	pub enum MachMsgE as u32 {
		success = 0x00000000
		// Thread is waiting to send.  (Internal use only.)
		send_in_progress = 0x10000001
		// Bogus in-line data.
		send_invalid_data = 0x10000002
		// Bogus destination port.
		send_invalid_dest = 0x10000003
		//  Message not sent before timeout expired.
		send_timed_out = 0x10000004
		//  Bogus voucher port.
		send_invalid_voucher = 0x10000005
		//  Software interrupt.
		send_interrupted = 0x10000007
		//  Data doesn't contain a complete message.
		send_msg_too_small = 0x10000008
		//  Bogus reply port.
		send_invalid_reply = 0x10000009
		//  Bogus port rights in the message body.
		send_invalid_right = 0x1000000a
		//  Bogus notify port argument.
		send_invalid_notify = 0x1000000b
		//  Invalid out-of-line memory pointer.
		send_invalid_memory = 0x1000000c
		//  No message buffer is available.
		send_no_buffer = 0x1000000d
		//  Send is too large for port
		send_too_large = 0x1000000e
		//  Invalid msg-type specification.
		send_invalid_type = 0x1000000f
		//  A field in the header had a bad value.
		send_invalid_header = 0x10000010
		//  The trailer to be sent does not match kernel format.
		send_invalid_trailer = 0x10000011
		//  The sending thread context did not match the context on the dest port
		send_invalid_context = 0x10000012
		//  compatibility: no longer a returned error
		send_invalid_rt_ool_size = 0x10000015
		//  The destination port doesn't accept ports in body
		send_no_grant_dest = 0x10000016
		//  Message send was rejected by message filter
		send_msg_filtered = 0x10000017
		//  Thread is waiting for receive.  (Internal use only.)
		rcv_in_progress = 0x10004001
		//  Bogus name for receive port/port-set.
		rcv_invalid_name = 0x10004002
		//  Didn't get a message within the timeout value.
		rcv_timed_out = 0x10004003
		//  Message buffer is not large enough for inline data.
		rcv_too_large = 0x10004004
		//  Software interrupt.
		rcv_interrupted = 0x10004005
		//  compatibility: no longer a returned error
		rcv_port_changed = 0x10004006
		//  Bogus notify port argument.
		rcv_invalid_notify = 0x10004007
		//  Bogus message buffer for inline data.
		rcv_invalid_data = 0x10004008
		//  Port/set was sent away/died during receive.
		rcv_port_died = 0x10004009
		//  compatibility: no longer a returned error
		rcv_in_set = 0x1000400a
		//  Error receiving message header.  See special bits.
		rcv_header_error = 0x1000400b
		//  Error receiving message body.  See special bits.
		rcv_body_error = 0x1000400c
		//  Invalid msg-type specification in scatter list.
		rcv_invalid_type = 0x1000400d
		//  Out-of-line overwrite region is not large enough
		rcv_scatter_small = 0x1000400e
		//  trailer type or number of trailer elements not supported
		rcv_invalid_trailer = 0x1000400f
		//  Waiting for receive with timeout. (Internal use only.)
		rcv_in_progress_timed = 0x10004011
		//  invalid reply port used in a STRICT_REPLY message
		rcv_invalid_reply = 0x10004012
	}
}
