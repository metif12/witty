module internal_os

#include "@VMODROOT/internal_os/valgrind.h"

fn C.witty_running_on_valgrind() usize

// running_on_valgrind returns the number of nested Valgrind instances, using
// the runtime client request translated from Zig 0.15.2's std.valgrind.
pub fn running_on_valgrind() usize {
	return C.witty_running_on_valgrind()
}
