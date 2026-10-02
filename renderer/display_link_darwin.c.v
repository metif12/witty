module renderer

import xev
import log

fn renderer_display_link_callback(display_link voidptr, now voidptr, output_time voidptr, flags_in u64, flags_out &u64, context voidptr) int {
	_ = display_link
	_ = now
	_ = output_time
	_ = flags_in
	_ = flags_out
	if context == unsafe { nil } {
		return 0
	}
	draw_now := unsafe { &xev.Async(context) }
	draw_now.notify() or { log.error('error notifying draw_now err=${err}') }
	return 0
}
