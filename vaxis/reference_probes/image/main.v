module main

import vaxis as v
import zigimg as z
import encoding.hex
import os

__global (
	observed       = &v.Vaxis(unsafe { nil })
	observed_image = &z.Image(unsafe { nil })
	observed_path  string
)

fn observe() {
	if observed == unsafe { nil } { return }
	mut state := '${observed.next_img_id}'
	if observed_image != unsafe { nil } {
		state += '|${observed_image.pixel_format()}|${observed_image.raw_bytes().len}'
	}
	os.write_file(observed_path, state) or {}
}

fn n(p []string, i int) u16 {
	return u16(p[i].u32())
}

fn optional(x ?u16) string {
	if y := x { return y.str() }
	return '-'
}

fn options(o v.ImageDrawOptions) string {
	s := if size := o.size { optional(size.rows) + ',' + optional(size.cols) } else { 'none' }
	x := if off := o.pixel_offset { '${off.x},${off.y}' } else { 'none' }
	z_index := if zi := o.z_index { zi.str() } else { 'none' }
	r := if c := o.clip_region {
		optional(c.x) + ',' + optional(c.y) + ',' + optional(c.width) + ',' + optional(c.height)
	} else {
		'none'
	}
	return '${u8(o.scale)}|${s}|${x}|${z_index}|${r}'
}

fn record(p []string, id int) string {
	mut out := '${id}|'
	if p[0] == 'G' {
		mut screen := v.Screen{
			width:      n(p, 1)
			height:     n(p, 2)
			width_pix:  n(p, 3)
			height_pix: n(p, 4)
			buf:        [
				v.Cell{
					char_: v.CellCharacter{
						grapheme: 'before'
					}
					style: v.Style{
						bold: true
					}
					link:  v.CellHyperlink{
						uri: 'u'
					}
				},
			]
		}
		mut win := v.Window.new(&screen)
		win.width = n(p, 5)
		win.height = n(p, 6)
		mut img := v.Image{
			id:     7
			width:  n(p, 7)
			height: n(p, 8)
		}
		img.id = 99
		seed := n(p, 10)
		opts := v.ImageDrawOptions{
			scale:        unsafe { v.ImageScale(n(p, 9)) }
			size:         if seed % 2 == 0 { none } else { ?v.ImageCellSize(v.ImageCellSize{
					rows: seed
					cols: 0
				}) }
			pixel_offset: if seed % 3 == 0 { none } else { ?v.ImagePixelOffset(v.ImagePixelOffset{
					x: seed
					y: 65535 - seed
				}) }
			z_index:      if seed % 3 == 0 { none } else { ?i32(-i32(seed)) }
			clip_region:  if seed % 2 == 0 { none } else { ?v.ImageClipRegion(v.ImageClipRegion{
					x:      seed
					height: 0
				}) }
		}
		size := img.cell_size(win) or {
			out += 'E${err.msg()}'
			v.ImageCellDimensions{
				rows: 0
				cols: 0
			}
		}
		if !out.contains('E') { out += '${size.rows},${size.cols}' }
		out += '|'
		img.draw(win, opts) or { out += 'E${err.msg()}' }
		if out.ends_with('|') { out += 'OK' }
		cell := screen.buf[0]
		out += '|${hex.encode(cell.char_.grapheme.bytes())}|${u8(cell.style.bold)}|${hex.encode(cell.link.uri.bytes())}|'
		if placed := cell.image {
			out += '${placed.img_id}|' + options(placed.options)
		} else {
			out += 'none'
		}
		out += '|original|' + options(opts)
	} else {
		mut vx := v.Vaxis.new(v.VaxisOptions{})
		vx.caps.kitty_graphics = n(p, 1) != 0
		vx.next_img_id = p[2].u32()
		payload := hex.decode(p[7]) or { panic(err) }
		format := unsafe { v.ImageTransmitFormat(n(p, 6)) }
		mut succeeded := true
		result := if p[0] == 'L' {
			vx.transmit_local_image_path(payload.bytestr(), n(p, 3), n(p, 4),
				unsafe { v.ImageTransmitMedium(n(p, 5)) }, format) or {
				out += 'E${err.msg()}'
				succeeded = false
				v.ImageTransmission{}
			}
		} else if p[0] == 'M' {
			mut img := z.Image.from_raw_pixels(uint(p[3].u64()), uint(p[4].u64()), payload,
				.rgb24) or { panic(err) }
			packet := vx.transmit_image(mut img, format) or {
				out += 'E${err.msg()}'
				succeeded = false
				v.ImageTransmission{}
			}
			out += '|${img.pixel_format()}|${img.raw_bytes().len}|'
			packet
		} else {
			vx.transmit_pre_encoded_image(payload.bytestr(), n(p, 3), n(p, 4), format) or {
				out += 'E${err.msg()}'
				succeeded = false
				v.ImageTransmission{}
			}
		}
		if succeeded { out += 'OK|${result.image.id},${result.image.width},${result.image.height}' }
		out += '|${vx.next_img_id}|${hex.encode(result.sequence.bytes())}'
	}
	return out + '\n'
}

fn trap(name string, path string) {
	initial := v.Vaxis.new(v.VaxisOptions{})
	mut vx := &v.Vaxis{
		...initial
	}
	vx.caps.kitty_graphics = true
	vx.next_img_id = 0xffffffff
	observed = vx
	observed_path = path
	at_exit(observe) or { panic(err) }
	if name == 'path_id' {
		vx.transmit_local_image_path('a', 1, 1, .file, .rgb) or { panic(err) }
	} else if name == 'path_error_id' {
		vx.transmit_local_image_path('a'.repeat(3072), 1, 1, .file, .png) or {
			panic('UNEXPECTED path error')
		}
	} else if name == 'encoded_id' {
		vx.transmit_pre_encoded_image('x', 1, 1, .png) or { panic(err) }
	} else {
		vx.next_img_id = 17
		image := z.Image.from_raw_pixels(uint(if name == 'height_cast' { 1 } else { 65536 }), uint(if name == 'height_cast' {
			65536
		} else if name == 'png_header' {
			0
		} else {
			1
		}), [u8(1), 2, 3, 4, 5, 6, 7, 8, 9], .rgb24) or { panic(err) }
		mut img := &z.Image{
			...image
		}
		observed_image = img
		vx.transmit_image(mut img, if name == 'width_rgba_cast' {
			.rgba
		} else if name in ['width_png_cast', 'png_header'] {
			.png
		} else {
			.rgb
		}) or { panic(err) }
	}
	panic('UNEXPECTED returning trap')
}

fn main() {
	if os.args.len > 2 && os.args[1] == '--trap' {
		trap(os.args[2], os.args[3])
		return
	}
	input := os.read_file(os.args[1]) or { panic(err) }
	mut id := 0
	for line in input.split_into_lines() {
		if line == '' { continue
		 }
		print(record(line.split('|'), id))
		id++
	}
}
