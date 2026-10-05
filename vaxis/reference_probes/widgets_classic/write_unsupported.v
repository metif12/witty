module main
import vaxis
fn main() {
 mut buffer := vaxis.TextViewBuffer{}
writer := vaxis.TextViewBufferWriter{buffer:&buffer}
writer.write("x".bytes()) or {panic(err)}
}
