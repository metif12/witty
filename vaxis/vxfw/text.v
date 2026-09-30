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
	text        string
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
				size:   ctx.min
				widget: text.widget()
			} }
	}
	size := text.find_container_size(ctx)
	mut surface := Surface.init(text.widget(), size)
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
			if row >= size.height { break
			 }
			mut col := text.start_col(size.width, line.width)
			mut chars := ctx.grapheme_iterator(line.bytes)
			for {
				grapheme := chars.next() or { break }
				if grapheme == '\t' {
					for i in 0 .. 8 {
						surface.write_cell(col + u16(i), row, vaxis.Cell{
							char_: vaxis.CellCharacter{
								grapheme: ' '
								width:    1
							}
							style: text.style
						})
					}
					col += 8
					continue
				}
				width := u8(ctx.string_width(grapheme))
				surface.write_cell(col, row, vaxis.Cell{
					char_: vaxis.CellCharacter{
						grapheme: grapheme
						width:    width
					}
					style: text.style
				})
				col += width
			}
			row++
		}
	} else {
		mut iter := LineIterator{
			buf: text.text
		}
		for {
			line := iter.next() or { break }
			if row >= size.height { break
			 }
			line_width := ctx.string_width(line) + 7 * usize(line.count('\t'))
			mut col := text.start_col(size.width, u16(math.min(usize(size.width), line_width)))
			mut chars := ctx.grapheme_iterator(line)
			for {
				grapheme := chars.next() or { break }
				if col >= size.width { break
				 }
				width := u8(ctx.string_width(grapheme))
				if col + width >= size.width && line_width > size.width
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
					col += width
				}
			}
			row++
		}
	}
	return surface.trim_height(math.max(row, ctx.min.height))
}

fn (text Text) start_col(width u16, line_width u16) u16 {
	return match text.text_align {
		.left { 0 }
		.center { (width - line_width) / 2 }
		.right { width - line_width }
	}
}

fn (text Text) find_container_size(ctx DrawContext) Size {
	mut row := u16(0)
	mut width := ctx.min.width
	if text.softwrap {
		mut iter := SoftwrapIterator.new(text.text, ctx)
		for {
			line := iter.next() or { break }
			if ctx.max.outside_height(row) { break
			 }
			width = math.max(width, line.width)
			row++
		}
	} else {
		mut iter := LineIterator{
			buf: text.text
		}
		for {
			line := iter.next() or { break }
			if ctx.max.outside_height(row) { break
			 }
			line_width := u16(ctx.string_width(line))
			width = math.max(width, if max_width := ctx.max.width {
				math.min(max_width, line_width)
			} else {
				line_width
			})
			row++
		}
	}
	return Size{
		width:  match text.width_basis {
			.longest_line {
				if max_width := ctx.max.width { math.min(max_width, width) } else { width }
			}
			.parent {
				ctx.max.width or { panic('parent width must be bounded') }
			}
		}
		height: math.max(row, ctx.min.height)
	}
}

pub struct LineIterator {
pub mut:
	buf   string
	index int
}

pub fn (mut iter LineIterator) next() ?string {
	if iter.index >= iter.buf.len { return none }
	start := iter.index
	for iter.index < iter.buf.len && iter.buf[iter.index] != `\r` && iter.buf[iter.index] != `\n` {
		iter.index++
	}
	end := iter.index
	if iter.index < iter.buf.len && iter.buf[iter.index] == `\r` { iter.index++ }
	if iter.index < iter.buf.len && iter.buf[iter.index] == `\n` { iter.index++ }
	return iter.buf[start..end]
}

pub struct WrappedLine {
pub mut:
	width u16
	bytes string
}

pub struct SoftwrapIterator {
	ctx DrawContext
mut:
	line      string
	index     int
	hard_iter LineIterator
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
	if iter.index == iter.line.len {
		iter.line = (iter.hard_iter.next() or { return none }).trim_right(' \t')
		iter.index = 0
	}
	start := iter.index
	mut width := u16(0)
	for iter.index < iter.line.len {
		idx := iter.next_wrap()
		word := iter.line[iter.index..idx]
		next_width := iter.ctx.string_width(word)
		if max_width := iter.ctx.max.width {
			if usize(width) + next_width > max_width {
				trimmed := word.trim_left(' \t')
				trimmed_width := next_width - usize(word.len - trimmed.len)
				if trimmed_width > max_width {
					mut chars := iter.ctx.grapheme_iterator(word)
					for {
						grapheme := chars.next() or { break }
						w := iter.ctx.string_width(grapheme)
						if usize(width) + w > max_width { return WrappedLine{
								width: width
								bytes: iter.line[start..iter.index]
							} }
						width += u16(w)
						iter.index += grapheme.len
					}
				}
				end := iter.index
				for iter.index < iter.line.len && iter.line[iter.index] in [` `, `\t`] {
					iter.index++
				}
				return WrappedLine{
					width: width
					bytes: iter.line[start..end]
				}
			}
		}
		iter.index = idx
		width += u16(next_width)
	}
	return WrappedLine{
		width: width
		bytes: iter.line[start..]
	}
}

fn (iter SoftwrapIterator) next_wrap() int {
	mut index := iter.index
	for index < iter.line.len && iter.line[index] in [` `, `\t`] {
		index++
	}
	for index < iter.line.len && iter.line[index] !in [` `, `\t`] {
		index++
	}
	return index
}
