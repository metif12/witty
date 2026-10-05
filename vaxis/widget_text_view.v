module vaxis

pub struct TextViewGrapheme {
pub:
	len    u16
	offset u32
}

pub struct TextViewBufferContent {
pub:
	bytes string @[required]
}

pub struct TextViewBufferStyle {
pub:
	begin usize @[required]
	end   usize @[required]
	style Style @[required]
}

@[heap]
pub struct TextViewBuffer {
pub mut:
	grapheme   []TextViewGrapheme
	content    string
	style_list []Style
	style_map  map[u64]usize
	rows       usize
	cols       usize
	last_cols  usize
}

pub fn (mut buffer TextViewBuffer) deinit() {
	buffer.clear()
}

pub fn (mut buffer TextViewBuffer) clear() {
	buffer = TextViewBuffer{}
}

// The source append/update and BufferWriter.write methods fail to compile
// at TextView.zig:88: error-union u3 subtraction cannot coerce to usize.

// GC-backed collections are emptied here. The source destroys both unmanaged
// collections without resetting them; subsequent source reuse is undefined.
pub fn (mut buffer TextViewBuffer) clear_style() {
	buffer.style_list = []
	buffer.style_map = map[u64]usize{}
}

pub fn (mut buffer TextViewBuffer) update_style(style TextViewBufferStyle) ! {
	mut index := buffer.style_list.len
	for i, previous in buffer.style_list {
		if previous.eql(style.style) {
			index = i
			break
		}
	}
	if index == buffer.style_list.len { buffer.style_list << style.style }
	if style.begin > style.end { panic('integer overflow') }
	for i := style.begin; i < style.end; i++ {
		buffer.style_map[u64(i)] = usize(index)
	}
}

pub struct TextViewBufferWriter {
pub:
	buffer &TextViewBuffer = unsafe { nil }
}

// The allocator and std.io.GenericWriter context are folded into the borrowed
// buffer adapter, matching the stream adapters elsewhere in this translation.
pub fn (mut buffer TextViewBuffer) writer() TextViewBufferWriter {
	return TextViewBufferWriter{
		buffer: unsafe { &buffer }
	}
}

pub fn (writer TextViewBufferWriter) writer() TextViewBufferWriter {
	return writer
}

pub struct TextView {
pub mut:
	scroll_view ScrollView
}

pub fn (mut view TextView) input(key Key) {
	view.scroll_view.input(key)
}

pub fn (mut view TextView) draw(win Window, buffer TextViewBuffer) {
	view.scroll_view.draw(win, ScrollViewContentSize{ cols: buffer.cols, rows: buffer.rows })
	mut x := usize(0)
	mut y := usize(0)
	mut byte_index := usize(0)
	bounds := view.scroll_view.bounds(win)
	for index, grapheme in buffer.grapheme {
		if bounds.above(y) {
			break
		}
		offset := usize(grapheme.offset)
		length := usize(grapheme.len)
		if offset > usize(buffer.content.len) || length > usize(buffer.content.len) - offset {
			panic('index out of bounds')
		}
		cluster := buffer.content[int(offset)..int(offset + length)]
		style_byte_index := byte_index
		byte_index = widget_checked_add(byte_index, usize(cluster.len))
		if cluster == '\n' {
			if index == buffer.grapheme.len - 1 {
				break
			}
			y = widget_saturating_add(y, 1)
			x = 0
			continue
		} else if bounds.below(y) {
			continue
		}
		width := win.gwidth(cluster)
		col := x
		x = widget_saturating_add(x, usize(width))
		if !bounds.col_inside(col) {
			continue
		}
		style := if u64(style_byte_index) in buffer.style_map {
			style_index := buffer.style_map[u64(style_byte_index)]
			if style_index >= usize(buffer.style_list.len) { panic('index out of bounds') }
			buffer.style_list[int(style_index)]
		} else {
			Style{}
		}
		if width > 255 { panic('integer does not fit in destination type') }
		view.scroll_view.write_cell(win, col, y, Cell{
			char_: CellCharacter{
				grapheme: cluster
				width:    u8(width)
			}
			style: style
		})
	}
}
