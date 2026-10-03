module zigimg

import hash.crc32
import os

fn png_reader_test_chunk(name string, payload []u8) []u8 {
	mut bytes := []u8{}
	append_be_u32(mut bytes, u32(payload.len))
	bytes << name.bytes()
	bytes << payload
	append_be_u32(mut bytes, crc32.sum(bytes[4..]))
	return bytes
}

// A stored zlib block makes the fixture's row bytes visible. The pinned
// decompressor ignores Adler32; the differential runner checks that behavior.
fn png_reader_test_fixture(width u32, height u32, depth u8, color u8, interlace u8, raw []u8, before []u8, split int) []u8 {
	mut header := []u8{}
	append_be_u32(mut header, width)
	append_be_u32(mut header, height)
	header << [depth, color, u8(0), 0, interlace]
	mut encoded := [u8(0x78), 1, 1, u8(raw.len), u8(raw.len >> 8), u8(~u16(raw.len)),
		u8(~u16(raw.len) >> 8)]
	encoded << raw
	encoded << [u8(0), 0, 0, 0]
	mut bytes := png_magic_header[..].clone()
	bytes << png_reader_test_chunk('IHDR', header)
	bytes << before
	bytes << png_reader_test_chunk('IDAT', encoded[..split])
	bytes << png_reader_test_chunk('IDAT', encoded[split..])
	bytes << png_reader_test_chunk('IEND', [])
	return bytes
}

fn test_png_reader_adam7_packed_samples_and_default_transparency() {
	// Six pass rows for a 3x3 one-bit checkerboard (empty passes omitted).
	raw := [u8(0), 0, 0, 0, 0, 0, 0, 0x80, 0, 0x80, 0, 0xa0]
	bytes := png_reader_test_fixture(3, 3, 1, 0, 1, raw, png_reader_test_chunk('tRNS', [
		u8(0),
		1,
	]), 3)
	mut stream := ReadStream.init_memory(bytes)
	plain := png_load(mut stream, PngReaderOptions{})!
	assert plain.pixel_format() == .grayscale1
	assert plain.raw_bytes() == [u8(0), 1, 0, 1, 0, 1, 0, 1, 0]
	assert stream.get_pos() == u64(bytes.len)
	stream = ReadStream.init_memory(bytes)
	image := PNG.read_image(mut stream)!
	assert image.width == 3 && image.height == 3 && image.pixel_format() == .grayscale8_alpha
	assert image.raw_bytes() == [u8(0), 255, 1, 0, 0, 255, 1, 0, 0, 255, 1, 0, 0, 255, 1, 0, 0,
		255]
}

fn test_png_reader_indexed_palette_transparency_and_palette_expansion() {
	mut before := png_reader_test_chunk('PLTE', [u8(10), 20, 30, 40, 50, 60, 70, 80, 90, 100, 110,
		120])
	before << png_reader_test_chunk('tRNS', [u8(0), 127])
	bytes := png_reader_test_fixture(4, 1, 2, 3, 0, [u8(0), 0x1b], before, 1)
	mut stream := ReadStream.init_memory(bytes)
	indexed := PNG.read_image(mut stream)!
	assert indexed.pixel_format() == .indexed2 && indexed.raw_bytes() == [u8(0), 1, 2, 3]
	palette := indexed.pixels.get_palette() or { panic('missing palette') }
	assert palette.len == 4
	assert palette[0] == Rgba32{
		r: 10
		g: 20
		b: 30
		a: 0
	}
	assert palette[1] == Rgba32{
		r: 40
		g: 50
		b: 60
		a: 127
	}
	assert palette[3] == Rgba32{
		r: 100
		g: 110
		b: 120
		a: 255
	}
	mut options := PngCustomReaderOptions2.init(PngTrnsProcessor{}, PngPlteProcessor{})
	stream = ReadStream.init_memory(bytes)
	expanded := png_load(mut stream, options.get())!
	assert expanded.pixel_format() == .rgba32
	assert expanded.raw_bytes() == [u8(10), 20, 30, 0, 40, 50, 60, 127, 70, 80, 90, 255, 100, 110,
		120, 255]
	assert options.processor1.processed && options.processor2.processed
}

fn test_png_reader_16_bit_channels_use_native_byte_order() {
	bytes := png_reader_test_fixture(1, 1, 16, 6, 0, [u8(0), 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc,
		0xde, 0xf0], [], 2)
	mut stream := ReadStream.init_memory(bytes)
	image := PNG.read_image(mut stream)!
	match image.pixels {
		Rgba64Pixels { assert image.pixels.data == [
				Rgba64{
					r: 0x1234
					g: 0x5678
					b: 0x9abc
					a: 0xdef0
				},
			] }
		else { assert false }
	}
}

struct PngReaderTestTracker {
mut:
	chunks     []u32
	lengths    []u32
	positions  []u64
	rows       int
	fail_chunk u32
	fail_row   bool
}

fn png_reader_test_notify(context voidptr, mut data PngChunkProcessData) !PixelFormat {
	mut tracker := unsafe { &PngReaderTestTracker(context) }
	tracker.chunks << data.chunk_id
	tracker.lengths << data.chunk_length
	tracker.positions << data.read_stream.get_pos()
	if tracker.fail_chunk == data.chunk_id { return error('Unsupported') }
	return data.current_format
}

fn png_reader_test_row(context voidptr, mut data PngRowProcessData) !PixelFormat {
	mut tracker := unsafe { &PngReaderTestTracker(context) }
	tracker.rows++
	if tracker.fail_row { return error('Unsupported') }
	return data.dest_format
}

fn test_png_reader_notifies_idat_before_rows_with_initial_chunk_length() {
	bytes := png_reader_test_fixture(2, 1, 8, 2, 0, [u8(0), 1, 2, 3, 4, 5, 6], [], 3)
	mut stream := ReadStream.init_memory(bytes)
	mut tracker := PngReaderTestTracker{}
	options := PngReaderOptions.init_with_processors([
		PngReaderProcessor.init(png_chunk_any.id, unsafe { voidptr(&tracker) },
			png_reader_test_notify, none, png_reader_test_row),
	])
	image := png_load(mut stream, options)!
	assert image.raw_bytes() == [u8(1), 2, 3, 4, 5, 6]
	assert tracker.chunks == [png_chunk_ihdr.id, png_chunk_idat.id, png_chunk_idat.id, png_chunk_iend.id]
	assert tracker.lengths == [u32(13), 3, 3, 0] // Consecutive IDAT lengths are not republished upstream.
	assert tracker.positions == [u64(33), 48, 75, 87]
	assert tracker.rows == 1
}

fn test_png_reader_preserves_callback_errors_and_crc_read_ahead_order() {
	bytes := png_reader_test_fixture(2, 1, 8, 2, 0, [u8(0), 1, 2, 3, 4, 5, 6], [], 3)
	for fail in [png_chunk_ihdr.id, png_chunk_idat.id, u32(0)] {
		mut stream := ReadStream.init_memory(bytes)
		mut tracker := PngReaderTestTracker{
			fail_chunk: fail
			fail_row:   fail == 0
		}
		options := PngReaderOptions.init_with_processors([
			PngReaderProcessor.init(png_chunk_any.id, unsafe { voidptr(&tracker) },
				png_reader_test_notify, none, png_reader_test_row),
		])
		mut failure := ''
		_ = png_load(mut stream, options) or {
			failure = err.msg()
			ImageUnmanaged{}
		}
		assert failure == if fail == png_chunk_idat.id {
			'InvalidData'
		} else {
			'Unsupported'
		}
		assert stream.get_pos() == if fail == png_chunk_ihdr.id {
			u64(33)
		} else if fail == png_chunk_idat.id {
			u64(48)
		} else {
			u64(75)
		}
		assert tracker.rows == if fail == 0 {
			1
		} else {
			0
		}
	}
	mut corrupt := bytes.clone()
	corrupt[47] ^= 1
	mut stream := ReadStream.init_memory(corrupt)
	mut tracker := PngReaderTestTracker{}
	options := PngReaderOptions.init_with_processors([
		PngReaderProcessor.init(png_chunk_any.id, unsafe { voidptr(&tracker) },
			png_reader_test_notify, none, png_reader_test_row),
	])
	mut failure := ''
	_ = png_load(mut stream, options) or {
		failure = err.msg()
		ImageUnmanaged{}
	}
	assert failure == 'InvalidData' && stream.get_pos() == 48
	assert tracker.chunks == [png_chunk_ihdr.id] && tracker.rows == 0
}

fn test_png_reader_preserves_ignored_iend_crc_and_nonconsecutive_idat_error() {
	mut bytes := png_reader_test_fixture(1, 1, 8, 0, 0, [u8(0), 42], [], 3)
	bytes[bytes.len - 1] ^= 1
	mut stream := ReadStream.init_memory(bytes)
	image := PNG.read_image(mut stream)!
	assert image.raw_bytes() == [u8(42)] && stream.get_pos() == u64(bytes.len)
	mut nonconsecutive := bytes[..bytes.len - 12].clone()
	nonconsecutive << png_reader_test_chunk('abCd', [u8(1)])
	nonconsecutive << png_reader_test_chunk('IDAT', [u8(1)])
	nonconsecutive << png_reader_test_chunk('IEND', [])
	stream = ReadStream.init_memory(nonconsecutive)
	mut failure := ''
	_ = PNG.read_image(mut stream) or {
		failure = err.msg()
		ImageUnmanaged{}
	}
	assert failure == 'InvalidData'
	assert stream.get_pos() == u64(bytes.len - 12 + 13 + 8)
}

fn test_png_reader_runs_through_small_file_buffers_and_image_registry() {
	bytes := png_reader_test_fixture(2, 1, 8, 2, 0, [u8(0), 1, 2, 3, 4, 5, 6], [], 3)
	path := os.join_path(os.temp_dir(), 'witty-png-reader-${os.getpid()}.png')
	os.write_file_array(path, bytes)!
	defer { os.rm(path) or {} }
	for capacity in [17, 33, 4096] {
		mut buffer := []u8{len: capacity}
		mut file := os.open(path)!
		mut stream := ReadStream.init_file(file, mut buffer)
		image := PNG.read_image(mut stream)!
		assert image.raw_bytes() == [u8(1), 2, 3, 4, 5, 6]
		assert stream.get_pos() == u64(bytes.len)
		file.close()
	}
	// The source holds IHDR bytes across takeInt(CRC). Rebasing a small file
	// buffer then overwrites that borrowed payload before the CRC comparison.
	for capacity in [16, 31] {
		mut buffer := []u8{len: capacity}
		mut file := os.open(path)!
		mut stream := ReadStream.init_file(file, mut buffer)
		mut failure := ''
		_ = PNG.read_image(mut stream) or {
			failure = err.msg()
			ImageUnmanaged{}
		}
		assert failure == 'InvalidData' && stream.get_pos() == 33
		file.close()
	}
	mut buffer := []u8{len: 4096}
	managed := Image.from_file_path(path, mut buffer)!
	unmanaged := ImageUnmanaged.from_memory(bytes)!
	assert managed.raw_bytes() == unmanaged.raw_bytes() && managed.pixel_format() == .rgb24
}
