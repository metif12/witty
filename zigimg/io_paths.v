module zigimg

import os

#flag -I @VMODROOT/zigimg
#include "file_io_shims.h"

fn C.witty_image_file_path_max() int
fn C.witty_image_file_open_interrupted(int) int
fn C.witty_image_file_open_error(int) &char

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
			if writing {
				file := os.create(path) or {
					if C.witty_image_file_open_interrupted(err.code()) == 1 {
						continue
					}
					return image_file_open_error(err)
				}
				return file
			}
			file := os.open(path) or {
				if C.witty_image_file_open_interrupted(err.code()) == 1 {
					continue
				}
				return image_file_open_error(err)
			}
			return file
		}
	}
	return error('Unexpected')
}
