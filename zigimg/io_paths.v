module zigimg

import os

#flag -I @VMODROOT/zigimg
#include "file_io_shims.h"

fn C.witty_image_file_path_max() int
fn C.witty_image_file_open_interrupted(int) int
fn C.witty_image_file_open_error(int) &char
fn C.witty_image_file_open(&char, int, &int) int
fn C.witty_image_file_close(int) int

fn image_file_open_error(err IError) IError {
	$if windows {
		return err
	} $else {
		name := unsafe { cstring_to_vstring(C.witty_image_file_open_error(err.code())) }
		if name == '_Unreachable' { panic('reached unreachable code') }
		return error(name)
	}
}

fn image_open_file(path string, writing bool) !os.File {
	$if windows {
		if writing { return os.create(path) }
		return os.open(path)
	} $else {
		// Source toPosixPath asserts before checking length or calling openat.
		for i in 0 .. path.len {
			if path[i] == 0 { panic('reached unreachable code') }
		}
		if path.len >= C.witty_image_file_path_max() { return error('NameTooLong') }
		if path.len == 0 { return error('FileNotFound') }
		for {
			mut saved_error := 0
			fd := C.witty_image_file_open(path.str, int(writing), &saved_error)
			if fd >= 0 {
				// Private path streams use only fd; no stdio buffer is attached.
				return os.File{
					fd: fd
				}
			}
			if C.witty_image_file_open_interrupted(saved_error) == 1 { continue
			 }
			return image_file_open_error(error_with_code('', saved_error))
		}
	}
	return error('Unexpected')
}

fn image_close_file(mut file os.File) {
	$if windows {
		file.close()
	} $else {
		// Source std.posix.close treats an invalid descriptor as unreachable.
		if C.witty_image_file_close(file.fd) == 4 { panic('reached unreachable code') }
	}
}
