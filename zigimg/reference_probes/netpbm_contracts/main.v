module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_path   string
	observed_header = &p.NetpbmHeader(unsafe { nil })
	observed_reader = &p.ReadStream(unsafe { nil })
	observed_writer = &p.WriteStream(unsafe { nil })
	observed_input  []u8
	observed_output []u8
	observed_pixels []u8
	observed_op     int
)
fn header_text(h p.NetpbmHeader) string {
	return '${int(h.format)}:${if h.binary {
		1
	} else {
		0
	}}:${h.width}:${h.height}:${h.max_value}'
}

fn state() string {
	h := if observed_op == 0 || observed_op == 3 { header_text(*observed_header) } else { '-' }
	return '${observed_reader.get_pos()}|${observed_writer.get_pos()}|${h}|${observed_input.hex()}|${observed_output.hex()}|${observed_pixels.hex()}'
}

fn observe() {
	if observed_path != '' { os.write_file(observed_path, state()) or {
			eprintln('OBSERVER ERROR: ${err}')} }
}

fn pixels(format p.PixelFormat, count usize) p.PixelStorage {
	mut result := p.PixelStorage.init(format, count) or { panic(err) }
	mut raw := result.as_bytes()
	for i in 0 .. raw.len {
		raw[i] = u8(i * 37 + 19)
	}
	if format in [.indexed1, .indexed2, .indexed4, .grayscale1, .grayscale2, .grayscale4] {
		mask := if format in [.indexed1, .grayscale1] {
			u8(1)
		} else if format in [.indexed2, .grayscale2] {
			u8(3)
		} else {
			u8(15)
		}
		for i in 0 .. raw.len {
			raw[i] &= mask
		}
	}
	if format in [.rgb555, .bgr555] {
		for i in 0 .. int(count) {
			raw[i * 2 + 1] &= 127
		}
	}
	return result
}

fn options(tag int, binary bool) p.EncoderOptions {
	return match tag {
		0 {
			p.BmpEncoderOptions{}
		}
		1 {
			p.FarbfeldEncoderOptions{}
		}
		2 {
			p.GifEncoderOptions{}
		}
		3 {
			p.IffEncoderOptions{}
		}
		4 {
			p.JpegEncoderOptions{}
		}
		5 {
			p.PamEncoderOptions{}
		}
		6 {
			p.PbmEncoderOptions{
				binary: binary
			}
		}
		7 {
			p.PcxEncoderOptions{}
		}
		8 {
			p.PgmEncoderOptions{
				binary: binary
			}
		}
		9 {
			p.PngEncoderOptions{}
		}
		10 {
			p.PpmEncoderOptions{
				binary: binary
			}
		}
		11 {
			p.QoiEncoderOptions{}
		}
		12 {
			p.RasEncoderOptions{}
		}
		13 {
			p.SgiEncoderOptions{}
		}
		14 {
			p.TgaEncoderOptions{}
		}
		15 {
			p.TiffEncoderOptions{}
		}
		else {
			p.XbmEncoderOptions{}
		}
	}
}

fn codec_interface[T]() p.FormatInterface {
	$if T is p.PbmKind {
		return p.PBM.format_interface()
	} $else $if T is p.PgmKind {
		return p.PGM.format_interface()
	} $else {
		return p.PPM.format_interface()
	}
}

fn run_case[T](fields []string, data []u8) {
	op := fields[1].int()
	binary := fields[3] == '1'
	mut codec := p.Netpbm[T]{
		header: p.NetpbmHeader{
			format:    unsafe { p.NetpbmFormat(fields[2].int()) }
			binary:    binary
			width:     usize(fields[4].u64())
			height:    usize(fields[5].u64())
			max_value: usize(fields[6].u64())
		}
	}
	mut reader := p.ReadStream.init_memory(data)
	mut output := []u8{len: fields[9].int(), init: 165}
	mut writer := p.WriteStream.init_memory(mut output)
	start := fields[10].int()
	if start > 0 {
		if op in [int(3), 4, 5] {
			writer.seek_to(u64(start)) or { panic(err) }
		} else {
			reader.take(start) or { panic(err) }
		}
	}
	observed_header = &codec.header
	observed_reader = &reader
	observed_writer = &writer
	observed_input = unsafe { data[..] }
	observed_output = unsafe { output[..] }
	observed_pixels = []
	observed_op = op
	if op == 6 {
		format := codec.pixel_format() or { panic(err) }
		mut copy := codec.header
		copy.width ^= usize(0x12345678)
		copy.binary = !copy.binary
		println('ok|${header_text(codec.header)}|${u32(format)}|${header_text(copy)}')
		return
	}
	if op == 2 {
		mut status := 'ok'
		result := p.Netpbm.format_detect[T](mut reader) or {
			status = err.msg()
			false
		}
		println('${status}|${if result { 1 } else { 0 }}|' + state())
		return
	}
	if op in [int(3), 4, 5] {
		value := pixels(unsafe { p.PixelFormat(fields[7].u32()) }, usize(fields[8].u64()))
		observed_pixels = value.as_bytes()
		mut status := 'ok'
		if op == 3 {
			codec.write(mut writer, value) or { status = err.msg() }
		} else {
			image := p.ImageUnmanaged{
				width:  codec.header.width
				height: codec.header.height
				pixels: value
			}
			encoded_options := options(fields[11].int(), binary)
			if op == 5 {
				iface := codec_interface[T]()
				iface.write_image(mut writer, image, encoded_options) or { status = err.msg() }
			} else {
				tag := fields[11].int()
				enabled := (tag == 6 || tag == 8 || tag == 10) && binary
				p.Netpbm.write_image[T](mut writer, image, p.NetpbmEncoderOptions{ binary: enabled }) or {
					status = err.msg()
				}
			}
		}
		println('${status}|' + state())
		return
	}
	mut image := p.ImageUnmanaged{}
	if op == 0 {
		value := codec.read(mut reader) or {
			println('${err.msg()}|' + state())
			return
		}
		image = p.ImageUnmanaged{
			width:  codec.header.width
			height: codec.header.height
			pixels: value
		}
	} else {
		image = p.Netpbm.read_image[T](mut reader) or {
			println('${err.msg()}|' + state())
			return
		}
	}
	mut raw := image.raw_bytes()
	before := raw.hex()
	mut separate := '-'
	if raw.len > 0 {
		ptr := usize(raw.data)
		separate = if ptr < usize(data.data) || ptr >= usize(data.data) + usize(data.len) {
			'1'
		} else {
			'0'
		}
		raw[0] ^= 1
	}
	println('ok|' + state() +
		'|${image.width}|${image.height}|${u32(image.pixel_format())}|${image.pixels.len()}|${before}|${separate}|${raw.hex()}')
}

fn line_case(line string) {
	fields := line.split('|')
	data := hex.decode(fields[12]) or { panic(err) }
	match fields[0].int() {
		0 { run_case[p.PbmKind](fields, data) }
		1 { run_case[p.PgmKind](fields, data) }
		else { run_case[p.PpmKind](fields, data) }
	}
}

fn main() {
	if os.args.len > 1 {
		if os.args[1] == '--corpus' {
			for line in os.read_lines(os.args[2]) or { panic(err) } {
				line_case(line)
			}
			return
		}
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		line_case(os.args[3])
		return
	}
	mut common := p.NetpbmEncoderOptions{}
	mut pbm := p.PbmEncoderOptions{}
	mut pgm := p.PgmEncoderOptions{}
	mut ppm := p.PpmEncoderOptions{}
	println('${common.binary}|${pbm.binary}|${pgm.binary}|${ppm.binary}')
	common.binary = false
	pbm.binary = false
	pgm.binary = false
	ppm.binary = false
	println('${common.binary}|${pbm.binary}|${pgm.binary}|${ppm.binary}')
}
