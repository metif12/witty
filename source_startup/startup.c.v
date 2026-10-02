// The pinned Zig executable startup installs a caught SIGPIPE disposition.
// V's startup leaves the default terminating disposition; reproduce the
// source runtime boundary before invoking translated executable entrypoints.
module source_startup

#include "@VMODROOT/source_startup/sigpipe.h"
fn C.witty_source_startup_sigpipe() int

pub fn prepare() {
	assert C.witty_source_startup_sigpipe() == 0
}
