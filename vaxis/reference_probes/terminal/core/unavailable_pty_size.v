module main
import vaxis
fn invoke(p vaxis.TerminalPty){p.set_size(vaxis.Winsize{}) or{panic(err)}}
fn main(){}
