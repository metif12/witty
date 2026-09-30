module vaxis

// Pinned Loop.ttyRun's Windows console event path. The opaque argument keeps
// V's generic thread wrappers on one pointer ABI for every application type.
fn loop_tty_run[T](context voidptr) ! {
	mut loop := unsafe { &Loop[T](context) }
	mut cache := GraphemeCache.new()
	for !loop.is_quitting() {
		mut tty := unsafe { loop.tty }
		event := tty.next_input()!
		loop.handle_input(event, mut cache)
	}
}
