module zigimg

import os

#flag -I @DIR
#include "fixture_shims.h"

fn C.witty_image_close_setup(&char, int) int
fn C.witty_image_close_seed(int, int) int
fn C.witty_image_close_cleanup(&char, int, int) int
fn C.witty_image_close_raw(int) int
fn C.witty_image_close_valid(int) int
fn C.witty_image_close_refs(int) int
fn C.witty_image_close_kind(int) int
fn C.witty_image_close_flags(int) int
fn C.witty_image_close_bytes(int, int, &u8, usize) isize

__global (
	close_state   string
	close_root    string
	close_kind    int
	close_keeper  int
	close_fd      int
	close_buffer  []u8
	close_output  []u8
	close_wire    []u8
	close_status  string
	close_pos     u64
	close_pending []u8
	close_drain   int
)

fn close_snapshot(drain bool) string {
	if drain {
		mut bytes := []u8{len: 256}
		if close_kind == 1 {
			for {
				n := C.witty_image_close_bytes(close_keeper, close_kind, bytes.data,
					usize(bytes.len))
				if n <= 0 {
					close_drain = int(n)
					break
				}
				close_wire << bytes[..int(n)]
			}
		} else {
			n := C.witty_image_close_bytes(close_keeper, close_kind, bytes.data, usize(bytes.len))
			if n < 0 { panic('Observer read failed') }
			close_wire = bytes[..int(n)].clone()
			close_drain = 0
		}
	}
	return '${C.witty_image_close_valid(close_fd)}:${C.witty_image_close_valid(close_keeper)}:${C.witty_image_close_refs(close_keeper)}:${C.witty_image_close_kind(close_keeper)}:${close_drain}:${C.witty_image_close_flags(close_fd)}|${close_buffer.hex()}|${close_output.hex()}|${close_pos}:${close_pending.hex()}|${close_status}|${close_wire.hex()}'
}

fn close_observe() {
	if close_state == '' { return }
	state := close_snapshot(true)
	os.write_file(close_state, state) or { eprintln('OBSERVER ERROR: ${err}') }
	C.witty_image_close_cleanup(close_root.str, close_kind, close_keeper)
}

fn close_record(line string) string {
	f := line.split('|')
	close_kind = f[0].int()
	writing := f[1] == '1'
	choice := f[5].int()
	close_keeper = C.witty_image_close_setup(close_root.str, close_kind)
	if close_keeper < 0 || close_keeper >= 128 { panic('Close setup failed') }
	defer { C.witty_image_close_cleanup(close_root.str, close_kind, close_keeper) }
	mut buffer := []u8{len: f[2].int(), init: 165}
	close_buffer = unsafe { buffer }
	mut output := []u8{len: f[3].int(), init: 182}
	close_output = unsafe { output }
	payload := []u8{len: output.len, init: u8(index * 17 + 11)}
	close_wire = []u8{}
	close_drain = -3
	mut out := ''
	for _ in 0 .. f[6].int() {
		if C.witty_image_close_seed(close_keeper, close_kind) != 0 { panic('FIFO seed failed') }
		mut file := if choice == 5 {
			os.File{
				fd: -1
			}
		} else {
			image_open_file(close_root + '/target', writing) or { panic(err) }
		}
		mut copied := file
		close_fd = file.fd
		close_status = 'ok'
		close_pos = 0
		close_pending = []u8{}
		if choice != 5 {
			if writing {
				mut stream := WriteStream.init_file(file, mut buffer)
				stream.write_all(payload) or { close_status = err.msg() }
				if f[4] == '1' { stream.flush() or { close_status = err.msg() } }
				close_pos = stream.get_pos()
				close_pending = stream.buffered().clone()
			} else {
				mut stream := ReadStream.init_file(file, mut buffer)
				if f[7] == '1' {
					value := stream.take(output.len) or {
						close_status = err.msg()
						[]u8{}
					}
					if close_status == 'ok' {
						for i, byte in value {
							output[i] = byte
						}
					}
				} else {
					stream.read_slice_all(mut output) or { close_status = err.msg() }
				}
				close_pos = stream.get_pos()
				close_pending = stream.buffer[stream.position..stream.end].clone()
			}
		}
		out += close_snapshot(false) + '~'
		if choice == 0 {
			image_close_file(mut file)
		} else if choice == 1 {
			image_close_file(mut copied)
		} else if choice == 2 {
			image_close_file(mut file)
			image_close_file(mut file)
		} else if choice == 3 {
			image_close_file(mut file)
			image_close_file(mut copied)
		} else if choice == 4 {
			C.witty_image_close_raw(file.fd)
			image_close_file(mut file)
		} else {
			image_close_file(mut file)
		}
		out += close_snapshot(true) + '~'
		if copied.fd != file.fd { panic('Close mutated descriptor storage') }
	}
	return out
}

fn test_image_close_driver() {
	args := os.args
	if args.len < 2 { panic('Missing close fixture input') }
	if args[1] == '--trap' {
		close_state = args[2]
		close_root = close_state + '.case'
		at_exit(close_observe) or { panic(err) }
		result := close_record(args[3])
		close_state = ''
		println(result)
		return
	}
	close_root = args[1] + '.case'
	for line in (os.read_file(args[1]) or { panic(err) }).split_into_lines() {
		if line != '' { println(close_record(line)) }
	}
}
