module main
import vaxis
struct Item { text []string }
fn main() { mut screen:=vaxis.Screen.new(vaxis.Winsize{cols:8,rows:3}); win:=vaxis.Window.new(&screen); mut ctx:=vaxis.TableContext{selected_bg:vaxis.ColorDefault{},active_bg:vaxis.ColorDefault{}}; vaxis.table_draw_table(true,win,vaxis.TableMultiArrayList[Item]{items:[Item{text:['a','b']}]},mut ctx) or {panic(err)} }
