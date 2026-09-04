module internal_os

#pkgconfig gio-2.0 gio-unix-2.0

#include "flatpak_linux.h"

fn C.witty_flatpak_host_command_new(argv &&char, cwd &char, envp &&char, stdin_fd int, stdout_fd int, stderr_fd int) voidptr

fn C.witty_flatpak_host_command_spawn(command voidptr, pid &u32) int

fn C.witty_flatpak_host_command_wait(command voidptr, status &u8) int

fn C.witty_flatpak_host_command_signal(command voidptr, signal u8, process_group int) int

fn C.witty_flatpak_host_command_error(command voidptr) &char

fn C.witty_flatpak_host_command_free(command voidptr)

fn flatpak_host_command_spawn_linux(mut self FlatpakHostCommand) !u32 {
	if !isnil(self.handle) {
		return error('Flatpak host command already spawned')
	}
	if self.argv.len == 0 {
		return error('Flatpak host command has no arguments')
	}

	mut argv := unsafe { []&char{len: self.argv.len + 1, init: &char(0)} }
	for i, arg in self.argv {
		argv[i] = arg.str
	}

	mut env_entries := []string{}
	mut envp := []&char{}
	if values := self.env {
		env_entries = []string{cap: values.len}
		for key, value in values {
			env_entries << '${key}=${value}'
		}
		envp = unsafe { []&char{len: env_entries.len + 1, init: &char(0)} }
		for i, entry in env_entries {
			envp[i] = entry.str
		}
	}

	cwd_ptr := if cwd := self.cwd { cwd.str } else { &char(unsafe { nil }) }
	envp_ptr := if envp.len > 0 { envp.data } else { &&char(unsafe { nil }) }
	self.handle = C.witty_flatpak_host_command_new(argv.data, cwd_ptr, envp_ptr, self.stdin, self.stdout, self.stderr)
	if isnil(self.handle) {
		return error('unable to allocate Flatpak host command')
	}

	mut pid := u32(0)
	if C.witty_flatpak_host_command_spawn(self.handle, &pid) != 0 {
		message := flatpak_host_command_error_message(self.handle)
		C.witty_flatpak_host_command_free(self.handle)
		self.handle = unsafe { nil }
		return error('unable to spawn Flatpak host command: ${message}')
	}
	return pid
}

fn flatpak_host_command_wait_linux(mut self FlatpakHostCommand) !u8 {
	if isnil(self.handle) {
		return error('Flatpak host command must be started')
	}
	mut status := u8(0)
	if C.witty_flatpak_host_command_wait(self.handle, &status) != 0 {
		return error('unable to wait for Flatpak host command: ${flatpak_host_command_error_message(self.handle)}')
	}
	return status
}

fn flatpak_host_command_signal_linux(mut self FlatpakHostCommand, sig u8, process_group bool) ! {
	if isnil(self.handle) {
		return
	}
	if C.witty_flatpak_host_command_signal(self.handle, sig, if process_group { 1 } else { 0 }) != 0 {
		return error('unable to signal Flatpak host command: ${flatpak_host_command_error_message(self.handle)}')
	}
}

fn flatpak_host_command_deinit_linux(mut self FlatpakHostCommand) {
	if !isnil(self.handle) {
		C.witty_flatpak_host_command_free(self.handle)
		self.handle = unsafe { nil }
	}
}

fn flatpak_host_command_error_message(handle voidptr) string {
	message := C.witty_flatpak_host_command_error(handle)
	if isnil(message) {
		return 'unknown error'
	}
	return unsafe { cstring_to_vstring(message) }
}
