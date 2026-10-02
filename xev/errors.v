module xev

// Zig error sets are closed sets of global error names. libxev composes its
// per-operation sets from Zig std.posix sets plus its own names, so the V
// translation keeps a single enum of every error name those sets use. Each
// backend documents which subset an operation can produce.
pub enum ErrorKind {
	// libxev
	eof
	canceled
	missing_kevent
	permission_denied
	unexpected
	thread_pool_required
	thread_pool_unsupported
	no_such_process
	nested_runs_not_allowed
	mach_port_alloc_failed
	mach_msg_failed
	// std.posix.KEventError
	access_denied
	event_not_found
	system_resources
	process_not_found
	overflow
	// std.posix.KQueueError
	process_fd_quota_exceeded
	system_fd_quota_exceeded
	// std.posix.AcceptError
	connection_aborted
	file_descriptor_not_a_socket
	socket_not_listening
	protocol_failure
	blocked_by_firewall
	would_block
	connection_reset_by_peer
	network_subsystem_failed
	operation_not_supported
	// std.posix.ConnectError
	address_in_use
	address_not_available
	address_family_not_supported
	connection_refused
	network_unreachable
	connection_timed_out
	file_not_found
	connection_pending
	// std.posix.ReadError / PReadError
	input_output
	is_dir
	operation_aborted
	broken_pipe
	not_open_for_reading
	socket_not_connected
	lock_violation
	unseekable
	// std.posix.RecvFromError
	socket_not_bound
	message_too_big
	// std.posix.WriteError / PWriteError
	disk_quota
	file_too_big
	no_space_left
	device_busy
	invalid_argument
	not_open_for_writing
	no_device
	// std.posix.SendError / SendMsgError / SendToError
	fast_open_already_in_progress
	sym_link_loop
	name_too_long
	not_dir
	unreachable_address
	// std.posix.ShutdownError
	blocking_operation_in_progress
	// std.posix.ClockGetTimeError
	unsupported_clock
	// std.posix.SocketError
	protocol_family_not_available
	protocol_not_supported
	socket_type_not_supported
	// std.posix.SetSockOptError
	timeout_too_big
	already_connected
	invalid_protocol_option
	// std.posix.BindError
	read_only_file_system
	// libxev epoll backend and watchers
	dup_failed
	unknown
	not_found
	invalid_child
	// libxev linux/timerfd.zig
	unknown_error
	// std.posix.EpollCtlError
	file_descriptor_already_present_in_set
	operation_causes_circular_loop
	file_descriptor_not_registered
	user_resource_limit_reached
	file_descriptor_incompatible_with_epoll
	// libxev io_uring backend and its watchers
	too_many_entries
	again
	expiration_in_progress
	host_unreachable
	timed_out
	// std.os.linux.IoUring init/init_params
	entries_zero
	entries_not_power_of_two
	params_outside_accessible_address_space
	arguments_invalid
	system_outdated
	// std.os.linux.IoUring enter
	file_descriptor_invalid
	file_descriptor_in_bad_state
	completion_queue_overcommitted
	submission_queue_entry_invalid
	buffer_invalid
	ring_shutting_down
	opcode_not_supported
	signal_interrupt
	// std.os.linux.IoUring get_sqe
	submission_queue_full
	// std.posix.MMapError
	memory_mapping_not_supported
	locked_memory_limit_exceeded
	out_of_memory
	mapping_already_exists
	// libxev dynamic API
	invalid_parameter
	already_exists
	batch_full
	invalid_op
	no_available_backends
}

// zig_name returns the Zig error name, as printed by Zig's `{}` formatting of
// an error value.
pub fn (kind ErrorKind) zig_name() string {
	if kind == .eof {
		return 'EOF'
	}
	mut out := []u8{}
	mut upper := true
	for c in kind.str().bytes() {
		if c == `_` {
			upper = true
			continue
		}
		out << if upper && c >= `a` && c <= `z` { c - 32 } else { c }
		upper = false
	}
	return 'error.' + out.bytestr()
}

// XevError carries a Zig error name through V's error handling.
pub struct XevError {
	Error
pub:
	kind ErrorKind
}

pub fn (e XevError) msg() string {
	return e.kind.zig_name()
}

pub fn (e XevError) code() int {
	return int(e.kind)
}

// new_error returns the V error value for the given Zig error name.
pub fn new_error(kind ErrorKind) IError {
	return XevError{
		kind: kind
	}
}

// error_kind returns the Zig error name carried by err. Errors that did not
// originate in xev report `Unexpected`.
pub fn error_kind(err IError) ErrorKind {
	if err is XevError {
		return err.kind
	}
	return .unexpected
}
