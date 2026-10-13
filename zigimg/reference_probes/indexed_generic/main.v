module main

import os
import strings
import hash.fnv1a
import zigimg as p

type ByteAlias = u8
type WordAlias = u16
type SignedAlias = i16

__global (
	observed_path  string
	observed_len   = &int(unsafe { nil })
	observed_bytes []u8
)

fn observe() {
	prefix := if observed_len == unsafe { nil } { '-|' } else { '${*observed_len}|' }
	os.write_file(observed_path, prefix + observed_bytes.hex()) or {
		eprintln('OBSERVER ERROR: ${err}')
	}
}

fn bytes(values []p.Rgba32) []u8 {
	return unsafe { (&u8(values.data)).vbytes(values.len * 4) }
}

fn scalar[T](raw u32) T {
	$if T.unaliased_typ is bool {
		return raw & 1 != 0
	} $else {
		return T(raw)
	}
}

fn emit[T](mut out strings.Builder, value T) {
	out.write_string('${value.palette.len},${value.indices.len},${fnv1a.sum64(bytes(value.palette))}|')
	for index in value.indices {
		out.write_string('${index};')
	}
	out.write_string('|')
}

fn changed[T](value p.IndexedStorage[T], size usize) p.IndexedStorage[T] {
	mut result := value
	p.IndexedStorage.resize_palette[T](mut result, size)
	return result
}

fn run[T](mut out strings.Builder, count usize, size usize, new_size usize, seed u32) {
	capacity := p.IndexedStorage.palette_size[T]()
	mut x := p.IndexedStorage[T]{
		palette: []p.Rgba32{}
		indices: []T{}
	}
	x = if u64(size) == capacity {
		p.IndexedStorage.init[T](count)
	} else {
		p.IndexedStorage.init_palette_size[T](count, size)
	}
	for i in 0 .. x.indices.len {
		x.indices[i] = scalar[T](u32(i) + seed)
	}
	out.write_string('${capacity}|')
	emit(mut out, x)
	p.IndexedStorage.resize_palette[T](mut x, usize(capacity))
	for i in 0 .. x.palette.len {
		x.palette[i] = p.Rgba32{
			r: u8(u32(i) + seed)
			g: u8(i >> 8)
			b: u8(u32(i) * 7 + seed)
			a: u8(i + 3)
		}
	}
	p.IndexedStorage.resize_palette[T](mut x, size)
	mut copy := x
	mut returned := changed(x, new_size)
	if copy.palette.len != 0 { copy.palette[0] = p.Rgba32{
			r: 9
			g: 8
			b: 7
			a: 6
		} }
	if returned.palette.len != 0 { returned.palette[0].a = 5 }
	if count != 0 { copy.indices[0] = scalar[T](seed + 99) }
	p.IndexedStorage.resize_palette[T](mut x, (size + new_size) % (usize(capacity) + 1))
	emit(mut out, x)
	emit(mut out, copy)
	emit(mut out, returned)
	returned = copy
	emit(mut out, returned)
	p.IndexedStorage.resize_palette[T](mut x, usize(capacity))
	emit(mut out, x)
	x.deinit()
}

fn trap[T](mode u8, size usize) {
	if mode == 0 {
		_ = p.IndexedStorage.init_palette_size[T](3, size)
	} else {
		mut x := p.IndexedStorage[T]{
			palette: []p.Rgba32{}
			indices: []T{}
		}
		x = p.IndexedStorage.init_palette_size[T](3, 1)
		observed_len = &x.palette.len
		observed_bytes = bytes(x.palette)
		p.IndexedStorage.resize_palette[T](mut x, size)
	}
}

fn main() {
	if os.args[1] == 'guard' {
		match os.args[2] {
			'u32' { _ = p.IndexedStorage.init_palette_size[u32](0, 0) }
			'int' { _ = p.IndexedStorage.init_palette_size[int](0, 0) }
			'f32' { _ = p.IndexedStorage.init_palette_size[f32](0, 0) }
			'count' { _ = p.IndexedStorage.init_palette_size[u8](~usize(0), 0) }
			else { panic('invalid guard') }
		}

		panic('UNEXPECTED SUCCESS')
	}
	if os.args[1] == 'trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		kind := os.args[3].int()
		mode := u8(os.args[4].int())
		size := usize(os.args[5].u64())
		match kind {
			0 { trap[bool](mode, size) }
			1 { trap[u8](mode, size) }
			2 { trap[u16](mode, size) }
			3 { trap[i8](mode, size) }
			4 { trap[i16](mode, size) }
			5 { trap[ByteAlias](mode, size) }
			6 { trap[WordAlias](mode, size) }
			7 { trap[SignedAlias](mode, size) }
			else { panic('invalid kind') }
		}

		panic('UNEXPECTED SUCCESS')
	}
	mut out := strings.new_builder(64 * 1024)
	if os.args[1] == 'capacity' {
		out.write_string('${p.IndexedStorage.palette_size[u32]()}\n${p.IndexedStorage.palette_size[int]()}\n${p.IndexedStorage.palette_size[f32]()}\n')
	} else if os.args[1] == 'named' {
		x1 := p.IndexedStorage1.init_palette_size(0, 1)
		out.write_string('${p.IndexedStorage1.palette_size()}|')
		emit(mut out, x1)
		out.write_string('\n')
		x1.deinit()
		x2 := p.IndexedStorage2.init_palette_size(0, 1)
		out.write_string('${p.IndexedStorage2.palette_size()}|')
		emit(mut out, x2)
		out.write_string('\n')
		x2.deinit()
		x4 := p.IndexedStorage4.init_palette_size(0, 1)
		out.write_string('${p.IndexedStorage4.palette_size()}|')
		emit(mut out, x4)
		out.write_string('\n')
		x4.deinit()
		x8 := p.IndexedStorage8.init_palette_size(0, 1)
		out.write_string('${p.IndexedStorage8.palette_size()}|')
		emit(mut out, x8)
		out.write_string('\n')
		x8.deinit()
		x16 := p.IndexedStorage16.init_palette_size(0, 1)
		out.write_string('${p.IndexedStorage16.palette_size()}|')
		emit(mut out, x16)
		out.write_string('\n')
		x16.deinit()
	} else {
		contents := os.read_file(os.args[1]) or { panic(err) }
		for line in contents.split_into_lines() {
			fields := line.split('|')
			count := usize(fields[1].u64())
			size := usize(fields[2].u64())
			new_size := usize(fields[3].u64())
			seed := u32(fields[4].u64())
			match fields[0].int() {
				0 { run[bool](mut out, count, size, new_size, seed) }
				1 { run[u8](mut out, count, size, new_size, seed) }
				2 { run[u16](mut out, count, size, new_size, seed) }
				3 { run[i8](mut out, count, size, new_size, seed) }
				4 { run[i16](mut out, count, size, new_size, seed) }
				5 { run[ByteAlias](mut out, count, size, new_size, seed) }
				6 { run[WordAlias](mut out, count, size, new_size, seed) }
				7 { run[SignedAlias](mut out, count, size, new_size, seed) }
				else { panic('invalid kind') }
			}

			out.write_string('\n')
		}
	}
	print(out.str())
}
