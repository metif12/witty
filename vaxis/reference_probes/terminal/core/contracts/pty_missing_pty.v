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
	value := vaxis.TerminalPty{ tty: os.File{ fd: -1 } }
	_ = value
	_ = pair
	_ = writer
	_ = command
	_ = screen
}
