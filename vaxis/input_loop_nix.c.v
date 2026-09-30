module vaxis

// Pinned Loop.ttyRun's POSIX read boundary. An ignored device-status reply
// still completes a read, allowing stop to join without an application event.
// The opaque argument keeps V's generic thread wrappers on one pointer ABI.
fn loop_tty_run[T](context voidptr) ! {
	mut loop := unsafe { &Loop[T](context) }
	mut cache := GraphemeCache.new()
	winsize := loop.tty.get_winsize()!
	post_terminal_event(mut loop, winsize)
	mut parser := Parser{}
	mut reader := LoopReadBuffer{}
	for !loop.is_quitting() {
		mut tty := unsafe { loop.tty }
		mut bytes := reader.read_buffer()
		count := tty.read(mut bytes)!
		reader.begin_read(count)
		for reader.has_next() {
			result := reader.parse_next(mut parser, loop.vx.opts.system_clipboard)!
			if event := result.event { loop.handle_input(event, mut cache) }
		}
	}
}
