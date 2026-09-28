module internal_os

import log
import os
import time as _

#include <sys/socket.h>

#include <sys/un.h>

#include <unistd.h>

const systemd_task_comm_len = 16
const systemd_unix_path_len = 108

struct C.sockaddr_un {
mut:
	sun_family u16
	sun_path   [systemd_unix_path_len]char
}

fn C.socket(domain i32, typ i32, protocol i32) i32

fn C.connect(sockfd i32, addr voidptr, addrlen u32) i32

fn C.write(fd i32, buf voidptr, count usize) int

fn C.close(fd i32) i32

fn launched_by_systemd_linux() bool {
	if os.getenv_opt('INVOCATION_ID') == none || os.getenv_opt('JOURNAL_STREAM') == none {
		return false
	}

	ppid := C.getppid()
	if ppid == 1 {
		return true
	}

	comm_path := '/proc/${ppid}/comm'
	mut comm_file := os.open(comm_path) or {
		log.error("unable to open '${comm_path}' for reading")
		return false
	}
	defer {
		comm_file.close()
	}
	mut comm_data := []u8{len: systemd_task_comm_len}
	comm_size := comm_file.read(mut comm_data) or {
		log.error("problems reading from '${comm_path}'")
		return false
	}
	return comm_data[..comm_size].bytestr().trim_right('\n') == 'systemd'
}

fn systemd_notify_send(message string) {
	socket_path := os.getenv('NOTIFY_SOCKET')
	if socket_path.len == 0 {
		return
	}
	if socket_path[0] != `/` && socket_path[0] != `@` {
		log.warn('only AF_UNIX sockets with path or abstract namespace addresses are supported!')
		return
	}
	if socket_path.len >= systemd_unix_path_len {
		log.warn('NOTIFY_SOCKET path is too long!')
		return
	}

	mut socket_address := C.sockaddr_un{}
	socket_address.sun_family = u16(C.AF_UNIX)
	for i, byte in socket_path.bytes() {
		socket_address.sun_path[i] = char(byte)
	}
	socket_address.sun_path[socket_path.len] = 0

	socket_fd := C.socket(C.AF_UNIX, C.SOCK_DGRAM | C.SOCK_CLOEXEC, 0)
	if socket_fd < 0 {
		log.warn('creating socket failed: ${os.last_error()}')
		return
	}
	defer {
		C.close(socket_fd)
	}

	if C.connect(socket_fd, &socket_address, u32(sizeof(C.sockaddr_un))) != 0 {
		log.warn('unable to connect to notify socket: ${os.last_error()}')
		return
	}

	written := C.write(socket_fd, message.str, usize(message.len))
	if written < 0 {
		log.warn('unable to write to notify socket: ${os.last_error()}')
		return
	}
	if written < message.len {
		log.warn('short write to notify socket: ${written} < ${message.len}')
	}
}

fn systemd_notify_reloading_linux() {
	mut timestamp := C.timespec{}
	if C.clock_gettime(C.CLOCK_MONOTONIC, &timestamp) != 0 {
		log.error('unable to get MONOTONIC clock: ${os.last_error()}')
		return
	}
	now := u64(timestamp.tv_sec) * 1_000_000 + u64(timestamp.tv_nsec) / 1_000
	systemd_notify_send('RELOADING=1\nMONOTONIC_USEC=${now}')
}
