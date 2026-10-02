module xev

import log
import sync.stdatomic as _

// Source: libxev 34fa508, src/backend/iocp.zig. The source queues, pairing
// timer heap, OVERLAPPED completions, cancellation, and job-object dispatch
// are translated together. Win32 SDK structures supply the native ABI.
#include <winsock2.h>
#include <mswsock.h>
#include <windows.h>
#flag windows -lws2_32
#flag windows -lmswsock

@[typedef]
pub struct C.OVERLAPPED {
pub mut:
	Internal     usize
	InternalHigh usize
	Offset       u32
	OffsetHigh   u32
	hEvent       voidptr
}

@[typedef]
pub struct C.OVERLAPPED_ENTRY {
pub mut:
	lpCompletionKey            usize
	lpOverlapped               &C.OVERLAPPED
	Internal                   usize
	dwNumberOfBytesTransferred u32
}

@[typedef]
pub struct C.WSABUF {
pub mut:
	len u32
	buf &char = unsafe { nil }
}

@[typedef]
struct C.JOBOBJECT_ASSOCIATE_COMPLETION_PORT {
mut:
	CompletionKey  voidptr
	CompletionPort voidptr
}

fn C.CreateIoCompletionPort(fd voidptr, existing voidptr, key usize, concurrency u32) voidptr
fn C.GetQueuedCompletionStatusEx(port voidptr, entries &C.OVERLAPPED_ENTRY, count u32, removed &u32, timeout u32, alertable int) bool
fn C.PostQueuedCompletionStatus(port voidptr, bytes u32, key usize, overlapped &C.OVERLAPPED) bool
fn C.QueryPerformanceFrequency(frequency &i64) int
fn C.QueryPerformanceCounter(counter &i64) int
fn C.GetLastError() u32
fn C.CloseHandle(handle voidptr) bool
fn C.ReadFile(handle voidptr, buffer voidptr, size u32, count &u32, overlapped voidptr) bool
fn C.WriteFile(handle voidptr, buffer voidptr, size u32, count &u32, overlapped voidptr) bool
fn C.CancelIoEx(handle voidptr, overlapped voidptr) bool
fn C.GetOverlappedResult(handle voidptr, overlapped &C.OVERLAPPED, count &u32, wait int) bool
fn C.SetInformationJobObject(job voidptr, class_ int, info voidptr, size u32) bool
fn C.WSAGetLastError() int
fn C.WSASocketW(af int, type_ int, protocol int, info voidptr, group u32, flags u32) usize
fn C.WSASend(socket usize, buffers &C.WSABUF, count u32, sent &u32, flags u32, overlapped &C.OVERLAPPED, callback voidptr) int
fn C.WSARecv(socket usize, buffers &C.WSABUF, count u32, received &u32, flags &u32, overlapped &C.OVERLAPPED, callback voidptr) int
fn C.WSASendTo(socket usize, buffers &C.WSABUF, count u32, sent &u32, flags u32, addr voidptr, addr_len int, overlapped &C.OVERLAPPED, callback voidptr) int
fn C.WSARecvFrom(socket usize, buffers &C.WSABUF, count u32, received &u32, flags &u32, addr voidptr, addr_len &int, overlapped &C.OVERLAPPED, callback voidptr) int
fn C.WSAGetOverlappedResult(socket usize, overlapped &C.OVERLAPPED, count &u32, wait int, flags &u32) int
fn C.AcceptEx(listener usize, socket usize, output voidptr, data_len u32, local_len u32, remote_len u32, received &u32, overlapped &C.OVERLAPPED) int
fn C.getsockname(socket usize, address voidptr, address_len &int) int
fn C.getsockopt(socket usize, level int, name int, value voidptr, size &int) int
fn C.connect(socket usize, address voidptr, address_len int) int
fn C.shutdown(socket usize, how int) int

pub type IocpCallback = fn (userdata voidptr, loop &IocpLoop, completion &IocpCompletion, result IocpResult) CallbackAction

pub fn iocp_noop_callback(_ voidptr, _ &IocpLoop, _ &IocpCompletion, _ IocpResult) CallbackAction {
	return .disarm
}

pub fn iocp_available() bool { return true }

struct IocpCancelOutcome {
mut:
	err ?ErrorKind
}

pub enum IocpCompletionStateFlag as u8 {
	dead
	adding
	active
}

pub struct IocpCompletionFlags {
pub mut:
	value u8
}

pub fn (f IocpCompletionFlags) state() IocpCompletionStateFlag {
	return unsafe { IocpCompletionStateFlag(f.value & 3) }
}

pub fn (mut f IocpCompletionFlags) set_state(s IocpCompletionStateFlag) { f.value = u8(s) }

pub enum IocpTimerTrigger as u8 {
	request
	expiration
	cancel
}

pub struct IocpJobObjectAssociated {}

pub struct IocpJobObjectMessage {
pub mut:
	type_ u32
	value usize
}

pub type IocpJobObjectValue = IocpJobObjectAssociated | IocpJobObjectMessage
pub type IocpReadBuffer = ReadBufferArray | ReadBufferSlice
pub type IocpWriteBuffer = WriteBufferArray | WriteBufferSlice

fn (self &IocpReadBuffer) slice_ptr() []u8 {
	return match self {
		ReadBufferSlice { self.slice }
		ReadBufferArray { unsafe { (&self.array[0]).vbytes(32) } }
	}
}

fn (self &IocpWriteBuffer) bytes() []u8 {
	return match self {
		WriteBufferSlice { self.slice }
		WriteBufferArray { unsafe { (&self.array[0]).vbytes(int(self.len)) } }
	}
}

pub enum IocpOperationType as u8 {
	noop
	accept
	close
	connect
	read
	pread
	shutdown
	write
	pwrite
	send
	recv
	sendto
	recvfrom
	timer
	cancel
	async_wait
	job_object
}

pub type IocpOperation = IocpNoopOp
	| IocpAcceptOp
	| IocpCloseOp
	| IocpConnectOp
	| IocpReadOp
	| IocpPReadOp
	| IocpShutdownOp
	| IocpWriteOp
	| IocpPWriteOp
	| IocpSendOp
	| IocpRecvOp
	| IocpSendToOp
	| IocpRecvFromOp
	| IocpHeapTimer
	| IocpCancelOp
	| IocpAsyncWaitOp
	| IocpJobObjectOp

pub struct IocpNoopOp {
}

pub struct IocpAcceptOp {
pub mut:
	socket                 voidptr
	storage                [128]u8
	internal_accept_socket ?voidptr
}

pub struct IocpCloseOp {
pub mut:
	fd voidptr
}

pub struct IocpConnectOp {
pub mut:
	socket voidptr
	addr   NetAddress
}

pub struct IocpReadOp {
pub mut:
	fd     voidptr
	buffer IocpReadBuffer
}

pub struct IocpPReadOp {
pub mut:
	fd     voidptr
	buffer IocpReadBuffer
	offset u64
}

pub struct IocpShutdownOp {
pub mut:
	socket voidptr
	how    ShutdownHow = .both
}

pub struct IocpWriteOp {
pub mut:
	fd     voidptr
	buffer IocpWriteBuffer
}

pub struct IocpPWriteOp {
pub mut:
	fd     voidptr
	buffer IocpWriteBuffer
	offset u64
}

pub struct IocpSendOp {
pub mut:
	fd         voidptr
	buffer     IocpWriteBuffer
	wsa_buffer C.WSABUF
}

pub struct IocpRecvOp {
pub mut:
	fd         voidptr
	buffer     IocpReadBuffer
	wsa_buffer C.WSABUF
}

pub struct IocpSendToOp {
pub mut:
	fd         voidptr
	buffer     IocpWriteBuffer
	addr       NetAddress
	wsa_buffer C.WSABUF
}

pub struct IocpRecvFromOp {
pub mut:
	fd         voidptr
	buffer     IocpReadBuffer
	addr       SockAddr
	addr_size  u32 = u32(sizeof(SockAddr))
	wsa_buffer C.WSABUF
}

pub struct IocpHeapTimer {
pub mut:
	next  u64
	reset ?u64
	heap  IntrusiveHeapField[IocpHeapTimer]
	c     &IocpCompletion = unsafe { nil }
}

pub struct IocpCancelOp {
pub mut:
	c &IocpCompletion = unsafe { nil }
}

pub struct IocpAsyncWaitOp {
pub mut:
	wakeup u8
}

pub struct IocpJobObjectOp {
pub mut:
	job        voidptr
	userdata   voidptr
	associated bool
}

pub fn (op IocpOperation) tag() IocpOperationType {
	return match op {
		IocpNoopOp { .noop }
		IocpAcceptOp { .accept }
		IocpCloseOp { .close }
		IocpConnectOp { .connect }
		IocpReadOp { .read }
		IocpPReadOp { .pread }
		IocpShutdownOp { .shutdown }
		IocpWriteOp { .write }
		IocpPWriteOp { .pwrite }
		IocpSendOp { .send }
		IocpRecvOp { .recv }
		IocpSendToOp { .sendto }
		IocpRecvFromOp { .recvfrom }
		IocpHeapTimer { .timer }
		IocpCancelOp { .cancel }
		IocpAsyncWaitOp { .async_wait }
		IocpJobObjectOp { .job_object }
	}
}

pub type IocpResult = IocpNoopResult
	| IocpAcceptResult
	| IocpCloseResult
	| IocpConnectResult
	| IocpReadResult
	| IocpPReadResult
	| IocpShutdownResult
	| IocpWriteResult
	| IocpPWriteResult
	| IocpSendResult
	| IocpRecvResult
	| IocpSendToResult
	| IocpRecvFromResult
	| IocpTimerResult
	| IocpCancelResult
	| IocpAsyncWaitResult
	| IocpJobObjectResult

pub struct IocpNoopResult {
pub mut:
	err ?ErrorKind
}

pub struct IocpAcceptResult {
pub mut:
	err    ?ErrorKind
	socket voidptr
}

pub struct IocpCloseResult {
pub mut:
	err ?ErrorKind
}

pub struct IocpConnectResult {
pub mut:
	err ?ErrorKind
}

pub struct IocpReadResult {
pub mut:
	err ?ErrorKind
	n   usize
}

pub struct IocpPReadResult {
pub mut:
	err ?ErrorKind
	n   usize
}

pub struct IocpShutdownResult {
pub mut:
	err ?ErrorKind
}

pub struct IocpWriteResult {
pub mut:
	err ?ErrorKind
	n   usize
}

pub struct IocpPWriteResult {
pub mut:
	err ?ErrorKind
	n   usize
}

pub struct IocpSendResult {
pub mut:
	err ?ErrorKind
	n   usize
}

pub struct IocpRecvResult {
pub mut:
	err ?ErrorKind
	n   usize
}

pub struct IocpSendToResult {
pub mut:
	err ?ErrorKind
	n   usize
}

pub struct IocpRecvFromResult {
pub mut:
	err ?ErrorKind
	n   usize
}

pub struct IocpTimerResult {
pub mut:
	err   ?ErrorKind
	timer IocpTimerTrigger
}

pub struct IocpCancelResult {
pub mut:
	err ?ErrorKind
}

pub struct IocpAsyncWaitResult {
pub mut:
	err ?ErrorKind
}

pub struct IocpJobObjectResult {
pub mut:
	err   ?ErrorKind
	value IocpJobObjectValue
}

pub fn (r IocpResult) tag() IocpOperationType {
	return match r {
		IocpNoopResult { .noop }
		IocpAcceptResult { .accept }
		IocpCloseResult { .close }
		IocpConnectResult { .connect }
		IocpReadResult { .read }
		IocpPReadResult { .pread }
		IocpShutdownResult { .shutdown }
		IocpWriteResult { .write }
		IocpPWriteResult { .pwrite }
		IocpSendResult { .send }
		IocpRecvResult { .recv }
		IocpSendToResult { .sendto }
		IocpRecvFromResult { .recvfrom }
		IocpTimerResult { .timer }
		IocpCancelResult { .cancel }
		IocpAsyncWaitResult { .async_wait }
		IocpJobObjectResult { .job_object }
	}
}

fn iocp_result_kind(tag IocpOperationType, kind ErrorKind) IocpResult {
	return match tag {
		.noop { IocpNoopResult{ err: kind } }
		.accept { IocpAcceptResult{ err: kind } }
		.close { IocpCloseResult{ err: kind } }
		.connect { IocpConnectResult{ err: kind } }
		.read { IocpReadResult{ err: kind } }
		.pread { IocpPReadResult{ err: kind } }
		.shutdown { IocpShutdownResult{ err: kind } }
		.write { IocpWriteResult{ err: kind } }
		.pwrite { IocpPWriteResult{ err: kind } }
		.send { IocpSendResult{ err: kind } }
		.recv { IocpRecvResult{ err: kind } }
		.sendto { IocpSendToResult{ err: kind } }
		.recvfrom { IocpRecvFromResult{ err: kind } }
		.timer { IocpTimerResult{ err: kind } }
		.cancel { IocpCancelResult{ err: kind } }
		.async_wait { IocpAsyncWaitResult{ err: kind } }
		.job_object { IocpJobObjectResult{ err: kind } }
	}
}

fn iocp_result_n(tag IocpOperationType, n usize) IocpResult {
	return match tag {
		.read { IocpReadResult{ n: n } }
		.pread { IocpPReadResult{ n: n } }
		.write { IocpWriteResult{ n: n } }
		.pwrite { IocpPWriteResult{ n: n } }
		.send { IocpSendResult{ n: n } }
		.recv { IocpRecvResult{ n: n } }
		.sendto { IocpSendToResult{ n: n } }
		.recvfrom { IocpRecvFromResult{ n: n } }
		else { panic('result has no byte count') }
	}
}

fn iocp_result_bytes(r IocpResult) usize {
	return match r {
		IocpReadResult { r.n }
		IocpPReadResult { r.n }
		IocpWriteResult { r.n }
		IocpPWriteResult { r.n }
		IocpSendResult { r.n }
		IocpRecvResult { r.n }
		IocpSendToResult { r.n }
		IocpRecvFromResult { r.n }
		else { panic('result has no byte count') }
	}
}

@[heap]
pub struct IocpCompletion {
pub mut:
	op         IocpOperation = IocpNoopOp{}
	userdata   voidptr
	callback   IocpCallback    = iocp_noop_callback
	next       &IocpCompletion = unsafe { nil }
	result     ?IocpResult
	flags      IocpCompletionFlags
	overlapped C.OVERLAPPED
	loop       &IocpLoop = unsafe { nil }
}

pub fn (self &IocpCompletion) state() CompletionState {
	return match self.flags.state() {
		.dead { .dead }
		.adding, .active { .active }
	}
}

fn (self &IocpCompletion) handle() ?voidptr {
	return match self.op {
		IocpAcceptOp { self.op.socket }
		IocpReadOp, IocpPReadOp, IocpWriteOp, IocpPWriteOp,
		IocpRecvOp, IocpSendOp, IocpSendToOp, IocpRecvFromOp {
			self.op.fd
		}
		else { none }
	}
}

pub fn (mut self IocpCompletion) reset() {
	self.overlapped = C.OVERLAPPED{}
	self.result = none
}

fn iocp_timer_less(a &IocpHeapTimer, b &IocpHeapTimer) bool { return a.next < b.next }

@[heap]
pub struct IocpLoop {
pub mut:
	iocp_handle   voidptr = voidptr(usize(-1))
	active        usize
	submissions   IntrusiveQueue[IocpCompletion]
	cancellations IntrusiveQueue[IocpCompletion]
	completions   IntrusiveQueue[IocpCompletion]
	asyncs        IntrusiveQueue[IocpCompletion]
	timers        IntrusiveHeap[IocpHeapTimer] = IntrusiveHeap[IocpHeapTimer]{ less: iocp_timer_less }
	cached_now    u64
	qpc_duration  u64
	in_run        bool
	is_stopped    bool
}

pub fn IocpLoop.init(options Options) !IocpLoop {
	_ = options
	mut frequency := i64(0)
	if C.QueryPerformanceFrequency(&frequency) == 0 {
		panic('unreachable QueryPerformanceFrequency')
	}
	qpc_duration := u64(1_000_000_000) / u64(frequency)
	handle := C.CreateIoCompletionPort(voidptr(usize(-1)), unsafe { nil }, 0, 1)
	if handle == unsafe { nil } { return new_error(.unexpected) }
	mut result := IocpLoop{ iocp_handle: handle, qpc_duration: qpc_duration }
	result.update_now()
	return result
}

pub fn (mut self IocpLoop) deinit() { C.CloseHandle(self.iocp_handle) }

pub fn (mut self IocpLoop) stop() { self.is_stopped = true }

pub fn (self &IocpLoop) stopped() bool { return self.is_stopped }

pub fn (mut self IocpLoop) add(c_ &IocpCompletion) {
	mut c := unsafe { c_ }
	if c.op is IocpCancelOp {
		self.start_completion(c)
		return
	}
	match c.flags.state() {
		.adding { return }
		.dead {}
		.active { panic('unreachable active completion') }
	}
	c.flags.set_state(.adding)
	self.submissions.push(c)
}

pub fn (mut self IocpLoop) submit() ! {
	mut queued := self.submissions
	self.submissions = IntrusiveQueue[IocpCompletion]{}
	for {
		mut c := queued.pop() or { break }
		match c.flags.state() {
			.adding { self.start_completion(c) }
			.dead { self.stop_completion(c, unsafe { nil }) }
			.active { log.error('invalid state in submission queue state=${c.flags.state()}') }
		}
	}
}

fn (mut self IocpLoop) process_cancellations() {
	for {
		mut c := self.cancellations.pop() or { break }
		mut target := (c.op as IocpCancelOp).c
		mut cancel_result := IocpCancelOutcome{}
		match target.flags.state() {
			.dead {}
			.adding { target.flags.set_state(.dead) }
			.active { self.stop_completion(target, &cancel_result) }
		}
		c.result = IocpCancelResult{ err: cancel_result.err }
		self.completions.push(c)
	}
}

pub fn (mut self IocpLoop) run(mode RunMode) ! {
	match mode {
		.no_wait { self.tick(0)! }
		.once { self.tick(1)! }
		.until_done {
			for !self.done() { self.tick(1)! }
		}
	}
}

pub fn (mut self IocpLoop) tick(wait u32) ! {
	if self.is_stopped { return }
	if self.in_run { return new_error(.nested_runs_not_allowed) }
	self.in_run = true
	defer { self.in_run = false }
	mut entries := [128]C.OVERLAPPED_ENTRY{}
	mut wait_rem := usize(wait)
	self.process_cancellations()
	self.submit()!
	for {
		if self.is_stopped { return }
		self.update_now()
		if !((self.active > 0 && (wait == 0 || wait_rem > 0)) || !self.completions.empty()) {
			break
		}
		for {
			t := self.timers.peek() or { break }
			if t.next >= self.cached_now { break }
			popped := self.timers.delete_min() or { panic('unreachable') }
			assert popped == t
			mut c := t.c
			c.flags.set_state(.dead)
			self.active -= 1
			if wait_rem > 0 { wait_rem -= 1 }
			if c.callback(c.userdata, self, c, IocpTimerResult{ timer: .expiration }) == .rearm {
				self.start_completion(c)
			}
		}
		for {
			mut c := self.completions.pop() or { break }
			c_active := c.flags.state() == .active
			c.flags.set_state(.dead)
			if wait_rem > 0 { wait_rem -= 1 }
			result := c.result or { panic('completion queue item has no result') }
			match c.callback(c.userdata, self, c, result) {
				.disarm {
					if c_active { self.active -= 1 }
				}
				.rearm {
					if !c_active { self.submissions.push(c) }
				}
			}
		}
		if !self.asyncs.empty() {
			mut asyncs := self.asyncs
			self.asyncs = IntrusiveQueue[IocpCompletion]{}
			for {
				mut c := asyncs.pop() or { break }
				mut op := unsafe { &(c.op as IocpAsyncWaitOp) }
				if C.atomic_exchange_byte(&op.wakeup, 0) == 0 {
					self.asyncs.push(c)
					continue
				}
				c.flags.set_state(.dead)
				self.active -= 1
				if wait_rem > 0 { wait_rem -= 1 }
				if c.callback(c.userdata, self, c, IocpAsyncWaitResult{}) == .rearm {
					self.start_completion(c)
				}
			}
		}
		if wait_rem == 0 { break }
		mut timeout := u32(0xffffffff)
		if t := self.timers.peek() {
			ms_now := self.cached_now / 1_000_000
			ms_next := t.next / 1_000_000
			ms := if ms_next > ms_now { ms_next - ms_now } else { u64(0) }
			timeout = if ms <= 0xffffffff { u32(ms) } else { u32(0xfffffffe) }
		}
		mut count := u32(0)
		if !C.GetQueuedCompletionStatusEx(self.iocp_handle, &entries[0], 128, &count, timeout, 0) {
			if C.GetLastError() != 258 { return new_error(.unexpected) }
			count = 0
		}
		for entry in entries[..int(count)] {
			mut c := &IocpCompletion(unsafe { nil })
			if entry.lpCompletionKey == 0 {
				if entry.lpOverlapped == unsafe { nil } { continue }
				c = unsafe { &IocpCompletion(voidptr(usize(entry.lpOverlapped) - __offsetof(IocpCompletion, overlapped))) }
			} else {
				c = unsafe { &IocpCompletion(voidptr(entry.lpCompletionKey)) }
				c.result = IocpJobObjectResult{ value: IocpJobObjectMessage{ type_: entry.dwNumberOfBytesTransferred, value: usize(entry.lpOverlapped) } }
			}
			if wait_rem > 0 { wait_rem -= 1 }
			self.active -= 1
			c.flags.set_state(.dead)
			result := c.perform()
			if c.callback(c.userdata, self, c, result) == .rearm {
				c.reset()
				self.start_completion(c)
			}
		}
		if wait == 0 { break }
	}
}

pub fn (self &IocpLoop) now() i64 {
	assert self.cached_now <= 0x7fffffffffffffff
	return i64(self.cached_now)
}

pub fn (mut self IocpLoop) update_now() {
	mut counter := i64(0)
	if C.QueryPerformanceCounter(&counter) == 0 { panic('unreachable QueryPerformanceCounter') }
	self.cached_now = u64(counter) * self.qpc_duration
}

pub fn (self &IocpLoop) timer_next(next_ms u64) u64 { return self.cached_now + next_ms * 1_000_000 }

pub fn (self &IocpLoop) done() bool {
	return self.is_stopped || (self.active == 0 && self.submissions.empty() && self.completions.empty())
}

pub fn (mut self IocpLoop) timer(c_ &IocpCompletion, next_ms u64, userdata voidptr, cb IocpCallback) {
	mut c := unsafe { c_ }
	unsafe { *c = IocpCompletion{ op: IocpHeapTimer{ next: self.timer_next(next_ms) }, userdata: userdata, callback: cb } }
	self.add(c)
}

pub fn (mut self IocpLoop) timer_reset(c_ &IocpCompletion, c_cancel_ &IocpCompletion, next_ms u64, userdata voidptr, cb IocpCallback) {
	mut c := unsafe { c_ }
	mut c_cancel := unsafe { c_cancel_ }
	match c.flags.state() {
		.dead {
			self.timer(c, next_ms, userdata, cb)
			return
		}
		.adding {
			mut timer := unsafe { &(c.op as IocpHeapTimer) }
			timer.next = self.timer_next(next_ms)
			c.userdata = userdata
			c.callback = cb
		}
		.active {
			mut timer := unsafe { &(c.op as IocpHeapTimer) }
			timer.reset = self.timer_next(next_ms)
			c.userdata = userdata
			c.callback = cb
			if c_cancel.state() == .active { return }
			assert c_cancel.state() == .dead && c.state() == .active
			unsafe { *c_cancel = IocpCompletion{ op: IocpCancelOp{ c: c } } }
			self.add(c_cancel)
		}
	}
}

pub fn (self &IocpLoop) associate_fd(fd voidptr) ! {
	if fd == voidptr(usize(-1)) || self.iocp_handle == voidptr(usize(-1)) {
		return new_error(.invalid_parameter)
	}
	// Repeated association can fail with INVALID_PARAMETER; the source ignores it.
	_ = C.CreateIoCompletionPort(fd, self.iocp_handle, 0, 0)
}

pub fn (mut self IocpLoop) async_notify(c_ &IocpCompletion) {
	mut c := unsafe { c_ }
	assert c.op is IocpAsyncWaitOp
	mut op := unsafe { &(c.op as IocpAsyncWaitOp) }
	C.atomic_store_byte(&op.wakeup, 1)
	if !C.PostQueuedCompletionStatus(self.iocp_handle, 0, 0, unsafe { nil }) {
		log.warn('unexpected async_notify error=${C.GetLastError()}')
	}
}

// start_completion's source StartAction carries one of submitted/timer/cancel/
// async_wait or an immediate Result. An optional result preserves that split
// without allocating a second tagged-union payload.
fn (mut self IocpLoop) start_completion(c_ &IocpCompletion) {
	mut c := unsafe { c_ }
	mut immediate := ?IocpResult(none)
	tag := c.op.tag()
	match mut c.op {
		IocpNoopOp {
			c.flags.set_state(.dead)
			return
		}
		IocpAcceptOp {
			if c.op.internal_accept_socket == none {
				mut addr := [128]u8{}
				mut addr_len := 128
				name_result := C.getsockname(usize(c.op.socket), &addr[0], &addr_len)
				assert name_result == 0
				mut socket_type := 0
				mut opt_len := 4
				option_result := C.getsockopt(usize(c.op.socket), 0xffff, 0x1008, &socket_type, &opt_len)
				assert option_result == 0
				family := unsafe { *(&u16(&addr[0])) }
				socket := C.WSASocketW(int(family), socket_type, 0, unsafe { nil }, 0, 1)
				if socket == usize(-1) {
					kind := match C.WSAGetLastError() {
						10047 { ErrorKind.address_family_not_supported }
						10024 { ErrorKind.process_fd_quota_exceeded }
						10055 { ErrorKind.system_resources }
						10043 { ErrorKind.protocol_not_supported }
						else { ErrorKind.unexpected }
					}
					immediate = iocp_result_kind(.accept, kind)
				} else {
					c.op.internal_accept_socket = voidptr(socket)
				}
			}
			if immediate == none {
				self.associate_fd(c.handle() or { panic('unreachable') }) or { panic('unreachable association') }
				mut discard := u32(0)
				accepted := c.op.internal_accept_socket or { panic('unreachable') }
				rc := C.AcceptEx(usize(c.op.socket), usize(accepted), &c.op.storage[0], 0, 0, 128,
					&discard, &c.overlapped)
				if rc != 1 && C.WSAGetLastError() != 997 {
					C.CloseHandle(accepted)
					immediate = iocp_result_kind(.accept, .unexpected)
				}
			}
		}
		IocpCloseOp {
			// std.os.windows.CloseHandle asserts that a close succeeds.
			rc := C.CloseHandle(c.op.fd)
			assert rc
			immediate = IocpCloseResult{}
		}
		IocpConnectOp {
			rc := C.connect(usize(c.op.socket), c.op.addr.any(), int(c.op.addr.get_os_sock_len()))
			immediate = if rc != 0 {
				IocpResult(IocpConnectResult{ err: .unexpected })
			} else {
				IocpResult(IocpConnectResult{})
			}
		}
		IocpReadOp {
			self.associate_fd(c.handle() or { panic('unreachable') }) or { panic('unreachable association') }
			buf := c.op.buffer.slice_ptr()
			assert u64(buf.len) <= 0xffffffff

			mut count := u32(0)
			if !C.ReadFile(c.op.fd, buf.data, u32(buf.len), &count, &c.overlapped) && C.GetLastError() != 997 {
				immediate = iocp_result_kind(tag, .unexpected)
			}
		}
		IocpPReadOp {
			self.associate_fd(c.handle() or { panic('unreachable') }) or { panic('unreachable association') }
			buf := c.op.buffer.slice_ptr()
			assert u64(buf.len) <= 0xffffffff
			// The pinned source masks by all 64 bits before its checked u32 cast.
			assert c.op.offset <= 0xffffffff
			c.overlapped.Offset = u32(c.op.offset)
			c.overlapped.OffsetHigh = u32(c.op.offset >> 32)

			mut count := u32(0)
			if !C.ReadFile(c.op.fd, buf.data, u32(buf.len), &count, &c.overlapped) && C.GetLastError() != 997 {
				immediate = iocp_result_kind(tag, .unexpected)
			}
		}
		IocpShutdownOp {
			rc := C.shutdown(usize(c.op.socket), int(c.op.how))
			if rc == 0 {
				immediate = IocpShutdownResult{}
			} else {
				kind := match C.WSAGetLastError() {
					10050 { ErrorKind.network_subsystem_failed }
					10057 { ErrorKind.socket_not_connected }
					10038 { ErrorKind.file_descriptor_not_a_socket }
					10036 { ErrorKind.blocking_operation_in_progress }
					else { ErrorKind.unexpected }
				}
				immediate = IocpShutdownResult{ err: kind }
			}
		}
		IocpWriteOp {
			self.associate_fd(c.handle() or { panic('unreachable') }) or { panic('unreachable association') }
			buf := c.op.buffer.bytes()
			assert u64(buf.len) <= 0xffffffff

			mut count := u32(0)
			if !C.WriteFile(c.op.fd, buf.data, u32(buf.len), &count, &c.overlapped) && C.GetLastError() != 997 {
				immediate = iocp_result_kind(tag, .unexpected)
			}
		}
		IocpPWriteOp {
			self.associate_fd(c.handle() or { panic('unreachable') }) or { panic('unreachable association') }
			buf := c.op.buffer.bytes()
			assert u64(buf.len) <= 0xffffffff
			assert c.op.offset <= 0xffffffff
			c.overlapped.Offset = u32(c.op.offset)
			c.overlapped.OffsetHigh = u32(c.op.offset >> 32)

			mut count := u32(0)
			if !C.WriteFile(c.op.fd, buf.data, u32(buf.len), &count, &c.overlapped) && C.GetLastError() != 997 {
				immediate = iocp_result_kind(tag, .unexpected)
			}
		}
		IocpSendOp {
			self.associate_fd(c.handle() or { panic('unreachable') }) or { panic('unreachable association') }
			buf := c.op.buffer.bytes()
			assert u64(buf.len) <= 0xffffffff
			c.op.wsa_buffer.len = u32(buf.len)
			c.op.wsa_buffer.buf = &char(buf.data)
			rc := C.WSASend(usize(c.op.fd), &c.op.wsa_buffer, 1, unsafe { nil }, 0, &c.overlapped, unsafe { nil })
			if rc != 0 {
				code := C.WSAGetLastError()
				if code != 997 { immediate = iocp_result_kind(tag, iocp_socket_error(code)) }
			}
		}
		IocpRecvOp {
			self.associate_fd(c.handle() or { panic('unreachable') }) or { panic('unreachable association') }
			buf := c.op.buffer.slice_ptr()
			assert u64(buf.len) <= 0xffffffff
			c.op.wsa_buffer.len = u32(buf.len)
			c.op.wsa_buffer.buf = &char(buf.data)
			mut flags := u32(0)
			rc := C.WSARecv(usize(c.op.fd), &c.op.wsa_buffer, 1, unsafe { nil }, &flags, &c.overlapped, unsafe { nil })
			if rc != 0 {
				code := C.WSAGetLastError()
				if code != 997 { immediate = iocp_result_kind(tag, iocp_socket_error(code)) }
			}
		}
		IocpSendToOp {
			self.associate_fd(c.handle() or { panic('unreachable') }) or { panic('unreachable association') }
			buf := c.op.buffer.bytes()
			assert u64(buf.len) <= 0xffffffff
			c.op.wsa_buffer.len = u32(buf.len)
			c.op.wsa_buffer.buf = &char(buf.data)
			rc := C.WSASendTo(usize(c.op.fd), &c.op.wsa_buffer, 1, unsafe { nil }, 0, c.op.addr.any(), int(c.op.addr.get_os_sock_len()), &c.overlapped, unsafe { nil })
			if rc != 0 {
				code := C.WSAGetLastError()
				if code != 997 { immediate = iocp_result_kind(tag, iocp_socket_error(code)) }
			}
		}
		IocpRecvFromOp {
			self.associate_fd(c.handle() or { panic('unreachable') }) or { panic('unreachable association') }
			buf := c.op.buffer.slice_ptr()
			assert u64(buf.len) <= 0xffffffff
			c.op.wsa_buffer.len = u32(buf.len)
			c.op.wsa_buffer.buf = &char(buf.data)
			mut flags := u32(0)
			rc := C.WSARecvFrom(usize(c.op.fd), &c.op.wsa_buffer, 1, unsafe { nil }, &flags, &c.op.addr, unsafe { &int(&c.op.addr_size) }, &c.overlapped, unsafe { nil })
			if rc != 0 {
				code := C.WSAGetLastError()
				if code != 997 { immediate = iocp_result_kind(tag, iocp_socket_error(code)) }
			}
		}
		IocpHeapTimer {
			c.op.c = c
			self.timers.insert(&c.op)
		}
		IocpCancelOp { self.cancellations.push(c) }
		IocpAsyncWaitOp { self.asyncs.push(c) }
		IocpJobObjectOp {
			if !c.op.associated {
				mut port := C.JOBOBJECT_ASSOCIATE_COMPLETION_PORT{}
				port.CompletionKey = voidptr(c)
				port.CompletionPort = self.iocp_handle
				if !C.SetInformationJobObject(c.op.job, 7, &port, u32(sizeof(C.JOBOBJECT_ASSOCIATE_COMPLETION_PORT))) {
					immediate = IocpJobObjectResult{ err: .unexpected }
				} else {
					c.op.associated = true
					action := c.callback(c.userdata, self, c, IocpJobObjectResult{ value: IocpJobObjectAssociated{} })
					if action == .disarm {
						c.flags.set_state(.dead)
						return
					}
				}
			}
		}
	}
	if result := immediate {
		c.result = result
		self.completions.push(c)
	} else {
		self.active += 1
		c.flags.set_state(.active)
	}
}

fn iocp_socket_error(code int) ErrorKind {
	return match code {
		995, 10053 { .canceled }
		10054, 10052 { .connection_reset_by_peer }
		else { .unexpected }
	}
}

fn (mut self IocpLoop) stop_completion(c_ &IocpCompletion, cancel_result &IocpCancelOutcome) {
	mut c := unsafe { c_ }
	if c.flags.state() == .active && c.result != none { return }
	match mut c.op {
		IocpHeapTimer {
			if c.flags.state() == .active {
				self.timers.remove(&c.op)
				if reset := c.op.reset {
					c.op.next = reset
					c.op.reset = none
					c.flags.set_state(.dead)
					self.active -= 1
					self.add(c)
					return
				}
			}
			c.result = IocpTimerResult{ timer: .cancel }
			self.completions.push(c)
		}
		IocpAcceptOp, IocpReadOp, IocpPReadOp, IocpWriteOp, IocpPWriteOp,
		IocpRecvOp, IocpSendOp, IocpSendToOp, IocpRecvFromOp {
			if c.flags.state() == .active {
				assert cancel_result != unsafe { nil }
				handle := c.handle() or { panic('unreachable') }
				rc := C.CancelIoEx(handle, &c.overlapped)
				mut outcome := unsafe { cancel_result }
				outcome.err = if !rc { ?ErrorKind(ErrorKind.unexpected) } else { none }
			}
		}
		else { panic('Not implemented') } // The pinned backend has this same panic.
	}
}

pub fn (mut self IocpCompletion) perform() IocpResult {
	tag := self.op.tag()
	match mut self.op {
		IocpNoopOp, IocpCloseOp, IocpConnectOp, IocpShutdownOp, IocpHeapTimer, IocpCancelOp {
			log.warn('perform op=${tag}')
			panic('unreachable')
		}
		IocpAcceptOp {
			mut n := u32(0)
			mut flags := u32(0)
			if C.WSAGetOverlappedResult(usize(self.op.socket), &self.overlapped, &n, 0, &flags) != 1 {
				kind := if C.WSAGetLastError() == 995 {
					ErrorKind.canceled
				} else {
					ErrorKind.unexpected
				}
				C.CloseHandle(self.op.internal_accept_socket or { panic('unreachable') })
				return IocpAcceptResult{ err: kind }
			}
			return IocpAcceptResult{ socket: self.op.internal_accept_socket or { panic('unreachable') } }
		}
		IocpReadOp, IocpPReadOp, IocpWriteOp, IocpPWriteOp {
			mut n := u32(0)
			if !C.GetOverlappedResult(self.op.fd, &self.overlapped, &n, 0) {
				kind := if C.GetLastError() == 995 {
					ErrorKind.canceled
				} else {
					ErrorKind.unexpected
				}
				// The source pread/pwrite failure paths carry read/write result tags.
				result_tag := if tag == .pread {
					IocpOperationType.read
				} else if tag == .pwrite {
					IocpOperationType.write
				} else {
					tag
				}
				return iocp_result_kind(result_tag, kind)
			}
			return iocp_result_n(tag, usize(n))
		}
		IocpSendOp, IocpRecvOp, IocpSendToOp, IocpRecvFromOp {
			mut n := u32(0)
			mut flags := u32(0)
			if C.WSAGetOverlappedResult(usize(self.op.fd), &self.overlapped, &n, 0, &flags) != 1 {
				return iocp_result_kind(tag, iocp_socket_error(C.WSAGetLastError()))
			}
			if tag == .recv {
				mut socket_type := u32(0)
				mut opt_len := 4
				rc := C.getsockopt(usize(self.op.fd), 0xffff, 0x1008, &socket_type, &opt_len)
				assert rc == 0
				if socket_type == 1 && n == 0 { return iocp_result_kind(.recv, .eof) }
			}
			return iocp_result_n(tag, usize(n))
		}
		IocpAsyncWaitOp { return IocpAsyncWaitResult{} }
		IocpJobObjectOp { return self.result or { panic('job-object result is missing') } }
	}
}
