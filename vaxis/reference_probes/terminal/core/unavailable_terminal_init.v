module main
import vaxis
fn main(){mut env:=map[string]string{};mut b:=[]u8{len:8};_:=vaxis.Terminal.init(['true'],&env,vaxis.TerminalOptions{},mut b) or{panic(err)}}
