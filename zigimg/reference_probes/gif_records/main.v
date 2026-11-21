module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_word   = &u8(unsafe { nil })
	observed_codec  = &p.GIF(unsafe { nil })
	observed_stream = &p.ReadStream(unsafe { nil })
	observed_path   string
	observed_toss   bool
)
fn packed_bytes[T](value T) string {
	return unsafe { (&u8(&value)).vbytes(int(sizeof(T))).hex() }
}

fn snapshot(codec &p.GIF) string {
	mut out := packed_bytes(codec.header) + '|' +
		unsafe { (&u8(codec.global_color_table.data.data)).vbytes(codec.global_color_table.data.len * 3).hex() } +
		'|'
	for frame in codec.frames {
		if control := frame.graphics_control {
			out += packed_bytes(control)
		} else {
			out += '-'
		}
		out += ':'
		for image in frame.sub_images {
			out += packed_bytes(image.image_descriptor) + ':' + image.pixels.hex() + ','
		}
		out += ';'
	}
	out += '|${codec.comments.len}|'
	for info in codec.application_infos {
		out += info.application_identifier[..].hex() + info.authentification_code[..].hex() + ':' +
			info.data.hex() + ';'
	}
	return out
}

fn observe() {
	out := if observed_word != unsafe { nil } {
		'${*observed_word}'
	} else if observed_toss {
		'${observed_stream.get_pos()}'
	} else {
		'${observed_stream.get_pos()}|' + snapshot(observed_codec)
	}
	os.write_file(observed_path, out) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn narrow(field string, value u8) {
	mut h := p.GifHeaderFlags{
		raw: 165
	}
	mut d := p.GifImageDescriptorFlags{
		raw: 165
	}
	mut c := p.GifGraphicControlExtensionFlags{
		raw: 165
	}
	match field {
		'header_size' {
			observed_word = &h.raw
			h.set_global_color_table_size(value)
		}
		'resolution' {
			observed_word = &h.raw
			h.set_color_resolution(value)
		}
		'local_size' {
			observed_word = &d.raw
			d.set_local_color_table_size(value)
		}
		'descriptor_reserved' {
			observed_word = &d.raw
			d.set_reserved(value)
		}
		'disposal' {
			observed_word = &c.raw
			c.set_disposal_method(unsafe { p.GifDisposeMethod(value) })
		}
		'control_reserved' {
			observed_word = &c.raw
			c.set_reserved(value)
		}
		else {
			panic('unknown field')
		}
	}

	eprintln('UNEXPECTED: narrow mutation returned')
}

fn decode(encoded string, short_loop bool) {
	data := hex.decode(encoded) or { panic(err) }
	mut stream := p.ReadStream.init_memory(data)
	mut codec := p.GIF.init()
	observed_codec = &codec
	observed_stream = &stream
	if short_loop {
		codec.application_infos << p.GifApplicationExtension{
			application_identifier: [u8(`N`), `E`, `T`, `S`, `C`, `A`, `P`, `E`]!
			authentification_code:  [u8(`2`), `.`, `0`]!
			data:                   [u8(1)]
		}
		_ = codec.loop_count()
	} else {
		if _ := codec.read(mut stream) {
			eprintln('UNEXPECTED: decoder returned')
		} else {
			eprintln('UNEXPECTED: recoverable ${err}')
		}
	}
}

fn main() {
	if os.args.len > 1 {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		if os.args[1] == '--toss' {
			mut stream := p.ReadStream.init_memory('abcd'.bytes())
			stream.seek_to(os.args[3].u64()) or { panic(err) }
			observed_stream = &stream
			observed_toss = true
			stream.toss(uint(os.args[4].u64()))
			eprintln('UNEXPECTED: toss returned')
			return
		}
		if os.args[1] == '--narrow' {
			narrow(os.args[3], u8(os.args[4].int()))
		} else {
			decode(os.args[3], os.args[1] == '--loop')
		}
		return
	}
	for raw in 0 .. 256 {
		for n in 0 .. 8 {
			mut x := p.GifHeaderFlags{
				raw: u8(raw)
			}
			copied := x
			x.set_global_color_table_size(u8(n))
			println('H|${raw}|0|${n}|${x.raw}|${x.global_color_table_size()}|${x.sorted()}|${x.color_resolution()}|${x.use_global_color_table()}|${copied.raw}')
		}
	}
	for raw in 0 .. 256 {
		for n in 0 .. 2 {
			mut x := p.GifHeaderFlags{
				raw: u8(raw)
			}
			copied := x
			x.set_sorted(n != 0)
			println('H|${raw}|1|${n}|${x.raw}|${x.global_color_table_size()}|${x.sorted()}|${x.color_resolution()}|${x.use_global_color_table()}|${copied.raw}')
		}
	}
	for raw in 0 .. 256 {
		for n in 0 .. 8 {
			mut x := p.GifHeaderFlags{
				raw: u8(raw)
			}
			copied := x
			x.set_color_resolution(u8(n))
			println('H|${raw}|2|${n}|${x.raw}|${x.global_color_table_size()}|${x.sorted()}|${x.color_resolution()}|${x.use_global_color_table()}|${copied.raw}')
		}
	}
	for raw in 0 .. 256 {
		for n in 0 .. 2 {
			mut x := p.GifHeaderFlags{
				raw: u8(raw)
			}
			copied := x
			x.set_use_global_color_table(n != 0)
			println('H|${raw}|3|${n}|${x.raw}|${x.global_color_table_size()}|${x.sorted()}|${x.color_resolution()}|${x.use_global_color_table()}|${copied.raw}')
		}
	}
	for raw in 0 .. 256 {
		for n in 0 .. 8 {
			mut x := p.GifImageDescriptorFlags{
				raw: u8(raw)
			}
			copied := x
			x.set_local_color_table_size(u8(n))
			println('D|${raw}|0|${n}|${x.raw}|${x.local_color_table_size()}|${x.reserved()}|${x.sort()}|${x.is_interlaced()}|${x.has_local_color_table()}|${copied.raw}')
		}
	}
	for raw in 0 .. 256 {
		for n in 0 .. 4 {
			mut x := p.GifImageDescriptorFlags{
				raw: u8(raw)
			}
			copied := x
			x.set_reserved(u8(n))
			println('D|${raw}|1|${n}|${x.raw}|${x.local_color_table_size()}|${x.reserved()}|${x.sort()}|${x.is_interlaced()}|${x.has_local_color_table()}|${copied.raw}')
		}
	}
	for raw in 0 .. 256 {
		for n in 0 .. 2 {
			mut x := p.GifImageDescriptorFlags{
				raw: u8(raw)
			}
			copied := x
			x.set_sort(n != 0)
			println('D|${raw}|2|${n}|${x.raw}|${x.local_color_table_size()}|${x.reserved()}|${x.sort()}|${x.is_interlaced()}|${x.has_local_color_table()}|${copied.raw}')
		}
	}
	for raw in 0 .. 256 {
		for n in 0 .. 2 {
			mut x := p.GifImageDescriptorFlags{
				raw: u8(raw)
			}
			copied := x
			x.set_is_interlaced(n != 0)
			println('D|${raw}|3|${n}|${x.raw}|${x.local_color_table_size()}|${x.reserved()}|${x.sort()}|${x.is_interlaced()}|${x.has_local_color_table()}|${copied.raw}')
		}
	}
	for raw in 0 .. 256 {
		for n in 0 .. 2 {
			mut x := p.GifImageDescriptorFlags{
				raw: u8(raw)
			}
			copied := x
			x.set_has_local_color_table(n != 0)
			println('D|${raw}|4|${n}|${x.raw}|${x.local_color_table_size()}|${x.reserved()}|${x.sort()}|${x.is_interlaced()}|${x.has_local_color_table()}|${copied.raw}')
		}
	}
	for raw in 0 .. 256 {
		for n in 0 .. 2 {
			mut x := p.GifGraphicControlExtensionFlags{
				raw: u8(raw)
			}
			copied := x
			x.set_has_transparent_color(n != 0)
			println('C|${raw}|0|${n}|${x.raw}|${x.has_transparent_color()}|${x.user_input()}|${u8(x.disposal_method())}|${x.reserved()}|${copied.raw}')
		}
	}
	for raw in 0 .. 256 {
		for n in 0 .. 2 {
			mut x := p.GifGraphicControlExtensionFlags{
				raw: u8(raw)
			}
			copied := x
			x.set_user_input(n != 0)
			println('C|${raw}|1|${n}|${x.raw}|${x.has_transparent_color()}|${x.user_input()}|${u8(x.disposal_method())}|${x.reserved()}|${copied.raw}')
		}
	}
	for raw in 0 .. 256 {
		for n in 0 .. 8 {
			mut x := p.GifGraphicControlExtensionFlags{
				raw: u8(raw)
			}
			copied := x
			x.set_disposal_method(unsafe { p.GifDisposeMethod(u8(n)) })
			println('C|${raw}|2|${n}|${x.raw}|${x.has_transparent_color()}|${x.user_input()}|${u8(x.disposal_method())}|${x.reserved()}|${copied.raw}')
		}
	}
	for raw in 0 .. 256 {
		for n in 0 .. 8 {
			mut x := p.GifGraphicControlExtensionFlags{
				raw: u8(raw)
			}
			copied := x
			x.set_reserved(u8(n))
			println('C|${raw}|3|${n}|${x.raw}|${x.has_transparent_color()}|${x.user_input()}|${u8(x.disposal_method())}|${x.reserved()}|${copied.raw}')
		}
	}
	println('DEFAULT|${packed_bytes(p.GifHeaderFlags{})}|${packed_bytes(p.GifImageDescriptorFlags{})}|${packed_bytes(p.GifGraphicControlExtensionFlags{})}|${packed_bytes(p.GifHeader{})}|${packed_bytes(p.GifImageDescriptor{})}|${packed_bytes(p.GifGraphicControlExtension{})}')
	for seed in [u16(0), 1, 255, 256, 32768, 65535] {
		mut h := p.GifHeader{
			magic:                  [u8(`G`), `I`, `F`]!
			version:                [u8(`8`), `9`, `a`]!
			width:                  seed
			height:                 seed
			flags:                  p.GifHeaderFlags{
				raw: u8(seed)
			}
			background_color_index: u8(seed)
			pixel_aspect_ratio:     u8(seed)
		}
		hc := h
		h.magic[0] = `X`
		h.version[2] = `b`
		h.width = 17
		h.height = 18
		h.flags.set_sorted(true)
		h.background_color_index = 19
		h.pixel_aspect_ratio = 20
		println('HEADER|${seed}|${packed_bytes(hc)}|${packed_bytes(h)}')
		mut d := p.GifImageDescriptor{
			left_position: seed
			top_position:  seed
			width:         seed
			height:        seed
			flags:         p.GifImageDescriptorFlags{
				raw: u8(seed)
			}
		}
		dc := d
		d.left_position = 17
		d.top_position = 18
		d.width = 19
		d.height = 20
		d.flags.set_is_interlaced(true)
		println('DESCRIPTOR|${seed}|${packed_bytes(dc)}|${packed_bytes(d)}')
		mut c := p.GifGraphicControlExtension{
			flags:                   p.GifGraphicControlExtensionFlags{
				raw: u8(seed)
			}
			delay_time:              seed
			transparent_color_index: u8(seed)
		}
		cc := c
		c.flags.set_reserved(3)
		c.delay_time = 17
		c.transparent_color_index = 18
		println('CONTROL|${seed}|${packed_bytes(cc)}|${packed_bytes(c)}')
		mut frame := p.GifFrameData{
			graphics_control: cc
		}
		mut img := frame.alloc_new_sub_image() or { panic(err) }
		img.image_descriptor = dc
		img.pixels = [u8(1), 2, 3]
		img.local_color_table.resize(2)
		img.local_color_table.data[0] = p.Rgb24{
			r: 1
			g: 2
			b: 3
		}
		img.local_color_table.data[1] = p.Rgb24{
			r: 4
			g: 5
			b: 6
		}
		fcopy := frame
		scopy := *img
		frame.graphics_control = c
		img.image_descriptor.width = 55
		img.pixels[0] = 42
		img.local_color_table.storage[0].r = 77
		old_control := fcopy.graphics_control or { panic('missing control') }
		new_control := frame.graphics_control or { panic('missing control') }
		println('FRAME|${seed}|${packed_bytes(old_control)}|${packed_bytes(new_control)}|${fcopy.sub_images.len}|${fcopy.sub_images[0].image_descriptor.width}|${scopy.image_descriptor.width}|${scopy.pixels.hex()}|${scopy.local_color_table.storage[0].r}|${scopy.local_color_table.data[0].r}')
	}
	mut data := [u8(1), 2, 3]
	mut comment := p.GifCommentExtension{
		comment: data
	}
	copied_comment := comment
	comment.comment[0] = 4
	data[1] = 5
	comment.comment = comment.comment[..1]
	println('COMMENT|${comment.comment.hex()}|${copied_comment.comment.hex()}')
	mut app := p.GifApplicationExtension{
		application_identifier: [8]u8{}
		authentification_code:  [3]u8{}
		data:                   data
	}
	copied_app := app
	app.application_identifier[0] = `N`
	app.authentification_code[0] = `2`
	data[2] = 6
	app.data = app.data[..1]
	println('APPLICATION|${app.application_identifier[..].hex()}|${copied_app.application_identifier[..].hex()}|${app.authentification_code[..].hex()}|${copied_app.authentification_code[..].hex()}|${app.data.hex()}|${copied_app.data.hex()}')
}
