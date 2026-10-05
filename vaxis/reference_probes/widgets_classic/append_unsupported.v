module main
import vaxis
fn main() {
 mut buffer := vaxis.TextViewBuffer{}
buffer.append(vaxis.TextViewBufferContent{bytes:"x"}) or {panic(err)}
}
