module main

import vaxis.vxfw

fn build(_ voidptr, _ uint, _ uint) ?vxfw.Widget {
	return none
}

fn main() {
	_ = vxfw.ScrollView{
		children: vxfw.ScrollSlice{
			widgets: []
		}
	}
	_ = vxfw.ScrollBuilder{
		userdata: voidptr(1)
		build_fn: build
	}
}
