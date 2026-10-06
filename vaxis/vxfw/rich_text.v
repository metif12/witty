module vxfw

import math
import vaxis

pub type TextSpan = vaxis.CellSegment

pub struct RichText {
pub mut:
	text        []TextSpan @[required]
	text_align  TextAlign = .left
	base_style  vaxis.Style
	softwrap    bool         = true
	overflow    TextOverflow = .ellipsis
	width_basis WidthBasis   = .longest_line
}

pub fn (text &RichText) widget() Widget {
	return Widget{
		userdata: unsafe { voidptr(text) }
		draw_fn:  rich_text_draw
	}
}

fn rich_text_draw(ptr voidptr, ctx DrawContext) !Surface {
	return unsafe { &RichText(ptr) }.draw(ctx)
}

pub fn (text &RichText) draw(ctx DrawContext) !Surface {
	if width := ctx.max.width {
		if width == 0 { return Surface{
				buffer:   []vaxis.Cell{}
				children: []SubSurface{}
				size:     ctx.min
				widget:   text.widget()
			} }
	}
	mut iter := RichSoftwrapIterator.new(text.text, ctx)
	size := text.find_container_size(mut iter)
	mut surface := Surface.init(text.widget(), size)
	for i in 0 .. surface.buffer.len {
		surface.buffer[i] = vaxis.Cell{
			style: text.base_style
		}
	}
	mut row := u16(0)
	if text.softwrap {
		for {
			line := iter.next() or { break }
			if ctx.max.outside_height(row) { break
			 }
			mut col := match text.text_align {
				.left { u16(0) }
				.center { (size.width - line.width) / 2 }
				.right { size.width - line.width }
			}

			for cell in line.cells {
				surface.write_cell(col, row, cell)
				col += cell.char_.width
			}
			row++
		}
	} else {
		for {
			line := iter.next_hard_break() or { break }
			if ctx.max.outside_height(row) { break
			 }
			width := rich_line_width(line, true)
			mut col := match text.text_align {
				.left { u16(0) }
				.center { sat_sub(size.width, width) / 2 }
				.right { sat_sub(size.width, width) }
			}

			for cell in line {
				if col + cell.char_.width >= size.width && width > size.width
					&& text.overflow == .ellipsis {
					surface.write_cell(col, row, vaxis.Cell{
						char_: vaxis.CellCharacter{
							grapheme: '…'
							width:    1
						}
						style: cell.style
					})
					col = size.width
					continue
				}
				surface.write_cell(col, row, cell)
				col += cell.char_.width
			}
			row++
		}
	}
	return surface.trim_height(math.max(row, ctx.min.height))
}

fn rich_line_width(line []vaxis.Cell, saturating bool) u16 {
	mut width := u16(0)
	for cell in line {
		if saturating {
			width = u16(math.min(u32(width) + cell.char_.width, u32(0xffff)))
		} else {
			width += cell.char_.width
		}
	}
	return width
}

fn (text RichText) find_container_size(mut iter RichSoftwrapIterator) Size {
	defer { iter.reset() }
	mut row := u16(0)
	mut width := iter.ctx.min.width
	if text.softwrap {
		for {
			line := iter.next() or { break }
			if iter.ctx.max.outside_height(row) { break
			 }
			width = math.max(width, line.width)
			row++
		}
	} else {
		for {
			line := iter.next_hard_break() or { break }
			if iter.ctx.max.outside_height(row) { break
			 }
			width = math.max(width, rich_line_width(line, true))
			row++
		}
	}
	return Size{
		width:  match text.width_basis {
			.longest_line {
				if max_width := iter.ctx.max.width { math.min(max_width, width) } else { width }
			}
			.parent {
				iter.ctx.max.width or { panic('parent width must be bounded') }
			}
		}
		height: math.max(row, iter.ctx.min.height)
	}
}

pub struct RichWrappedLine {
pub mut:
	width u16
	cells []vaxis.Cell
}

pub struct RichSoftwrapIterator {
	ctx  DrawContext
	text []vaxis.Cell
mut:
	line       []vaxis.Cell
	index      int
	hard_index int
}

pub fn RichSoftwrapIterator.new(spans []TextSpan, ctx DrawContext) RichSoftwrapIterator {
	mut cells := []vaxis.Cell{}
	for span in spans {
		mut chars := ctx.grapheme_iterator(span.text)
		for {
			grapheme := chars.next() or { break }
			if grapheme == '\t' {
				cell := vaxis.Cell{
					char_: vaxis.CellCharacter{
						grapheme: ' '
						width:    1
					}
					style: span.style
					link:  span.link
				}
				for _ in 0 .. 8 {
					cells << cell
				}
				continue
			}
			cells << vaxis.Cell{
				char_: vaxis.CellCharacter{
					grapheme: grapheme
					width:    u8(ctx.string_width(grapheme))
				}
				style: span.style
				link:  span.link
			}
		}
	}
	return RichSoftwrapIterator{
		ctx:  ctx
		text: cells
	}
}

pub fn (mut iter RichSoftwrapIterator) reset() {
	iter.index = 0
	iter.hard_index = 0
	iter.line = []vaxis.Cell{}
}

pub fn (mut iter RichSoftwrapIterator) next_hard_break() ?[]vaxis.Cell {
	if iter.hard_index >= iter.text.len { return none }
	start := iter.hard_index
	mut saw_cr := false
	for iter.hard_index < iter.text.len {
		cell := iter.text[iter.hard_index]
		if cell.char_.grapheme == '\r' { saw_cr = true }
		if cell.char_.grapheme == '\n' {
			iter.hard_index++
			return iter.text[start..iter.hard_index - if saw_cr {
				2
			} else {
				1
			}]
		}
		if saw_cr {
			iter.hard_index--
			return iter.text[start..iter.hard_index - 1]
		}
		iter.hard_index++
	}
	return iter.text[start..]
}

fn rich_whitespace(cell vaxis.Cell) bool {
	return cell.char_.grapheme in [' ', '\t']
}

pub fn (mut iter RichSoftwrapIterator) next() ?RichWrappedLine {
	if iter.index == iter.line.len {
		iter.line = iter.next_hard_break() or { return none }
		mut end := iter.line.len
		for end > 0 && rich_whitespace(iter.line[end - 1]) {
			end--
		}
		iter.line = iter.line[..end]
		iter.index = 0
	}
	max_width := iter.ctx.max.width or {
		iter.index = iter.line.len
		return RichWrappedLine{
			width: rich_line_width(iter.line, false)
			cells: iter.line
		}
	}

	start := iter.index
	mut width := u16(0)
	for iter.index < iter.line.len {
		idx := iter.next_wrap()
		word := iter.line[iter.index..idx]
		mut next_width := usize(0)
		for cell in word {
			next_width += cell.char_.width
		}
		if usize(width) + next_width > max_width {
			mut trim := 0
			for trim < word.len && rich_whitespace(word[trim]) {
				trim++
			}
			trimmed_width := if next_width > usize(trim) {
				next_width - usize(trim)
			} else {
				usize(0)
			}
			if trimmed_width > max_width {
				for cell in word {
					if width + cell.char_.width > max_width { return RichWrappedLine{
							width: width
							cells: iter.line[start..iter.index]
						} }
					width += cell.char_.width
					iter.index++
				}
			}
			end := iter.index
			iter.index += trim
			return RichWrappedLine{
				width: width
				cells: iter.line[start..end]
			}
		}
		iter.index = idx
		width += u16(next_width)
	}
	return RichWrappedLine{
		width: width
		cells: iter.line[start..]
	}
}

fn (iter RichSoftwrapIterator) next_wrap() int {
	mut i := iter.index
	for i < iter.line.len && rich_whitespace(iter.line[i]) {
		i++
	}
	for i < iter.line.len && !rich_whitespace(iter.line[i]) {
		i++
	}
	return i
}
