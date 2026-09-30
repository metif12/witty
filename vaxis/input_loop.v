module vaxis

import sync

// Pinned vaxis Loop(Event), with application event variants selected at compile time.
// The reader intercepts terminal reports before posting application events.
// T is an application sum type containing any supported terminal event types.

@[heap]
pub struct Loop[T] {
mut:
	tty         &Tty   = unsafe { nil }
	vx          &Vaxis = unsafe { nil }
	thread_     ?LoopThread
	quit_mutex  &sync.Mutex = unsafe { nil }
	should_quit bool
pub mut:
	queue &EventQueue[T] = unsafe { nil }
}

pub fn Loop.new[T](mut tty Tty, mut vx Vaxis) &Loop[T] {
	return &Loop[T]{
		tty:        &tty
		vx:         &vx
		queue:      EventQueue.new[T](512)
		quit_mutex: sync.new_mutex()
	}
}

pub fn (mut loop Loop[T]) init() ! {
	$if !windows {
		Tty.notify_winsize(voidptr(loop), voidptr(loop_winsize_callback[T]))!
	}
}

fn loop_winsize_callback[T](context voidptr) {
	mut loop := unsafe { &Loop[T](context) }
	if loop.vx.state.in_band_resize {
		return
	}
	winsize := loop.tty.get_winsize() or { return }
	post_terminal_event(mut loop, winsize)
}

pub fn (mut loop Loop[T]) start() ! {
	if loop.thread_ != none {
		return
	}
	loop.thread_ = loop_thread_start[T](voidptr(loop))!
}

pub fn (mut loop Loop[T]) stop() {
	if worker := loop.thread_ {
		loop.quit_mutex.lock()
		loop.should_quit = true
		loop.quit_mutex.unlock()
		loop.tty.write(loop.vx.device_status_report()) or {}
		worker.join()
		loop.thread_ = none
		loop.quit_mutex.lock()
		loop.should_quit = false
		loop.quit_mutex.unlock()
	}
}

pub fn (mut loop Loop[T]) deinit() {
	loop.stop()
	loop.queue.deinit()
	loop.quit_mutex.destroy()
}

pub fn (mut loop Loop[T]) next_event() T {
	return loop.queue.pop()
}

pub fn (mut loop Loop[T]) poll_event() {
	loop.queue.poll()
}

pub fn (mut loop Loop[T]) try_event() ?T {
	return loop.queue.try_pop()
}

pub fn (mut loop Loop[T]) post_event(event T) {
	loop.queue.push(event)
}

pub fn (mut loop Loop[T]) try_post_event(event T) bool {
	return loop.queue.try_push(event)
}

fn (mut loop Loop[T]) is_quitting() bool {
	loop.quit_mutex.lock()
	defer { loop.quit_mutex.unlock() }
	return loop.should_quit
}

// Direct resize notifications bypass terminal report interception, as in the source.
fn post_terminal_event[T, U](mut loop Loop[T], event U) {
	$for variant in T.variants {
		$if variant.typ is U {
			loop.post_event(T(event))
			return
		}
	}
}

// Intercept reports even when the application has not subscribed to their types.
fn (mut loop Loop[T]) handle_input(event InputEvent, mut cache GraphemeCache) {
	mut vx := unsafe { loop.vx }
	if forwarded := vx.handle_input(event) {
		loop.forward_input(forwarded, mut cache)
	}
}

fn (mut loop Loop[T]) forward_input(event InputEvent, mut cache GraphemeCache) {
	$for variant in InputEvent.variants {
		if event is variant {
			value := event
			post_cached_event(mut loop, value, mut cache)
			return
		}
	}
}

// Source key text is borrowed from the reader's wrapping cache only if subscribed.
fn post_cached_event[T, U](mut loop Loop[T], event U, mut cache GraphemeCache) {
	$for variant in T.variants {
		$if variant.typ is U {
			$if U is Key {
				mut key := event
				if text := key.text {
					cached := cache.put(text.bytes())
					key.text = unsafe { tos(cached.data, cached.len) }
				}
				loop.post_event(T(key))
			} $else $if U is KeyRelease {
				mut key := event.key
				if text := key.text {
					cached := cache.put(text.bytes())
					key.text = unsafe { tos(cached.data, cached.len) }
				}
				loop.post_event(T(KeyRelease{ key: key }))
			} $else {
				loop.post_event(T(event))
			}
			return
		}
	}
}
