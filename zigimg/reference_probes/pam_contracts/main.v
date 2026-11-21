module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_path     string
	observed_reader   = &p.ReadStream(unsafe { nil })
	observed_writer   = &p.WriteStream(unsafe { nil })
	observed_image    = &p.ImageUnmanaged(unsafe { nil })
	observed_input    []u8
	observed_output   []u8
	observed_comments []string
	observed_op       int
)
fn image_text(image p.ImageUnmanaged) string {
	mut result := '${image.width}:${image.height}:${u32(image.pixel_format())}:${image.pixels.len()}:${image.raw_bytes().hex()}:${image.animation.loop_count}:${image.animation.frames.len}'
	for frame in image.animation.frames {
		duration := frame.duration
		bits := unsafe { *(&u32(&duration)) }
		result += ':${u32(frame.pixels.pixel_format())}:${frame.pixels.len()}:${frame.pixels.as_bytes().hex()}:${bits}'
	}
	return result
}

fn comment_text(comments []string) string {
	mut result := '${comments.len}'
	for comment in comments {
		result += ':' + comment.bytes().hex()
	}
	return result
}

fn state() string {
	image := if observed_op >= 3 { image_text(*observed_image) } else { '-' }
	return '${observed_reader.get_pos()}|${observed_writer.get_pos()}|${observed_input.hex()}|${observed_output.hex()}|${image}|${comment_text(observed_comments)}'
}

fn observe() {
	if observed_path != '' { os.write_file(observed_path, state()) or {
			eprintln('OBSERVER ERROR: ${err}')} }
}

fn case_comments(variant int) []string {
	return match variant {
		1 { ['one', 'two'] }
		2 { ['', 'x\ny\r', 'π'] }
		3 { ['\xff\x00#%{x}'] }
		else { []string{} }
	}
}

fn pixels(format p.PixelFormat, count uint) p.PixelStorage {
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

fn options(tag int, comments []string, duration bool) p.EncoderOptions {
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
			p.PamEncoderOptions{
				comments:                comments
				add_duration_as_comment: duration
			}
		}
		6 {
			p.PbmEncoderOptions{
				binary: true
			}
		}
		7 {
			p.PcxEncoderOptions{}
		}
		8 {
			p.PgmEncoderOptions{
				binary: true
			}
		}
		9 {
			p.PngEncoderOptions{}
		}
		10 {
			p.PpmEncoderOptions{
				binary: true
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

fn image_record(mut image p.ImageUnmanaged, data []u8) string {
	before := image_text(image)
	mut raw := image.raw_bytes()
	mut separate := '-'
	if raw.len > 0 {
		ptr := uint(raw.data)
		separate = if ptr < uint(data.data) || ptr >= uint(data.data) + uint(data.len) {
			'1'
		} else {
			'0'
		}
		raw[0] ^= 1
	}
	mut independent := '1'
	for frame in image.animation.frames {
		mut bytes := frame.pixels.as_bytes()
		if bytes.len > 0 {
			if uint(bytes.data) == uint(raw.data) { independent = '0' }
			bytes[0] ^= 1
		}
	}
	return before + '|' + separate + '|' + independent + '|' + image_text(image)
}

fn line_case(line string) {
	f := line.split('|')
	op := f[0].int()
	data := hex.decode(f[15]) or { panic(err) }
	mut reader := p.ReadStream.init_memory(data)
	mut output := []u8{len: f[5].int(), init: 165}
	mut writer := p.WriteStream.init_memory(mut output)
	start := f[6].int()
	if start > 0 {
		if op >= 3 {
			writer.seek_to(u64(start)) or { panic(err) }
		} else {
			reader.take(start) or { panic(err) }
		}
	}
	observed_reader = &reader
	observed_writer = &writer
	observed_input = unsafe { data[..] }
	observed_output = unsafe { output[..] }
	observed_comments = case_comments(f[9].int())
	observed_op = op
	if op == 2 {
		mut status := 'ok'
		result := p.PAM.format_detect(mut reader) or {
			status = err.msg()
			false
		}
		println('${status}|${if result { 1 } else { 0 }}|' + state())
		return
	}
	if op >= 3 {
		mut image := p.ImageUnmanaged{
			width:  uint(f[3].u64())
			height: uint(f[4].u64())
			pixels: pixels(unsafe { p.PixelFormat(f[1].u32()) }, uint(f[2].u64()))
		}
		image.animation.loop_count = f[13].i32()
		duration_bits := f[14].u32()
		duration := unsafe { *(&f32(&duration_bits)) }
		for _ in 0 .. f[12].int() {
			image.animation.frames << p.AnimationFrame{
				pixels:   pixels(unsafe { p.PixelFormat(f[10].u32()) }, uint(f[11].u64()))
				duration: duration
			}
		}
		observed_image = &image
		selected := options(f[7].int(), observed_comments, f[8] == '1')
		mut status := 'ok'
		if op == 3 {
			p.PAM.write_frame(mut writer, image, selected) or { status = err.msg() }
		} else if op == 4 {
			p.PAM.write_image(mut writer, image, selected) or { status = err.msg() }
		} else {
			iface := p.PAM.format_interface()
			iface.write_image(mut writer, image, selected) or { status = err.msg() }
		}
		println('${status}|' + state())
		return
	}
	if op == 0 {
		mut images := p.PAM.read(mut reader) or {
			println('${err.msg()}|' + state())
			return
		}
		mut record := 'ok|${images.len}'
		for mut image in images {
			record += '|' + image_record(mut image, data)
		}
		println(record + '|' + state())
	} else {
		mut image := p.PAM.read_image(mut reader) or {
			println('${err.msg()}|' + state())
			return
		}
		println('ok|1|' + image_record(mut image, data) + '|' + state())
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
	mut backing := ['one', 'two']
	mut value := p.PamEncoderOptions{
		comments: unsafe { backing[..] }
	}
	before := comment_text(value.comments)
	println('${before}|${value.add_duration_as_comment}')
	copy := value
	backing[0] = 'changed'
	println('${comment_text(value.comments)}|${comment_text(copy.comments)}')
	value.comments = ['replaced']
	value.add_duration_as_comment = true
	println('${comment_text(value.comments)}|${value.add_duration_as_comment}|${comment_text(copy.comments)}|${copy.add_duration_as_comment}')
}
