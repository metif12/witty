module main

import vaxis.vxfw

fn main() {
	_ = vxfw.ScrollView{
		children: vxfw.ScrollSlice{
			widgets: []
		}
		scroll:   vxfw.ViewScroll{
			pending_lines: 65536
		}
	}
}
