module vaxis

pub struct ViewConfig {
pub:
	width  u16 @[required]
	height u16 @[required]
}

@[heap]
pub struct View {
pub mut:
	screen Screen
}

pub fn View.init(config ViewConfig) View {
	return View{
		screen: Screen.new(Winsize{ cols: config.width, rows: config.height })
	}
}

pub fn (mut view View) window() Window {
	return Window.new(unsafe { &view.screen })
}

pub fn (mut view View) deinit() {
	view.screen.deinit()
}

pub struct ViewDrawOptions {
pub:
	x_off u16
	y_off u16
}

// The source evaluates its row offsets as checked i17 arithmetic, before
// converting the final offsets to usize; it copies directly without clipping.
fn widget_i17(value i64) i64 {
	if value < -65536 || value > 65535 { panic('integer overflow') }
	return value
}

fn widget_nonnegative_index(value i64) int {
	if value < 0 { panic('integer does not fit in destination type') }
	return int(value)
}

pub fn (view &View) draw(win Window, opts ViewDrawOptions) {
	if opts.x_off >= view.screen.width { return }
	if opts.y_off >= view.screen.height { return }
	width := if win.width < view.screen.width - opts.x_off {
		win.width
	} else {
		view.screen.width - opts.x_off
	}
	height := if win.height < view.screen.height - opts.y_off {
		win.height
	} else {
		view.screen.height - opts.y_off
	}
	for row in 0 .. int(height) {
		src := widget_nonnegative_index(widget_i17(i64(opts.x_off) +
			widget_i17(widget_i17(i64(row) + i64(opts.y_off)) * i64(view.screen.width))))
		dst := widget_nonnegative_index(widget_i17(i64(win.x_off) + widget_i17(widget_i17(i64(row) +
			i64(win.y_off)) * i64(win.screen.width))))
		if src + int(width) > view.screen.buf.len || dst + int(width) > win.screen.buf.len {
			panic('index out of bounds')
		}
		src_address := usize(view.screen.buf.data) + usize(src) * sizeof(Cell)
		dst_address := usize(win.screen.buf.data) + usize(dst) * sizeof(Cell)
		span := usize(width) * sizeof(Cell)
		if width > 0 && src_address < dst_address + span && dst_address < src_address + span {
			panic('@memcpy arguments alias')
		}
		for col in 0 .. int(width) {
			mut target := unsafe { win.screen }
			target.buf[dst + col] = view.screen.buf[src + col]
		}
	}
}

pub struct ViewExtentFit {}

pub struct ViewExtentMax {
pub:
	value u16
}

pub type ViewExtent = ViewExtentFit | ViewExtentMax

pub struct ViewRenderConfig {
pub:
	x      u16
	y      u16
	width  ViewExtent = ViewExtentFit{}
	height ViewExtent = ViewExtentFit{}
}

fn widget_u16_sub(a u16, b u16) u16 {
	return if a > b { a - b } else { 0 }
}

pub fn (view &View) to_win(win Window, config ViewRenderConfig) !(u16, u16) {
	if view.screen.width == 0 || view.screen.height == 0 { panic('integer overflow') }
	mut x := if config.x < view.screen.width - 1 { config.x } else { view.screen.width - 1 }
	mut y := if config.y < view.screen.height - 1 { config.y } else { view.screen.height - 1 }
	mut width := match config.width {
		ViewExtentFit {
			win.width
		}
		ViewExtentMax {
			if config.width.value < win.width { config.width.value } else { win.width }
		}
	}

	mut height := match config.height {
		ViewExtentFit {
			win.height
		}
		ViewExtentMax {
			if config.height.value < win.height { config.height.value } else { win.height }
		}
	}

	if width > view.screen.width { width = view.screen.width }
	if height > view.screen.height { height = view.screen.height }
	width_bound := saturating_u16_add(widget_u16_sub(widget_u16_sub(view.screen.width, 1), x),
		win.width)
	height_bound := saturating_u16_add(widget_u16_sub(widget_u16_sub(view.screen.height, 1), y),
		win.height)
	if width > width_bound { width = width_bound }
	if height > height_bound { height = height_bound }
	if x > widget_u16_sub(view.screen.width, width) { x = widget_u16_sub(view.screen.width, width) }
	if y > widget_u16_sub(view.screen.height, height) {
		y = widget_u16_sub(view.screen.height, height)
	}
	view.draw(win.child(WindowChildOptions{ width: width, height: height }), ViewDrawOptions{
		x_off: x
		y_off: y
	})
	return x, y
}

pub fn (mut view View) write_cell(col u16, row u16, cell Cell) {
	view.screen.write_cell(col, row, cell)
}

pub fn (view &View) read_cell(col u16, row u16) ?Cell {
	return view.screen.read_cell(col, row)
}

pub fn (mut view View) clear() {
	view.fill(Cell{ default_: true })
}

pub fn (view &View) gwidth(text string) u16 {
	return gwidth(text, view.screen.width_method)
}

pub fn (mut view View) fill(cell Cell) {
	for i in 0 .. view.screen.buf.len {
		view.screen.buf[i] = cell
	}
}

pub fn (mut view View) print(segments []CellSegment, opts PrintOptions) PrintResult {
	return view.window().print(segments, opts)
}

pub fn (mut view View) print_segment(segment CellSegment, opts PrintOptions) PrintResult {
	return view.print([segment], opts)
}
