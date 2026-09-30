module zigimg

import zig_fmt

pub struct XBM {
pub mut:
	width     u32
	height    u32
	hotspot_x u32
	hotspot_y u32
}

pub fn XBM.format_detect(mut stream ReadStream) !bool {
	mut define_line_count := u32(0)
	mut found_non_define := false
	for !found_non_define {
		// The pinned source peeks without advancing: a leading #define line
		// is examined repeatedly until its debug-build u32 counter overflows.
		line := stream.peek_delimiter_inclusive(`\n`)!
		if xbm_is_define_line(line) {
			assert define_line_count < u32(0xffffffff)
			define_line_count++
		} else {
			found_non_define = true
		}
	}
	return define_line_count == 2 || define_line_count == 4
}

fn xbm_is_define_line(line []u8) bool {
	return line.len >= 7 && line[..7] == '#define'.bytes()
}

fn xbm_parse_define_value(line []u8) ?u32 {
	mut start := line.len
	for start > 0 && line[start - 1] != ` ` && line[start - 1] != `\t` {
		start--
	}
	value := zig_fmt.parse_int_unsigned(line[start..].bytestr(), 32, 10) or { return none }
	return u32(value)
}

fn xbm_hex_delimiter(byte u8) bool {
	return byte in [u8(`,`), ` `, `\t`, `\n`, `{`, `}`, `;`]
}

fn xbm_collect_hex_bytes(line []u8, mut bytes []u8) {
	mut index := 0
	for index < line.len {
		for index < line.len && xbm_hex_delimiter(line[index]) {
			index++
		}
		start := index
		for index < line.len && !xbm_hex_delimiter(line[index]) {
			index++
		}
		token := line[start..index]
		if token.len < 2 || token[0] != `0` || token[1] !in [u8(`x`), `X`] { continue
		 }
		value := zig_fmt.parse_int_unsigned(token[2..].bytestr(), 32, 16) or { continue }
		bytes << u8(value & 0xff)
		if value > 0xff { bytes << u8((value >> 8) & 0xff) }
	}
}

pub fn (mut codec XBM) read(mut stream ReadStream) !PixelStorage {
	mut width := ?u32(none)
	mut height := ?u32(none)
	mut hotspot_x := u32(0)
	mut hotspot_y := u32(0)
	mut first_pixel_line := []u8{}
	mut have_first_pixel_line := false
	mut line_full := stream.take_delimiter_inclusive(`\n`)!
	for line_full.len > 0 {
		mut length := line_full.len
		for length > 0 && line_full[length - 1] in [u8(` `), `\r`, `\n`] {
			length--
		}
		line := unsafe { line_full[..length] }
		if xbm_is_define_line(line) {
			value := xbm_parse_define_value(line) or { return error('InvalidData') }
			if width == none {
				width = value
			} else if height == none {
				height = value
			} else if hotspot_x == 0 {
				hotspot_x = value
			} else if hotspot_y == 0 {
				hotspot_y = value
			}
		} else {
			first_pixel_line = unsafe { line }
			have_first_pixel_line = true
			break
		}
		line_full = stream.take_delimiter_inclusive(`\n`)!
	}
	if width == none || height == none { return error('InvalidData') }
	codec.width = width or { panic('unreachable') }
	codec.height = height or { panic('unreachable') }
	codec.hotspot_x = hotspot_x
	codec.hotspot_y = hotspot_y
	pixel_count := usize(codec.width) * usize(codec.height)
	mut pixels := PixelStorage.init(.indexed1, pixel_count)!
	mut indexed := pixels as IndexedStorage1
	indexed.palette[0] = Rgba32{
		r: 255
		g: 255
		b: 255
		a: 255
	}
	indexed.palette[1] = Rgba32{
		r: 0
		g: 0
		b: 0
		a: 255
	}
	expected_bytes := (pixel_count + 7) / 8
	mut bytes := []u8{cap: int(expected_bytes)}
	if have_first_pixel_line { xbm_collect_hex_bytes(first_pixel_line, mut bytes) }
	for {
		line := stream.take_delimiter_inclusive(`\n`) or {
			if err.msg() == 'EndOfStream' { break
			 }
			return err
		}
		xbm_collect_hex_bytes(line, mut bytes)
	}
	if usize(bytes.len) < expected_bytes { return error('InvalidData') }
	for index := usize(0); index < pixel_count; index++ {
		indexed.indices[int(index)] = (bytes[int(index / 8)] >> u8(index & 7)) & 1
	}
	return pixels
}

pub fn XBM.read_image(mut stream ReadStream) !ImageUnmanaged {
	mut codec := XBM{}
	pixels := codec.read(mut stream)!
	return ImageUnmanaged{
		width:  usize(codec.width)
		height: usize(codec.height)
		pixels: pixels
	}
}

pub fn XBM.write_image(mut stream WriteStream, image ImageUnmanaged) ! {
	_ = stream
	_ = image
}
