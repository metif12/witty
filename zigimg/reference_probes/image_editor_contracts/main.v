module main

import os
import zigimg as p

const formats = [p.PixelFormat.invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16,
	.grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8_alpha,
	.grayscale16_alpha, .rgb332, .rgb555, .rgb565, .rgb24, .rgba32, .bgr555, .bgr24, .bgra32, .rgb48,
	.rgba64, .float32]

__global (
	observed_path  string
	observed_image = &p.ImageUnmanaged(unsafe { nil })
	observed_box   = &p.Box(unsafe { nil })
)
fn pixel_state(pixels p.PixelStorage) string {
	pal := if colors := pixels.get_palette() {
		unsafe { (&u8(colors.data)).vbytes(colors.len * 4).hex() }
	} else {
		'-'
	}
	return '${u32(pixels.pixel_format())}|${pixels.len()}|${pixels.as_bytes().hex()}|${pal}'
}

fn image_state(image p.ImageUnmanaged) string {
	mut out := '${image.width}|${image.height}|' + pixel_state(image.pixels) +
		'|${image.animation.loop_count}|${image.animation.frames.len}'
	for frame in image.animation.frames {
		duration := frame.duration
		out += '|' + unsafe { (&u8(&duration)).vbytes(4).hex() } + '|' + pixel_state(frame.pixels)
	}
	return out
}

fn box_state(box p.Box) string {
	return '${box.x}|${box.y}|${box.width}|${box.height}'
}

fn observe() {
	mut out := ''
	if observed_image != unsafe { nil } { out += image_state(observed_image) }
	if observed_box != unsafe { nil } { out += '|' + box_state(observed_box) }
	os.write_file(observed_path, out) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn make_pixels(format p.PixelFormat, count int, seed int) p.PixelStorage {
	mut result := p.PixelStorage.init(format, uint(count)) or { panic(err) }
	mut raw := result.as_bytes()
	for i in 0 .. raw.len {
		raw[i] = u8(i * 37 + seed * 19)
	}
	match format {
		.indexed1, .grayscale1 {
			for i in 0 .. raw.len {
				raw[i] &= 1
			}
		}
		.indexed2, .grayscale2 {
			for i in 0 .. raw.len {
				raw[i] &= 3
			}
		}
		.indexed4, .grayscale4 {
			for i in 0 .. raw.len {
				raw[i] &= 15
			}
		}
		.rgb555, .bgr555 {
			for i in 0 .. count {
				raw[i * 2 + 1] &= 127
			}
		}
		else {}
	}

	if _ := result.get_palette() {
		mut pal := result.get_palette() or { panic('missing palette') }
		length := if pal.len < 4 { pal.len } else { 4 }
		result.resize_palette(uint(length))
		for i in 0 .. length {
			pal[i] = p.Rgba32{
				r: u8(i * 31 + seed)
				g: u8(i * 71)
				b: u8(i * 113)
				a: u8(i * 47)
			}
		}
	}
	return result
}

fn make_image(format p.PixelFormat, count int, width uint, height uint, seed int) p.ImageUnmanaged {
	pixels := make_pixels(format, count, seed)
	return p.ImageUnmanaged{
		width:     width
		height:    height
		pixels:    pixels
		animation: p.Animation{
			loop_count: 4
			frames:     [p.AnimationFrame{ pixels: pixels, duration: 0.25 },
				p.AnimationFrame{ pixels: make_pixels(.rgba32, 2, 9), duration: 0.5 }]
		}
	}
}

fn flip(image &p.ImageUnmanaged, api int) {
	if api == 0 {
		p.flip_vertically(&image.pixels, image.height) or { panic(err) }
	} else if api == 1 {
		image.flip_vertically() or { panic(err) }
	} else {
		managed := image.to_managed()
		managed.flip_vertically() or { panic(err) }
	}
}

fn crop(image &p.ImageUnmanaged, box p.Box, api int) p.ImageUnmanaged {
	if api == 0 { return p.crop(image, box) or { panic(err) } }
	if api == 1 { return image.crop(box) or { panic(err) } }
	managed := image.to_managed()
	return (managed.crop(box) or { panic(err) }).to_unmanaged()
}

fn flip_returns(length int, height int) bool {
	row := length / height
	if row == 0 { return length == 0 }
	mut remaining := length
	for remaining > row {
		if row > remaining - row { return false }
		remaining -= row * 2
	}
	return true
}

fn main() {
	if os.args.len > 1 {
		if os.args[2] != '-' {
			observed_path = os.args[2]
			at_exit(observe) or { panic(err) }
		}
		api := os.args[3].int()
		format := unsafe { p.PixelFormat(os.args[4].u32()) }
		count := os.args[5].int()
		width := uint(os.args[6].u64())
		height := uint(os.args[7].u64())
		mut image := make_image(format, count, width, height, 1)
		observed_image = &image
		if os.args[1] == '--row' {
			_ = if api == 1 { image.row_byte_size() } else { image.to_managed().row_byte_size() }
		} else if os.args[1] == '--flip' {
			flip(&image, api)
		} else {
			mut box := p.Box{
				x:      uint(os.args[8].u64())
				y:      uint(os.args[9].u64())
				width:  uint(os.args[10].u64())
				height: uint(os.args[11].u64())
			}
			observed_box = &box
			if os.args[1] == '--clamp' {
				result := box.clamp(width, height)
				if observed_path == '' {
					println(box_state(result))
					return
				}
			} else {
				result := crop(&image, box, api)
				if observed_path == '' {
					println(image_state(result) + '|' + image_state(image))
					return
				}
			}
		}
		eprintln('UNEXPECTED: operation returned')
		return
	}
	original := p.Box{}
	mut copied := original
	copied.x = ~uint(0)
	copied.height = 9
	println('H|' + box_state(original) + '|' + box_state(copied))
	for width in 0 .. 5 {
		for height in 0 .. 5 {
			for x in 0 .. width + 1 {
				for y in 0 .. height + 1 {
					for w in 0 .. 6 {
						for h in 0 .. 6 {
							box := p.Box{
								x:      uint(x)
								y:      uint(y)
								width:  uint(w)
								height: uint(h)
							}
							println('B|${width}|${height}|' + box_state(box) + '|' +
								box_state(box.clamp(uint(width), uint(height))))
						}
					}
				}
			}
		}
	}
	for format in formats {
		for count in 0 .. 10 {
			for v in 1 .. 14 {
				height := if v == 13 { ~uint(0) } else { uint(v) }
				image := make_image(format, count, 99, height, 1)
				println(
					'R|${u32(format)}|${count}|${height}|${image.row_byte_size()}|${image.to_managed().row_byte_size()}|' +
					image_state(image))
			}
			for height in 1 .. 9 {
				if !flip_returns(count * int(format.pixel_stride()), height) { continue
				 }
				for seed in 0 .. 3 {
					for api in 0 .. 3 {
						image := make_image(format, count, 99, uint(height), seed)
						flip(&image, api)
						first := image_state(image)
						flip(&image, api)
						println('F|${u32(format)}|${count}|${height}|${seed}|${api}|' + first +
							'|' + image_state(image))
					}
				}
			}
		}
		if format == .invalid { continue
		 }
		for width in 0 .. 4 {
			for height in 0 .. 4 {
				boxes := [p.Box{}, p.Box{ width: uint(width), height: uint(height) },
					p.Box{ x: uint(width), y: uint(height), width: 1, height: 1 },
					p.Box{ x: uint(width / 2), y: uint(height / 2), width: 5, height: 5 },
					p.Box{ width: 1, height: 1 }, p.Box{ x: uint(width), width: 1, height: 5 },
					p.Box{ y: uint(height), width: 5, height: 1 },
					p.Box{
						x:      uint(if width == 0 { 0 } else { width - 1 })
						y:      uint(if height == 0 {
							0
						} else {
							height - 1
						})
						width:  5
						height: 5
					}]
				for b, box in boxes {
					for seed in 0 .. 2 {
						for api in 0 .. 3 {
							image := make_image(format, width * height, uint(width),
								uint(height), seed)
							mut result := crop(&image, box, api)
							mut out := 'C|${u32(format)}|${width}|${height}|${b}|${seed}|${api}|' +
								image_state(result)
							mut raw := result.pixels.as_bytes()
							if raw.len != 0 {
								out += '|${uint(raw.data) != uint(image.raw_bytes().data)}'
								raw[0] ^= 1
							} else {
								out += '|-'
							}
							if _ := result.pixels.get_palette() {
								mut pal := result.pixels.get_palette() or {
									panic('missing palette')
								}
								source := image.pixels.get_palette() or { panic('missing palette') }
								out += '|${uint(pal.data) != uint(source.data)}'
								pal[0].r ^= 1
							} else {
								out += '|-'
							}
							println(out + '|' + image_state(image) + '|' + image_state(result))
						}
					}
				}
			}
		}
	}
}
