module main

import os
import zigimg

const formats = [zigimg.PixelFormat.indexed1, .indexed2, .indexed4, .indexed8, .grayscale1,
	.grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8_alpha, .grayscale16_alpha,
	.rgb24, .rgb48, .rgba32, .rgba64, .indexed16, .invalid, .rgb332, .rgb565]!

fn pixels_for(format zigimg.PixelFormat, count uint, seed int) zigimg.PixelStorage {
	if format == .invalid { return zigimg.InvalidPixels{} }
	pixels := zigimg.PixelStorage.init(format, count) or { panic(err) }
	mut bytes := pixels.as_bytes()
	depth := if format in [.indexed1, .grayscale1] {
		u8(1)
	} else if format in [.indexed2, .grayscale2] {
		u8(2)
	} else if format in [.indexed4, .grayscale4] {
		u8(4)
	} else {
		u8(8)
	}
	for i, mut byte in bytes {
		byte = u8(i * 37 + seed * 19 + i / 7)
		if depth < 8 { byte &= u8((u16(1) << depth) - 1) }
	}
	return pixels
}

__global (
	observed_path   string
	observed_writer = &zigimg.WriteStream(unsafe { nil })
	observed_pixels []u8
	observed_output []u8
)
fn snapshot(writer &zigimg.WriteStream, pixels []u8, output []u8) string {
	return '${writer.get_pos()}|${output.hex()}|${pixels.hex()}'
}

fn observe() {
	os.write_file(observed_path, snapshot(observed_writer, observed_pixels, observed_output)) or {
		eprintln('OBSERVER ERROR: ${err}')
	}
}

fn record(line string) string {
	p := line.split('|').map(it.u64())
	pixels := pixels_for(formats[int(p[0])], uint(p[3]), int(p[6]))
	header := zigimg.PngHeaderData{
		compression_method: .deflate
		filter_method:      .adaptive
		interlace_method:   .none
		width:              u32(p[1])
		height:             u32(p[2])
		bit_depth:          u8(p[4])
		color_type:         unsafe { zigimg.PngColorType(u8(p[5])) }
	}
	choice := if p[7] == 6 {
		zigimg.PngFilterChoice(zigimg.PngTryAll{})
	} else if p[7] == 5 {
		zigimg.PngFilterChoice(zigimg.PngHeuristic{})
	} else {
		zigimg.PngFilterChoice(zigimg.PngSpecified{
			filter: unsafe { zigimg.PngFilterType(u8(p[7])) }
		})
	}
	mut bytes := []u8{len: int(p[8]), init: u8(165)}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	if observed_path != '' {
		observed_writer = &writer
		observed_pixels = unsafe { pixels.as_bytes() }
		observed_output = unsafe { bytes }
	}
	zigimg.png_filter(mut writer, pixels, choice, header) or {
		return 'E${err.msg()}|' + snapshot(&writer, pixels.as_bytes(), bytes)
	}
	return 'ok|' + snapshot(&writer, pixels.as_bytes(), bytes)
}

fn main() {
	if os.args.len == 4 && os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		println(record(os.args[3]))
		return
	}
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		println(record(line))
	}
}
