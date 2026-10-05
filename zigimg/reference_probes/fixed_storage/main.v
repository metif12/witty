module main

import os
import zigimg

fn mix(mut hash []u64, value u64) {
	hash[0] = (hash[0] ^ value) * u64(1099511628211)
}

fn run[T, B](storage B, value T, capacity int) {
	_ = value
	mut buffer := zigimg.FixedStorage[T, B]{
		storage: storage
	}
	if os.args.len > 1 {
		buffer.resize(usize(capacity + 1))
		eprintln('UNEXPECTED')
		return
	}
	mut bytes := unsafe { (&u8(&buffer.storage)).vbytes(capacity * int(sizeof(T))) }
	for i in 0 .. bytes.len {
		bytes[i] = u8(i * 37 + 11)
	}
	for size in 0 .. capacity + 1 {
		buffer.resize(usize(size))
		borrowed := size == 0 || buffer.data.data == voidptr(&buffer.storage)
		old := buffer.data
		buffer.resize(0)
		if size > 0 {
			mut old_bytes := unsafe { (&u8(old.data)).vbytes(size * int(sizeof(T))) }
			old_bytes[old_bytes.len - 1] ^= 0x5a
		}
		buffer.resize(usize(size))
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
	run([]u8{}, u8(0), 0)
	run([1]u8{}, u8(0), 1)
	run([7]u8{}, u8(0), 7)
	run([8]u8{}, u8(0), 8)
	run([256]u8{}, u8(0), 256)
	run([513]u8{}, u8(0), 513)
	run([]u16{}, u16(0), 0)
	run([1]u16{}, u16(0), 1)
	run([7]u16{}, u16(0), 7)
	run([8]u16{}, u16(0), 8)
	run([256]u16{}, u16(0), 256)
	run([513]u16{}, u16(0), 513)
	run([]zigimg.Rgba32{}, zigimg.Rgba32{}, 0)
	run([1]zigimg.Rgba32{}, zigimg.Rgba32{}, 1)
	run([7]zigimg.Rgba32{}, zigimg.Rgba32{}, 7)
	run([8]zigimg.Rgba32{}, zigimg.Rgba32{}, 8)
	run([256]zigimg.Rgba32{}, zigimg.Rgba32{}, 256)
	run([513]zigimg.Rgba32{}, zigimg.Rgba32{}, 513)
}
