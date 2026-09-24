module xev

// V translation of libxev's src/watcher/timer.zig TimerLoop, the Timer of the
// epoll backend (pinned 34fa508).

// Error that could happen while running a timer (RunError): Canceled when
// the timer was canceled before it could expire, or Unexpected. The cancel
// callback receives a CancelError.

// A timer fires a callback after a specified amount of time. A timer can
// repeat by returning "rearm" in the callback or by rescheduling the
// start within the callback.
pub struct EpollTimer {}

// Create a new timer.
pub fn EpollTimer.init() !EpollTimer {
	return EpollTimer{}
}

pub fn (self &EpollTimer) deinit() {
	// Nothing for now.
	_ = self
}

// Convert the loop's timer result into the watcher's RunError!void.
fn epoll_timer_run_error(r EpollResult) ?ErrorKind {
	if err := r.err {
		return err
	}
	return match r.timer {
		.request, .expiration { none }
		.cancel { ErrorKind.canceled }
	}
}

// Start the timer. The timer will execute in next_ms milliseconds from
// now.
//
// This will use the monotonic clock on your system if available so
// this is immune to system clock changes or drift. The callback is
// guaranteed to fire NO EARLIER THAN "next_ms" milliseconds. We can't
// make any guarantees about exactness or time bounds because its possible
// for your OS to just... pause.. the process for an indefinite period of
// time.
//
// Like everything else in libxev, if you want something to repeat, you
// must then requeue the completion manually. This punts off one of the
// "hard" aspects of timers: it is up to you to determine what the semantic
// meaning of intervals are. For example, if you want a timer to repeat every
// 10 seconds, is it every 10th second of a wall clock? every 10th second
// after an invocation? every 10th second after the work time from the
// invocation? You have the power to answer these questions, manually.
pub fn (self &EpollTimer) run(mut loop EpollLoop, c &EpollCompletion, next_ms u64, userdata voidptr, cb EpollWatcherCallback) {
	_ = self

	loop.timer(c, next_ms, userdata, fn [cb] (ud voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, r EpollResult) CallbackAction {
		return cb(ud, l_inner, c_inner, epoll_timer_run_error(r))
	})
}

// Reset a timer to execute in next_ms milliseconds. If the timer
// is already started, this will stop it and restart it. If the
// timer has never been started, this is equivalent to running "run".
// In every case, the timer callback is updated to the given userdata
// and callback.
//
// This requires an additional completion c_cancel to represent
// the need to possibly cancel the previous timer. You can check
// if c_cancel was used by checking the state() after the call.
//
// VERY IMPORTANT: both c and c_cancel MUST NOT be undefined. They
// must be initialized to ".{}" if being used for the first time.
pub fn (self &EpollTimer) reset(mut loop EpollLoop, c &EpollCompletion, c_cancel &EpollCompletion, next_ms u64, userdata voidptr, cb EpollWatcherCallback) {
	_ = self

	loop.timer_reset(c, c_cancel, next_ms, userdata, fn [cb] (ud voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, r EpollResult) CallbackAction {
		return cb(ud, l_inner, c_inner, epoll_timer_run_error(r))
	})
}

// Cancel a previously started timer. The timer to cancel used the completion
// "c_cancel". A new completion "c" must be specified which will be called
// with the callback once cancellation is complete.
//
// The original timer will still have its callback fired but with the
// error "error.Canceled".
pub fn (self &EpollTimer) cancel(mut loop EpollLoop, c_timer &EpollCompletion, c_cancel &EpollCompletion, userdata voidptr, cb EpollWatcherCallback) {
	_ = self

	mut completion := unsafe { c_cancel }
	unsafe {
		*completion = EpollCompletion{
			op:       EpollOperation{
				tag:    .cancel
				cancel: EpollCancelOp{
					c: c_timer
				}
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, r EpollResult) CallbackAction {
				return cb(ud, l_inner, c_inner, r.err)
			}
		}
	}

	loop.add(completion)
}
