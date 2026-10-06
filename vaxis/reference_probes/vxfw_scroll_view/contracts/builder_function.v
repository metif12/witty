module main

import vaxis.vxfw

fn build(_ voidptr, _ usize, _ usize) ?vxfw.Widget {
	return none
}

fn main() {
	_ = vxfw.ScrollBuilder{
		userdata: voidptr(1)
	}
}
