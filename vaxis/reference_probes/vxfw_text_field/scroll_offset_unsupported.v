module main
import vaxis
import vaxis.vxfw
fn main() {
	value := vxfw.TextField{buf: vaxis.TextInputBuffer.new(), scroll_offset: 16}
	println(value.scroll_offset)
}
