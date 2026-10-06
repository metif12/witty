module main

import vaxis.vxfw

fn main() {
	_ = vxfw.ScrollView{
		children: vxfw.ScrollSlice{
			widgets: []
		}
		scroll:   vxfw.ViewScroll{
			vertical_offset: -65537
		}
	}
}
