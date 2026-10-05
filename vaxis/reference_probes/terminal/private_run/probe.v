module vaxis

import os
import encoding.hex
import strings
import zigimg

fn private_run_decode(text string) []u8 { return hex.decode(text) or { panic(err) } }
fn private_run_color(value Color) u32 {
	return match value {
		ColorDefault { u32(0) }
		ColorIndex { u32(0x1000000) | u32(value.index) }
		ColorRgb { u32(0x2000000) | (u32(value.rgb[0]) << 16) | (u32(value.rgb[1]) << 8) | u32(value.rgb[2]) }
	}
}
fn private_run_style(value Style) string {
	flags := u8(value.bold) | (u8(value.dim)<<1) | (u8(value.italic)<<2) | (u8(value.blink)<<3) | (u8(value.reverse)<<4) | (u8(value.invisible)<<5) | (u8(value.strikethrough)<<6)
	return '${private_run_color(value.fg)},${private_run_color(value.bg)},${private_run_color(value.ul)},${u8(value.ul_style)},${flags}'
}
fn private_run_screen(value TerminalScreen) string {
	mut output := strings.new_builder(2048)
	cursor := value.cursor
	sr := value.scrolling_region
	output.write_string('${value.width},${value.height}/${sr.top},${sr.bottom},${sr.left},${sr.right}/${cursor.col},${cursor.row},${int(cursor.pending_wrap)},${u8(cursor.shape)},${int(cursor.visible)}/${value.csi_u_flags.int()}/${private_run_style(cursor.style)};')
	for cell in value.buf {
		output.write_string('${hex.encode(cell.char_.bytes())}/${cell.width},${int(cell.wrapped)},${int(cell.dirty)}/${private_run_style(cell.style)}/${hex.encode(cell.uri.bytes())}/${hex.encode(cell.uri_id.bytes())};')
	}
	return output.str()
}
fn private_run_seed(mut screen TerminalScreen, offset int) {
	for i in 0 .. screen.buf.len {
		screen.buf[i].char_ = '${i+offset}'.clone()
		screen.buf[i].dirty = false
		screen.buf[i].style = Style{bg: ColorIndex{index: u8(i%8)}, bold: i%2==0}
	}
}
fn private_run_case(p []string, input_path string, response_path string) string {
	data := private_run_decode(p[0])
	os.write_file_array(input_path, data) or { panic(err) }
	mut input := os.open(input_path) or { panic(err) }
	defer { input.close() }
	mut output := os.create(response_path) or { panic(err) }
	defer { output.close() }
	mut write_buf := []u8{len:16}
	mut environment := map[string]string{}
	pty := TerminalPty{pty:input,tty:os.File{fd:-1}}
	w := u16(p[1].int())
	h := u16(p[2].int())
	mut terminal := Terminal{
		scrollback_size: 0
		pty: pty
		pty_writer: zigimg.WriteStream.init_file_streaming(output, mut write_buf)
		cmd: TerminalCommand{argv:['true'],working_directory:none,env_map:&environment,pty:pty}
		front_screen: TerminalScreen.new(w,h) or { panic(err) }
		back_screen_pri: TerminalScreen.new(w,h) or { panic(err) }
		back_screen_alt: TerminalScreen.new(w,h) or { panic(err) }
		tab_stops: []u16{cap:128}
		title: []u8{cap:128}
		working_directory: []u8{cap:128}
	}
	terminal.back_screen = &terminal.back_screen_pri
	private_run_seed(mut terminal.front_screen,200)
	private_run_seed(mut terminal.back_screen_pri,0)
	private_run_seed(mut terminal.back_screen_alt,100)
	terminal.back_screen.cursor.col = u16(p[3].int())
	terminal.back_screen.cursor.row = u16(p[4].int())
	terminal.back_screen.cursor.pending_wrap = true
	modes := p[5].int()
	terminal.mode = TerminalMode{origin:modes&1!=0,autowrap:modes&2!=0,cursor:modes&4!=0,sync:modes&8!=0}
	terminal.dirty = p[6]=='1'
	terminal.should_quit = p[8]=='1'
	terminal.last_printed = private_run_decode(p[7]).bytestr()
	for col:=u16(0);col<w;col+=8 { terminal.tab_stops << col }
	terminal.title << 'initial'.bytes()
	terminal.working_directory << 'before'.bytes()
	mut result := 'ok'
	terminal.run() or { result=err.msg() }
	terminal.pty_writer.flush() or { panic(err) }
	reply := os.read_bytes(response_path) or { panic(err) }
	unlocked := terminal.back_mutex.try_lock()
	if unlocked { terminal.back_mutex.unlock() }
	input_position := input.tell() or { panic(err) }
	mut stops := ''
	for stop in terminal.tab_stops { stops += '${stop},' }
	mut events := ''
	for {
		event := terminal.try_event() or { break }
		events += match event {
			TerminalRedraw { 'r' }
			TerminalBell { 'b' }
			TerminalExited { 'e' }
			TerminalTitleChange { 't${hex.encode(event.bytes)}' }
			TerminalPwdChange { 'p${hex.encode(event.bytes)}' }
		} + ','
	}
	return '${result}|${int(terminal.mode.origin)}${int(terminal.mode.autowrap)}${int(terminal.mode.cursor)}${int(terminal.mode.sync)}/${int(terminal.dirty)}/${int(terminal.should_quit)}/${int(terminal.back_screen==&terminal.back_screen_alt)}/${int(unlocked)}/${input_position}|${hex.encode(terminal.title)}|${hex.encode(terminal.working_directory)}|${hex.encode(terminal.last_printed.bytes())}|${hex.encode(reply)}|${stops}|${events}|${private_run_screen(terminal.front_screen)}|${private_run_screen(terminal.back_screen_pri)}|${private_run_screen(terminal.back_screen_alt)}'
}
fn test_private_run_reference_consumer() {
	path := os.getenv('WITTY_TERMINAL_PRIVATE_CORPUS')
	if path == '' { return }
	for line in (os.read_file(path) or { panic(err) }).split_into_lines() {
		if line=='' { continue }
		println(private_run_case(line.split('|'),path+'.input',path+'.reply'))
	}
}
