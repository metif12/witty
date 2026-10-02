module internal_os

#include <windows.h>

pub type PipeFd = voidptr

fn C.CreatePipe(read &voidptr, write &voidptr, attributes voidptr, size u32) bool
fn C.GetLastError() u32

// src/os/pipe.zig: Windows uses anonymous HANDLEs with default security,
// rather than CRT descriptors or POSIX flags.
// HANDLE is already an opaque pointer; retain the exact two-handle result
// without the compiler's alias-element fixed-array result typedef bug.
pub fn pipe() ![2]voidptr {
	mut read := voidptr(unsafe { nil })
	mut write := voidptr(unsafe { nil })
	if !C.CreatePipe(&read, &write, unsafe { nil }, 0) {
		return error('Unexpected: ${C.GetLastError()}')
	}
	return [read, write]!
}
