module vaxis

// The source widgets.alignment namespace is flattened into alignment_* functions.
pub fn alignment_center(parent Window, cols u16, rows u16) Window {
	return parent.child(WindowChildOptions{
		x_off:  max_int(int(parent.width / 2) - int(cols / 2), 0)
		y_off:  max_int(int(parent.height / 2) - int(rows / 2), 0)
		width:  cols
		height: rows
	})
}

pub fn alignment_top_left(parent Window, cols u16, rows u16) Window {
	return parent.child(WindowChildOptions{ width: cols, height: rows })
}

pub fn alignment_top_right(parent Window, cols u16, rows u16) Window {
	return parent.child(WindowChildOptions{
		x_off:  max_int(int(parent.width) - int(cols), 0)
		width:  cols
		height: rows
	})
}

pub fn alignment_bottom_left(parent Window, cols u16, rows u16) Window {
	return parent.child(WindowChildOptions{
		y_off:  max_int(int(parent.height) - int(rows), 0)
		width:  cols
		height: rows
	})
}

pub fn alignment_bottom_right(parent Window, cols u16, rows u16) Window {
	return parent.child(WindowChildOptions{
		x_off:  max_int(int(parent.width) - int(cols), 0)
		y_off:  max_int(int(parent.height) - int(rows), 0)
		width:  cols
		height: rows
	})
}
