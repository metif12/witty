module source_file_writer

#flag -I @VMODROOT/source_file_writer
#include "file_writer_shims.h"

fn C.witty_synthetic_seek(int, u64) int
fn C.witty_synthetic_file_drain(int, int, u64, voidptr, uint, voidptr, uint, &int) int

// Zig 0.15.2 fs.File.Writer, restricted to the write/flush operations used by
// src/synthetic/cli.zig and src/crash/sentry.zig. Vectors, positional fallback, and consume are source
// operations; native syscall declarations live in the small ABI shim.
pub struct FileWriter {
pub mut:
	fd        int  = 1
	buffer    []u8 = []u8{len: 2048}
	end       int
	position  u64
	streaming bool
	failed    bool
}

pub fn (mut writer FileWriter) write(data []u8) !int {
	if writer.end + data.len <= writer.buffer.len {
		for i, byte in data {
			writer.buffer[writer.end + i] = byte
		}
		writer.end += data.len
		return data.len
	}
	return writer.drain(data)
}

pub fn FileWriter.init(fd int, buffer_length int) FileWriter {
	return FileWriter{ fd: fd, buffer: []u8{len: buffer_length} }
}

fn (mut writer FileWriter) drain(data []u8) !int {
	if writer.failed { return error('WriteFailed') }
	mut unseekable := 0
	count := C.witty_synthetic_file_drain(writer.fd, int(!writer.streaming), writer.position,
		writer.buffer.data, uint(writer.end), data.data, uint(data.len), &unseekable)
	if count < 0 {
		if !writer.streaming && unseekable != 0 {
			writer.streaming = true
			if writer.position != 0 {
				position := writer.position
				writer.position = 0
				if C.witty_synthetic_seek(writer.fd, position) < 0 {
					writer.failed = true
					return error('WriteFailed')
				}
			}
			return 0
		}
		return error('WriteFailed')
	}
	writer.position += u64(count)
	if count < writer.end {
		remaining := writer.end - int(count)
		for i in 0 .. remaining {
			writer.buffer[i] = writer.buffer[int(count) + i]
		}
		writer.end = remaining
		return 0
	}
	consumed := int(count) - writer.end
	writer.end = 0
	return consumed
}

pub fn (mut writer FileWriter) flush() ! {
	for writer.end > 0 {
		writer.drain([]u8{})!
	}
}
