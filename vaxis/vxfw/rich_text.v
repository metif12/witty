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
	mut iter := &RichSoftwrapIterator{
		...RichSoftwrapIterator.new(text.text, ctx)
	}
	size := text.find_container_size(mut iter)
	mut surface := &Surface{
		...Surface.init(text.widget(), size)
	}
	for i in 0 .. surface.buffer.len {
		surface.buffer[i] = vaxis.Cell{
			style: text.base_style
		}
	}
	mut row := u16(0)
	if text.softwrap {
		for {
			line := rich_draw_next(mut iter) or { break }
			if ctx.max.outside_height(row) { break
			 }
			mut col := match text.text_align {
				.left { u16(0) }
				.center { vxfw_u16_sub(size.width, line.width) / 2 }
				.right { vxfw_u16_sub(size.width, line.width) }
			}

			for cell in line.cells {
				surface.write_cell(col, row, cell)
				col = vxfw_u16_add(col, u16(cell.char_.width))
			}
			row = vxfw_u16_add(row, 1)
		}
	} else {
		for {
			line := rich_draw_next_hard(mut iter) or { break }
			if ctx.max.outside_height(row) { break
			 }
			width := rich_line_width(line.cells, true)
			mut col := match text.text_align {
				.left { u16(0) }
				.center { sat_sub(size.width, width) / 2 }
				.right { sat_sub(size.width, width) }
			}

			for cell in line.cells {
				if vxfw_u16_add(col, u16(cell.char_.width)) >= size.width && width > size.width
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
				col = vxfw_u16_add(col, u16(cell.char_.width))
			}
			row = vxfw_u16_add(row, 1)
		}
	}
	return surface.trim_height(math.max(row, ctx.min.height))
}

// Keep GC ownership in heap shells during drawing. The source line arrays stay
// borrowed; this avoids repeated recursive production keepalive scans per cell.
struct RichDrawCells {
	cells []vaxis.Cell
}

fn rich_draw_next(mut iter RichSoftwrapIterator) ?&RichWrappedLine {
	value := iter.next() or { return none }
	return &RichWrappedLine{
		...value
	}
}

fn rich_draw_next_hard(mut iter RichSoftwrapIterator) ?&RichDrawCells {
	cells := iter.next_hard_break() or { return none }
	return &RichDrawCells{
		cells: cells
	}
}

fn rich_line_width(line []vaxis.Cell, saturating bool) u16 {
	mut width := u16(0)
	for cell in line {
		if saturating {
			width = u16(math.min(u32(width) + cell.char_.width, u32(0xffff)))
		} else {
			width = vxfw_u16_add(width, u16(cell.char_.width))
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
			row = vxfw_u16_add(row, 1)
		}
	} else {
		for {
			line := iter.next_hard_break() or { break }
			if iter.ctx.max.outside_height(row) { break
			 }
			width = math.max(width, rich_line_width(line, true))
			row = vxfw_u16_add(row, 1)
		}
	}
	return Size{
		width:  match text.width_basis {
			.longest_line {
				if max_width := iter.ctx.max.width { math.min(max_width, width) } else { width }
			}
			.parent {
				iter.ctx.max.width or { panic('Assertion failed') }
			}
		}
		height: math.max(row, iter.ctx.min.height)
	}
}

pub struct RichWrappedLine {
pub mut:
	width u16          @[required]
	cells []vaxis.Cell @[required]
}

// The allocator is GC-owned in V; the source cell slices and usize cursors stay
// borrowed public payloads. Methods are V adapters for the source-private ones.
pub struct RichSoftwrapIterator {
pub mut:
	ctx        DrawContext  @[required]
	text       []vaxis.Cell @[required]
	line       []vaxis.Cell @[required]
	index      uint
	hard_index uint
}

fn rich_cells_slice(cells []vaxis.Cell, start uint, end uint) []vaxis.Cell {
	if start > end || end > uint(cells.len) { panic('index out of bounds') }
	return cells[int(start)..int(end)]
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
					width:    vxfw_u8_cast(u64(ctx.string_width(grapheme)))
				}
				style: span.style
				link:  span.link
			}
		}
	}
	return RichSoftwrapIterator{
		ctx:  ctx
		text: cells
		line: []vaxis.Cell{}
	}
}

pub fn (mut iter RichSoftwrapIterator) reset() {
	iter.index = 0
	iter.hard_index = 0
	iter.line = []vaxis.Cell{}
}

pub fn (mut iter RichSoftwrapIterator) next_hard_break() ?[]vaxis.Cell {
	if iter.hard_index >= uint(iter.text.len) { return none }
	start := iter.hard_index
	mut saw_cr := false
	for iter.hard_index < uint(iter.text.len) {
		cell := iter.text[int(iter.hard_index)]
		if cell.char_.grapheme == '\r' { saw_cr = true }
		if cell.char_.grapheme == '\n' {
			iter.hard_index = vxfw_usize_add(iter.hard_index, 1)
			end := vxfw_usize_sub(iter.hard_index, if saw_cr { uint(2) } else { uint(1) })
			if start > end { panic('index out of bounds') }
			return rich_cells_slice(iter.text, start, end)
		}
		if saw_cr {
			iter.hard_index = vxfw_usize_sub(iter.hard_index, 1)
			end := vxfw_usize_sub(iter.hard_index, 1)
			if start > end { panic('index out of bounds') }
			return rich_cells_slice(iter.text, start, end)
		}
		iter.hard_index = vxfw_usize_add(iter.hard_index, 1)
	}
	return rich_cells_slice(iter.text, start, uint(iter.text.len))
}

fn rich_whitespace(cell vaxis.Cell) bool {
	return cell.char_.grapheme in [' ', '\t']
}

pub fn (mut iter RichSoftwrapIterator) next() ?RichWrappedLine {
	if iter.index == uint(iter.line.len) {
		iter.line = iter.next_hard_break() or { return none }
		mut end := iter.line.len
		for end > 0 && rich_whitespace(iter.line[end - 1]) {
			end--
		}
		iter.line = iter.line[..end]
		iter.index = 0
	}
	max_width := iter.ctx.max.width or {
		width := rich_line_width(iter.line, false)
		iter.index = uint(iter.line.len)
		return RichWrappedLine{
			width: width
			cells: iter.line
		}
	}

	start := iter.index
	mut width := u16(0)
	for iter.index < uint(iter.line.len) {
		idx := iter.next_wrap()
		word := rich_cells_slice(iter.line, iter.index, idx)
		mut next_width := uint(0)
		for cell in word {
			next_width = vxfw_usize_add(next_width, uint(cell.char_.width))
		}
		if vxfw_usize_add(uint(width), next_width) > uint(max_width) {
			mut trim := 0
			for trim < word.len && rich_whitespace(word[trim]) {
				trim++
			}
			trimmed_width := if next_width > uint(trim) {
				next_width - uint(trim)
			} else {
				uint(0)
			}
			if trimmed_width > max_width {
				for cell in word {
					if vxfw_u16_add(width, u16(cell.char_.width)) > max_width { return RichWrappedLine{
							width: width
							cells: rich_cells_slice(iter.line, start, iter.index)
						} }
					width = vxfw_u16_add(width, u16(cell.char_.width))
					iter.index = vxfw_usize_add(iter.index, 1)
				}
			}
			end := iter.index
			iter.index = vxfw_usize_add(iter.index, uint(trim))
			return RichWrappedLine{
				width: width
				cells: rich_cells_slice(iter.line, start, end)
			}
		}
		iter.index = idx
		width = vxfw_u16_add(width, vxfw_u16_cast(u64(next_width)))
	}
	return RichWrappedLine{
		width: width
		cells: rich_cells_slice(iter.line, start, uint(iter.line.len))
	}
}

fn (iter RichSoftwrapIterator) next_wrap() uint {
	mut i := iter.index
	for i < uint(iter.line.len) && rich_whitespace(iter.line[int(i)]) {
		i = vxfw_usize_add(i, 1)
	}
	for i < uint(iter.line.len) && !rich_whitespace(iter.line[int(i)]) {
		i = vxfw_usize_add(i, 1)
	}
	return i
}
