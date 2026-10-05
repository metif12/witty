module main
import vaxis
fn main() {
	mut iter := vaxis.TerminalCsi{params: '12'.bytes(), final: `m`}.iterator[i8]()
	_ = iter.next()
}
