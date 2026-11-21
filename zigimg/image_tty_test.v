module zigimg

import os

#flag -I @VMODROOT/zigimg
#include "reference_probes/image_tty/fixture_shims.h"

fn C.witty_image_tty_setup() int
fn C.witty_image_tty_path() &char
fn C.witty_image_tty_cleanup() int
fn C.witty_image_tty_state() int
fn C.witty_image_tty_session() int
fn C.witty_image_tty_refs() int
fn C.witty_image_tty_keeper_fd() int
fn C.witty_image_tty_seed(&u8, uint) int
fn C.witty_image_tty_read(int, &u8, uint) int

fn image_tty_check_direct_reader(buffered bool) ! {
	assert C.witty_image_tty_setup() == 0
	defer { assert C.witty_image_tty_cleanup() == 0 }
	seed := png_magic_header[..]
	assert C.witty_image_tty_seed(seed.data, uint(seed.len)) == seed.len
	file := os.File{
		fd: C.witty_image_tty_keeper_fd()
	}
	mut buffer := []u8{len: if buffered { 8 } else { 0 }, init: 165}
	mut stream := ReadStream.init_file(file, mut buffer)
	mut byte := []u8{len: 1, init: 182}
	if buffered {
		value := stream.take(1)!
		byte[0] = value[0]
	} else {
		stream.read_slice_all(mut byte)!
	}
	assert byte == seed[..1] && stream.get_pos() == 1
	assert C.witty_image_tty_state() == 0 && C.witty_image_tty_refs() == 1
	assert stream.buffered_len() == if buffered {
		7
	} else {
		0
	}
	mut remaining := []u8{len: 32}
	n := C.witty_image_tty_read(1, remaining.data, uint(remaining.len))
	if buffered {
		assert n == -1 && buffer == seed
	} else {
		assert n == 7 && remaining[..int(n)] == seed[1..]
	}
}

fn image_tty_check_reader(managed bool, decode bool) ! {
	assert C.witty_image_tty_setup() == 0
	defer { assert C.witty_image_tty_cleanup() == 0 }
	path := unsafe { cstring_to_vstring(C.witty_image_tty_path()) }
	seed := png_magic_header[..]
	assert C.witty_image_tty_seed(seed.data, uint(seed.len)) == seed.len
	assert C.witty_image_tty_state() == 0 && C.witty_image_tty_session() == 1
	mut buffer := []u8{len: 8, init: 165}
	for _ in 0 .. 2 {
		mut status := 'ok'
		if decode {
			if managed {
				Image.from_file_path(path, mut buffer) or { status = err.msg() }
			} else {
				ImageUnmanaged.from_file_path(path, mut buffer) or { status = err.msg() }
			}
		} else {
			if managed {
				Image.detect_format_from_file_path(path, mut buffer) or { status = err.msg() }
			} else {
				ImageUnmanaged.detect_format_from_file_path(path, mut buffer) or {
					status = err.msg()
				}
			}
		}
		assert status == 'Unseekable' && buffer == []u8{len: 8, init: 165}
		assert C.witty_image_tty_state() == 0 && C.witty_image_tty_refs() == 1
	}
	mut bytes := []u8{len: 32}
	n := C.witty_image_tty_read(1, bytes.data, uint(bytes.len))
	assert n == 8 && bytes[..int(n)] == seed
	assert C.witty_image_tty_read(1, bytes.data, uint(bytes.len)) == -1
	assert C.witty_image_tty_read(0, bytes.data, uint(bytes.len)) == -1
}

fn image_tty_check_writers() ! {
	assert C.witty_image_tty_setup() == 0
	defer { assert C.witty_image_tty_cleanup() == 0 }
	path := unsafe { cstring_to_vstring(C.witty_image_tty_path()) }
	assert C.witty_image_tty_state() == 0 && C.witty_image_tty_session() == 1
	mut raw := []u8{len: 24}
	for i in 0 .. raw.len {
		raw[i] = u8(i * 37 + 19)
	}
	image := ImageUnmanaged.from_raw_pixels(4, 2, raw, .rgb24)!
	for managed in [false, true] {
		for noop in [false, true] {
			opts := if noop {
				EncoderOptions(GifEncoderOptions{})
			} else {
				EncoderOptions(PngEncoderOptions{})
			}
			mut buffer := []u8{len: 8, init: 165}
			for _ in 0 .. 2 {
				if managed {
					image.to_managed().write_to_file_path(path, mut buffer, opts)!
				} else {
					image.write_to_file_path(path, mut buffer, opts)!
				}
				assert C.witty_image_tty_state() == 1 && C.witty_image_tty_refs() == 1
				assert image.raw_bytes() == raw
				mut bytes := []u8{len: 32}
				n := C.witty_image_tty_read(0, bytes.data, uint(bytes.len))
				if noop {
					assert n == -1 && buffer == []u8{len: 8, init: 165}
				} else {
					assert n == 8 && bytes[..int(n)] == png_magic_header[..]
						&& buffer == png_magic_header[..]
				}
				assert C.witty_image_tty_read(0, bytes.data, uint(bytes.len)) == -1
			}
		}
	}
}

fn test_public_image_tty_paths_preserve_session_and_streaming_contracts() {
	$if !windows {
		// This file runs in its own test process. Reader cases acquire no terminal;
		// the final writer group owns one until its handles close and the process exits.
		for buffered in [false, true] {
			image_tty_check_direct_reader(buffered)!
		}
		for managed in [false, true] {
			for decode in [false, true] {
				image_tty_check_reader(managed, decode)!
			}
		}
		image_tty_check_writers()!
	}
}
