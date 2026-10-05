module main

import vaxis

fn main() {
	mut screen := vaxis.Screen{}
	win := vaxis.Window.new(&screen)
	mut view := vaxis.ScrollView{}
	_ = view.read_cell(win, 0, 0)
}
