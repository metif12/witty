module sprite

// Braille Patterns | U+2800...U+28FF
// https://en.wikipedia.org/wiki/Braille_Patterns
//
// (6 dot patterns)
// ⠀ ⠁ ⠂ ⠃ ⠄ ⠅ ⠆ ⠇ ⠈ ⠉ ⠊ ⠋ ⠌ ⠍ ⠎ ⠏
// ⠐ ⠑ ⠒ ⠓ ⠔ ⠕ ⠖ ⠗ ⠘ ⠙ ⠚ ⠛ ⠜ ⠝ ⠞ ⠟
// ⠠ ⠡ ⠢ ⠣ ⠤ ⠥ ⠦ ⠧ ⠨ ⠩ ⠪ ⠫ ⠬ ⠭ ⠮ ⠯
// ⠰ ⠱ ⠲ ⠳ ⠴ ⠵ ⠶ ⠷ ⠸ ⠹ ⠺ ⠻ ⠼ ⠽ ⠾ ⠿
//
// (8 dot patterns)
// ⡀ ⡁ ⡂ ⡃ ⡄ ⡅ ⡆ ⡇ ⡈ ⡉ ⡊ ⡋ ⡌ ⡍ ⡎ ⡏
// ⡐ ⡑ ⡒ ⡓ ⡔ ⡕ ⡖ ⡗ ⡘ ⡙ ⡚ ⡛ ⡜ ⡝ ⡞ ⡟
// ⡠ ⡡ ⡢ ⡣ ⡤ ⡥ ⡦ ⡧ ⡨ ⡩ ⡪ ⡫ ⡬ ⡭ ⡮ ⡯
// ⡰ ⡱ ⡲ ⡳ ⡴ ⡵ ⡶ ⡷ ⡸ ⡹ ⡺ ⡻ ⡼ ⡽ ⡾ ⡿
// ⢀ ⢁ ⢂ ⢃ ⢄ ⢅ ⢆ ⢇ ⢈ ⢉ ⢊ ⢋ ⢌ ⢍ ⢎ ⢏
// ⢐ ⢑ ⢒ ⢓ ⢔ ⢕ ⢖ ⢗ ⢘ ⢙ ⢚ ⢛ ⢜ ⢝ ⢞ ⢟
// ⢠ ⢡ ⢢ ⢣ ⢤ ⢥ ⢦ ⢧ ⢨ ⢩ ⢪ ⢫ ⢬ ⢭ ⢮ ⢯
// ⢰ ⢱ ⢲ ⢳ ⢴ ⢵ ⢶ ⢷ ⢸ ⢹ ⢺ ⢻ ⢼ ⢽ ⢾ ⢿
// ⣀ ⣁ ⣂ ⣃ ⣄ ⣅ ⣆ ⣇ ⣈ ⣉ ⣊ ⣋ ⣌ ⣍ ⣎ ⣏
// ⣐ ⣑ ⣒ ⣓ ⣔ ⣕ ⣖ ⣗ ⣘ ⣙ ⣚ ⣛ ⣜ ⣝ ⣞ ⣟
// ⣠ ⣡ ⣢ ⣣ ⣤ ⣥ ⣦ ⣧ ⣨ ⣩ ⣪ ⣫ ⣬ ⣭ ⣮ ⣯
// ⣰ ⣱ ⣲ ⣳ ⣴ ⣵ ⣶ ⣷ ⣸ ⣹ ⣺ ⣻ ⣼ ⣽ ⣾ ⣿
//
// Translated from ghostty/src/font/sprite/draw/braille.zig

import sprite_types as font

// A braille pattern.
//
// Mnemonic:
// [t]op    - .       .
// [u]pper  - .       .
// [l]ower  - .       .
// [b]ottom - .       .
//            |       |
//           [l]eft, [r]ight
//
// Struct layout matches bit patterns of unicode codepoints.
struct BraillePattern {
	value u8
}

// braille_pattern_from creates a BraillePattern from a codepoint
// by retaining the low byte as the packed bit pattern.
fn braille_pattern_from(cp u32) BraillePattern {
	return BraillePattern{
		value: u8(cp)
	}
}

fn (self BraillePattern) tl() bool {
	return self.value & 0x01 != 0
}

fn (self BraillePattern) ul() bool {
	return self.value & 0x02 != 0
}

fn (self BraillePattern) ll() bool {
	return self.value & 0x04 != 0
}

fn (self BraillePattern) tr() bool {
	return self.value & 0x08 != 0
}

fn (self BraillePattern) ur() bool {
	return self.value & 0x10 != 0
}

fn (self BraillePattern) lr() bool {
	return self.value & 0x20 != 0
}

fn (self BraillePattern) bl() bool {
	return self.value & 0x40 != 0
}

fn (self BraillePattern) br() bool {
	return self.value & 0x80 != 0
}

// draw_2800_28ff draws braille pattern characters (U+2800..U+28FF).
pub fn draw_2800_28ff(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = metrics

	mut w := i32(if width / 4 < height / 8 { width / 4 } else { height / 8 })
	mut x_spacing := i32(width / 4)
	mut y_spacing := i32(height / 8)
	mut x_margin := x_spacing / 2
	mut y_margin := y_spacing / 2

	mut x_px_left := i32(width) - 2 * x_margin - x_spacing - 2 * w

	mut y_px_left := i32(height) - 2 * y_margin - 3 * y_spacing - 4 * w

	// First, try hard to ensure the DOT width is non-zero
	if x_px_left >= 2 && y_px_left >= 4 && w == 0 {
		w += 1
		x_px_left -= 2
		y_px_left -= 4
	}

	// Second, prefer a non-zero margin
	if x_px_left >= 2 && x_margin == 0 {
		x_margin = 1
		x_px_left -= 2
	}
	if y_px_left >= 2 && y_margin == 0 {
		y_margin = 1
		y_px_left -= 2
	}

	// Third, increase spacing
	if x_px_left >= 1 {
		x_spacing += 1
		x_px_left -= 1
	}
	if y_px_left >= 3 {
		y_spacing += 1
		y_px_left -= 3
	}

	// Fourth, margins ("spacing", but on the sides)
	if x_px_left >= 2 {
		x_margin += 1
		x_px_left -= 2
	}
	if y_px_left >= 2 {
		y_margin += 1
		y_px_left -= 2
	}

	// Last - increase dot width
	if x_px_left >= 2 && y_px_left >= 4 {
		w += 1
		x_px_left -= 2
		y_px_left -= 4
	}

	assert x_px_left <= 1 || y_px_left <= 1
	assert 2 * x_margin + 2 * w + x_spacing <= i32(width)
	assert 2 * y_margin + 4 * w + 3 * y_spacing <= i32(height)

	x := [x_margin, x_margin + w + x_spacing]!
	y0 := y_margin
	y1 := y0 + w + y_spacing
	y2 := y1 + w + y_spacing
	y3 := y2 + w + y_spacing
	y := [y0, y1, y2, y3]!

	assert cp >= 0x2800
	assert cp <= 0x28ff
	p := braille_pattern_from(cp)

	if p.tl() {
		canvas.draw_box(x[0], y[0], x[0] + w, y[0] + w, .on)
	}
	if p.ul() {
		canvas.draw_box(x[0], y[1], x[0] + w, y[1] + w, .on)
	}
	if p.ll() {
		canvas.draw_box(x[0], y[2], x[0] + w, y[2] + w, .on)
	}
	if p.bl() {
		canvas.draw_box(x[0], y[3], x[0] + w, y[3] + w, .on)
	}
	if p.tr() {
		canvas.draw_box(x[1], y[0], x[1] + w, y[0] + w, .on)
	}
	if p.ur() {
		canvas.draw_box(x[1], y[1], x[1] + w, y[1] + w, .on)
	}
	if p.lr() {
		canvas.draw_box(x[1], y[2], x[1] + w, y[2] + w, .on)
	}
	if p.br() {
		canvas.draw_box(x[1], y[3], x[1] + w, y[3] + w, .on)
	}
}
