module vaxis

// Scrollbar follows widgets/Scrollbar.zig; it is independent of vxfw.ScrollBars.
pub struct Scrollbar {
pub mut:
	character CellCharacter = CellCharacter{
		grapheme: '▐'
		width:    1
	}
	style     Style
	top       uint
	total     uint @[required]
	view_size uint @[required]
}

pub fn (bar Scrollbar) draw(win Window) {
	if bar.total < 1 || bar.view_size >= bar.total { return }
	product := widget_checked_mul(bar.view_size, uint(win.height))
	mut bar_height := product / bar.total
	if product % bar.total != 0 { bar_height++ }
	if bar_height < 1 { bar_height = 1 }
	bar_top := widget_checked_mul(bar.top, uint(win.height)) / bar.total
	for i := uint(0); i < bar_height; i++ {
		row := widget_checked_u16(widget_checked_add(i, bar_top))
		win.write_cell(0, row, Cell{ char_: bar.character, style: bar.style })
	}
}

fn widget_checked_mul(a uint, b uint) uint {
	if b != 0 && a > (~uint(0)) / b { panic('integer overflow') }
	return a * b
}

fn widget_checked_add(a uint, b uint) uint {
	if b > (~uint(0)) - a { panic('integer overflow') }
	return a + b
}

fn widget_checked_u16(value uint) u16 {
	if value > 0xffff { panic('integer does not fit in destination type') }
	return u16(value)
}

fn widget_saturating_add(a uint, b uint) uint {
	if b > (~uint(0)) - a { return ~uint(0) }
	return a + b
}

fn widget_saturating_sub(a uint, b uint) uint {
	return if a < b { uint(0) } else { a - b }
}
