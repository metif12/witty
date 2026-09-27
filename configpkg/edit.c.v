module configpkg

import os

#include <errno.h>
#include <fcntl.h>

fn C.open(path &char, flags int, mode int) int

// create_config_file creates the editable config only when it does not exist.
// This preserves config/edit.zig's exclusive create: an existing file is left
// untouched even if it appears between path selection and creation.
fn create_config_file(path string) ! {
	fd := C.open(&char(path.str), C.O_WRONLY | C.O_CREAT | C.O_EXCL, 0o666)
	if fd < 0 {
		if C.errno == C.EEXIST {
			return
		}
		return os.error_posix()
	}
	os.fd_close(fd)
}
