module vaxis

// Cell, Screen, and their value types follow the pinned vaxis Cell.zig and
// Screen.zig layouts. The V names char_ and default_ avoid reserved words.

pub struct CellCharacter {
pub mut:
	grapheme string = ' '
	width    u8     = 1
}

pub struct CellHyperlink {
pub mut:
	uri    string
	params string
}

pub struct CellSegment {
pub mut:
	text  string @[required]
	style Style
	link  CellHyperlink
}

pub enum CursorShape as u8 {
	default
	block_blink
	block
	underline_blink
	underline
	beam_blink
	beam
}

pub enum MouseShape as u8 {
	default
	text
	pointer
	help
	progress
	wait
	ew_resize
	ns_resize
	cell
}

pub enum VerticalAlignment as u8 {
	top
	bottom
	center
}

// Source's enum(u2) numeric construction checks the width before the tag.
pub fn VerticalAlignment.from_int(value u64) VerticalAlignment {
	if value > 3 { panic('integer does not fit in destination type') }
	if value == 3 { panic('invalid enum value') }
	return unsafe { VerticalAlignment(value) }
}

// Source Scale is packed into thirteen bits. V stores that bit pattern in a
// u16; setters adapt Source's mutable packed fields without changing getters.
pub struct CellScale {
mut:
	value u16 = 0x089
}

pub fn CellScale.init(scale u64, numerator u64, denominator u64, alignment VerticalAlignment) CellScale {
	if scale > 7 { panic('integer does not fit in destination type') }
	if numerator > 15 { panic('integer does not fit in destination type') }
	if denominator > 15 { panic('integer does not fit in destination type') }
	if u8(alignment) > 3 { panic('integer does not fit in destination type') }
	return CellScale{
		value: u16(scale) | (u16(numerator) << 3) | (u16(denominator) << 7) | (u16(alignment) << 11)
	}
}

// Source @bitCast permits every u13 pattern, including raw alignment bits 3.
pub fn CellScale.from_bits(value u64) CellScale {
	if value > 0x1fff { panic('integer does not fit in destination type') }
	return CellScale{
		value: u16(value)
	}
}

pub fn (s CellScale) bits() u16 {
	return s.value
}

pub fn (s CellScale) scale() u8 {
	return u8(s.value & 7)
}

pub fn (s CellScale) numerator() u8 {
	return u8((s.value >> 3) & 15)
}

pub fn (s CellScale) denominator() u8 {
	return u8((s.value >> 7) & 15)
}

pub fn (s CellScale) vertical_alignment() VerticalAlignment {
	return unsafe { VerticalAlignment((s.value >> 11) & 3) }
}

pub fn (mut s CellScale) set_scale(value u64) {
	if value > 7 { panic('integer does not fit in destination type') }
	s.value = (s.value & ~u16(7)) | u16(value)
}

pub fn (mut s CellScale) set_numerator(value u64) {
	if value > 15 { panic('integer does not fit in destination type') }
	s.value = (s.value & ~u16(15 << 3)) | (u16(value) << 3)
}

pub fn (mut s CellScale) set_denominator(value u64) {
	if value > 15 { panic('integer does not fit in destination type') }
	s.value = (s.value & ~u16(15 << 7)) | (u16(value) << 7)
}

pub fn (mut s CellScale) set_vertical_alignment(value VerticalAlignment) {
	if u8(value) > 3 { panic('integer does not fit in destination type') }
	s.value = (s.value & ~u16(3 << 11)) | (u16(value) << 11)
}

pub fn (a CellScale) eql(b CellScale) bool {
	return a.value == b.value
}

pub struct ImagePixelOffset {
pub mut:
	x u16 @[required]
	y u16 @[required]
}

pub struct ImageClipRegion {
pub mut:
	x      ?u16
	y      ?u16
	width  ?u16
	height ?u16
}

pub enum ImageScale as u8 {
	none
	fill
	fit
	contain
}

pub struct ImageCellSize {
pub mut:
	rows ?u16
	cols ?u16
}

pub struct ImageDrawOptions {
pub mut:
	pixel_offset ?ImagePixelOffset
	z_index      ?i32
	clip_region  ?ImageClipRegion
	scale        ImageScale = .none
	size         ?ImageCellSize
}

pub struct ImagePlacement {
pub mut:
	img_id  u32              @[required]
	options ImageDrawOptions @[required]
}

pub struct Cell {
pub mut:
	char_    CellCharacter = CellCharacter{}
	style    Style
	link     CellHyperlink
	image    ?ImagePlacement
	default_ bool
	wrapped  bool
	scale    CellScale = CellScale{}
}

@[heap]
pub struct Screen {
pub mut:
	width        u16
	height       u16
	width_pix    u16
	height_pix   u16
	buf          []Cell
	cursor_row   u16
	cursor_col   u16
	cursor_vis   bool
	width_method GWidthMethod = .wcwidth
	mouse_shape  MouseShape   = .default
	cursor_shape CursorShape  = .default
}

pub fn Screen.new(winsize Winsize) Screen {
	return Screen{
		width:      winsize.cols
		height:     winsize.rows
		width_pix:  winsize.x_pixel
		height_pix: winsize.y_pixel
		buf:        []Cell{len: int(winsize.cols) * int(winsize.rows), init: Cell{}}
	}
}

pub fn (mut s Screen) deinit() {
	s.buf = []Cell{}
}

pub fn (mut s Screen) write_cell(col u16, row u16, cell Cell) {
	if col >= s.width || row >= s.height {
		return
	}
	index := uint(row) * uint(s.width) + uint(col)
	if index >= uint(s.buf.len) { panic('Assertion failed') }
	s.buf[int(index)] = cell
}

pub fn (s &Screen) read_cell(col u16, row u16) ?Cell {
	if col >= s.width || row >= s.height {
		return none
	}
	index := uint(row) * uint(s.width) + uint(col)
	if index >= uint(s.buf.len) { panic('Assertion failed') }
	return s.buf[int(index)]
}

pub fn (mut s Screen) clear() {
	for i in 0 .. s.buf.len {
		s.buf[i] = Cell{}
	}
}
