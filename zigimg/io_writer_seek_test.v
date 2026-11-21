module zigimg

import os

#flag -I @VMODROOT/zigimg
#include "reference_probes/writer_seek/fixture_shims.h"

fn C.witty_writer_seek_setup(&char) int
fn C.witty_writer_seek_replace(int) int
fn C.witty_writer_seek_restore(&char, uint) int
fn C.witty_writer_seek_close() int
fn C.witty_writer_seek_cleanup() int
fn C.witty_writer_seek_drain(&u8, uint) int
fn C.witty_writer_seek_view(&u8, uint) int

fn test_writer_seek_flushes_before_caching_error_and_retains_it_after_replacement() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-writer-seek-cache-${os.getpid()}.owned')
		fd := C.witty_writer_seek_setup(path.str)
		assert fd >= 0
		defer { assert C.witty_writer_seek_cleanup() == 0 }
		mut buffer := []u8{len: 8, init: 165}
		mut writer := WriteStream.init_file_streaming(os.File{ fd: fd }, mut buffer)
		writer.seek_to(0)!
		assert C.witty_writer_seek_replace(1) == 0
		writer.write_all([u8(7)])!
		mut status := 'ok'
		writer.seek_to(7) or { status = err.msg() }
		assert status == 'Unseekable' && writer.get_pos() == 1 && writer.buffered().len == 0
		mut delivered := []u8{len: 16}
		assert C.witty_writer_seek_drain(delivered.data, uint(delivered.len)) == 1
		assert delivered[0] == 7
		restored := path + '.restored'
		assert C.witty_writer_seek_restore(restored.str, 32) == 0
		writer.write_all([u8(209), 210, 211])!
		status = 'ok'
		writer.seek_to(0) or { status = err.msg() }
		assert status == 'Unseekable' && writer.get_pos() == 4 && writer.buffered().len == 0
		assert buffer[..3] == [u8(209), 210, 211]
		mut contents := []u8{len: 64}
		assert C.witty_writer_seek_view(contents.data, uint(contents.len)) == 32
		assert contents[..3] == [u8(209), 210, 211]
		assert contents[3..32] == []u8{len: 29, init: u8((index + 3) * 37 + 19)}
	}
}

fn test_writer_failed_positional_transition_retains_pending_bytes_after_restore() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-writer-seek-failed-${os.getpid()}.owned')
		fd := C.witty_writer_seek_setup(path.str)
		assert fd >= 0
		defer { assert C.witty_writer_seek_cleanup() == 0 }
		mut buffer := []u8{len: 8, init: 165}
		mut writer := WriteStream.init_file(os.File{ fd: fd }, mut buffer)
		writer.seek_to(7)!
		assert C.witty_writer_seek_replace(1) == 0
		writer.write_all([u8(7)])!
		mut status := 'ok'
		writer.seek_to(0) or { status = err.msg() }
		assert status == 'Unexpected' && writer.get_pos() == 1
		assert writer.buffered() == [u8(7)]
		restored := path + '.restored'
		assert C.witty_writer_seek_restore(restored.str, 32) == 0
		writer.write_all([u8(209), 210, 211])!
		status = 'ok'
		writer.seek_to(0) or { status = err.msg() }
		assert status == 'Unexpected' && writer.get_pos() == 4
		assert writer.buffered() == [u8(7), 209, 210, 211]
		mut contents := []u8{len: 64}
		assert C.witty_writer_seek_view(contents.data, uint(contents.len)) == 32
		assert contents[..32] == []u8{len: 32, init: u8(index * 37 + 19)}
	}
}

fn test_writer_seek_flush_failure_on_closed_descriptor_precedes_native_seek() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-writer-seek-closed-${os.getpid()}.owned')
		fd := C.witty_writer_seek_setup(path.str)
		assert fd >= 0
		defer { assert C.witty_writer_seek_cleanup() == 0 }
		mut buffer := []u8{len: 8, init: 165}
		mut writer := WriteStream.init_file_streaming(os.File{ fd: fd }, mut buffer)
		assert C.witty_writer_seek_replace(1) == 0
		writer.write_all([u8(7)])!
		assert C.witty_writer_seek_close() == 0
		mut status := 'ok'
		writer.seek_to(0) or { status = err.msg() }
		assert status == 'Unexpected' && writer.get_pos() == 1 && writer.buffered() == [u8(7)]
		assert buffer == [u8(7), 165, 165, 165, 165, 165, 165, 165]
	}
}
