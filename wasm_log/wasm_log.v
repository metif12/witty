// Translated from Ghostty src/os/wasm/log.zig and lib_vt.zig std_options.
// V callers already format their arguments into strings. The source buffer,
// allocation fallback, ownership, level filtering and env.log ABI stay here.
module wasm_log

import buildcfg
import lib_allocator

#include "@VMODROOT/wasm_log/host.h"
fn C.ghostty_wasm_host_log(&u8, usize)

pub enum Level {
	err
	warn
	info
	debug
}

fn (level Level) text() string {
	return match level { .err { 'error' } .warn { 'warning' } .info { 'info' } .debug { 'debug' } }
}

pub fn write(level Level, scope string, message string) {
	maximum := match buildcfg.mode_string { 'Debug' { Level.debug } 'ReleaseSmall' { Level.warn } else { Level.info } }
	if int(level) > int(maximum) { return }
	level_text := level.text()
	separator := if scope.len == 0 { ': ' } else { '): ' }
	length := level_text.len + message.len + if scope.len == 0 { 2 } else { scope.len + 4 }
	mut stack := [2048]u8{}
	mut allocated := false
	allocator := lib_allocator.default(none)
	mut buffer := unsafe { &stack[0] }
	if length > stack.len {
		buffer = &u8(allocator.alloc_bytes(usize(length), 0, 0))
		if isnil(buffer) { return }
		allocated = true
	}
	defer {
		if allocated { allocator.free_bytes(buffer, usize(length), 0, 0) }
	}
	unsafe {
		vmemcpy(buffer, level_text.str, level_text.len)
		mut offset := level_text.len
		if scope.len > 0 {
			buffer[offset] = `(`
			offset++
			vmemcpy(buffer + offset, scope.str, scope.len)
			offset += scope.len
		}
		vmemcpy(buffer + offset, separator.str, separator.len)
		offset += separator.len
		vmemcpy(buffer + offset, message.str, message.len)
		C.ghostty_wasm_host_log(buffer, usize(length))
	}
}
