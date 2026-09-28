module vaxis

pub struct Window {
pub:
	x_off        int
	y_off        int
	parent_x_off int
	parent_y_off int
	width        u16
	height       u16
	screen       &Screen = unsafe { nil }
}

pub struct WindowChildOptions {
pub:
	x_off  int
	y_off  int
	width  ?u16
	height ?u16
	border WindowBorderOptions
}

pub struct BorderNone {}

pub struct BorderAll {}

pub struct BorderTop {}

pub struct BorderRight {}

pub struct BorderBottom {}

pub struct BorderLeft {}

pub struct BorderLocations {
pub:
	top    bool
	right  bool
	bottom bool
	left   bool
}

pub type BorderWhere = BorderNone
	| BorderAll
	| BorderTop
	| BorderRight
	| BorderBottom
	| BorderLeft
	| BorderLocations

pub struct BorderSingleRounded {}

pub struct BorderSingleSquare {}

pub struct BorderCustom {
pub:
	glyphs [6]string
}

pub type BorderGlyphs = BorderSingleRounded | BorderSingleSquare | BorderCustom

pub struct WindowBorderOptions {
pub:
	style  Style
	where_ BorderWhere  = BorderNone{}
	glyphs BorderGlyphs = BorderSingleRounded{}
}

pub fn Window.new(screen &Screen) Window {
	return Window{
		width:  screen.width
		height: screen.height
		screen: screen
	}
}

fn (w Window) init_child(x_off int, y_off int, maybe_width ?u16, maybe_height ?u16) Window {
	// V has no i17 storage; enforce the source's signed range on every child.
	assert x_off >= -0x10000 && x_off <= 0xffff
	assert y_off >= -0x10000 && y_off <= 0xffff
	max_height := max_int(int(w.height) - y_off, 0)
	max_width := max_int(int(w.width) - x_off, 0)
	assert max_height <= 0xffff && max_width <= 0xffff
	width := if value := maybe_width { int(value) } else { max_width }
	height := if value := maybe_height { int(value) } else { max_height }
	abs_x := x_off + w.x_off
	abs_y := y_off + w.y_off
	parent_x := min_int(w.parent_x_off + x_off, 0)
	parent_y := min_int(w.parent_y_off + y_off, 0)
	assert abs_x >= -0x10000 && abs_x <= 0xffff
	assert abs_y >= -0x10000 && abs_y <= 0xffff
	assert parent_x >= -0x10000 && parent_x <= 0xffff
	assert parent_y >= -0x10000 && parent_y <= 0xffff
	return Window{
		x_off:        abs_x
		y_off:        abs_y
		parent_x_off: parent_x
		parent_y_off: parent_y
		width:        u16(min_int(width, max_width))
		height:       u16(min_int(height, max_height))
		screen:       w.screen
	}
}

pub fn (w Window) child(opts WindowChildOptions) Window {
	result := w.init_child(opts.x_off, opts.y_off, opts.width, opts.height)
	glyphs := match opts.border.glyphs {
		BorderSingleRounded { ['╭', '─', '╮', '│', '╯', '╰']! }
		BorderSingleSquare { ['┌', '─', '┐', '│', '┘', '└']! }
		BorderCustom { opts.border.glyphs.glyphs }
	}

	locations := match opts.border.where_ {
		BorderNone {
			return result
		}
		BorderAll {
			BorderLocations{
				top:    true
				right:  true
				bottom: true
				left:   true
			}
		}
		BorderTop {
			BorderLocations{
				top: true
			}
		}
		BorderRight {
			BorderLocations{
				right: true
			}
		}
		BorderBottom {
			BorderLocations{
				bottom: true
			}
		}
		BorderLeft {
			BorderLocations{
				left: true
			}
		}
		BorderLocations {
			opts.border.where_
		}
	}

	style := opts.border.style
	for i := u16(0); i < result.width; i++ {
		if locations.top {
			result.write_cell(i, 0, Cell{
				char_: CellCharacter{
					grapheme: glyphs[1]
				}
				style: style
			})
		}
		if locations.bottom {
			result.write_cell(i, u16(max_int(int(result.height) - 1, 0)), Cell{
				char_: CellCharacter{
					grapheme: glyphs[1]
				}
				style: style
			})
		}
	}
	for i := u16(0); i < result.height; i++ {
		if locations.left {
			result.write_cell(0, i, Cell{
				char_: CellCharacter{
					grapheme: glyphs[3]
				}
				style: style
			})
		}
		if locations.right {
			result.write_cell(u16(max_int(int(result.width) - 1, 0)), i, Cell{
				char_: CellCharacter{
					grapheme: glyphs[3]
				}
				style: style
			})
		}
	}
	if locations.top && locations.left {
		result.write_cell(0, 0, Cell{
			char_: CellCharacter{
				grapheme: glyphs[0]
			}
			style: style
		})
	}
	if locations.top && locations.right {
		result.write_cell(u16(max_int(int(result.width) - 1, 0)), 0, Cell{
			char_: CellCharacter{
				grapheme: glyphs[2]
			}
			style: style
		})
	}
	if locations.bottom && locations.left {
		result.write_cell(0, u16(max_int(int(result.height) - 1, 0)), Cell{
			char_: CellCharacter{
				grapheme: glyphs[5]
			}
			style: style
		})
	}
	if locations.bottom && locations.right {
		result.write_cell(u16(max_int(int(result.width) - 1, 0)), u16(max_int(int(result.height) - 1,
			0)), Cell{
			char_: CellCharacter{
				grapheme: glyphs[4]
			}
			style: style
		})
	}
	child_x := if locations.left { 1 } else { 0 }
	child_y := if locations.top { 1 } else { 0 }
	child_width := max_int(int(result.width) - child_x - (if locations.right { 1 } else { 0 }), 0)
	child_height :=
		max_int(int(result.height) - child_y - (if locations.bottom { 1 } else { 0 }), 0)
	return result.init_child(child_x, child_y, u16(child_width), u16(child_height))
}

pub fn (w Window) write_cell(col u16, row u16, cell Cell) {
	if row >= w.height || col >= w.width || w.x_off + int(col) < 0 || w.y_off + int(row) < 0
		|| w.parent_x_off + int(col) < 0 || w.parent_y_off + int(row) < 0 {
		return
	}
	mut screen := unsafe { w.screen }
	screen.write_cell(u16(w.x_off + int(col)), u16(w.y_off + int(row)), cell)
}

pub fn (w Window) read_cell(col u16, row u16) ?Cell {
	if row >= w.height || col >= w.width || w.x_off + int(col) < 0 || w.y_off + int(row) < 0
		|| w.parent_x_off + int(col) < 0 || w.parent_y_off + int(row) < 0 {
		return none
	}
	return w.screen.read_cell(u16(w.x_off + int(col)), u16(w.y_off + int(row)))
}

pub fn (w Window) clear() {
	w.fill(Cell{ default_: true })
}

pub fn (w Window) gwidth(text string) u16 {
	return gwidth(text, w.screen.width_method)
}

pub fn (w Window) fill(cell Cell) {
	if w.x_off + int(w.width) < 0 || w.y_off + int(w.height) < 0 || int(w.screen.width) < w.x_off
		|| int(w.screen.height) < w.y_off {
		return
	}
	mut screen := unsafe { w.screen }
	first_row := max_int(w.y_off, 0)
	if w.x_off == 0 && w.width == w.screen.width {
		start := min_int(first_row * int(w.width), w.screen.buf.len)
		fill_end := min_int(start + int(w.height) * int(w.width), w.screen.buf.len)
		for i in start .. fill_end {
			screen.buf[i] = cell
		}
	} else {
		first_col := max_int(w.x_off, 0)
		last_row := min_int(int(w.height) + w.y_off, int(w.screen.height))
		for row := first_row; row < last_row; row++ {
			start := min_int(first_col + row * int(w.screen.width), w.screen.buf.len)
			mut fill_end := min_int(start + int(w.width), start + int(w.screen.width) - first_col)
			fill_end = min_int(fill_end, w.screen.buf.len)
			for i in start .. fill_end {
				screen.buf[i] = cell
			}
		}
	}
}

pub fn (w Window) hide_cursor() {
	mut screen := unsafe { w.screen }
	screen.cursor_vis = false
}

pub fn (w Window) show_cursor(col u16, row u16) {
	if w.x_off + int(col) < 0 || w.y_off + int(row) < 0 || row >= w.height || col >= w.width {
		return
	}
	mut screen := unsafe { w.screen }
	screen.cursor_vis = true
	screen.cursor_row = u16(w.y_off + int(row))
	screen.cursor_col = u16(w.x_off + int(col))
}

pub fn (w Window) set_cursor_shape(shape CursorShape) {
	mut screen := unsafe { w.screen }
	screen.cursor_shape = shape
}

pub enum PrintWrap as u8 {
	grapheme
	word
	none
}

pub struct PrintOptions {
pub:
	row_offset u16
	col_offset u16
	wrap       PrintWrap = .grapheme
	commit     bool      = true
}

pub struct PrintResult {
pub:
	col      u16
	row      u16
	overflow bool
}

pub fn (w Window) print(segments []CellSegment, opts PrintOptions) PrintResult {
	mut row := opts.row_offset
	match opts.wrap {
		.grapheme {
			mut col := opts.col_offset
			mut overflow := false
			grapheme_outer: for segment in segments {
				mut offset := 0
				for offset < segment.text.len {
					if col >= w.width {
						row++
						col = 0
					}
					if row >= w.height {
						overflow = true
						break grapheme_outer
					}
					length := first_grapheme_byte_length(segment.text[offset..])
					if length == 0 {
						break
					}
					grapheme := segment.text[offset..offset + length]
					offset += length
					if grapheme == '\n' {
						row = saturating_u16_add(row, 1)
						col = 0
						continue
					}
					width := w.gwidth(grapheme)
					if width == 0 {
						continue
					}
					if opts.commit {
						w.write_cell(col, row, Cell{
							char_:   CellCharacter{
								grapheme: grapheme
								width:    u8(width)
							}
							style:   segment.style
							link:    segment.link
							wrapped: int(col) + int(width) >= int(w.width)
						})
					}
					col += width
				}
			}
			if col >= w.width {
				row++
				col = 0
			}
			return PrintResult{
				row:      row
				col:      col
				overflow: overflow
			}
		}
		.word {
			mut col := opts.col_offset
			mut overflow := false
			mut soft_wrapped := false
			word_outer: for segment in segments {
				mut line_iter := WindowLineIterator{
					buf: segment.text
				}
				for {
					line := line_iter.next() or { break }
					mut iter := WindowWhitespaceTokenizer{
						buf: line
					}
					mut stop := false
					for {
						token := iter.next() or { break }
						match token {
							WindowWhitespace {
								if soft_wrapped {
									continue
								}
								for _ in 0 .. token.length {
									if col >= w.width {
										col = 0
										row++
										break
									}
									if opts.commit {
										w.write_cell(col, row, Cell{
											char_: CellCharacter{}
											style: segment.style
											link:  segment.link
										})
									}
									col++
								}
							}
							WindowWord {
								word_width := w.gwidth(token.text)
								if int(word_width) + int(col) > int(w.width) && word_width < w.width {
									row++
									col = 0
								}
								mut offset := 0
								for offset < token.text.len {
									soft_wrapped = false
									if row >= w.height {
										overflow = true
										stop = true
										break
									}
									length := first_grapheme_byte_length(token.text[offset..])
									if length == 0 {
										break
									}
									grapheme := token.text[offset..offset + length]
									offset += length
									width := w.gwidth(grapheme)
									if opts.commit {
										w.write_cell(col, row, Cell{
											char_: CellCharacter{
												grapheme: grapheme
												width:    u8(width)
											}
											style: segment.style
											link:  segment.link
										})
									}
									col += width
									if col >= w.width {
										row++
										col = 0
										soft_wrapped = true
									}
								}
							}
						}

						if stop {
							break
						}
					}
					if line_iter.has_break {
						soft_wrapped = false
						row++
						col = 0
					}
					if stop {
						break word_outer
					}
				}
			}
			return PrintResult{
				row:      row
				col:      col
				overflow: overflow
			}
		}
		.none {
			mut col := opts.col_offset
			mut overflow := false
			none_outer: for segment in segments {
				mut offset := 0
				for offset < segment.text.len {
					if col >= w.width {
						overflow = true
						break none_outer
					}
					length := first_grapheme_byte_length(segment.text[offset..])
					if length == 0 {
						break
					}
					grapheme := segment.text[offset..offset + length]
					offset += length
					if grapheme == '\n' {
						overflow = true
						break none_outer
					}
					width := w.gwidth(grapheme)
					if width == 0 {
						continue
					}
					if opts.commit {
						w.write_cell(col, row, Cell{
							char_: CellCharacter{
								grapheme: grapheme
								width:    u8(width)
							}
							style: segment.style
							link:  segment.link
						})
					}
					col = saturating_u16_add(col, width)
				}
			}
			return PrintResult{
				row:      row
				col:      col
				overflow: overflow
			}
		}
	}
}

pub fn (w Window) print_segment(segment CellSegment, opts PrintOptions) PrintResult {
	return w.print([segment], opts)
}

pub fn (w Window) scroll(n u16) {
	if n > w.height {
		return
	}
	mut screen := unsafe { w.screen }
	mut row := u16(max_int(w.y_off, 0))
	first_col := u16(max_int(w.x_off, 0))
	for row < w.height - n {
		dst_start := int(row) * int(w.screen.width) + int(first_col)
		src_start := (int(row) + int(n)) * int(w.screen.width) + int(first_col)
		assert dst_start + int(w.width) <= screen.buf.len
		assert src_start + int(w.width) <= screen.buf.len
		for col in 0 .. int(w.width) {
			screen.buf[dst_start + col] = screen.buf[src_start + col]
		}
		row++
	}
	last_row := w.child(WindowChildOptions{ y_off: int(w.height - n) })
	last_row.clear()
}

fn saturating_u16_add(a u16, b u16) u16 {
	return u16(min_int(int(a) + int(b), 0xffff))
}

struct WindowLineIterator {
	buf string
mut:
	index     int
	has_break bool = true
}

fn (mut iter WindowLineIterator) next() ?string {
	if iter.index >= iter.buf.len {
		return none
	}
	start := iter.index
	mut range_end := iter.buf.len
	for i in iter.index .. iter.buf.len {
		if iter.buf[i] == `\r` || iter.buf[i] == `\n` {
			range_end = i
			break
		}
	}
	if range_end == iter.buf.len {
		if start == 0 {
			iter.has_break = false
		}
		iter.index = iter.buf.len
		return iter.buf[start..]
	}
	iter.index = range_end
	if iter.index < iter.buf.len && iter.buf[iter.index] == `\r` {
		iter.index++
	}
	if iter.index < iter.buf.len && iter.buf[iter.index] == `\n` {
		iter.index++
	}
	return iter.buf[start..range_end]
}

struct WindowWhitespace {
	length int
}

struct WindowWord {
	text string
}

type WindowToken = WindowWhitespace | WindowWord

struct WindowWhitespaceTokenizer {
	buf string
mut:
	index int
}

fn (mut iter WindowWhitespaceTokenizer) next() ?WindowToken {
	if iter.index >= iter.buf.len {
		return none
	}
	first := iter.buf[iter.index]
	if first == ` ` || first == `\t` {
		mut length := 0
		for iter.index < iter.buf.len {
			match iter.buf[iter.index] {
				` ` { length++ }
				`\t` { length += 8 }
				else { break }
			}

			iter.index++
		}
		return WindowWhitespace{
			length: length
		}
	}
	start := iter.index
	for iter.index < iter.buf.len && iter.buf[iter.index] != ` ` && iter.buf[iter.index] != `\t` {
		iter.index++
	}
	return WindowWord{
		text: iter.buf[start..iter.index]
	}
}

pub fn (w Window) has_mouse(mouse ?Mouse) ?Mouse {
	if event := mouse {
		if int(event.col) >= w.x_off && int(event.col) < w.x_off + int(w.width)
			&& int(event.row) >= w.y_off && int(event.row) < w.y_off + int(w.height) {
			return event
		}
	}
	return none
}

fn min_int(a int, b int) int {
	return if a < b { a } else { b }
}
