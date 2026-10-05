module main

import vaxis

fn main() {
	mut env := map[string]string{}
	mut buf := []u8{len: 8}
	mut pty := vaxis.TerminalPty.init() or { panic(err) }
	pty.set_size(vaxis.Winsize{ cols: 4, rows: 2 }) or { panic(err) }
	mut command := vaxis.TerminalCommand{ argv: ['true'], working_directory: none, env_map: &env, pty: pty }
	command.spawn() or { panic(err) }
	command.kill()
	mut widget := vaxis.Terminal.init(['true'], &env, vaxis.TerminalOptions{}, mut buf) or { panic(err) }
	widget.spawn() or { panic(err) }
	widget.resize(vaxis.Winsize{ cols: 4, rows: 2 }) or { panic(err) }
	widget.deinit()
}
