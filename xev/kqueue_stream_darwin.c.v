module xev

// V translation of libxev's src/watcher/stream.zig for the kqueue backend
// (pinned 34fa508): the Shared write-queue types, the Closeable, Pollable,
// Readable, and Writeable stream mixins, and GenericStream, which enables all
// four with the `read`/`write` methods and no thread pool.

// WriteQueue is the queue of write requests for ordered writes.
// This can be copied around.
pub type KqueueWriteQueue = IntrusiveQueue[KqueueWriteRequest]

// WriteRequest is a single request for a write. It wraps a
// completion so that it can be inserted into the WriteQueue.
@[heap]
pub struct KqueueWriteRequest {
pub mut:
	completion KqueueCompletion
	userdata   voidptr = unsafe { nil }

	// This is the original buffer passed to queueWrite. We have
	// to keep track of this because we may be forced to split
	// the write or rearm the write due to partial writes, but when
	// we call the final callback we want to pass the original
	// complete buffer.
	full_write_buffer KqueueWriteBuffer

	next &KqueueWriteRequest = unsafe { nil }
}

// This can be used to convert a completion pointer back to
// a WriteRequest. This is only safe of course if the completion
// originally is from a write request. This is useful for getting
// the WriteRequest back in a callback from queuedWrite.
pub fn KqueueWriteRequest.from(c &KqueueCompletion) &KqueueWriteRequest {
	return unsafe { &KqueueWriteRequest(voidptr(usize(c) - __offsetof(KqueueWriteRequest, completion))) }
}

// Events that can be polled for using the high level streams.
pub enum KqueuePollEvent as u32 {
	read = 0 // doesn't matter
}

// Errors that can be returned from polling are ReadErrors for kqueue.
fn kqueue_poll_event_from_result(c &KqueueCompletion, result KqueueResult) (?ErrorKind, KqueuePollEvent) {
	return match c.op.tag() {
		.read, .recv { result.err, KqueuePollEvent.read }
		else { panic('unreachable') }
	}
}

// The callback of Stream.close. The error is a CloseError.
pub type KqueueStreamCloseCallback = fn (ud voidptr, l &KqueueLoop, c &KqueueCompletion, s KqueueStream, r ?ErrorKind) CallbackAction

// The callback of Stream.poll. The error is a PollError.
pub type KqueueStreamPollCallback = fn (ud voidptr, l &KqueueLoop, c &KqueueCompletion, s KqueueStream, r ?ErrorKind, event KqueuePollEvent) CallbackAction

// The callback of Stream.read. The error is a ReadError; on success the byte
// count is supplied.
pub type KqueueStreamReadCallback = fn (ud voidptr, l &KqueueLoop, c &KqueueCompletion, s KqueueStream, b KqueueReadBuffer, r ?ErrorKind, n usize) CallbackAction

// The callback of Stream.write and Stream.queueWrite. The error is a
// WriteError; on success the byte count is supplied.
pub type KqueueStreamWriteCallback = fn (ud voidptr, l &KqueueLoop, c &KqueueCompletion, s KqueueStream, b KqueueWriteBuffer, r ?ErrorKind, n usize) CallbackAction

// Creates a generic stream type that supports read, write, close, poll. This
// can be used for any file descriptor that would exhibit normal blocking
// behavior on read/write. This should NOT be used for local files because
// local files have some special properties; you should use xev.File for that.
pub struct KqueueStream {
pub mut:
	// The underlying file
	fd int
}

// Initialize a generic stream from a file descriptor.
pub fn KqueueStream.init_fd(fd int) KqueueStream {
	return KqueueStream{
		fd: fd
	}
}

// Clean up any watcher resources. This does NOT close the file.
// If you want to close the file you must call close or do so
// synchronously.
pub fn (self &KqueueStream) deinit() {
	_ = self
}

// Close the socket.
pub fn (self KqueueStream) close(mut loop KqueueLoop, c &KqueueCompletion, userdata voidptr, cb KqueueStreamCloseCallback) {
	mut completion := unsafe { c }
	unsafe {
		*completion = KqueueCompletion{
			op: KqueueCloseOp{
				fd: self.fd
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &KqueueLoop, c_inner &KqueueCompletion, r KqueueResult) CallbackAction {
				fd := KqueueStream.init_fd((c_inner.op as KqueueCloseOp).fd)
				return cb(ud, l_inner, c_inner, fd, r.err)
			}
		}
	}

	// If we're dup-ing, then we ask the backend to manage the fd.
	completion.flags.set_threadpool(true)

	loop.add(completion)
}

// Poll the file descriptor for the given event. The high-level
// abstraction only allows a single event to be polled at a time.
// If you want to be more efficient for multiple events then you
// should use the lower level interfaces for the xev backend.
pub fn (self KqueueStream) poll(mut loop KqueueLoop, c &KqueueCompletion, event KqueuePollEvent, userdata voidptr, cb KqueueStreamPollCallback) {
	_ = event
	mut completion := unsafe { c }
	unsafe {
		*completion = KqueueCompletion{
			op: KqueueReadOp{
				fd: self.fd
				buffer: KqueueReadBuffer{
					kind: .slice
					slice: []u8{}
				}
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &KqueueLoop, c_inner &KqueueCompletion, r KqueueResult) CallbackAction {
				fd := KqueueStream.init_fd((c_inner.op as KqueueReadOp).fd)
				err, poll_event := kqueue_poll_event_from_result(c_inner, r)
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
pub fn (self KqueueStream) read(mut loop KqueueLoop, c &KqueueCompletion, buf KqueueReadBuffer, userdata voidptr, cb KqueueStreamReadCallback) {
	mut completion := unsafe { c }
	unsafe {
		*completion = KqueueCompletion{
			op: KqueueReadOp{
				fd: self.fd
				buffer: buf
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &KqueueLoop, c_inner &KqueueCompletion, r KqueueResult) CallbackAction {
				return cb(ud, l_inner, c_inner, KqueueStream.init_fd((c_inner.op as KqueueReadOp).fd), (c_inner.op as KqueueReadOp).buffer,
					r.err, kqueue_result_bytes(r))
			}
		}
	}

	// If we're dup-ing, then we ask the backend to manage the fd. If we're
	// not reading any actual data, we don't need a threadpool since only
	// read() is blocking. GenericStream does not use the thread pool.

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
pub fn (self KqueueStream) queue_write(mut loop KqueueLoop, q &KqueueWriteQueue, req &KqueueWriteRequest, buf KqueueWriteBuffer, userdata voidptr, cb KqueueStreamWriteCallback) {
	mut request := unsafe { req }
	mut write_queue := unsafe { q }

	// Initialize our completion
	unsafe {
		*request = KqueueWriteRequest{
			full_write_buffer: buf
		}
	}
	// Must be kept in sync with partial write logic inside the callback
	self.write_init(&request.completion, buf)
	request.completion.userdata = voidptr(write_queue)
	request.completion.callback = fn [cb] (ud voidptr, l_inner &KqueueLoop, c_inner &KqueueCompletion, r KqueueResult) CallbackAction {
		mut q_inner := unsafe { &KqueueWriteQueue(ud) }
		mut loop_inner := unsafe { l_inner }

		// The queue MUST have a request because a completion
		// can only be added if the queue is not empty, and
		// nothing else should be popping!.
		//
		// We only peek the request here (not pop) because we may
		// need to rearm this write if the write was partial.
		mut req_inner := q_inner.head
		assert !isnil(req_inner)

		writer, cb_buf, cb_err, cb_n := kqueue_stream_write_result(c_inner, r)
		mut result_err := cb_err
		mut result_n := cb_n

		// Checks whether the entire buffer was written, this is
		// necessary to guarantee correct ordering of writes.
		// If the write was partial, it re-submits the remainder of
		// the buffer.
		queued_len := kqueue_write_buffer_length(cb_buf)
		if cb_err == none {
			written_len := cb_n
			if written_len < queued_len {
				// Write remainder of the buffer, reusing the same completion.
				// V closures cannot name themselves, so the running
				// callback is read back from the completion before
				// writeInit resets it.
				callback := c_inner.callback
				rem_buf := kqueue_write_buffer_remainder(cb_buf, written_len)
				writer.write_init(&req_inner.completion, rem_buf)
				req_inner.completion.userdata = voidptr(q_inner)
				req_inner.completion.callback = callback
				loop_inner.add(&req_inner.completion)
				return .disarm
			}

			// We wrote the entire buffer, modify the result to indicate
			// to the caller that all bytes have been written.
			result_n = kqueue_write_buffer_length(req_inner.full_write_buffer)
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
pub fn (self KqueueStream) write(mut loop KqueueLoop, c &KqueueCompletion, buf KqueueWriteBuffer, userdata voidptr, cb KqueueStreamWriteCallback) {
	mut completion := unsafe { c }
	self.write_init(completion, buf)
	completion.userdata = userdata
	completion.callback = fn [cb] (ud voidptr, l_inner &KqueueLoop, c_inner &KqueueCompletion, r KqueueResult) CallbackAction {
		writer, b, err, n := kqueue_stream_write_result(c_inner, r)
		return cb(ud, l_inner, c_inner, writer, b, err, n)
	}

	loop.add(completion)
}

// Extracts the result from a completion for a write callback.
@[inline]
fn kqueue_stream_write_result(c &KqueueCompletion, r KqueueResult) (KqueueStream, KqueueWriteBuffer, ?ErrorKind, usize) {
	return KqueueStream.init_fd((c.op as KqueueWriteOp).fd), (c.op as KqueueWriteOp).buffer, r.err, kqueue_result_bytes(r)
}

// Initialize the completion c for a write. This does NOT set
// userdata or a callback.
pub fn (self KqueueStream) write_init(c &KqueueCompletion, buf KqueueWriteBuffer) {
	mut completion := unsafe { c }
	unsafe {
		*completion = KqueueCompletion{
			op: KqueueWriteOp{
				fd: self.fd
				buffer: buf
			}
		}
	}

	// If we're dup-ing, then we ask the backend to manage the fd.
	// GenericStream does not use the thread pool.
}

// Returns the length of the write buffer
fn kqueue_write_buffer_length(buf KqueueWriteBuffer) usize {
	return match buf.kind {
		.slice { usize(buf.slice.len) }
		.array { buf.array_len }
	}
}

// Given a `WriteBuffer` and number of bytes written during the previous
// write operation, returns a new `WriteBuffer` with remaining data.
fn kqueue_write_buffer_remainder(buf KqueueWriteBuffer, offset usize) KqueueWriteBuffer {
	match buf.kind {
		.slice {
			assert offset <= usize(buf.slice.len)
			return KqueueWriteBuffer{
				kind: .slice
				slice: buf.slice[int(offset)..]
			}
		}
		.array {
			assert offset <= buf.array_len
			rem_len := buf.array_len - offset
			mut wb := KqueueWriteBuffer{
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
