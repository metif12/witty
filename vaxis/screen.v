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

// Source Scale is packed into thirteen bits. V stores that bit pattern in a
// u16 so equality and the four exposed fields keep the source representation.
pub struct CellScale {
mut:
	value u16 = 0x089
}

pub fn CellScale.init(scale u8, numerator u8, denominator u8, alignment VerticalAlignment) CellScale {
	assert scale < 8
	assert numerator < 16
	assert denominator < 16
	assert u8(alignment) < 4
	return CellScale{
		value: u16(scale) | (u16(numerator) << 3) | (u16(denominator) << 7) | (u16(alignment) << 11)
	}
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

pub fn (a CellScale) eql(b CellScale) bool {
	return a.value == b.value
}

pub struct ImagePixelOffset {
pub mut:
	x u16
	y u16
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
	img_id  u32
	options ImageDrawOptions
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
	index := int(row) * int(s.width) + int(col)
	assert index < s.buf.len
	s.buf[index] = cell
}

pub fn (s &Screen) read_cell(col u16, row u16) ?Cell {
	if col >= s.width || row >= s.height {
		return none
	}
	index := int(row) * int(s.width) + int(col)
	assert index < s.buf.len
	return s.buf[index]
}

pub fn (mut s Screen) clear() {
	for i in 0 .. s.buf.len {
		s.buf[i] = Cell{}
	}
}
