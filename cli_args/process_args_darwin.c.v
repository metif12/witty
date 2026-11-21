module cli_args

#flag darwin -framework Foundation
#flag darwin -lobjc

#insert "@VMODROOT/cli_args/process_args_darwin.h"

fn C.witty_cli_process_argument_count() uint

fn C.witty_cli_process_argument_copy(index uint) &char

fn C.free(pointer voidptr)

// Cocoa applications may replace or invalidate libc's argc/argv during
// NSApplicationMain. Match Ghostty's Darwin iterator by reading the snapshot
// maintained by NSProcessInfo instead.
fn process_args_snapshot() []string {
	count := C.witty_cli_process_argument_count()
	mut result := []string{cap: int(count)}
	for index in uint(0) .. count {
		value := C.witty_cli_process_argument_copy(index)
		if value == unsafe { nil } {
			result << ''
			continue
		}
		result << unsafe { value.vstring().clone() }
		C.free(value)
	}
	return result
}
