module vaxis

// InternalCell is the retained previous-frame representation from pinned
// InternalScreen.zig. V strings replace its arena-owned ArrayLists.
pub struct InternalCell {
pub mut:
	char_    string = ' '
	style    Style
	uri      string
	uri_id   string
	skipped  bool
	default_ bool = true
	skip     bool
	scale    CellScale = CellScale{}
}

pub fn (old InternalCell) eql(cell Cell) bool {
	if old.default_ && cell.default_ {
		return true
	}
	return old.char_ == cell.char_.grapheme && old.style.eql(cell.style) && old.uri == cell.link.uri
		&& old.uri_id == cell.link.params
}

@[heap]
pub struct InternalScreen {
pub mut:
	width        u16
	height       u16
	buf          []InternalCell
	cursor_row   u16
	cursor_col   u16
	cursor_vis   bool
	cursor_shape CursorShape = .default
	mouse_shape  MouseShape  = .default
}

pub fn InternalScreen.new(width u16, height u16) InternalScreen {
	return InternalScreen{
		width:  width
		height: height
		buf:    []InternalCell{len: int(width) * int(height), init: InternalCell{}}
	}
}

pub fn (mut s InternalScreen) deinit() {
	s.buf = []InternalCell{}
}

pub fn (mut s InternalScreen) write_cell(col u16, row u16, cell Cell) {
	if s.width < col || s.height < row {
		return
	}
	index := int(row) * int(s.width) + int(col)
	assert index < s.buf.len
	s.buf[index].char_ = cell.char_.grapheme
	s.buf[index].uri = cell.link.uri
	s.buf[index].uri_id = cell.link.params
	s.buf[index].style = cell.style
	s.buf[index].default_ = cell.default_
}

pub fn (s &InternalScreen) read_cell(col u16, row u16) ?Cell {
	if s.width < col || s.height < row {
		return none
	}
	index := int(row) * int(s.width) + int(col)
	assert index < s.buf.len
	cell := s.buf[index]
	return Cell{
		char_:    CellCharacter{
			grapheme: cell.char_
		}
		style:    cell.style
		link:     CellHyperlink{
			uri:    cell.uri
			params: cell.uri_id
		}
		default_: cell.default_
	}
}
