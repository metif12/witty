module xev

// V translation of libxev's src/watcher/stream.zig for the io_uring backend
// (pinned 34fa508): the Shared write-queue types, the Closeable, Pollable,
// Readable, and Writeable stream mixins, and GenericStream, which enables all
// four with the `read`/`write` methods and no thread pool.

// WriteQueue is the queue of write requests for ordered writes.
// This can be copied around.
pub type IoUringWriteQueue = IntrusiveQueue[IoUringWriteRequest]

// WriteRequest is a single request for a write. It wraps a
// completion so that it can be inserted into the WriteQueue.
@[heap]
pub struct IoUringWriteRequest {
pub mut:
	completion IoUringCompletion
	userdata   voidptr = unsafe { nil }

	// This is the original buffer passed to queueWrite. We have
	// to keep track of this because we may be forced to split
	// the write or rearm the write due to partial writes, but when
	// we call the final callback we want to pass the original
	// complete buffer.
	full_write_buffer IoUringWriteBuffer

	next &IoUringWriteRequest = unsafe { nil }
}

// This can be used to convert a completion pointer back to
// a WriteRequest. This is only safe of course if the completion
// originally is from a write request. This is useful for getting
// the WriteRequest back in a callback from queuedWrite.
pub fn IoUringWriteRequest.from(c &IoUringCompletion) &IoUringWriteRequest {
	return unsafe { &IoUringWriteRequest(voidptr(usize(c) - __offsetof(IoUringWriteRequest, completion))) }
}

// Errors that can be returned from polling are xev.Sys.PollError for io_uring.

// Events that can be polled for using the high level streams.
pub enum IoUringPollEvent as u32 {
	read = 0x001 // std.posix.POLL.IN
}

// PollEvent.fromResult. The event is only meaningful when there is no error.
fn io_uring_poll_event_from_result(c &IoUringCompletion, result IoUringResult) (?ErrorKind, IoUringPollEvent) {
	if err := result.err {
		return err, IoUringPollEvent.read
	}
	return none, unsafe { IoUringPollEvent((c.op as IoUringPollOp).events) }
}

// The callback of Stream.close. The error is a CloseError.
pub type IoUringStreamCloseCallback = fn (ud voidptr, l &IoUringLoop, c &IoUringCompletion, s IoUringStream, r ?ErrorKind) CallbackAction

// The callback of Stream.poll. The error is a PollError.
pub type IoUringStreamPollCallback = fn (ud voidptr, l &IoUringLoop, c &IoUringCompletion, s IoUringStream, r ?ErrorKind, event IoUringPollEvent) CallbackAction

// The callback of Stream.read. The error is a ReadError; on success the byte
// count is supplied.
pub type IoUringStreamReadCallback = fn (ud voidptr, l &IoUringLoop, c &IoUringCompletion, s IoUringStream, b IoUringReadBuffer, r ?ErrorKind, n usize) CallbackAction

// The callback of Stream.write and Stream.queueWrite. The error is a
// WriteError; on success the byte count is supplied.
pub type IoUringStreamWriteCallback = fn (ud voidptr, l &IoUringLoop, c &IoUringCompletion, s IoUringStream, b IoUringWriteBuffer, r ?ErrorKind, n usize) CallbackAction

// Creates a generic stream type that supports read, write, close, poll. This
// can be used for any file descriptor that would exhibit normal blocking
// behavior on read/write. This should NOT be used for local files because
// local files have some special properties; you should use xev.File for that.
pub struct IoUringStream {
pub mut:
	// The underlying file
	fd int
}

// Initialize a generic stream from a file descriptor.
pub fn IoUringStream.init_fd(fd int) IoUringStream {
	return IoUringStream{
		fd: fd
	}
}

// Clean up any watcher resources. This does NOT close the file.
// If you want to close the file you must call close or do so
// synchronously.
pub fn (self &IoUringStream) deinit() {
	_ = self
}

// Close the socket.
pub fn (self IoUringStream) close(mut loop IoUringLoop, c &IoUringCompletion, userdata voidptr, cb IoUringStreamCloseCallback) {
	mut completion := unsafe { c }
	unsafe {
		*completion = IoUringCompletion{
			op: IoUringCloseOp{
				fd: self.fd
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, r IoUringResult) CallbackAction {
				fd := IoUringStream.init_fd((c_inner.op as IoUringCloseOp).fd)
				return cb(ud, l_inner, c_inner, fd, r.err)
			}
		}
	}

	// If we're dup-ing, then we ask the backend to manage the fd.
	// (Nothing to do for io_uring.)

	loop.add(completion)
}

// Poll the file descriptor for the given event. The high-level
// abstraction only allows a single event to be polled at a time.
// If you want to be more efficient for multiple events then you
// should use the lower level interfaces for the xev backend.
pub fn (self IoUringStream) poll(mut loop IoUringLoop, c &IoUringCompletion, event IoUringPollEvent, userdata voidptr, cb IoUringStreamPollCallback) {
	mut completion := unsafe { c }
	unsafe {
		*completion = IoUringCompletion{
			op: IoUringPollOp{
				fd: self.fd
				events: match event {
					.read { linux_poll_in }
				}
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, r IoUringResult) CallbackAction {
				fd := IoUringStream.init_fd((c_inner.op as IoUringPollOp).fd)
				err, poll_event := io_uring_poll_event_from_result(c_inner, r)
				return cb(ud, l_inner, c_inner, fd, err, poll_event)
			}
		}
	}

	loop.add(completion)
}

// Read from the socket. This performs a single read. The callback must
// requeue the read if additional reads want to be performed. Additional
// reads simultaneously can be queued by calling this multiple times. Note
// that depending on the backend, the reads can happen out of order.
pub fn (self IoUringStream) read(mut loop IoUringLoop, c &IoUringCompletion, buf IoUringReadBuffer, userdata voidptr, cb IoUringStreamReadCallback) {
	mut completion := unsafe { c }
	unsafe {
		*completion = IoUringCompletion{
			op: IoUringReadOp{
				fd: self.fd
				buffer: buf
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, r IoUringResult) CallbackAction {
				return cb(ud, l_inner, c_inner, IoUringStream.init_fd((c_inner.op as IoUringReadOp).fd),
					(c_inner.op as IoUringReadOp).buffer, r.err, io_uring_result_bytes(r))
			}
		}
	}

	// If we're dup-ing, then we ask the backend to manage the fd.
	// (Nothing to do for io_uring.)

	loop.add(completion)
}

// Write to the stream. This queues the writes to ensure they
// remain in order. Queueing has a small overhead: you must
// maintain a WriteQueue and WriteRequests instead of just
// Completions.
//
// If ordering isn't important, or you can maintain ordering
// naturally in your program, consider using write since it
// has a slightly smaller overhead.
//
// The "CallbackAction" return value of this callback behaves slightly
// different. The "rearm" return value will re-queue the same write
// at the end of the queue.
//
// It is safe to call this at anytime from the main thread.
pub fn (self IoUringStream) queue_write(mut loop IoUringLoop, q &IoUringWriteQueue, req &IoUringWriteRequest, buf IoUringWriteBuffer, userdata voidptr, cb IoUringStreamWriteCallback) {
	mut request := unsafe { req }
	mut write_queue := unsafe { q }

	// Initialize our completion
	unsafe {
		*request = IoUringWriteRequest{
			full_write_buffer: buf
		}
	}
	// Must be kept in sync with partial write logic inside the callback
	self.write_init(&request.completion, buf)
	request.completion.userdata = voidptr(write_queue)
	request.completion.callback = fn [cb] (ud voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, r IoUringResult) CallbackAction {
		mut q_inner := unsafe { &IoUringWriteQueue(ud) }
		mut loop_inner := unsafe { l_inner }

		// The queue MUST have a request because a completion
		// can only be added if the queue is not empty, and
		// nothing else should be popping!.
		//
		// We only peek the request here (not pop) because we may
		// need to rearm this write if the write was partial.
		mut req_inner := q_inner.head
		assert !isnil(req_inner)

		writer, cb_buf, cb_err, cb_n := io_uring_stream_write_result(c_inner, r)
		mut result_err := cb_err
		mut result_n := cb_n

		// Checks whether the entire buffer was written, this is
		// necessary to guarantee correct ordering of writes.
		// If the write was partial, it re-submits the remainder of
		// the buffer.
		queued_len := io_uring_write_buffer_length(cb_buf)
		if cb_err == none {
			written_len := cb_n
			if written_len < queued_len {
				// Write remainder of the buffer, reusing the same completion.
				// V closures cannot name themselves, so the running
				// callback is read back from the completion before
				// writeInit resets it.
				callback := c_inner.callback
				rem_buf := io_uring_write_buffer_remainder(cb_buf, written_len)
				writer.write_init(&req_inner.completion, rem_buf)
				req_inner.completion.userdata = voidptr(q_inner)
				req_inner.completion.callback = callback
				loop_inner.add(&req_inner.completion)
				return .disarm
			}

			// We wrote the entire buffer, modify the result to indicate
			// to the caller that all bytes have been written.
			result_n = io_uring_write_buffer_length(req_inner.full_write_buffer)
			result_err = none
		}

		// We can pop previously peeked request.
		_ = q_inner.pop() or { panic('unreachable') }

		action := cb(req_inner.userdata, l_inner, c_inner, writer, req_inner.full_write_buffer,
			result_err, result_n)

		// Rearm requeues this request, it doesn't return rearm
		// on the actual callback here...
		if action == .rearm {
			q_inner.push(req_inner)
		}

		// If we have another request, add that completion next.
		if !isnil(q_inner.head) {
			mut req_next := q_inner.head
			loop_inner.add(&req_next.completion)
		}

		// We always disarm because the completion in the next
		// request will be used if there is more to queue.
		return .disarm
	}

	// The userdata as to go on the WriteRequest because we need
	// our actual completion userdata to be the WriteQueue so that
	// we can process the queue.
	request.userdata = userdata

	// If the queue is empty, then we add our completion. Otherwise,
	// the previously queued writes will trigger this one.
	if write_queue.empty() {
		loop.add(&request.completion)
	}

	// We always add this item to our queue no matter what
	write_queue.push(request)
}

// Write to the stream. This performs a single write. Additional
// writes can be requested by calling this multiple times.
//
// IMPORTANT: writes are NOT queued. There is no order guarantee
// if this is called multiple times. If ordered writes are important
// (they usually are!) then you should only call write again once
// the previous write callback is called.
//
// If ordering is important, use queueWrite instead.
pub fn (self IoUringStream) write(mut loop IoUringLoop, c &IoUringCompletion, buf IoUringWriteBuffer, userdata voidptr, cb IoUringStreamWriteCallback) {
	mut completion := unsafe { c }
	self.write_init(completion, buf)
	completion.userdata = userdata
	completion.callback = fn [cb] (ud voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, r IoUringResult) CallbackAction {
		writer, b, err, n := io_uring_stream_write_result(c_inner, r)
		return cb(ud, l_inner, c_inner, writer, b, err, n)
	}

	loop.add(completion)
}

// Extracts the result from a completion for a write callback.
@[inline]
fn io_uring_stream_write_result(c &IoUringCompletion, r IoUringResult) (IoUringStream, IoUringWriteBuffer, ?ErrorKind, usize) {
	return IoUringStream.init_fd((c.op as IoUringWriteOp).fd), (c.op as IoUringWriteOp).buffer, r.err, io_uring_result_bytes(r)
}

// Initialize the completion c for a write. This does NOT set
// userdata or a callback.
pub fn (self IoUringStream) write_init(c &IoUringCompletion, buf IoUringWriteBuffer) {
	mut completion := unsafe { c }
	unsafe {
		*completion = IoUringCompletion{
			op: IoUringWriteOp{
				fd: self.fd
				buffer: buf
			}
		}
	}

	// If we're dup-ing, then we ask the backend to manage the fd.
	// (Nothing to do for io_uring.)
}

// Returns the length of the write buffer
fn io_uring_write_buffer_length(buf IoUringWriteBuffer) usize {
	return match buf.kind {
		.slice { usize(buf.slice.len) }
		.array { buf.array_len }
	}
}

// Given a `WriteBuffer` and number of bytes written during the previous
// write operation, returns a new `WriteBuffer` with remaining data.
fn io_uring_write_buffer_remainder(buf IoUringWriteBuffer, offset usize) IoUringWriteBuffer {
	match buf.kind {
		.slice {
			assert offset <= usize(buf.slice.len)
			return IoUringWriteBuffer{
				kind: .slice
				slice: buf.slice[int(offset)..]
			}
		}
		.array {
			assert offset <= buf.array_len
			rem_len := buf.array_len - offset
			mut wb := IoUringWriteBuffer{
				kind: .array
				array_len: rem_len
			}
			for i in 0 .. int(rem_len) {
				wb.array[i] = buf.array[int(offset) + i]
			}
			return wb
		}
	}
}
