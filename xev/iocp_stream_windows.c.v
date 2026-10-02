module xev

// V translation of libxev's src/watcher/stream.zig for the IOCP backend
// (pinned 34fa508): the Shared write-queue types, the Closeable, Readable,
// and Writeable stream mixins, and GenericStream. Polling is a compile error
// in the source for IOCP, so no polling operation is exported.

// WriteQueue is the queue of write requests for ordered writes.
// This can be copied around.
pub type IocpWriteQueue = IntrusiveQueue[IocpWriteRequest]

// WriteRequest is a single request for a write. It wraps a
// completion so that it can be inserted into the WriteQueue.
@[heap]
pub struct IocpWriteRequest {
pub mut:
	completion IocpCompletion
	userdata   voidptr = unsafe { nil }

	// This is the original buffer passed to queueWrite. We have
	// to keep track of this because we may be forced to split
	// the write or rearm the write due to partial writes, but when
	// we call the final callback we want to pass the original
	// complete buffer.
	full_write_buffer IocpWriteBuffer

	next &IocpWriteRequest = unsafe { nil }
}

// This can be used to convert a completion pointer back to
// a WriteRequest. This is only safe of course if the completion
// originally is from a write request. This is useful for getting
// the WriteRequest back in a callback from queuedWrite.
pub fn IocpWriteRequest.from(c &IocpCompletion) &IocpWriteRequest {
	return unsafe { &IocpWriteRequest(voidptr(usize(c) - __offsetof(IocpWriteRequest, completion))) }
}

// Events that can be polled for using the high level streams.
pub enum IocpPollEvent as u32 {
	read = 0 // doesn't matter
}

// The callback of Stream.close. The error is a CloseError.
pub type IocpStreamCloseCallback = fn (ud voidptr, l &IocpLoop, c &IocpCompletion, s IocpStream, r ?ErrorKind) CallbackAction

// The callback of Stream.read. The error is a ReadError; on success the byte
// count is supplied.
pub type IocpStreamReadCallback = fn (ud voidptr, l &IocpLoop, c &IocpCompletion, s IocpStream, b IocpReadBuffer, r ?ErrorKind, n usize) CallbackAction

// The callback of Stream.write and Stream.queueWrite. The error is a
// WriteError; on success the byte count is supplied.
pub type IocpStreamWriteCallback = fn (ud voidptr, l &IocpLoop, c &IocpCompletion, s IocpStream, b IocpWriteBuffer, r ?ErrorKind, n usize) CallbackAction

// Creates a generic stream type that supports read, write, close. This
// can be used for any file descriptor that would exhibit normal blocking
// behavior on read/write. This should NOT be used for local files because
// local files have some special properties; you should use xev.File for that.
pub struct IocpStream {
pub mut:
	// The underlying file
	fd voidptr
}

// Initialize a generic stream from a file descriptor.
pub fn IocpStream.init_fd(fd voidptr) IocpStream {
	return IocpStream{
		fd: fd
	}
}

// Clean up any watcher resources. This does NOT close the file.
// If you want to close the file you must call close or do so
// synchronously.
pub fn (self &IocpStream) deinit() {
	_ = self
}

// Close the socket.
pub fn (self IocpStream) close(mut loop IocpLoop, c &IocpCompletion, userdata voidptr, cb IocpStreamCloseCallback) {
	mut completion := unsafe { c }
	unsafe {
		*completion = IocpCompletion{
			op:       IocpCloseOp{
				fd: self.fd
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &IocpLoop, c_inner &IocpCompletion, r IocpResult) CallbackAction {
				fd := IocpStream.init_fd((c_inner.op as IocpCloseOp).fd)
				return cb(ud, l_inner, c_inner, fd, r.err)
			}
		}
	}

	// If we're dup-ing, then we ask the backend to manage the fd.

	loop.add(completion)
}

// Read from the socket. This performs a single read. The callback must
// requeue the read if additional reads want to be performed. Additional
// reads simultaneously can be queued by calling this multiple times. Note
// that depending on the backend, the reads can happen out of order.
pub fn (self IocpStream) read(mut loop IocpLoop, c &IocpCompletion, buf IocpReadBuffer, userdata voidptr, cb IocpStreamReadCallback) {
	mut completion := unsafe { c }
	unsafe {
		*completion = IocpCompletion{
			op:       IocpReadOp{
				fd:     self.fd
				buffer: buf
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &IocpLoop, c_inner &IocpCompletion, r IocpResult) CallbackAction {
				return cb(ud, l_inner, c_inner, IocpStream.init_fd((c_inner.op as IocpReadOp).fd), (c_inner.op as IocpReadOp).buffer,
					r.err, iocp_result_bytes(r))
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
pub fn (self IocpStream) queue_write(mut loop IocpLoop, q &IocpWriteQueue, req &IocpWriteRequest, buf IocpWriteBuffer, userdata voidptr, cb IocpStreamWriteCallback) {
	mut request := unsafe { req }
	mut write_queue := unsafe { q }

	// Initialize our completion
	unsafe {
		*request = IocpWriteRequest{
			full_write_buffer: buf
		}
	}
	// Must be kept in sync with partial write logic inside the callback
	self.write_init(&request.completion, buf)
	request.completion.userdata = voidptr(write_queue)
	request.completion.callback = fn [cb] (ud voidptr, l_inner &IocpLoop, c_inner &IocpCompletion, r IocpResult) CallbackAction {
		mut q_inner := unsafe { &IocpWriteQueue(ud) }
		mut loop_inner := unsafe { l_inner }

		// The queue MUST have a request because a completion
		// can only be added if the queue is not empty, and
		// nothing else should be popping!.
		//
		// We only peek the request here (not pop) because we may
		// need to rearm this write if the write was partial.
		mut req_inner := q_inner.head
		assert !isnil(req_inner)

		writer, cb_buf, cb_err, cb_n := iocp_stream_write_result(c_inner, r)
		mut result_err := cb_err
		mut result_n := cb_n

		// Checks whether the entire buffer was written, this is
		// necessary to guarantee correct ordering of writes.
		// If the write was partial, it re-submits the remainder of
		// the buffer.
		queued_len := iocp_write_buffer_length(cb_buf)
		if cb_err == none {
			written_len := cb_n
			if written_len < queued_len {
				// Write remainder of the buffer, reusing the same completion.
				// V closures cannot name themselves, so the running
				// callback is read back from the completion before
				// writeInit resets it.
				callback := c_inner.callback
				rem_buf := iocp_write_buffer_remainder(cb_buf, written_len)
				writer.write_init(&req_inner.completion, rem_buf)
				req_inner.completion.userdata = voidptr(q_inner)
				req_inner.completion.callback = callback
				loop_inner.add(&req_inner.completion)
				return .disarm
			}

			// We wrote the entire buffer, modify the result to indicate
			// to the caller that all bytes have been written.
			result_n = iocp_write_buffer_length(req_inner.full_write_buffer)
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
pub fn (self IocpStream) write(mut loop IocpLoop, c &IocpCompletion, buf IocpWriteBuffer, userdata voidptr, cb IocpStreamWriteCallback) {
	mut completion := unsafe { c }
	self.write_init(completion, buf)
	completion.userdata = userdata
	completion.callback = fn [cb] (ud voidptr, l_inner &IocpLoop, c_inner &IocpCompletion, r IocpResult) CallbackAction {
		writer, b, err, n := iocp_stream_write_result(c_inner, r)
		return cb(ud, l_inner, c_inner, writer, b, err, n)
	}

	loop.add(completion)
}

// Extracts the result from a completion for a write callback.
@[inline]
fn iocp_stream_write_result(c &IocpCompletion, r IocpResult) (IocpStream, IocpWriteBuffer, ?ErrorKind, usize) {
	return IocpStream.init_fd((c.op as IocpWriteOp).fd), (c.op as IocpWriteOp).buffer, r.err, iocp_result_bytes(r)
}

// Initialize the completion c for a write. This does NOT set
// userdata or a callback.
pub fn (self IocpStream) write_init(c &IocpCompletion, buf IocpWriteBuffer) {
	mut completion := unsafe { c }
	unsafe {
		*completion = IocpCompletion{
			op: IocpWriteOp{
				fd:     self.fd
				buffer: buf
			}
		}
	}

	// If we're dup-ing, then we ask the backend to manage the fd.
	// GenericStream does not use the thread pool.
}

// Returns the length of the write buffer
fn iocp_write_buffer_length(buf IocpWriteBuffer) usize {
	return match buf {
		WriteBufferSlice { usize(buf.slice.len) }
		WriteBufferArray { buf.len }
	}
}

// Given a `WriteBuffer` and number of bytes written during the previous
// write operation, returns a new `WriteBuffer` with remaining data.
fn iocp_write_buffer_remainder(buf IocpWriteBuffer, offset usize) IocpWriteBuffer {
	match buf {
		WriteBufferSlice {
			assert offset <= usize(buf.slice.len)
			return IocpWriteBuffer(WriteBufferSlice{ slice: buf.slice[int(offset)..] })
		}
		WriteBufferArray {
			assert offset <= buf.len
			rem_len := buf.len - offset
			mut wb := WriteBufferArray{
				len: rem_len
			}
			for i in 0 .. int(rem_len) {
				wb.array[i] = buf.array[int(offset) + i]
			}
			return IocpWriteBuffer(wb)
		}
	}
}
