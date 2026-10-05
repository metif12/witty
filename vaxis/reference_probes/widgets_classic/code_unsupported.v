module main
import vaxis
fn main() {
 mut buffer := vaxis.TextViewBuffer{}
mut screen := vaxis.Screen{}
win := vaxis.Window.new(&screen)
mut code := vaxis.CodeView{}
code.draw(win,buffer,vaxis.CodeViewDrawOptions{})
}
