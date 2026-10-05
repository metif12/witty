module vaxis

import math

// widgets/terminal/Screen.zig is independent of the Linux-only PTY initializer.
// GC-owned strings replace its per-cell ArrayLists; cursor URI defaults are
// empty rather than the source's undefined values and must be seeded in probes.
pub struct TerminalScreenCell {
pub mut:
	char_   string
	style   Style
	uri     string
	uri_id  string
	width   u8 = 1
	wrapped bool
	dirty   bool = true
}

pub fn (mut cell TerminalScreenCell) erase(bg Color) {
	cell.char_ = ' '.clone()
	cell.style = Style{
		bg: bg
	}
	cell.uri = ''
	cell.uri_id = ''
	cell.width = 1
	cell.wrapped = false
	cell.dirty = true
}

pub fn (mut cell TerminalScreenCell) copy_from(src &TerminalScreenCell) ! {
	cell.char_ = ''
	cell.char_ = src.char_.clone()
	cell.style = src.style
	cell.uri = ''
	cell.uri = src.uri.clone()
	cell.uri_id = ''
	cell.uri_id = src.uri_id.clone()
	cell.width = src.width
	cell.wrapped = src.wrapped
	cell.dirty = true
}

pub struct TerminalScreenCursor {
pub mut:
	style        Style
	uri          string
	uri_id       string
	col          u16
	row          u16
	pending_wrap bool
	shape        CursorShape = .default
	visible      bool        = true
}

pub fn (cursor TerminalScreenCursor) is_outside_scrolling_region(sr TerminalScrollingRegion) bool {
	return cursor.row < sr.top || cursor.row > sr.bottom || cursor.col < sr.left
		|| cursor.col > sr.right
}

pub fn (cursor TerminalScreenCursor) is_inside_scrolling_region(sr TerminalScrollingRegion) bool {
	return !cursor.is_outside_scrolling_region(sr)
}

pub struct TerminalScrollingRegion {
pub mut:
	top    u16 @[required]
	bottom u16 @[required]
	left   u16 @[required]
	right  u16 @[required]
}

pub fn (region TerminalScrollingRegion) contains(col usize, row usize) bool {
	return col >= region.left && col <= region.right && row >= region.top && row <= region.bottom
}

pub struct TerminalScreen {
pub mut:
	width            u16
	height           u16
	scrolling_region TerminalScrollingRegion @[required]
	buf              []TerminalScreenCell
	cursor           TerminalScreenCursor
	csi_u_flags      KittyFlags = KittyFlags.from_int(0)
}

pub fn TerminalScreen.new(w u16, h u16) !TerminalScreen {
	size := widget_checked_mul(usize(w), usize(h))
	if size > 0x7fffffff { panic('terminal screen exceeds V array capacity') }
	mut cells := []TerminalScreenCell{len: int(size)}
	if h == 0 || w == 0 { panic('integer overflow') }
	for i in 0 .. cells.len {
		cells[i] = TerminalScreenCell{
			char_: ' '.clone()
		}
	}
	return TerminalScreen{
		width:            w
		height:           h
		buf:              cells
		scrolling_region: TerminalScrollingRegion{
			top:    0
			left:   0
			bottom: h - 1
			right:  w - 1
		}
	}
}

pub fn (mut screen TerminalScreen) deinit() {
	screen.buf = []TerminalScreenCell{}
}

pub fn (mut screen TerminalScreen) copy_to(mut dst TerminalScreen) ! {
	dst.cursor = screen.cursor
	for i in 0 .. screen.buf.len {
		value := screen.buf[i]
		if !value.dirty {
			continue
		}
		screen.buf[i].dirty = false
		if i >= dst.buf.len { panic('index out of bounds') }
		aliases := unsafe { dst.buf[i].char_.str == value.char_.str }
		dst.buf[i].char_ = ''
		if aliases && value.char_.len > 0 { panic('memcpy arguments alias') }
		dst.buf[i].char_ = value.char_.clone()
		dst.buf[i].width = value.width
		dst.buf[i].style = value.style
	}
}

pub fn (screen &TerminalScreen) read_cell(col usize, row usize) ?Cell {
	if usize(screen.width) < col || usize(screen.height) < row { return none }
	i := widget_checked_add(widget_checked_mul(row, usize(screen.width)), col)
	if i >= usize(screen.buf.len) { panic('reached unreachable code') }
	value := screen.buf[int(i)]
	return Cell{
		char_: CellCharacter{
			grapheme: value.char_
			width:    value.width
		}
		style: value.style
	}
}

pub fn (screen TerminalScreen) within_scrolling_region() bool {
	return screen.scrolling_region.contains(usize(screen.cursor.col), usize(screen.cursor.row))
}

pub fn (mut screen TerminalScreen) print(grapheme string, width u8, wrap bool) ! {
	if screen.cursor.pending_wrap {
		screen.index()!
		screen.cursor.col = screen.scrolling_region.left
	}
	if screen.cursor.col >= screen.width || screen.cursor.row >= screen.height { return }
	i := terminal_screen_add16(terminal_screen_mul16(screen.cursor.row, screen.width),
		screen.cursor.col)
	if int(i) >= screen.buf.len { panic('reached unreachable code') }
	screen.buf[int(i)].char_ = grapheme.clone()
	screen.buf[int(i)].uri = screen.cursor.uri.clone()
	screen.buf[int(i)].uri_id = screen.cursor.uri_id.clone()
	screen.buf[int(i)].style = screen.cursor.style
	screen.buf[int(i)].width = width
	screen.buf[int(i)].dirty = true
	if wrap && screen.cursor.col >= terminal_screen_sub16(screen.width, 1) {
		screen.cursor.pending_wrap = true
	}
	screen.cursor.col = terminal_screen_add16(screen.cursor.col, u16(width))
}

pub fn (mut screen TerminalScreen) index() ! {
	screen.cursor.pending_wrap = false
	if screen.cursor.is_outside_scrolling_region(screen.scrolling_region) {
		screen.cursor.row = math.min(terminal_screen_sub16(screen.height, 1),
			terminal_screen_add16(screen.cursor.row, 1))
		return
	}
	if screen.cursor.row == screen.scrolling_region.bottom {
		screen.delete_line(1)!
		return
	}
	screen.cursor.row = terminal_screen_add16(screen.cursor.row, 1)
}

pub fn (mut screen TerminalScreen) cursor_up(n u16) {
	screen.cursor.pending_wrap = false
	delta := if n > screen.cursor.row { u16(0) } else { screen.cursor.row - n }
	screen.cursor.row = if screen.within_scrolling_region() {
		math.max(delta, screen.scrolling_region.top)
	} else {
		delta
	}
}

pub fn (mut screen TerminalScreen) cursor_left(n u16) {
	screen.cursor.pending_wrap = false
	delta := if n > screen.cursor.col { u16(0) } else { screen.cursor.col - n }
	screen.cursor.col = if screen.within_scrolling_region() {
		math.max(delta, screen.scrolling_region.left)
	} else {
		delta
	}
}

pub fn (mut screen TerminalScreen) cursor_right(n u16) {
	screen.cursor.pending_wrap = false
	delta := terminal_screen_add16(screen.cursor.col, n)
	screen.cursor.col = math.min(delta, if screen.within_scrolling_region() {
		screen.scrolling_region.right
	} else {
		terminal_screen_sub16(screen.width, 1)
	})
}

pub fn (mut screen TerminalScreen) cursor_down(n usize) {
	screen.cursor.pending_wrap = false
	delta := widget_checked_add(usize(screen.cursor.row), n)
	maximum := if screen.within_scrolling_region() {
		screen.scrolling_region.bottom
	} else {
		if screen.height == 0 { u16(0) } else { screen.height - 1 }
	}
	screen.cursor.row = u16(math.min(usize(maximum), delta))
}

pub fn (mut screen TerminalScreen) erase_right() {
	screen.cursor.pending_wrap = false
	limit := terminal_screen_add16(terminal_screen_mul16(screen.cursor.row, screen.width),
		screen.width)
	mut i := terminal_screen_add16(terminal_screen_mul16(screen.cursor.row, screen.width),
		screen.cursor.col)
	for i < limit {
		screen.buf[int(i)].erase(screen.cursor.style.bg)
		i = terminal_screen_add16(i, 1)
	}
}

pub fn (mut screen TerminalScreen) erase_left() {
	screen.cursor.pending_wrap = false
	start := terminal_screen_mul16(screen.cursor.row, screen.width)
	limit := terminal_screen_add16(terminal_screen_add16(start, screen.cursor.col), 1)
	mut i := start
	for i < limit {
		screen.buf[int(i)].erase(screen.cursor.style.bg)
		i = terminal_screen_add16(i, 1)
	}
}

pub fn (mut screen TerminalScreen) erase_line() {
	screen.cursor.pending_wrap = false
	start := terminal_screen_mul16(screen.cursor.row, screen.width)
	limit := terminal_screen_add16(start, screen.width)
	mut i := start
	for i < limit {
		screen.buf[int(i)].erase(screen.cursor.style.bg)
		i = terminal_screen_add16(i, 1)
	}
}

pub fn (mut screen TerminalScreen) delete_line(n usize) ! {
	if n == 0 || !screen.within_scrolling_region() { return }
	screen.cursor.pending_wrap = false
	count := math.min(usize(terminal_screen_add16(terminal_screen_sub16(screen.scrolling_region.bottom,
		screen.cursor.row), 1)), n)
	stride := widget_checked_mul(usize(screen.width), count)
	mut row := usize(screen.scrolling_region.top)
	for row <= usize(screen.scrolling_region.bottom) {
		mut col := usize(screen.scrolling_region.left)
		for col <= usize(screen.scrolling_region.right) {
			i := widget_checked_add(widget_checked_mul(row, usize(screen.width)), col)
			if widget_checked_add(row, count) > usize(screen.scrolling_region.bottom) {
				screen.buf[int(i)].erase(screen.cursor.style.bg)
			} else {
				screen.buf[int(i)].copy_from(screen.buf[int(widget_checked_add(i, stride))])!
			}
			col = widget_checked_add(col, 1)
		}
		row = widget_checked_add(row, 1)
	}
}

pub fn (mut screen TerminalScreen) insert_line(n usize) ! {
	if n == 0 { return }
	screen.cursor.pending_wrap = false
	if !screen.within_scrolling_region() { return }
	count := math.min(usize(screen.scrolling_region.bottom) - usize(screen.cursor.row), n)
	stride := widget_checked_mul(usize(screen.width), count)
	mut row := usize(screen.scrolling_region.bottom)
	for row >= widget_checked_add(usize(screen.scrolling_region.top), count) {
		mut col := usize(screen.scrolling_region.left)
		for col <= usize(screen.scrolling_region.right) {
			i := widget_checked_add(widget_checked_mul(row, usize(screen.width)), col)
			if i < stride { panic('integer overflow') }
			screen.buf[int(i)].copy_from(screen.buf[int(i - stride)])!
			col = widget_checked_add(col, 1)
		}
		row = widget_saturating_sub(row, 1)
	}
	row = usize(screen.scrolling_region.top)
	for row < widget_checked_add(usize(screen.scrolling_region.top), count) {
		mut col := usize(screen.scrolling_region.left)
		for col <= usize(screen.scrolling_region.right) {
			i := widget_checked_add(widget_checked_mul(row, usize(screen.width)), col)
			screen.buf[int(i)].erase(screen.cursor.style.bg)
			col = widget_checked_add(col, 1)
		}
		row = widget_checked_add(row, 1)
	}
}

pub fn (mut screen TerminalScreen) erase_below() {
	screen.erase_right()
	mut i := terminal_screen_add16(terminal_screen_mul16(screen.cursor.row, screen.width),
		screen.width)
	for int(i) < screen.buf.len {
		screen.buf[int(i)].erase(screen.cursor.style.bg)
		i = terminal_screen_add16(i, 1)
	}
}

pub fn (mut screen TerminalScreen) erase_above() {
	screen.erase_left()
	limit := terminal_screen_mul16(screen.cursor.row, screen.width)
	mut i := usize(0)
	for i < usize(limit) {
		screen.buf[int(i)].erase(screen.cursor.style.bg)
		i = widget_checked_add(i, 1)
	}
}

pub fn (mut screen TerminalScreen) erase_all() {
	for i in 0 .. screen.buf.len {
		screen.buf[i].erase(screen.cursor.style.bg)
	}
}

pub fn (mut screen TerminalScreen) delete_characters(n usize) ! {
	if !screen.within_scrolling_region() { return }
	screen.cursor.pending_wrap = false
	mut col := screen.cursor.col
	for col <= screen.scrolling_region.right {
		next := widget_checked_add(usize(col), n)
		if next <= usize(screen.scrolling_region.right) {
			screen.buf[int(col)].copy_from(screen.buf[int(next)])!
		} else {
			screen.buf[int(col)].erase(screen.cursor.style.bg)
		}
		col = terminal_screen_add16(col, 1)
	}
}

pub fn (mut screen TerminalScreen) reverse_index() ! {
	if screen.cursor.row != screen.scrolling_region.top
		|| screen.cursor.col < screen.scrolling_region.left
		|| screen.cursor.col > screen.scrolling_region.right {
		screen.cursor_up(1)
	} else {
		screen.scroll_down(1)!
	}
}

pub fn (mut screen TerminalScreen) scroll_down(n usize) ! {
	row := screen.cursor.row
	col := screen.cursor.col
	wrap := screen.cursor.pending_wrap
	defer {
		screen.cursor.row = row
		screen.cursor.col = col
		screen.cursor.pending_wrap = wrap
	}
	screen.cursor.col = screen.scrolling_region.left
	screen.cursor.row = screen.scrolling_region.top
	screen.insert_line(n)!
}

fn terminal_screen_add16(a u16, b u16) u16 {
	if b > 0xffff - a { panic('integer overflow') }
	return a + b
}

fn terminal_screen_sub16(a u16, b u16) u16 {
	if b > a { panic('integer overflow') }
	return a - b
}

fn terminal_screen_mul16(a u16, b u16) u16 {
	if b != 0 && a > 0xffff / b { panic('integer overflow') }
	return a * b
}

pub fn (mut screen TerminalScreen) sgr(seq TerminalCsi) {
	if seq.params.len == 0 {
		screen.cursor.style = Style{}
		return
	}
	mut iter := seq.iterator[u8]()
	for {
		ps := iter.next() or { break }
		match ps {
			0 {
				screen.cursor.style = Style{}
			}
			1 {
				screen.cursor.style = Style{
					...screen.cursor.style
					bold: true
				}
			}
			2 {
				screen.cursor.style = Style{
					...screen.cursor.style
					dim: true
				}
			}
			3 {
				screen.cursor.style = Style{
					...screen.cursor.style
					italic: true
				}
			}
			4 {
				kind := if iter.next_is_sub { iter.next() or { u8(1) } } else { u8(1) }
				if kind > 5 { panic('invalid enum value') }
				screen.cursor.style = Style{
					...screen.cursor.style
					ul_style: unsafe { UnderlineStyle(kind) }
				}
			}
			5 {
				screen.cursor.style = Style{
					...screen.cursor.style
					blink: true
				}
			}
			7 {
				screen.cursor.style = Style{
					...screen.cursor.style
					reverse: true
				}
			}
			8 {
				screen.cursor.style = Style{
					...screen.cursor.style
					invisible: true
				}
			}
			9 {
				screen.cursor.style = Style{
					...screen.cursor.style
					strikethrough: true
				}
			}
			21 {
				screen.cursor.style = Style{
					...screen.cursor.style
					ul_style: .double_
				}
			}
			22 {
				screen.cursor.style = Style{
					...screen.cursor.style
					bold: false
				}
				screen.cursor.style = Style{
					...screen.cursor.style
					dim: false
				}
			}
			23 {
				screen.cursor.style = Style{
					...screen.cursor.style
					italic: false
				}
			}
			24 {
				screen.cursor.style = Style{
					...screen.cursor.style
					ul_style: .off
				}
			}
			25 {
				screen.cursor.style = Style{
					...screen.cursor.style
					blink: false
				}
			}
			27 {
				screen.cursor.style = Style{
					...screen.cursor.style
					reverse: false
				}
			}
			28 {
				screen.cursor.style = Style{
					...screen.cursor.style
					invisible: false
				}
			}
			29 {
				screen.cursor.style = Style{
					...screen.cursor.style
					strikethrough: false
				}
			}
			30...37 {
				screen.cursor.style = Style{
					...screen.cursor.style
					fg: ColorIndex{
						index: ps - 30
					}
				}
			}
			38 {
				value := terminal_screen_color(mut iter) or { return }
				screen.cursor.style = Style{
					...screen.cursor.style
					fg: value
				}
			}
			39 {
				screen.cursor.style = Style{
					...screen.cursor.style
					fg: ColorDefault{}
				}
			}
			40...47 {
				screen.cursor.style = Style{
					...screen.cursor.style
					bg: ColorIndex{
						index: ps - 40
					}
				}
			}
			48 {
				value := terminal_screen_color(mut iter) or { return }
				screen.cursor.style = Style{
					...screen.cursor.style
					bg: value
				}
			}
			49 {
				screen.cursor.style = Style{
					...screen.cursor.style
					bg: ColorDefault{}
				}
			}
			90...97 {
				screen.cursor.style = Style{
					...screen.cursor.style
					fg: ColorIndex{
						index: ps - 90 + 8
					}
				}
			}
			100...107 {
				screen.cursor.style = Style{
					...screen.cursor.style
					bg: ColorIndex{
						index: ps - 100 + 8
					}
				}
			}
			else {
				continue
			}
		}
	}
}

fn terminal_screen_color(mut iter TerminalParamIterator[u8]) ?Color {
	kind := iter.next() or { return none }
	match kind {
		2 {
			mut r := iter.next() or { return none }
			if iter.is_empty { r = iter.next() or { return none } }
			g := iter.next() or { return none }
			b := iter.next() or { return none }
			return ColorRgb{
				rgb: [r, g, b]!
			}
		}
		5 {
			index := iter.next() or { return none }
			return ColorIndex{
				index: index
			}
		}
		else {
			return none
		}
	}
}
