module vaxis

#include <windows.h>

fn C.GetConsoleOutputCP() u32

fn C.SetConsoleOutputCP(code_page u32) bool

const windows_tty_input_mode = u32(0x0008 | 0x0010 | 0x0080)
const windows_tty_output_mode = u32(0x0001 | 0x0004 | 0x0008 | 0x0010)
const windows_tty_utf8_cp = u32(65001)

fn Tty.open_windows() !Tty {
	stdin_handle := C.GetStdHandle(C.STD_INPUT_HANDLE)
	stdout_handle := C.GetStdHandle(C.STD_OUTPUT_HANDLE)
	mut input_mode := u32(0)
	mut output_mode := u32(0)
	if !C.GetConsoleMode(stdin_handle, &input_mode) {
		return error('GetConsoleMode stdin failed')
	}
	if !C.GetConsoleMode(stdout_handle, &output_mode) {
		return error('GetConsoleMode stdout failed')
	}
	output_cp := u32(C.GetConsoleOutputCP())
	if !C.SetConsoleMode(stdin_handle, windows_tty_input_mode) {
		return error('SetConsoleMode stdin failed')
	}
	if !C.SetConsoleMode(stdout_handle, windows_tty_output_mode) {
		return error('SetConsoleMode stdout failed')
	}
	if !C.SetConsoleOutputCP(windows_tty_utf8_cp) {
		return error('SetConsoleOutputCP failed')
	}
	return Tty{
		pending:       []u8{cap: 32}
		stdin_handle:  stdin_handle
		stdout_handle: stdout_handle
		input_mode:    input_mode
		output_mode:   output_mode
		output_cp:     output_cp
	}
}

pub fn Tty.notify_winsize(context voidptr, callback voidptr) ! {
	_ = context
	_ = callback
}

pub fn Tty.reset_winsize_handler() {}

pub fn (mut tty Tty) deinit() {
	if isnil(tty.stdin_handle) {
		return
	}
	C.SetConsoleOutputCP(tty.output_cp)
	C.SetConsoleMode(tty.stdin_handle, tty.input_mode)
	C.SetConsoleMode(tty.stdout_handle, tty.output_mode)
	C.CloseHandle(tty.stdin_handle)
	C.CloseHandle(tty.stdout_handle)
	tty.stdin_handle = unsafe { nil }
	tty.stdout_handle = unsafe { nil }
}

pub fn (tty &Tty) get_winsize() !Winsize {
	mut info := C.CONSOLE_SCREEN_BUFFER_INFO{}
	if !C.GetConsoleScreenBufferInfo(tty.stdout_handle, &info) {
		return error('GetConsoleScreenBufferInfo failed')
	}
	return Winsize{
		cols:    u16(info.srWindow.Right - info.srWindow.Left + 1)
		rows:    u16(info.srWindow.Bottom - info.srWindow.Top + 1)
		x_pixel: 0
		y_pixel: 0
	}
}

pub fn (tty &Tty) write(bytes string) ! {
	mut written := 0
	for written < bytes.len {
		mut count := u32(0)
		if !C.WriteFile(tty.stdout_handle, unsafe { bytes.str + written },
			u32(bytes.len - written), &count, unsafe { nil }) {
			return error('WriteFile stdout failed')
		}
		if count == 0 {
			return error('WriteFile stdout returned zero')
		}
		written += int(count)
	}
}

pub fn (mut tty Tty) next_input() !InputEvent {
	mut parser := Parser{}
	return own_input_key_text(tty.next_console_input(mut parser, true)!)
}
