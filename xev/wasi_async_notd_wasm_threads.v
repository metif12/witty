module xev

$if !windows {
	// src/watcher/async.zig AsyncLoopState, libxev 34fa508. The source API only
	// exposes this watcher on the nonthreaded loop; threaded WASI uses the loop's
	// low-level async_notify operation directly.
	struct WasiAsyncWaiter {
		loop &WasiLoop       = unsafe { nil }
		c    &WasiCompletion = unsafe { nil }
	}

	pub struct WasiAsync {
	mut:
		wakeup bool
		waiter ?WasiAsyncWaiter
	}

	pub fn WasiAsync.init() !WasiAsync { return WasiAsync{} }

	pub fn (self &WasiAsync) deinit() { _ = self }

	pub fn (mut self WasiAsync) wait(mut loop WasiLoop, c_ &WasiCompletion, userdata voidptr, cb WasiWatcherCallback) {
		mut c := unsafe { c_ }
		unsafe {
			*c = WasiCompletion{
				op:       WasiAsyncWaitOp{}
				userdata: userdata
				callback: fn [cb] (ud voidptr, l &WasiLoop, c &WasiCompletion, r WasiResult) CallbackAction {
					return cb(ud, l, c, r.err)
				}
			}
		}
		loop.add(c)
		self.waiter = WasiAsyncWaiter{ loop: unsafe { &loop }, c: c }
		if self.wakeup { self.notify() or {} }
	}

	pub fn (mut self WasiAsync) notify() ! {
		if waiter := self.waiter {
			mut loop := unsafe { waiter.loop }
			loop.async_notify(waiter.c)
		} else {
			self.wakeup = true
		}
	}
}
