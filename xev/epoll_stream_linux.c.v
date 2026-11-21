module xev

// V translation of libxev's src/watcher/stream.zig for the epoll backend
// (pinned 34fa508): the Shared write-queue types, the Closeable, Pollable,
// Readable, and Writeable stream mixins, and GenericStream, which enables all
// four with the `read`/`write` methods and no thread pool.

// WriteQueue is the queue of write requests for ordered writes.
// This can be copied around.
pub type EpollWriteQueue = IntrusiveQueue[EpollWriteRequest]

// WriteRequest is a single request for a write. It wraps a
// completion so that it can be inserted into the WriteQueue.
@[heap]
pub struct EpollWriteRequest {
pub mut:
	completion EpollCompletion
	userdata   voidptr = unsafe { nil }

	// This is the original buffer passed to queueWrite. We have
	// to keep track of this because we may be forced to split
	// the write or rearm the write due to partial writes, but when
	// we call the final callback we want to pass the original
	// complete buffer.
	full_write_buffer EpollWriteBuffer

	next &EpollWriteRequest = unsafe { nil }
}

// This can be used to convert a completion pointer back to
// a WriteRequest. This is only safe of course if the completion
// originally is from a write request. This is useful for getting
// the WriteRequest back in a callback from queuedWrite.
pub fn EpollWriteRequest.from(c &EpollCompletion) &EpollWriteRequest {
	return unsafe { &EpollWriteRequest(voidptr(uint(c) - __offsetof(EpollWriteRequest, completion))) }
}

// Events that can be polled for using the high level streams.
pub enum EpollPollEvent as u32 {
	read = 0x001 // std.os.linux.EPOLL.IN
}

// Errors that can be returned from polling are the backend's PollError for
// epoll.
fn epoll_poll_event_from_result(c &EpollCompletion, result EpollResult) (?ErrorKind, EpollPollEvent) {
	if err := result.err {
		return err, EpollPollEvent.read
	}
	return none, unsafe { EpollPollEvent((c.op as EpollPollOp).events) }
}

// The callback of Stream.close. The error is a CloseError.
pub type EpollStreamCloseCallback = fn (ud voidptr, l &EpollLoop, c &EpollCompletion, s EpollStream, r ?ErrorKind) CallbackAction

// The callback of Stream.poll. The error is a PollError; on success the
// polled event is supplied.
pub type EpollStreamPollCallback = fn (ud voidptr, l &EpollLoop, c &EpollCompletion, s EpollStream, r ?ErrorKind, event EpollPollEvent) CallbackAction

// The callback of Stream.read. The error is a ReadError; on success the byte
// count is supplied.
pub type EpollStreamReadCallback = fn (ud voidptr, l &EpollLoop, c &EpollCompletion, s EpollStream, b EpollReadBuffer, r ?ErrorKind, n uint) CallbackAction

// The callback of Stream.write and Stream.queueWrite. The error is a
// WriteError; on success the byte count is supplied.
pub type EpollStreamWriteCallback = fn (ud voidptr, l &EpollLoop, c &EpollCompletion, s EpollStream, b EpollWriteBuffer, r ?ErrorKind, n uint) CallbackAction

// Creates a generic stream type that supports read, write, close, poll. This
// can be used for any file descriptor that would exhibit normal blocking
// behavior on read/write. This should NOT be used for local files because
// local files have some special properties; you should use xev.File for that.
pub struct EpollStream {
pub mut:
	// The underlying file
	fd int
}

// Initialize a generic stream from a file descriptor.
pub fn EpollStream.init_fd(fd int) EpollStream {
	return EpollStream{
		fd: fd
	}
}

// Clean up any watcher resources. This does NOT close the file.
// If you want to close the file you must call close or do so
// synchronously.
pub fn (self &EpollStream) deinit() {
	_ = self
}

// Close the socket.
pub fn (self EpollStream) close(mut loop EpollLoop, c &EpollCompletion, userdata voidptr, cb EpollStreamCloseCallback) {
	mut completion := unsafe { c }
	unsafe {
		*completion = EpollCompletion{
			op:       EpollCloseOp{
				fd: self.fd
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, r EpollResult) CallbackAction {
				fd := EpollStream.init_fd((c_inner.op as EpollCloseOp).fd)
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
pub fn (self EpollStream) poll(mut loop EpollLoop, c &EpollCompletion, event EpollPollEvent, userdata voidptr, cb EpollStreamPollCallback) {
	mut completion := unsafe { c }
	unsafe {
		*completion = EpollCompletion{
			op:       EpollPollOp{
				fd:     self.fd
				events: match event {
					.read { epoll_in }
				}
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, r EpollResult) CallbackAction {
				fd := EpollStream.init_fd((c_inner.op as EpollPollOp).fd)
				err, poll_event := epoll_poll_event_from_result(c_inner, r)
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
pub fn (self EpollStream) read(mut loop EpollLoop, c &EpollCompletion, buf EpollReadBuffer, userdata voidptr, cb EpollStreamReadCallback) {
	mut completion := unsafe { c }
	unsafe {
		*completion = EpollCompletion{
			op:       EpollReadOp{
				fd:     self.fd
				buffer: buf
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, r EpollResult) CallbackAction {
				return cb(ud, l_inner, c_inner, EpollStream.init_fd((c_inner.op as EpollReadOp).fd), (c_inner.op as EpollReadOp).buffer,
					r.err, epoll_result_bytes(r))
			}
		}
	}

	// If we're dup-ing, then we ask the backend to manage the fd.
	// GenericStream does not use the thread pool.
	completion.flags.set_dup(true)

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
pub fn (self EpollStream) queue_write(mut loop EpollLoop, q &EpollWriteQueue, req &EpollWriteRequest, buf EpollWriteBuffer, userdata voidptr, cb EpollStreamWriteCallback) {
	mut request := unsafe { req }
	mut write_queue := unsafe { q }

	// Initialize our completion
	unsafe {
		*request = EpollWriteRequest{
			full_write_buffer: buf
		}
	}
	// Must be kept in sync with partial write logic inside the callback
	self.write_init(&request.completion, buf)
	request.completion.userdata = voidptr(write_queue)
	request.completion.callback = fn [cb] (ud voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, r EpollResult) CallbackAction {
		mut q_inner := unsafe { &EpollWriteQueue(ud) }
		mut loop_inner := unsafe { l_inner }

		// The queue MUST have a request because a completion
		// can only be added if the queue is not empty, and
		// nothing else should be popping!.
		//
		// We only peek the request here (not pop) because we may
		// need to rearm this write if the write was partial.
		mut req_inner := q_inner.head
		assert !isnil(req_inner)

		writer, cb_buf, cb_err, cb_n := epoll_stream_write_result(c_inner, r)
		mut result_err := cb_err
		mut result_n := cb_n

		// Checks whether the entire buffer was written, this is
		// necessary to guarantee correct ordering of writes.
		// If the write was partial, it re-submits the remainder of
		// the buffer.
		queued_len := epoll_write_buffer_length(cb_buf)
		if cb_err == none {
			written_len := cb_n
			if written_len < queued_len {
				// Write remainder of the buffer, reusing the same completion.
				// V closures cannot name themselves, so the running
				// callback is read back from the completion before
				// writeInit resets it.
				callback := c_inner.callback
				rem_buf := epoll_write_buffer_remainder(cb_buf, written_len)
				writer.write_init(&req_inner.completion, rem_buf)
				req_inner.completion.userdata = voidptr(q_inner)
				req_inner.completion.callback = callback
				loop_inner.add(&req_inner.completion)
				return .disarm
			}

			// We wrote the entire buffer, modify the result to indicate
			// to the caller that all bytes have been written.
			result_n = epoll_write_buffer_length(req_inner.full_write_buffer)
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
pub fn (self EpollStream) write(mut loop EpollLoop, c &EpollCompletion, buf EpollWriteBuffer, userdata voidptr, cb EpollStreamWriteCallback) {
	mut completion := unsafe { c }
	self.write_init(completion, buf)
	completion.userdata = userdata
	completion.callback = fn [cb] (ud voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, r EpollResult) CallbackAction {
		writer, b, err, n := epoll_stream_write_result(c_inner, r)
		return cb(ud, l_inner, c_inner, writer, b, err, n)
	}

	loop.add(completion)
}

// Extracts the result from a completion for a write callback.
@[inline]
fn epoll_stream_write_result(c &EpollCompletion, r EpollResult) (EpollStream, EpollWriteBuffer, ?ErrorKind, uint) {
	return EpollStream.init_fd((c.op as EpollWriteOp).fd), (c.op as EpollWriteOp).buffer, r.err, epoll_result_bytes(r)
}

// Initialize the completion c for a write. This does NOT set
// userdata or a callback.
pub fn (self EpollStream) write_init(c &EpollCompletion, buf EpollWriteBuffer) {
	mut completion := unsafe { c }
	unsafe {
		*completion = EpollCompletion{
			op: EpollWriteOp{
				fd:     self.fd
				buffer: buf
			}
		}
	}

	// If we're dup-ing, then we ask the backend to manage the fd.
	// GenericStream does not use the thread pool.
	completion.flags.set_dup(true)
}

// Returns the length of the write buffer
fn epoll_write_buffer_length(buf EpollWriteBuffer) uint {
	return match buf {
		WriteBufferSlice { uint(buf.slice.len) }
		WriteBufferArray { buf.len }
	}
}

// Given a `WriteBuffer` and number of bytes written during the previous
// write operation, returns a new `WriteBuffer` with remaining data.
fn epoll_write_buffer_remainder(buf EpollWriteBuffer, offset uint) EpollWriteBuffer {
	match buf {
		WriteBufferSlice {
			assert offset <= uint(buf.slice.len)
			return EpollWriteBuffer(WriteBufferSlice{ slice: buf.slice[int(offset)..] })
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
			return EpollWriteBuffer(wb)
		}
	}
}
