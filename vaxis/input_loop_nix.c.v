module vaxis

// Pinned Loop.ttyRun's POSIX read boundary. An ignored device-status reply
// still completes a read, allowing stop to join without an application event.
// The opaque argument keeps V's generic thread wrappers on one pointer ABI.
fn loop_tty_run[T](context voidptr) ! {
	mut loop := unsafe { &Loop[T](context) }
	mut cache := GraphemeCache.new()
	winsize := loop.tty.get_winsize()!
	post_terminal_event(mut loop, winsize)
	mut buf := [1024]u8{}
	// A direct V fixed-array slice copies; borrow the read buffer instead.
	mut bytes := unsafe { (&buf[0]).vbytes(buf.len) }
	for !loop.is_quitting() {
		mut tty := unsafe { loop.tty }
		count := tty.read(mut bytes)!
		tty.pending << bytes[..int(count)]
		for {
			event := tty.parse_pending() or { break }
			loop.handle_input(event, mut cache)
		}
	}
}
