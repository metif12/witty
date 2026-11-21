module vaxis

pub struct LineNumbers {
pub mut:
	num_lines         uint = ~uint(0)
	highlighted_line  uint
	style             Style = Style{
		dim: true
	}
	highlighted_style Style = Style{
		dim: true
		bg:  ColorIndex{
			index: 0
		}
	}
}

pub fn LineNumbers.extract_digit(value uint, n uint) uint {
	mut divisor := uint(1)
	for i := uint(0); i < n; i++ {
		if divisor > ~uint(0) / 10 { panic('attempt to unwrap error: Overflow') }
		divisor *= 10
	}
	return (value / divisor) % 10
}

pub fn LineNumbers.num_digits(value uint) u8 {
	return match true {
		value <= 9 { 1 }
		value <= 99 { 2 }
		value <= 999 { 3 }
		value <= 9999 { 4 }
		value <= 99999 { 5 }
		value <= 999999 { 6 }
		value <= 9999999 { 7 }
		value <= 99999999 { 8 }
		else { 0 }
	}
}

pub fn (numbers LineNumbers) draw(win Window, y_scroll uint) {
	start := widget_checked_add(1, y_scroll)
	if start > numbers.num_lines { panic('integer overflow') }
	for line := start; line < numbers.num_lines; line++ {
		if line - 1 >= widget_saturating_add(y_scroll, uint(win.height)) {
			break
		}
		highlighted := line == numbers.highlighted_line
		digits := LineNumbers.num_digits(line)
		style := if highlighted { numbers.highlighted_style } else { numbers.style }
		for i in 0 .. int(digits) {
			digit := int(LineNumbers.extract_digit(line, uint(i)))
			win.write_cell(widget_checked_u16(widget_saturating_sub(uint(win.width), uint(i + 2))), widget_checked_u16(widget_saturating_sub(line, widget_saturating_add(y_scroll,
				1))), Cell{
				char_: CellCharacter{
					grapheme: '0123456789'[digit..digit + 1]
					width:    1
				}
				style: style
			})
		}
		if highlighted {
			if int(digits) + 1 > int(win.width) { panic('integer overflow') }
			for i in int(digits) + 1 .. int(win.width) {
				win.write_cell(u16(i), widget_checked_u16(widget_saturating_sub(line, widget_saturating_add(y_scroll,
					1))), Cell{ style: style })
			}
		}
	}
}
