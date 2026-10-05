module vaxis

pub struct ScrollViewScroll {
pub mut:
	x usize
	y usize
}

pub fn (mut scroll ScrollViewScroll) restrict_to(width usize, height usize) {
	if scroll.x > width { scroll.x = width }
	if scroll.y > height { scroll.y = height }
}

pub struct ScrollViewVerticalScrollbar {
pub mut:
	character CellCharacter = CellCharacter{
		grapheme: '▐'
		width:    1
	}
	fg        Style
	bg        Style = Style{
		fg: ColorIndex{
			index: 8
		}
	}
}

pub struct ScrollViewContentSize {
pub:
	cols usize @[required]
	rows usize @[required]
}

// Window-based widgets/ScrollView.zig, distinct from the vxfw widget.
pub struct ScrollView {
pub mut:
	scroll             ScrollViewScroll
	vertical_scrollbar ?ScrollViewVerticalScrollbar = ScrollViewVerticalScrollbar{}
}

pub fn (mut view ScrollView) input(key Key) {
	plain := Modifiers{}
	shift := Modifiers.from_int(1)
	if key.matches(right, plain) {
		view.scroll.x = widget_saturating_add(view.scroll.x, 1)
	} else if key.matches(right, shift) {
		view.scroll.x = widget_saturating_add(view.scroll.x, 32)
	} else if key.matches(left, plain) {
		view.scroll.x = widget_saturating_sub(view.scroll.x, 1)
	} else if key.matches(left, shift) {
		view.scroll.x = widget_saturating_sub(view.scroll.x, 32)
	} else if key.matches(up, plain) {
		view.scroll.y = widget_saturating_sub(view.scroll.y, 1)
	} else if key.matches(page_up, plain) {
		view.scroll.y = widget_saturating_sub(view.scroll.y, 32)
	} else if key.matches(down, plain) {
		view.scroll.y = widget_saturating_add(view.scroll.y, 1)
	} else if key.matches(page_down, plain) {
		view.scroll.y = widget_saturating_add(view.scroll.y, 32)
	} else if key.matches(end, plain) {
		view.scroll.y = ~usize(0)
	} else if key.matches(home, plain) {
		view.scroll.y = 0
	}
}

pub fn (mut view ScrollView) draw(parent Window, content_size ScrollViewContentSize) {
	content_cols := if view.vertical_scrollbar != none {
		widget_saturating_add(content_size.cols, 1)
	} else {
		content_size.cols
	}
	max_scroll_x := widget_saturating_sub(content_cols, usize(parent.width))
	max_scroll_y := widget_saturating_sub(content_size.rows, usize(parent.height))
	view.scroll.restrict_to(max_scroll_x, max_scroll_y)
	if opts := view.vertical_scrollbar {
		bar := Scrollbar{
			character: opts.character
			style:     opts.fg
			total:     content_size.rows
			view_size: usize(parent.height)
			top:       view.scroll.y
		}
		background := parent.child(WindowChildOptions{
			x_off:  int(widget_saturating_sub(usize(parent.width), usize(opts.character.width)))
			width:  u16(opts.character.width)
			height: parent.height
		})
		background.fill(Cell{ char_: opts.character, style: opts.bg })
		bar.draw(background)
	}
}

pub struct ScrollViewBoundingBox {
pub:
	x1 usize @[required]
	y1 usize @[required]
	x2 usize @[required]
	y2 usize @[required]
}

pub fn (box ScrollViewBoundingBox) below(row usize) bool {
	return row < box.y1
}

pub fn (box ScrollViewBoundingBox) above(row usize) bool {
	return row >= box.y2
}

pub fn (box ScrollViewBoundingBox) row_inside(row usize) bool {
	return row >= box.y1 && row < box.y2
}

pub fn (box ScrollViewBoundingBox) col_inside(col usize) bool {
	return col >= box.x1 && col < box.x2
}

pub fn (box ScrollViewBoundingBox) inside(col usize, row usize) bool {
	return box.row_inside(row) && box.col_inside(col)
}

pub fn (view &ScrollView) bounds(parent Window) ScrollViewBoundingBox {
	right_pad := if view.vertical_scrollbar != none { usize(1) } else { usize(0) }
	return ScrollViewBoundingBox{
		x1: view.scroll.x
		y1: view.scroll.y
		x2: widget_saturating_sub(widget_saturating_add(view.scroll.x, usize(parent.width)),
			right_pad)
		y2: widget_saturating_add(view.scroll.y, usize(parent.height))
	}
}

pub fn (view &ScrollView) write_cell(parent Window, col usize, row usize, cell Cell) {
	box := view.bounds(parent)
	if !box.inside(col, row) { return }
	win := parent.child(WindowChildOptions{
		width:  widget_checked_u16(box.x2 - box.x1)
		height: widget_checked_u16(box.y2 - box.y1)
	})
	win.write_cell(widget_checked_u16(widget_saturating_sub(col, view.scroll.x)), widget_checked_u16(widget_saturating_sub(row,
		view.scroll.y)), cell)
}

// The pinned source readCell method is not callable: its bare return in a
// ?Cell function fails Zig 0.15.2 compilation. Read through Window instead.
