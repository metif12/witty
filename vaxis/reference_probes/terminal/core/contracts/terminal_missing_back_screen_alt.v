module main

import os
import zigimg
import vaxis

fn main() {
	mut bytes := []u8{len: 8}
	mut env := map[string]string{}
	pair := vaxis.TerminalPty{ pty: os.File{ fd: -1 }, tty: os.File{ fd: -1 } }
	writer := zigimg.WriteStream.init_memory(mut bytes)
	command := vaxis.TerminalCommand{ argv: [], working_directory: none, env_map: unsafe { &env }, pty: pair }
	screen := vaxis.TerminalScreen.new(4, 2) or { panic(err) }
	value := vaxis.Terminal{ scrollback_size: 0, pty: pair, pty_writer: writer, cmd: command, front_screen: screen, back_screen_pri: screen, tab_stops: [] }
	_ = value
	_ = pair
	_ = writer
	_ = command
	_ = screen
}
