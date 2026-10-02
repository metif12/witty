module xev

import sync

// src/watcher/async.zig AsyncIOCP, libxev 34fa508.
pub type IocpWatcherCallback = fn (ud voidptr, l &IocpLoop, c &IocpCompletion, r ?ErrorKind) CallbackAction

struct IocpAsyncWaiter {
	loop &IocpLoop       = unsafe { nil }
	c    &IocpCompletion = unsafe { nil }
}

pub struct IocpAsync {
mut:
	guard  sync.Mutex
	wakeup bool
	waiter ?IocpAsyncWaiter
}

pub fn IocpAsync.init() !IocpAsync { return IocpAsync{} }

pub fn (self &IocpAsync) deinit() { _ = self }

pub fn (mut self IocpAsync) wait(mut loop IocpLoop, c_ &IocpCompletion, userdata voidptr, cb IocpWatcherCallback) {
	mut c := unsafe { c_ }
	unsafe {
		*c = IocpCompletion{
			op:       IocpAsyncWaitOp{}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l &IocpLoop, c &IocpCompletion, r IocpResult) CallbackAction {
				return cb(ud, l, c, r.err)
			}
		}
	}
	loop.add(c)
	self.guard.lock()
	defer { self.guard.unlock() }
	self.waiter = IocpAsyncWaiter{ loop: unsafe { &loop }, c: c }
	if self.wakeup { loop.async_notify(c) }
}

pub fn (mut self IocpAsync) notify() ! {
	self.guard.lock()
	defer { self.guard.unlock() }
	if waiter := self.waiter {
		mut loop := unsafe { waiter.loop }
		loop.async_notify(waiter.c)
	} else {
		self.wakeup = true
	}
}
