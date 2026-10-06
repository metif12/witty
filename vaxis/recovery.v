module vaxis

#flag -I @VMODROOT/vaxis
#include "recovery_shims.h"

fn C.witty_vaxis_recovery_tty_get() voidptr
fn C.witty_vaxis_recovery_tty_set(value voidptr)

const recovery_reset = '\x1b[<u\x1b[?1002;1003;1004;1006;1016l\x1b[?2004l\x1b[?1049l'

fn register_recovery_tty(tty Tty) {
	// The source registers the last successful init by value, before returning it.
	C.witty_vaxis_recovery_tty_set(&Tty{ ...tty })
}

// recover restores the last successfully initialized terminal after writing the
// source reset sequence. Reset write errors do not prevent terminal restoration.
pub fn recover() {
	pointer := C.witty_vaxis_recovery_tty_get()
	if isnil(pointer) { return }
	saved := unsafe { &Tty(pointer) }
	// V deinit mutates its receiver; use a copy to retain the source global value.
	mut tty := Tty{
		...saved
	}
	tty.write(recovery_reset) or {}
	tty.deinit()
}

// Source StackTrace and return-address data have no V panic-runtime equivalent.
// Recovery runs before the V runtime reports the supplied panic message.
@[noreturn]
pub fn panic_handler(message string, trace voidptr, ret_addr ?usize) {
	_ = trace
	_ = ret_addr
	recover()
	panic(message)
}

pub struct Panic {}

@[noreturn]
pub fn Panic.call(message string, trace voidptr, ret_addr ?usize) {
	panic_handler(message, trace, ret_addr)
}
