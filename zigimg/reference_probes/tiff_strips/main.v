module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_codec          = &p.TIFF(unsafe { nil })
	observed_stream         = &p.ReadStream(unsafe { nil })
	observed_bytes          []u8
	observed_palette        []u8
	observed_format         u32
	observed_length         int
	observed_palette_length int
	observed_path           string
	observed_buffer         []u8
)

fn numbers(text string) []u32 {
	return if text == '' { []u32{} } else { text.split(',').map(it.u32()) }
}

fn list(values ?[]u32) string {
	if vs := values {
		mut out := 'P'
		for v in vs {
			out += '${v},'
		}
		return out
	}
	return 'N'
}

fn snapshot() string {
	b := &observed_codec.bitmap
	mut out := '${observed_stream.get_pos()}|${observed_stream.buffered_len()}|${observed_buffer.hex()}|${observed_format}:${observed_length}:${observed_bytes.hex()}|${observed_palette_length}|${observed_palette.hex()}|'
	out += '${u16(b.compression)}:${b.image_width}:${b.image_height}:${b.rows_per_strip}:${b.photometric_interpretation}:${b.samples_per_pixel}:${b.fill_order}:${b.planar_configuration}:${b.predictor}:${u16(b.resolution_unit)}:${b.new_subfile_type}:${b.x_resolution[0]}:${b.x_resolution[1]}:${b.y_resolution[0]}:${b.y_resolution[1]}|'
	out += list(b.strip_offsets) + '|' + list(b.strip_byte_counts) +
		'|${b.bits_per_sample.data.len}|'
	for v in b.bits_per_sample.storage {
		out += '${v},'
	}
	out += '|${b.extra_samples.data.len}|'
	for v in b.extra_samples.storage {
		out += '${v},'
	}
	storage := unsafe { (&u8(&b.color_map.storage[0])).vbytes(1024).hex() }
	return out + '|${b.color_map.data.len}|${storage}'
}

fn observe() {
	os.write_file(observed_path, snapshot()) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn record(line string, path string) string {
	fields := line.split('|')
	a := fields[..12].map(it.u32())
	bits := numbers(fields[12])
	data := hex.decode(fields[15]) or { panic(err) }
	mut buffer := []u8{len: int(a[0]), init: 165}
	mut stream := p.ReadStream.init_memory(data)
	mut file := os.File{}
	if a[0] > 0 {
		os.write_file_array(path, data) or { panic(err) }
		file = os.open(path) or { panic(err) }
		stream = p.ReadStream.init_file(file, mut buffer)
	}
	mut codec := p.TIFF{
		bitmap: p.TiffBitmapDescriptor{
			image_width:                a[2]
			image_height:               a[3]
			rows_per_strip:             a[4]
			compression:                unsafe { p.TiffCompressionType(a[11]) }
			photometric_interpretation: u16(a[8])
			predictor:                  u16(a[9])
			samples_per_pixel:          u16(a[10])
			x_resolution:               [u32(23), 29]!
			y_resolution:               [u32(31), 37]!
			new_subfile_type:           41
			resolution_unit:            .cm
			fill_order:                 2
			planar_configuration:       2
		}
	}
	codec.bitmap.strip_offsets = if fields[13] == 'N' { none } else { numbers(fields[13]) }
	codec.bitmap.strip_byte_counts = if fields[14] == 'N' { none } else { numbers(fields[14]) }
	codec.bitmap.bits_per_sample.resize(8)
	codec.bitmap.extra_samples.resize(8)
	codec.bitmap.color_map.resize(256)
	for i in 0 .. 8 {
		codec.bitmap.bits_per_sample.data[i] = u16(100 + i)
		codec.bitmap.extra_samples.data[i] = u16(200 + i)
	}
	codec.bitmap.bits_per_sample.resize(uint(bits.len))
	for i, v in bits {
		codec.bitmap.bits_per_sample.data[i] = u16(v)
	}
	codec.bitmap.extra_samples.resize(2)
	for i in 0 .. 256 {
		codec.bitmap.color_map.data[i] = p.Rgba32{
			r: u8(i * 17)
			g: u8(i * 59)
			b: u8(i * 97)
			a: 201
		}
	}
	codec.bitmap.color_map.resize(uint(a[7]))
	formats := [p.PixelFormat.grayscale1, .grayscale8, .indexed8, .rgb24, .rgba32, .grayscale16]
	mut pixels := p.PixelStorage.init(formats[int(a[1])], uint(a[5])) or { panic(err) }
	mut bytes := pixels.as_bytes()
	for i in 0 .. bytes.len {
		bytes[i] = if a[1] == 0 { u8(1) } else { u8(165) }
	}
	mut palette_bytes := []u8{}
	match mut pixels {
		p.IndexedStorage8 {
			for i in 0 .. 256 {
				pixels.palette[i] = p.Rgba32{
					r: u8(i * 31)
					g: u8(i * 71)
					b: u8(i * 47)
					a: 99
				}
			}
			palette_bytes = unsafe { (&u8(pixels.palette.data)).vbytes(1024) }
			pixels.resize_palette(uint(a[6]))
		}
		else {}
	}

	observed_codec = &codec
	observed_stream = &stream
	observed_bytes = unsafe { bytes }
	observed_palette = unsafe { palette_bytes }
	observed_format = u32(pixels.pixel_format())
	observed_length = int(pixels.len())
	observed_palette_length = if a[1] == 2 { int(a[6]) } else { 0 }
	observed_buffer = unsafe { buffer }
	mut status := 'ok'
	codec.read_strips(mut stream, mut pixels) or { status = err.msg() }
	out := status + '|' + snapshot()
	if a[0] > 0 { file.close() }
	return out
}

fn main() {
	if os.args.len == 4 && os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		println(record(os.args[3], os.args[2] + '.bin'))
		return
	}
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		println(record(line, os.args[1] + '.v.bin'))
	}
}
