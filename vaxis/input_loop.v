module vaxis

import sync

// InputLoop is the fixed InputEvent form of pinned vaxis Loop(Event). The
// reader owns parsing; the caller applies capability interception as it drains
// the queue so Vaxis state is modified on one thread.
@[heap]
pub struct InputLoop {
mut:
	tty         &Tty                    = unsafe { nil }
	queue       &EventQueue[InputEvent] = unsafe { nil }
	thread_     ?thread
	quit_mutex  &sync.Mutex = unsafe { nil }
	should_quit bool
}

pub fn InputLoop.new(mut tty Tty) &InputLoop {
	return &InputLoop{
		tty:        &tty
		queue:      EventQueue.new[InputEvent](512)
		quit_mutex: sync.new_mutex()
	}
}

pub fn (mut loop InputLoop) start() {
	if loop.thread_ != none {
		return
	}
	loop.thread_ = spawn loop.tty_run()
}

pub fn (mut loop InputLoop) stop(vx &Vaxis) {
	if worker := loop.thread_ {
		loop.quit_mutex.lock()
		loop.should_quit = true
		loop.quit_mutex.unlock()
		$if !windows {
			loop.tty.write(vx.device_status_report()) or {}
		}
		worker.wait()
		loop.thread_ = none
		loop.quit_mutex.lock()
		loop.should_quit = false
		loop.quit_mutex.unlock()
	}
}

pub fn (mut loop InputLoop) deinit(vx &Vaxis) {
	loop.stop(vx)
	loop.queue.deinit()
	loop.quit_mutex.destroy()
}

pub fn (mut loop InputLoop) next_event() InputEvent {
	return loop.queue.pop()
}

pub fn (mut loop InputLoop) poll_event() {
	loop.queue.poll()
}

pub fn (mut loop InputLoop) try_event() ?InputEvent {
	return loop.queue.try_pop()
}

pub fn (mut loop InputLoop) post_event(event InputEvent) {
	loop.queue.push(event)
}

pub fn (mut loop InputLoop) try_post_event(event InputEvent) bool {
	return loop.queue.try_push(event)
}

fn (mut loop InputLoop) is_quitting() bool {
	loop.quit_mutex.lock()
	defer { loop.quit_mutex.unlock() }
	return loop.should_quit
}

fn (mut loop InputLoop) tty_run() {
	for !loop.is_quitting() {
		mut tty := unsafe { loop.tty }
		event := tty.next_input() or { return }
		if loop.is_quitting() {
			return
		}
		loop.post_event(event)
	}
}
