module vxfw

import vaxis
import math

pub enum TextAlign {
	left
	center
	right
}
pub enum TextOverflow {
	ellipsis
	clip
}
pub enum WidthBasis {
	parent
	longest_line
}

pub struct Text {
pub mut:
	text        string @[required]
	style       vaxis.Style
	text_align  TextAlign    = .left
	softwrap    bool         = true
	overflow    TextOverflow = .ellipsis
	width_basis WidthBasis   = .longest_line
}

pub fn (text &Text) widget() Widget {
	return Widget{
		userdata: unsafe { voidptr(text) }
		draw_fn:  text_draw
	}
}

fn text_draw(ptr voidptr, ctx DrawContext) !Surface {
	text := unsafe { &Text(ptr) }
	return text.draw(ctx)
}

pub fn (text &Text) draw(ctx DrawContext) !Surface {
	if width := ctx.max.width {
		if width == 0 { return Surface{
				buffer:   []vaxis.Cell{}
				children: []SubSurface{}
				size:     ctx.min
				widget:   text.widget()
			} }
	}
	size := text.find_container_size(ctx)
	// Keep the local surface on the heap: pinned V production keepalive scans
	// value aggregates on every call, otherwise visiting all cells repeatedly.
	mut surface := &Surface{
		...Surface.init(text.widget(), size)
	}
	base := vaxis.Cell{
		style: vaxis.Style{
			fg:      text.style.fg
			bg:      text.style.bg
			reverse: text.style.reverse
		}
	}
	for i in 0 .. surface.buffer.len {
		surface.buffer[i] = base
	}
	mut row := u16(0)
	if text.softwrap {
		mut iter := SoftwrapIterator.new(text.text, ctx)
		for {
			line := iter.next() or { break }
			if row >= size.height {
				break
			}
			mut col := text.start_col(size.width, line.width)
			mut chars := ctx.grapheme_iterator(line.bytes)
			for {
				grapheme := chars.next() or { break }
				if grapheme == '\t' {
					for i in 0 .. 8 {
						surface.write_cell(vxfw_u16_cast(u64(vxfw_usize_add(uint(col), uint(i)))),
							row, vaxis.Cell{
							char_: vaxis.CellCharacter{
								grapheme: ' '
								width:    1
							}
							style: text.style
						})
					}
					col = vxfw_u16_add(col, 8)
					continue
				}
				width := vxfw_u8_cast(u64(ctx.string_width(grapheme)))
				surface.write_cell(col, row, vaxis.Cell{
					char_: vaxis.CellCharacter{
						grapheme: grapheme
						width:    width
					}
					style: text.style
				})
				col = vxfw_u16_add(col, u16(width))
			}
			row = vxfw_u16_add(row, 1)
		}
	} else {
		mut iter := LineIterator{
			buf: text.text
		}
		for {
			line := iter.next() or { break }
			if row >= size.height {
				break
			}
			line_width := vxfw_usize_add(ctx.string_width(line), vxfw_usize_mul(7,
				uint(line.count('\t'))))
			mut col := text.start_col(size.width, u16(math.min(uint(size.width), line_width)))
			mut chars := ctx.grapheme_iterator(line)
			for {
				grapheme := chars.next() or { break }
				if col >= size.width {
					break
				}
				width := vxfw_u8_cast(u64(ctx.string_width(grapheme)))
				if vxfw_u16_add(col, u16(width)) >= size.width && line_width > size.width
					&& text.overflow == .ellipsis {
					surface.write_cell(col, row, vaxis.Cell{
						char_: vaxis.CellCharacter{
							grapheme: '…'
							width:    1
						}
						style: text.style
					})
					col = size.width
				} else {
					surface.write_cell(col, row, vaxis.Cell{
						char_: vaxis.CellCharacter{
							grapheme: grapheme
							width:    width
						}
						style: text.style
					})
					col = vxfw_u16_add(col, u16(width))
				}
			}
			row = vxfw_u16_add(row, 1)
		}
	}
	return surface.trim_height(math.max(row, ctx.min.height))
}

fn (text Text) start_col(width u16, line_width u16) u16 {
	return match text.text_align {
		.left { 0 }
		.center { vxfw_u16_sub(width, line_width) / 2 }
		.right { vxfw_u16_sub(width, line_width) }
	}
}

fn (text Text) find_container_size(ctx DrawContext) Size {
	mut row := u16(0)
	mut width := ctx.min.width
	if text.softwrap {
		mut iter := SoftwrapIterator.new(text.text, ctx)
		for {
			line := iter.next() or { break }
			if ctx.max.outside_height(row) {
				break
			}
			width = math.max(width, line.width)
			row = vxfw_u16_add(row, 1)
		}
	} else {
		mut iter := LineIterator{
			buf: text.text
		}
		for {
			line := iter.next() or { break }
			if ctx.max.outside_height(row) {
				break
			}
			// The original intentionally truncates this width instead of casting it.
			line_width := u16(ctx.string_width(line) & 0xffff)
			width = math.max(width, if max_width := ctx.max.width {
				math.min(max_width, line_width)
			} else {
				line_width
			})
			row = vxfw_u16_add(row, 1)
		}
	}
	return Size{
		width:  match text.width_basis {
			.longest_line {
				if max_width := ctx.max.width { math.min(max_width, width) } else { width }
			}
			.parent {
				ctx.max.width or { panic('Assertion failed') }
			}
		}
		height: math.max(row, ctx.min.height)
	}
}

pub struct LineIterator {
pub mut:
	buf   string @[required]
	index uint
}

// Source exposes these payload types, but its iterator methods are private.
// The existing V iterator methods remain public adapters used by Text.draw.
pub fn (mut iter LineIterator) next() ?string {
	if iter.index >= uint(iter.buf.len) { return none }
	start := iter.index
	for iter.index < uint(iter.buf.len) && iter.buf[int(iter.index)] != `\r`
		&& iter.buf[int(iter.index)] != `\n` {
		iter.index = vxfw_usize_add(iter.index, 1)
	}
	end := iter.index
	if iter.index < uint(iter.buf.len) && iter.buf[int(iter.index)] == `\r` {
		iter.index = vxfw_usize_add(iter.index, 1)
	}
	if iter.index < uint(iter.buf.len) && iter.buf[int(iter.index)] == `\n` {
		iter.index = vxfw_usize_add(iter.index, 1)
	}
	return text_borrowed_slice(iter.buf, start, end)
}

pub struct WrappedLine {
pub mut:
	width u16    @[required]
	bytes string @[required]
}

pub struct SoftwrapIterator {
pub mut:
	ctx       DrawContext @[required]
	line      string
	index     uint
	hard_iter LineIterator @[required]
}

pub fn SoftwrapIterator.new(text string, ctx DrawContext) SoftwrapIterator {
	return SoftwrapIterator{
		ctx:       ctx
		hard_iter: LineIterator{
			buf: text
		}
	}
}

pub fn (mut iter SoftwrapIterator) next() ?WrappedLine {
	if iter.index == uint(iter.line.len) {
		iter.line = text_trim_right(iter.hard_iter.next() or { return none })
		iter.index = 0
	}
	start := iter.index
	mut width := u16(0)
	for iter.index < uint(iter.line.len) {
		idx := iter.next_wrap()
		word := text_borrowed_slice(iter.line, iter.index, idx)
		next_width := iter.ctx.string_width(word)
		if max_width := iter.ctx.max.width {
			if vxfw_usize_add(uint(width), next_width) > max_width {
				trimmed := text_trim_left(word)
				trimmed_width := vxfw_usize_sub(next_width, uint(word.len - trimmed.len))
				if trimmed_width > max_width {
					mut chars := iter.ctx.grapheme_iterator(word)
					for {
						grapheme := chars.next() or { break }
						w := iter.ctx.string_width(grapheme)
						if vxfw_usize_add(uint(width), w) > max_width { return WrappedLine{
								width: width
								bytes: text_borrowed_slice(iter.line, start, iter.index)
							} }
						width = vxfw_u16_add(width, vxfw_u16_cast(u64(w)))
						iter.index = vxfw_usize_add(iter.index, uint(grapheme.len))
					}
				}
				end := iter.index
				for iter.index < uint(iter.line.len) && iter.line[int(iter.index)] in [` `, `\t`] {
					iter.index = vxfw_usize_add(iter.index, 1)
				}
				return WrappedLine{
					width: width
					bytes: text_borrowed_slice(iter.line, start, end)
				}
			}
		}
		iter.index = idx
		width = vxfw_u16_add(width, vxfw_u16_cast(u64(next_width)))
	}
	return WrappedLine{
		width: width
		bytes: text_borrowed_slice(iter.line, start, uint(iter.line.len))
	}
}

fn (iter SoftwrapIterator) next_wrap() uint {
	mut index := iter.index
	for index < uint(iter.line.len) && iter.line[int(index)] in [` `, `\t`] {
		index = vxfw_usize_add(index, 1)
	}
	for index < uint(iter.line.len) && iter.line[int(index)] !in [` `, `\t`] {
		index = vxfw_usize_add(index, 1)
	}
	return index
}

// Source slices borrow caller storage, including zero-length views.
fn text_borrowed_slice(value string, start uint, end uint) string {
	if start > end || end > uint(value.len) { panic('index out of bounds') }
	return unsafe { tos(value.str + int(start), int(end - start)) }
}

fn text_trim_right(value string) string {
	mut end := value.len
	for end > 0 && value[end - 1] in [` `, `\t`] {
		end--
	}
	return text_borrowed_slice(value, 0, uint(end))
}

fn text_trim_left(value string) string {
	mut start := 0
	for start < value.len && value[start] in [` `, `\t`] {
		start++
	}
	return text_borrowed_slice(value, uint(start), uint(value.len))
}
