module cli

// Direct translation of Zig 0.15.2 std.fs.AtomicFile used by DiskCache:
// random 64-bit hexadecimal names, exclusive creation, a 1024-byte writer,
// close-before-rename, and removal on every unfinished exit.
import crypto.rand
import os
import math

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>

$if windows {
	#include <io.h>
	#include <windows.h>
} $else {
	#include <unistd.h>
}

fn C.open(&char, int, ...int) int
fn C.close(int) int
fn C.write(int, voidptr, usize) isize
fn C.read(int, voidptr, usize) isize
fn C.memcpy(voidptr, voidptr, usize) voidptr
fn C._read(int, voidptr, u32) int
fn C.openat(int, &char, int, ...int) int
fn C.renameat(int, &char, int, &char) int
fn C.unlinkat(int, &char, int) int
fn C._wopen(&u16, int, ...int) int
fn C._close(int) int
fn C._write(int, voidptr, u32) int
fn C.MoveFileExW(&u16, &u16, u32) int

struct SshAtomicFile {
mut:
	dir_fd int = -1
	fd int = -1
	dir string
	name string
	basename string
	file_exists bool
	buffer [1024]u8
	end int
}

fn ssh_create_file(path string) ! {
	// createFileAbsolute(..., read=true, truncate=false, mode=0600).
	mut file := os.open_file(path, 'a+', 0o600)!
	file.close()
	$if !windows { os.chmod(path, 0o600)! }
}

fn SshAtomicFile.init(path string) !SshAtomicFile {
	dir := os.dir(path)
	mut result := SshAtomicFile{dir: dir, basename: os.base(path)}
	$if !windows {
		result.dir_fd = C.open(&char(dir.str), C.O_RDONLY | C.O_DIRECTORY | C.O_CLOEXEC, 0)
		if result.dir_fd < 0 { return os.error_posix() }
	}
	for {
		bytes := rand.bytes(8) or {
			result.deinit()
			return err
		}
		// std.fmt.hex(u64) emits little-endian byte pairs; the native random
		// integer is supplied by those same eight random bytes.
		result.name = bytes.hex()
		$if windows {
			name := os.join_path(dir, result.name)
			result.fd = C._wopen(name.to_wide(), C.O_WRONLY | C.O_CREAT | C.O_EXCL | C.O_BINARY, 0o600)
		} $else {
			result.fd = C.openat(result.dir_fd, &char(result.name.str), C.O_WRONLY | C.O_CREAT | C.O_EXCL | C.O_CLOEXEC, 0o600)
		}
		if result.fd >= 0 {
			result.file_exists = true
			return result
		}
		if C.errno == C.EEXIST { continue }
		err := os.error_posix()
		result.deinit()
		return err
	}
	return error('unreachable')
}

fn (mut file SshAtomicFile) write(data string) ! {
	mut offset := 0
	for offset < data.len {
		if file.end == file.buffer.len { file.flush()! }
		count := math.min(file.buffer.len - file.end, data.len - offset)
		unsafe { C.memcpy(&file.buffer[file.end], data.str + offset, usize(count)) }
		file.end += count
		offset += count
	}
}

fn (mut file SshAtomicFile) flush() ! {
	mut offset := 0
	for offset < file.end {
		written := $if windows {
			isize(C._write(file.fd, unsafe { &file.buffer[offset] }, u32(file.end - offset)))
		} $else {
			C.write(file.fd, unsafe { &file.buffer[offset] }, usize(file.end - offset))
		}
		if written < 0 {
			if C.errno == C.EINTR { continue }
			return os.error_posix()
		}
		if written == 0 { return error('WriteFailed') }
		offset += int(written)
	}
	file.end = 0
}

fn (mut file SshAtomicFile) close() {
	if file.fd >= 0 {
		$if windows { C._close(file.fd) } $else { C.close(file.fd) }
		file.fd = -1
	}
}

fn (mut file SshAtomicFile) finish() ! {
	file.flush()!
	file.close()
	$if windows {
		from := os.join_path(file.dir, file.name)
		to := os.join_path(file.dir, file.basename)
		if C.MoveFileExW(from.to_wide(), to.to_wide(), C.MOVEFILE_REPLACE_EXISTING) == 0 {
			return error('RenameFailed')
		}
	} $else {
		if C.renameat(file.dir_fd, &char(file.name.str), file.dir_fd, &char(file.basename.str)) != 0 {
			return os.error_posix()
		}
	}
	file.file_exists = false
}

fn (mut file SshAtomicFile) deinit() {
	file.close()
	if file.file_exists {
		$if windows {
			os.rm(os.join_path(file.dir, file.name)) or {}
		} $else {
			C.unlinkat(file.dir_fd, &char(file.name.str), 0)
		}
		file.file_exists = false
	}
	$if !windows {
		if file.dir_fd >= 0 { C.close(file.dir_fd); file.dir_fd = -1 }
	}
}
