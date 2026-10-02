module terminal

import lib_allocator
import fastmem

fn C.witty_page_mmap(usize) voidptr
fn C.witty_page_munmap(voidptr, usize)

// Inline tagged colors retain source Style.Color's 4-byte payload alignment
// and 8-byte storage, without V sum-type pointers in the page buffer.
struct StoredStyleColor {
mut:
	payload u32
	tag     u8
	padding [3]u8
}

struct StoredStyle {
mut:
	fg_color        StoredStyleColor
	bg_color        StoredStyleColor
	underline_color StoredStyleColor
	flags           u16
}

fn store_color(color StyleColor) StoredStyleColor {
	return StoredStyleColor{ payload: u32(color.data()), tag: u8(color.tag()) }
}

fn (color StoredStyleColor) color() StyleColor {
	return match color.tag {
		1 { StyleColor(StyleColorPalette{ index: u8(color.payload) }) }
		2 {
			StyleColor(StyleColorRgb{ rgb: RGB{ r: u8(color.payload), g: u8(color.payload >> 8), b: u8(color.payload >> 16) } })
		}
		else { StyleColor(StyleColorNone{}) }
	}
}

fn store_style(style CellStyle) StoredStyle {
	return StoredStyle{ fg_color: store_color(style.fg_color), bg_color: store_color(style.bg_color), underline_color: store_color(style.underline_color), flags: style.flags.int() }
}

fn (style StoredStyle) style() CellStyle {
	return CellStyle{ fg_color: style.fg_color.color(), bg_color: style.bg_color.color(), underline_color: style.underline_color.color(), flags: StyleFlags{ value: style.flags } }
}

struct StoredStyleContext {}

fn (_ StoredStyleContext) hash(value StoredStyle) u64 { return value.style().hash() }

fn (_ StoredStyleContext) eql(a StoredStyle, b StoredStyle) bool {
	left := a.style()
	right := b.style()
	return left.eql(&right)
}

// Page map descriptors contain the source offset map and a transient true-base
// pointer. clone_buf rebinds that pointer; all entries remain inside the mapping.
struct PageOffsetMap[V] {
mut:
	offset GenericOffsetHashMap[u32, V, AutoHashContext[u32]]
	base   &u8 = unsafe { nil }
}

fn page_offset_map_init[V](buf OffsetBuf, layout HashMapLayout) PageOffsetMap[V] {
	return PageOffsetMap[V]{ offset: auto_offset_hash_map_init[u32, V](buf, layout), base: buf.base }
}

fn (self &PageOffsetMap[V]) contains(key u32) bool {
	return self.offset.map(self.base, AutoHashContext[u32]{}).contains(key)
}

fn (self &PageOffsetMap[V]) get(key u32) ?V {
	return self.offset.map(self.base, AutoHashContext[u32]{}).get(key)
}

fn (mut self PageOffsetMap[V]) put(key u32, value V) {
	mut view := self.offset.map(self.base, AutoHashContext[u32]{})
	view.put_assume_capacity(key, value)
}

fn (mut self PageOffsetMap[V]) delete(key u32) {
	mut view := self.offset.map(self.base, AutoHashContext[u32]{})
	view.remove(key)
}

fn (self &PageOffsetMap[V]) count() usize {
	return usize(self.offset.map(self.base, AutoHashContext[u32]{}).count())
}

// Rotate packed headers using the original fastmem algorithm, then rebind the
// transient cell slices. Row view addresses stay stable for cached cursor rows.
fn rotate_row_views(mut rows []RowData, reverse bool) {
	if rows.len < 2 { return }
	base := unsafe { &u8(usize(rows[0].cells.data) - usize(rows[0].header.cells_offset)) }
	cols := rows[0].cells.len
	mut headers := lib_allocator.borrowed_array[PageRowHeader](rows[0].header, rows.len, rows.len)
	if reverse { fastmem.rotate_once_r(mut headers) } else { fastmem.rotate_once(mut headers) }
	for mut row in rows {
		row.cells = lib_allocator.borrowed_array[CellData](unsafe { base + row.header.cells_offset }, cols, cols)
	}
}

fn (mut self Page) swap_rows(a int, b int) {
	value := *self.rows[a].header
	unsafe {
		*self.rows[a].header = *self.rows[b].header
		*self.rows[b].header = value
	}
	cells := self.rows[a].cells
	self.rows[a].cells = self.rows[b].cells
	self.rows[b].cells = cells
}
