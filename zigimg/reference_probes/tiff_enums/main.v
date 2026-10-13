module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_codec  = &p.TIFF(unsafe { nil })
	observed_stream = &p.ReadStream(unsafe { nil })
	observed_path   string
	observed_buffer []u8
)

fn snapshot(codec &p.TIFF, stream &p.ReadStream, buffer []u8) string {
	b := &codec.bitmap
	mut out := '${stream.get_pos()}|${stream.buffered_len()}|${buffer.hex()}|${codec.header.version}:${codec.header.idf_offset}|${codec.ifd.ifd_offset}:${codec.ifd.num_tag_entries}:${codec.ifd.next_ifd_offset}:${codec.ifd.tags_map.count()}|'
	mut iterator := codec.ifd.tags_map.key_iterator()
	for {
		key := iterator.next() or { break }
		tag := codec.ifd.tags_map.get(*key) or { panic('missing tag') }
		out += '${u16(*key)}:${tag.data_type}:${tag.data_count}:${tag.data_offset},'
	}
	out += '|${u16(b.compression)}:${b.image_width}:${b.image_height}:${b.photometric_interpretation}:${b.rows_per_strip}:${b.x_resolution[0]}:${b.x_resolution[1]}:${b.y_resolution[0]}:${b.y_resolution[1]}:${u16(b.resolution_unit)}:${b.new_subfile_type}:${b.samples_per_pixel}:${b.fill_order}:${b.planar_configuration}:${b.predictor}:${b.bits_per_sample.data.len}|'
	for v in b.bits_per_sample.storage {
		out += '${v},'
	}
	out += '|${b.extra_samples.data.len}|'
	for v in b.extra_samples.storage {
		out += '${v},'
	}
	storage := unsafe { (&u8(&b.color_map.storage[0])).vbytes(1024).hex() }
	out += '|${b.color_map.data.len}|${storage}|'
	for v in b.strip_offsets or { panic('missing offsets') } {
		out += '${v},'
	}
	out += '|'
	for v in b.strip_byte_counts or { panic('missing counts') } {
		out += '${v},'
	}
	return out
}

fn observe() {
	os.write_file(observed_path, snapshot(observed_codec, observed_stream, observed_buffer)) or {
		eprintln('OBSERVER ERROR: ${err}')
	}
}

fn record(line string, path string) string {
	fields := line.split('|')
	capacity := fields[0].int()
	endian := if fields[1] == '0' { p.TiffEndian.little } else { p.TiffEndian.big }
	decode := fields[2] == '1'
	reads := fields[3].int()
	data := hex.decode(fields[4]) or { panic(err) }
	mut buffer := []u8{len: capacity, init: u8(165)}
	mut stream := p.ReadStream.init_memory(data)
	mut file := os.File{}
	if capacity > 0 {
		os.write_file_array(path, data) or { panic(err) }
		file = os.open(path) or { panic(err) }
		stream = p.ReadStream.init_file(file, mut buffer)
	}
	mut codec := p.TIFF{
		endianess: endian
		header:    p.TiffHeader{
			version:    42
			idf_offset: 123
		}
		ifd:       p.TiffIFD.init(&stream, 1) or { panic(err) }
		bitmap:    p.TiffBitmapDescriptor{
			compression:                .packbits
			resolution_unit:            .cm
			image_width:                17
			image_height:               19
			photometric_interpretation: 2
			rows_per_strip:             7
			x_resolution:               [u32(23), 29]!
			y_resolution:               [u32(31), 37]!
			new_subfile_type:           41
			samples_per_pixel:          3
			fill_order:                 2
			planar_configuration:       2
			predictor:                  2
			strip_offsets:              [u32(11), 22]
			strip_byte_counts:          [u32(33), 44]
		}
	}
	codec.ifd.num_tag_entries = 77
	codec.ifd.next_ifd_offset = 0x55667788
	codec.ifd.tags_map.put(.orientation, p.TiffTagField{
		data_type:   4
		data_count:  1
		data_offset: 99
	}) or { panic(err) }
	codec.bitmap.bits_per_sample.resize(8)
	codec.bitmap.extra_samples.resize(8)
	for i in 0 .. 8 {
		codec.bitmap.bits_per_sample.data[i] = u16(100 + i)
		codec.bitmap.extra_samples.data[i] = u16(200 + i)
	}
	codec.bitmap.bits_per_sample.resize(3)
	codec.bitmap.extra_samples.resize(2)
	codec.bitmap.color_map.resize(256)
	for i in 0 .. 256 {
		codec.bitmap.color_map.data[i] = p.Rgba32{
			r: u8(i * 31)
			g: u8(i * 71)
			b: u8(i * 47)
			a: 99
		}
	}
	codec.bitmap.color_map.resize(4)
	if observed_path != '' {
		observed_codec = &codec
		observed_stream = &stream
		observed_buffer = unsafe { buffer }
	}
	mut out := ''
	for _ in 0 .. reads {
		codec.ifd.read_tags(endian) or {
			out += '${err.msg()}|' + snapshot(&codec, &stream, buffer) + '~'
			continue
		}
		if decode {
			codec.decode_bitmap(mut stream) or {
				out += '${err.msg()}|' + snapshot(&codec, &stream, buffer) + '~'
				continue
			}
		}
		out += 'ok|' + snapshot(&codec, &stream, buffer) + '~'
	}
	if capacity > 0 { file.close() }
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
