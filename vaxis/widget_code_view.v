module vaxis

pub struct CodeViewDrawOptions {
pub:
	highlighted_line  u16
	draw_line_numbers bool = true
	indentation       u16
}

pub type CodeViewBuffer = TextViewBuffer

pub struct CodeView {
pub mut:
	scroll_view       ScrollView = ScrollView{
		vertical_scrollbar: none
	}
	highlighted_style Style      = Style{
		bg: ColorIndex{
			index: 0
		}
	}
	indentation_cell  Cell       = Cell{
		char_: CellCharacter{
			grapheme: '┆'
			width:    1
		}
		style: Style{
			dim: true
		}
	}
}

pub fn (mut view CodeView) input(key Key) {
	view.scroll_view.input(key)
}

// The source draw method passes usize pad_left to ?u16 child width,
// so it cannot be called unchanged with Zig 0.15.2.
