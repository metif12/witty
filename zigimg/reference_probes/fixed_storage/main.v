module main

import os
import zigimg

fn mix(mut hash []u64, value u64) {
	hash[0] = (hash[0] ^ value) * u64(1099511628211)
}

fn run[T, B](storage B, value T, capacity int, trap bool) {
	_ = value
	mut buffer := zigimg.FixedStorage[T, B]{
		storage: storage
	}
	if trap {
		buffer.resize(uint(capacity + 1))
		eprintln('UNEXPECTED')
		return
	}
	mut bytes := unsafe { (&u8(&buffer.storage)).vbytes(capacity * int(sizeof(T))) }
	for i in 0 .. bytes.len {
		bytes[i] = u8(i * 37 + 11)
	}
	for size in 0 .. capacity + 1 {
		buffer.resize(uint(size))
		borrowed := size == 0 || buffer.data.data == voidptr(&buffer.storage)
		old := buffer.data
		buffer.resize(0)
		if size > 0 {
			mut old_bytes := unsafe { (&u8(old.data)).vbytes(size * int(sizeof(T))) }
			old_bytes[old_bytes.len - 1] ^= 0x5a
		}
		buffer.resize(uint(size))
		mut active := [u64(14695981039346656037)]
		data := unsafe { (&u8(buffer.data.data)).vbytes(size * int(sizeof(T))) }
		for byte in data {
			mix(mut active, byte)
		}
		mut hash := [u64(14695981039346656037)]
		for byte in bytes {
			mix(mut hash, byte)
		}
		println('${sizeof(T)}:${capacity}:${size}|${borrowed}:${old.len}:${buffer.data.len}:${active[0]:016x}:${hash[0]:016x}')
	}
}

fn main() {
	if os.args.len > 1 && os.args[1] == 'special8' {
		mut buffer := zigimg.FixedStorage8[u16]{}
		buffer.resize(9)
		eprintln('UNEXPECTED')
		return
	}
	if os.args.len > 1 && os.args[1] == 'special256' {
		mut buffer := zigimg.FixedStorage256[u16]{}
		buffer.resize(257)
		eprintln('UNEXPECTED')
		return
	}
	selected := if os.args.len > 1 { os.args[1].int() } else { -1 }
	run([]u8{}, u8(0), 0, selected == 0)
	run([1]u8{}, u8(0), 1, selected == 1)
	run([7]u8{}, u8(0), 7, selected == 2)
	run([8]u8{}, u8(0), 8, selected == 3)
	run([256]u8{}, u8(0), 256, selected == 4)
	run([513]u8{}, u8(0), 513, selected == 5)
	run([]u16{}, u16(0), 0, selected == 6)
	run([1]u16{}, u16(0), 1, selected == 7)
	run([7]u16{}, u16(0), 7, selected == 8)
	run([8]u16{}, u16(0), 8, selected == 9)
	run([256]u16{}, u16(0), 256, selected == 10)
	run([513]u16{}, u16(0), 513, selected == 11)
	run([]zigimg.Rgba32{}, zigimg.Rgba32{}, 0, selected == 12)
	run([1]zigimg.Rgba32{}, zigimg.Rgba32{}, 1, selected == 13)
	run([7]zigimg.Rgba32{}, zigimg.Rgba32{}, 7, selected == 14)
	run([8]zigimg.Rgba32{}, zigimg.Rgba32{}, 8, selected == 15)
	run([256]zigimg.Rgba32{}, zigimg.Rgba32{}, 256, selected == 16)
	run([513]zigimg.Rgba32{}, zigimg.Rgba32{}, 513, selected == 17)
}
