module internal_os

#include <windows.h>

pub type PipeFd = voidptr

fn C.CreatePipe(read &voidptr, write &voidptr, attributes voidptr, size u32) int
fn C.GetLastError() u32

// src/os/pipe.zig: Windows uses anonymous HANDLEs with default security,
// rather than CRT descriptors or POSIX flags.
pub fn pipe() ![2]PipeFd {
	mut read := voidptr(unsafe { nil })
	mut write := voidptr(unsafe { nil })
	if C.CreatePipe(&read, &write, unsafe { nil }, 0) == 0 {
		return error('Unexpected: ${C.GetLastError()}')
	}
	return [PipeFd(read), PipeFd(write)]!
}
