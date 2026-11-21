module main

import os
import zigimg as p

__global (
	observed_path   string
	observed_input  []u8
	observed_output []u8
	observed_reader = &p.ReadStream(unsafe { nil })
	observed_writer = &p.WriteStream(unsafe { nil })
	observed_image  = &p.ImageUnmanaged(unsafe { nil })
	trace           u64
)
fn state() string {
	pos := if observed_reader == unsafe { nil } { u64(0) } else { observed_reader.get_pos() }
	return '${trace}:${pos}:${observed_writer.get_pos()}|${observed_image.width}:${observed_image.height}:${observed_image.pixel_format()}|${observed_image.raw_bytes().hex()}|${observed_input.hex()}|${observed_output.hex()}'
}

fn observe() {
	if observed_path != '' { os.write_file(observed_path, state()) or {
			eprintln('OBSERVER ERROR: ${err}')} }
}

fn d0(mut r p.ReadStream) !bool {
	trace = trace * 10 + 1
	r.take_byte()!
	return false
}

fn d1(mut r p.ReadStream) !bool {
	trace = trace * 10 + 2
	r.take(2)!
	return true
}

fn d2(mut r p.ReadStream) !bool {
	trace = trace * 10 + 3
	r.take_byte()!
	return error('InvalidData')
}

fn r0(mut r p.ReadStream) !p.ImageUnmanaged {
	trace = trace * 10 + 1
	return p.ImageUnmanaged{
		width:  1
		height: uint(r.take_byte()!)
	}
}

fn r1(mut r p.ReadStream) !p.ImageUnmanaged {
	trace = trace * 10 + 2
	bytes := r.take(2)!
	return p.ImageUnmanaged{
		width:  2
		height: uint(bytes[1])
	}
}

fn r2(mut r p.ReadStream) !p.ImageUnmanaged {
	trace = trace * 10 + 3
	r.take_byte()!
	return error('InvalidData')
}

fn w0(mut w p.WriteStream, img p.ImageUnmanaged, opt p.EncoderOptions) ! {
	_ = img
	trace = trace * 10 + 1
	w.write_byte(u8(opt.format()))!
}

fn w1(mut w p.WriteStream, img p.ImageUnmanaged, opt p.EncoderOptions) ! {
	trace = trace * 10 + 2
	w.write_all([u8(img.width), u8(img.height), u8(opt.format())])!
}

fn w2(mut w p.WriteStream, img p.ImageUnmanaged, opt p.EncoderOptions) ! {
	_ = img
	_ = opt
	trace = trace * 10 + 3
	w.write_byte(238)!
	return error('InvalidData')
}

fn options(index int) p.EncoderOptions {
	tag := unsafe { p.Format(index) }
	return match tag {
		.bmp { p.BmpEncoderOptions{} }
		.farbfeld { p.FarbfeldEncoderOptions{} }
		.gif { p.GifEncoderOptions{} }
		.iff { p.IffEncoderOptions{} }
		.jpeg { p.JpegEncoderOptions{} }
		.pam { p.PamEncoderOptions{} }
		.pbm { p.PbmEncoderOptions{} }
		.pcx { p.PcxEncoderOptions{} }
		.pgm { p.PgmEncoderOptions{} }
		.png { p.PngEncoderOptions{} }
		.ppm { p.PpmEncoderOptions{} }
		.qoi { p.QoiEncoderOptions{} }
		.ras { p.RasEncoderOptions{} }
		.sgi { p.SgiEncoderOptions{} }
		.tga { p.TgaEncoderOptions{} }
		.tiff { p.TiffEncoderOptions{} }
		.xbm { p.XbmEncoderOptions{} }
	}
}

fn line_case(line string) {
	f := line.split('|').map(it.int())
	detects := [p.FormatDetectFn(d0), d1, d2]
	reads := [p.ReadImageFn(r0), r1, r2]
	writes := [p.WriteImageFn(w0), w1, w2]
	mut original := p.FormatInterface{
		format_detect: detects[f[1]]
		read_image:    reads[f[2]]
		write_image:   writes[f[3]]
	}
	mut copied := original
	mut changed := if f[0] < 2 { &original } else { &copied }
	if f[4] & 1 != 0 { changed.format_detect = detects[(f[1] + 1) % 3] }
	if f[4] & 2 != 0 { changed.read_image = reads[(f[2] + 1) % 3] }
	if f[4] & 4 != 0 { changed.write_image = writes[(f[3] + 1) % 3] }
	selected := if f[0] == 0 || f[0] == 2 { original } else { copied }
	bytes := []u8{len: f[5], init: u8(index * 37 + 11)}
	mut dest := []u8{len: f[6], init: 165}
	mut rd := p.ReadStream.init_memory(bytes)
	mut wr := p.WriteStream.init_memory(mut dest)
	if f[7] == 1 {
		if bytes.len > 0 { rd.seek_to(u64(bytes.len - 1)) or { panic(err) } }
		if dest.len > 0 { wr.seek_to(u64(dest.len - 1)) or { panic(err) } }
	}
	mut img := p.ImageUnmanaged{
		width:  2
		height: 3
	}
	trace = 0
	observed_input = unsafe { bytes }
	observed_output = unsafe { dest }
	observed_reader = &rd
	observed_writer = &wr
	observed_image = &img
	mut ds := ''
	if found := selected.format_detect(mut rd) {
		ds = '${int(found)}'
	} else {
		ds = err.msg()
	}
	mut rs := ''
	if loaded := selected.read_image(mut rd) {
		rs = '${loaded.width}:${loaded.height}:${loaded.pixel_format()}'
	} else {
		rs = err.msg()
	}
	mut ws := 'ok'
	selected.write_image(mut wr, img, options(f[8])) or { ws = err.msg() }
	println('d:${ds}|r:${rs}|w:${ws}|' + state())
}

fn trap_case(line string) {
	f := line.split('|')
	profile := f[2].int()
	formats := [p.PixelFormat.invalid, .rgb24, .grayscale8, .rgb24]
	mut img := p.ImageUnmanaged.create(if profile == 0 { uint(4) } else { uint(1) }, if profile == 0 {
		uint(2)
	} else if profile == 3 {
		uint(0)
	} else {
		uint(1)
	}, formats[profile]) or { panic(err) }
	mut bytes := img.raw_bytes()
	for i in 0 .. bytes.len {
		bytes[i] = u8(i * 37 + 19)
	}
	mut dest := []u8{len: f[3].int(), init: 165}
	mut wr := p.WriteStream.init_memory(mut dest)
	if f[4] == '1' && dest.len > 0 { wr.seek_to(u64(dest.len - 1)) or { panic(err) } }
	trace = 0
	observed_input = []u8{}
	observed_output = unsafe { dest }
	observed_reader = unsafe { nil }
	observed_writer = &wr
	observed_image = &img
	codec := if f[0] == 'png' { p.PNG.format_interface() } else { p.TGA.format_interface() }
	codec.write_image(mut wr, img, options(f[1].int())) or {
		eprintln('UNEXPECTED ${err}')
		return
	}
	eprintln('UNEXPECTED return')
}

fn main() {
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		trap_case(os.args[3])
		return
	}
	for line in os.read_lines(os.args[2]) or { panic(err) } {
		line_case(line)
	}
}
