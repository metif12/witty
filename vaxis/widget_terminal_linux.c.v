module vaxis

import os
import zigimg

fn C.witty_terminal_open(path &char) int
fn C.witty_terminal_unlockpt(fd int) int
fn C.witty_terminal_ptsname(fd int, number &u32) int
fn C.witty_terminal_set_size(fd int, rows u16, cols u16, xp u16, yp u16) int
fn C.witty_terminal_control_tty(fd int) int
fn C.witty_terminal_fork() int
fn C.witty_terminal_setsid() int
fn C.witty_terminal_dup2(from int, to int) int
fn C.witty_terminal_chdir(path &char) int
fn C.witty_terminal_exec(argv &&char, envp &&char)
fn C.witty_terminal_cwd_path(bytes &u8, length uint) int

pub fn TerminalPty.init() !TerminalPty {
	master := C.witty_terminal_open(c'/dev/ptmx')
	if master < 0 { return terminal_open_error(C.witty_terminal_errno()) }
	mut complete := false
	defer {
		if !complete { terminal_close(master) }
	}
	if C.witty_terminal_unlockpt(master) != 0 { return error('IoctlError') }
	mut number := u32(0)
	if C.witty_terminal_ptsname(master, &number) != 0 { return error('IoctlError') }
	name := '/dev/pts/${number}'
	if name.len > 16 { return error('NoSpaceLeft') }
	slave := C.witty_terminal_open(name.str)
	if slave < 0 { return terminal_open_error(C.witty_terminal_errno()) }
	complete = true
	return TerminalPty{
		pty: os.File{
			fd:        master
			is_opened: true
		}
		tty: os.File{
			fd:        slave
			is_opened: true
		}
	}
}

pub fn (pty TerminalPty) set_size(ws Winsize) ! {
	if C.witty_terminal_set_size(pty.pty.fd, ws.rows, ws.cols, ws.x_pixel, ws.y_pixel) != 0 {
		return error('SetWinsizeError')
	}
}

pub fn (mut command TerminalCommand) spawn() ! {
	mut argv := []&char{len: command.argv.len + 1, init: unsafe { nil }}
	for i, arg in command.argv {
		argv[i] = arg.str
	}
	mut envp := []&char{len: command.env_map.len + 1, init: unsafe { nil }}
	mut retained := []string{}
	for name, value in command.env_map {
		entry := '${name}=${value}'
		envp[retained.len] = entry.str
		retained << entry
	}
	pid := C.witty_terminal_fork()
	if pid < 0 {
		code := C.witty_terminal_errno()
		if code == C.EAGAIN || code == C.ENOMEM { return error('SystemResources') }
		return error('Unexpected')
	}
	if pid == 0 {
		C.witty_terminal_setsid()
		if C.witty_terminal_control_tty(command.pty.tty.fd) != 0 { return error('IoctlError') }
		for fd in 0 .. 3 {
			if C.witty_terminal_dup2(command.pty.tty.fd, fd) < 0 {
				code := C.witty_terminal_errno()
				if code == C.EBADF || code == C.EINVAL { panic('unreachable') }
				if code == C.EMFILE { return error('ProcessFdQuotaExceeded') }
				return error('Unexpected')
			}
		}
		terminal_close(command.pty.tty.fd)
		if command.pty.pty.fd > 2 { terminal_close(command.pty.pty.fd) }
		if path := command.working_directory {
			if C.witty_terminal_chdir(path.str) != 0 {
				return terminal_chdir_error(C.witty_terminal_errno())
			}
		}
		// Source catches and ignores exec errors, then continues the parent path.
		C.witty_terminal_exec(argv.data, envp.data)
	}
	command.pid = pid
	mut globals := terminal_global_state()
	if !globals.sigchild_installed {
		globals.sigchild_installed = true
		if C.witty_terminal_sigchild(voidptr(terminal_sigchild)) != 0 { panic('unreachable') }
	}
}

pub fn Terminal.init(argv []string, env_map &map[string]string, opts TerminalOptions, mut write_buf []u8) !Terminal {
	if path := opts.initial_working_directory {
		if !os.is_abs_path(path) { return error('InvalidWorkingDirectory') }
	}
	pty := TerminalPty.init()!
	pty.set_size(opts.winsize)!
	mut tabs := []u16{cap: int(opts.winsize.cols / 8)}
	mut col := u16(0)
	for col < opts.winsize.cols {
		tabs << col
		col = terminal_add_u16(col, 8)
	}
	return Terminal{
		pty:             pty
		pty_writer:      zigimg.WriteStream.init_file_streaming(pty.pty, mut write_buf)
		cmd:             TerminalCommand{
			argv:              argv
			env_map:           unsafe { env_map }
			pty:               pty
			working_directory: opts.initial_working_directory
		}
		scrollback_size: opts.scrollback_size
		front_screen:    TerminalScreen.new(opts.winsize.cols, opts.winsize.rows)!
		back_screen_pri: TerminalScreen.new(opts.winsize.cols, terminal_add_u16(opts.winsize.rows,
			opts.scrollback_size))!
		back_screen_alt: TerminalScreen.new(opts.winsize.cols, opts.winsize.rows)!
		tab_stops:       tabs
	}
}

pub fn (mut terminal Terminal) spawn() ! {
	if terminal.thread != none { return }
	terminal.back_screen = &terminal.back_screen_pri
	terminal.cmd.spawn()!
	terminal.working_directory.clear()
	if path := terminal.cmd.working_directory {
		terminal.working_directory << path.bytes()
	} else {
		mut path := []u8{len: 4096}
		len := C.witty_terminal_cwd_path(path.data, uint(path.len))
		if len < 0 {
			code := C.witty_terminal_errno()
			if code == C.ENOENT { return error('FileNotFound') }
			if code == C.EACCES { return error('AccessDenied') }
			if code == C.ENOMEM { return error('SystemResources') }
			return error('Unexpected')
		}
		terminal.working_directory << path[..int(len)]
	}
	mut globals := terminal_global_state()
	globals.mutex.lock()
	if globals.vts == none {
		globals.vts = map[int]&Terminal{}
		globals.count = 0
	}
	if pid := terminal.cmd.pid {
		mut vts := (globals.vts or { panic('unreachable') }).clone()
		if pid !in vts { globals.count = widget_checked_add(globals.count, 1) }
		vts[pid] = &terminal
		globals.vts = vts.move()
	}
	globals.mutex.unlock()
	terminal.thread = terminal_start_thread(mut terminal)!
}

pub fn (mut terminal Terminal) resize(ws Winsize) ! {
	if ws.cols == terminal.front_screen.width && ws.rows == terminal.front_screen.height { return }
	terminal.back_mutex.lock()
	defer { terminal.back_mutex.unlock() }
	terminal.front_screen.deinit()
	terminal.front_screen = TerminalScreen.new(ws.cols, ws.rows)!
	terminal.back_screen_pri.deinit()
	terminal.back_screen_alt.deinit()
	terminal.back_screen_pri = TerminalScreen.new(ws.cols, terminal_add_u16(ws.rows,
		terminal.scrollback_size))!
	terminal.back_screen_alt = TerminalScreen.new(ws.cols, ws.rows)!
	terminal.pty.set_size(ws)!
}

fn terminal_chdir_error(code int) IError {
	return match code {
		C.EFAULT { panic('unreachable') }
		C.EACCES { error('AccessDenied') }
		C.EIO { error('FileSystem') }
		C.ELOOP { error('SymLinkLoop') }
		C.ENAMETOOLONG { error('NameTooLong') }
		C.ENOENT { error('FileNotFound') }
		C.ENOMEM { error('SystemResources') }
		C.ENOTDIR { error('NotDir') }
		else { error('Unexpected') }
	}
}

fn terminal_open_error(code int) IError {
	return match code {
		C.EFAULT { panic('unreachable') }
		C.EINVAL { error('BadPathName') }
		C.EACCES { error('AccessDenied') }
		C.EFBIG, C.EOVERFLOW { error('FileTooBig') }
		C.EISDIR { error('IsDir') }
		C.ELOOP { error('SymLinkLoop') }
		C.EMFILE { error('ProcessFdQuotaExceeded') }
		C.ENAMETOOLONG { error('NameTooLong') }
		C.ENFILE { error('SystemFdQuotaExceeded') }
		C.ENODEV { error('NoDevice') }
		C.ENOENT { error('FileNotFound') }
		C.ESRCH { error('ProcessNotFound') }
		C.ENOMEM { error('SystemResources') }
		C.ENOSPC { error('NoSpaceLeft') }
		C.ENOTDIR { error('NotDir') }
		C.EPERM { error('PermissionDenied') }
		C.EEXIST { error('PathAlreadyExists') }
		C.EBUSY { error('DeviceBusy') }
		else { error('Unexpected') }
	}
}
