module main
import vaxis
fn main() {
 mut buffer := vaxis.TextViewBuffer{}
buffer.update(vaxis.TextViewBufferContent{bytes:"x"}) or {panic(err)}
}
