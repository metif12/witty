module main

import os
import zigimg as p

fn palette(n int, seed int) []p.Rgba32 {
	return []p.Rgba32{len: n, init: p.Rgba32{
		r: u8(seed + index * 17)
		g: u8(seed + index * 31)
		b: u8(seed + index * 47)
		a: 255
	}}
}

fn pixels(format p.PixelFormat, n int, seed int) p.PixelStorage {
	match format {
		.indexed1 {
			return p.IndexedStorage1{
				palette: palette(2, seed)
				indices: []u8{len: n, init: u8(index % 2)}
			}
		}
		.indexed2 {
			return p.IndexedStorage2{
				palette: palette(3, seed)
				indices: []u8{len: n, init: u8(index % 4)}
			}
		}
		.indexed4 {
			return p.IndexedStorage4{
				palette: palette(3, seed)
				indices: []u8{len: n, init: u8(index % 16)}
			}
		}
		.indexed8 {
			return p.IndexedStorage8{
				palette: palette(3, seed)
				indices: []u8{len: n, init: u8(index % 256)}
			}
		}
		.indexed16 {
			return p.IndexedStorage16{
				palette: palette(3, seed)
				indices: []u16{len: n, init: u16(index % 65536)}
			}
		}
		else {
			mut result := p.PixelStorage.init(format, usize(n)) or { panic(err) }
			mut raw := result.as_bytes()
			for i in 0 .. raw.len {
				raw[i] = u8(i * 37 + seed)
			}
			if format in [.grayscale1, .grayscale2, .grayscale4] {
				maximum := if format == .grayscale1 {
					2
				} else if format == .grayscale2 {
					4
				} else {
					16
				}
				for i in 0 .. raw.len {
					raw[i] = u8(i % maximum)
				}
			}
			return result
		}
	}
}

fn mutate(mut storage p.PixelStorage) {
	mut bytes := storage.as_bytes()
	if bytes.len > 0 {
		mask := match storage.pixel_format() {
			.indexed1, .grayscale1 { u8(1) }
			.indexed2, .grayscale2 { u8(3) }
			.indexed4, .grayscale4 { u8(15) }
			else { u8(85) }
		}

		bytes[0] ^= mask
	}
	if entries := storage.get_palette() {
		mut entries2 := unsafe { entries }
		if entries2.len > 0 { entries2[0].r ^= 85 }
	}
}

fn float_word(word u32) f32 {
	return unsafe { *(&f32(&word)) }
}

fn frame_state(frame p.AnimationFrame) string {
	duration := frame.duration
	bits := unsafe { *(&u32(&duration)) }
	return '${bits}:' + pixel_state(frame.pixels)
}

fn pixel_state(storage p.PixelStorage) string {
	mut colors := '-'
	if palette := storage.get_palette() {
		colors = unsafe { (&u8(palette.data)).vbytes(palette.len * 4).hex() }
	}
	return '${u32(storage.pixel_format())}:${storage.len()}:${storage.as_bytes().hex()}:${colors}'
}

fn animation_state(animation p.Animation) string {
	mut result := '${animation.loop_count}:${animation.frames.len}'
	for frame in animation.frames {
		result += '|' + frame_state(frame)
	}
	return result
}

fn image_state(image p.ImageUnmanaged) string {
	return '${image.width}:${image.height}:${int(image.is_animation())}:' +
		pixel_state(image.pixels) + '|' + animation_state(image.animation)
}

fn line_case(line string) {
	f := line.split('|')
	op := f[0].int()
	format := unsafe { p.PixelFormat(f[1].u32()) }
	n := f[2].int()
	word := f[3].u32()
	count := f[4].int()
	loops := f[5].i32()
	seed := f[6].int()
	mut frame := p.AnimationFrame{
		pixels:   pixels(format, n, seed)
		duration: float_word(word)
	}
	mut copied := frame
	mut storage := []p.AnimationFrame{len: 3, init: p.AnimationFrame{
		pixels:   pixels(format, n, seed + index)
		duration: float_word(word ^ u32(index))
	}}
	mut animation := p.Animation{
		loop_count: loops
		frames:     unsafe { storage[..count] }
	}
	mut result := ''
	match op {
		0 {
			managed := p.Image.init()
			original := p.ImageUnmanaged{}
			result = frame_state(frame) + '|' + animation_state(p.Animation{}) +
				'|${int(original.is_animation())}:${int(managed.is_animation())}'
		}
		1 {
			copied.duration = float_word(word ^ 0x80000000)
			mutate(mut copied.pixels)
			result = frame_state(frame) + '|' + frame_state(copied)
		}
		2 {
			copied.pixels = pixels(.rgba32, 2, seed + 9)
			frame.duration = float_word(word ^ 0x55555555)
			result = frame_state(frame) + '|' + frame_state(copied)
		}
		3 {
			mut other := animation
			other.loop_count = ~loops
			if count > 0 {
				other.frames[0].duration = float_word(word ^ 0x80000000)
				other.frames[0].pixels = pixels(.rgb24, 1, seed + 9)
			}
			result = animation_state(animation) + '||' + animation_state(other)
		}
		4 {
			mut other := animation
			other.frames = unsafe { other.frames[..if count > 0 { count - 1 } else { 0 }] }
			if count > 1 { other.frames[0].duration = float_word(word ^ 0x80000000) }
			result = animation_state(animation) + '||' + animation_state(other)
		}
		5 {
			mut other := animation
			other.frames = [copied]
			other.loop_count = ~loops
			other.frames[0].duration = float_word(word ^ 0x80000000)
			result = animation_state(animation) + '||' + animation_state(other)
		}
		6 {
			original := p.ImageUnmanaged{
				width:     17
				height:    19
				pixels:    frame.pixels
				animation: animation
			}
			mut view := original.to_managed()
			view.width = 23
			view.animation.loop_count = ~loops
			view.pixels = view.pixels.slice(0, if view.pixels.len() > 0 {
				usize(1)
			} else {
				usize(0)
			})
			mutate(mut view.pixels)
			if count > 0 { view.animation.frames[0].duration = float_word(word ^ 0x80000000) }
			result = image_state(original) + '||' + image_state(view.to_unmanaged())
		}
		7 {
			mut original := p.Image.init()
			original.width = 17
			original.height = 19
			original.pixels = frame.pixels
			original.animation = animation
			mut view := original.to_unmanaged()
			view.height = 29
			view.animation.loop_count = ~loops
			view.pixels = view.pixels.slice(0, if view.pixels.len() > 0 {
				usize(1)
			} else {
				usize(0)
			})
			mutate(mut view.pixels)
			if count > 0 { view.animation.frames[0].pixels = pixels(.rgba32, 1, seed + 9) }
			result = image_state(original.to_unmanaged()) + '||' + image_state(view)
		}
		else {
			panic('invalid operation')
		}
	}

	println(result)
}

fn boxed(format p.PixelFormat) {
	mut frame := p.AnimationFrame{
		pixels:   pixels(format, 3, 7)
		duration: 0.5
	}
	copied := frame
	frame.pixels.resize_palette(1)
	first := frame.pixels.get_palette() or { panic('missing palette') }
	second := copied.pixels.get_palette() or { panic('missing palette') }
	println('${first.len}:${second.len}:${frame.pixels.len()}:${copied.pixels.len()}')
}

fn main() {
	if os.args[1] == '--boxed' {
		boxed(unsafe { p.PixelFormat(os.args[2].u32()) })
		return
	}
	for line in os.read_lines(os.args[2]) or { panic(err) } {
		line_case(line)
	}
}
