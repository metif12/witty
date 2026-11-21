module main

import os
import zigimg as p

__global (
	observed_path     string
	root_x            voidptr
	root_y            voidptr
	old_bytes         []u8
	old_len           int
	external_bytes    []u8
	selected_kind     int
	selected_form     int
	observed_inline_x []u8
	observed_inline_y []u8
)
fn view(bytes []u8, len int, bases [][]u8, stride int) string {
	mut origin := 0
	mut offset := 0
	if bytes.len > 0 {
		ptr := uint(bytes.data)
		for index, base in bases {
			start := uint(base.data)
			if ptr >= start && bytes.len <= base.len && ptr - start <= uint(base.len - bytes.len) {
				origin = index + 1
				offset = int((ptr - start) / uint(stride))
				break
			}
		}
		if origin == 0 { panic('OBSERVER ERROR: unknown view') }
	}
	return '${len}:${origin}:${offset}:${bytes.hex()}'
}

// Array headers share V's built-in array carrier. Only this observer erases
// element types; the exercised buffer operations keep their concrete types.
fn snapshot() string {
	stride := [1, 2, 4][selected_kind]
	x := unsafe { &[]u8(root_x) }
	y := unsafe { &[]u8(root_y) }
	xd := unsafe { (&u8(x.data)).vbytes(x.len * stride) }
	yd := unsafe { (&u8(y.data)).vbytes(y.len * stride) }
	bases := [observed_inline_x, observed_inline_y, external_bytes]
	return view(xd, x.len, bases, stride) + '|' + view(yd, y.len, bases, stride) + '|' +
		view(old_bytes, old_len, bases, stride) + '|' + observed_inline_x.hex() + '|' +
		observed_inline_y.hex() + '|' + external_bytes.hex()
}

fn make_fixed[T, B](storage B, value T) p.FixedStorage[T, B] {
	return p.FixedStorage[T, B]{
		storage: storage
	}
}

fn observe() {
	if observed_path != '' { os.write_file(observed_path, snapshot()) or {
			eprintln('OBSERVER ERROR: ${err}')} }
}

fn run_0_0(f []uint) {
	mut x := make_fixed([]u8{}, u8(0))

	mut external := []u8{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u8))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u8))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_0_1(f []uint) {
	mut x := make_fixed([1]u8{}, u8(0))

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []u8{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u8))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u8))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_0_2(f []uint) {
	mut x := make_fixed([7]u8{}, u8(0))

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []u8{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u8))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u8))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_0_3(f []uint) {
	mut x := make_fixed([8]u8{}, u8(0))

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []u8{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u8))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u8))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_0_4(f []uint) {
	mut x := make_fixed([256]u8{}, u8(0))

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []u8{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u8))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u8))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_0_5(f []uint) {
	mut x := make_fixed([513]u8{}, u8(0))

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []u8{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u8))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u8))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_0_6(f []uint) {
	mut x := p.FixedStorage8[u8]{}

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []u8{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u8))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u8))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_0_7(f []uint) {
	mut x := p.FixedStorage256[u8]{}

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []u8{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u8))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u8))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u8))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_1_0(f []uint) {
	mut x := make_fixed([]u16{}, u16(0))

	mut external := []u16{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u16))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u16))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_1_1(f []uint) {
	mut x := make_fixed([1]u16{}, u16(0))

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []u16{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u16))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u16))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_1_2(f []uint) {
	mut x := make_fixed([7]u16{}, u16(0))

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []u16{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u16))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u16))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_1_3(f []uint) {
	mut x := make_fixed([8]u16{}, u16(0))

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []u16{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u16))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u16))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_1_4(f []uint) {
	mut x := make_fixed([256]u16{}, u16(0))

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []u16{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u16))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u16))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_1_5(f []uint) {
	mut x := make_fixed([513]u16{}, u16(0))

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []u16{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u16))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u16))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_1_6(f []uint) {
	mut x := p.FixedStorage8[u16]{}

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []u16{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u16))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u16))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_1_7(f []uint) {
	mut x := p.FixedStorage256[u16]{}

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []u16{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(u16))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(u16))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(u16))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_2_0(f []uint) {
	mut x := make_fixed([]p.Rgba32{}, p.Rgba32{})

	mut external := []p.Rgba32{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(p.Rgba32))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(p.Rgba32))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_2_1(f []uint) {
	mut x := make_fixed([1]p.Rgba32{}, p.Rgba32{})

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []p.Rgba32{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(p.Rgba32))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(p.Rgba32))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_2_2(f []uint) {
	mut x := make_fixed([7]p.Rgba32{}, p.Rgba32{})

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []p.Rgba32{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(p.Rgba32))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(p.Rgba32))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_2_3(f []uint) {
	mut x := make_fixed([8]p.Rgba32{}, p.Rgba32{})

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []p.Rgba32{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(p.Rgba32))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(p.Rgba32))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_2_4(f []uint) {
	mut x := make_fixed([256]p.Rgba32{}, p.Rgba32{})

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []p.Rgba32{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(p.Rgba32))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(p.Rgba32))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_2_5(f []uint) {
	mut x := make_fixed([513]p.Rgba32{}, p.Rgba32{})

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []p.Rgba32{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(p.Rgba32))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(p.Rgba32))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_2_6(f []uint) {
	mut x := p.FixedStorage8[p.Rgba32]{}

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []p.Rgba32{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(p.Rgba32))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(p.Rgba32))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn run_2_7(f []uint) {
	mut x := p.FixedStorage256[p.Rgba32]{}

	mut initial_bytes := unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	for i in 0 .. initial_bytes.len {
		initial_bytes[i] = u8(i * 37 + int(f[4]))
	}

	mut external := []p.Rgba32{len: 4}
	mut ext := unsafe { (&u8(external.data)).vbytes(4 * int(sizeof(p.Rgba32))) }
	for i in 0 .. ext.len {
		ext[i] = u8(i * 19 + int(f[4]) + 7)
	}
	match int(f[1]) {
		0 {}
		1 { x.resize(f[2]) }
		2 { x.data = unsafe { external[..int(f[2])] } }
		3 { x.data = unsafe { external[1..1 + int(f[2])] } }
		else { panic('bad mode') }
	}

	old := x.data
	mut y := x
	root_x = &x.data
	root_y = &y.data
	observed_inline_x = unsafe {
		(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	observed_inline_y = unsafe {
		(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
			1,
			2,
			4,
		][selected_kind])
	}
	old_bytes = unsafe { (&u8(old.data)).vbytes(old.len * int(sizeof(p.Rgba32))) }
	old_len = old.len
	external_bytes = unsafe { ext }
	match int(f[0]) {
		0 {
			x.resize(f[3])
		}
		1 {
			y.resize(f[3])
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			if bytes.len > 0 { bytes[bytes.len - 1] ^= 85 }
		}
		2 {
			x.resize(f[3])
			if old_bytes.len > 0 { old_bytes[old_bytes.len - 1] ^= 85 }
		}
		3 {
			mut bytes := unsafe {
				(&u8(&y.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }
		}
		4 {
			y.data = unsafe { external[1..3] }
			mut bytes := unsafe { (&u8(y.data.data)).vbytes(y.data.len * int(sizeof(p.Rgba32))) }
			bytes[0] ^= 85
		}
		5 {
			y.data = unsafe { old[..if old.len > 0 { 1 } else { 0 }] }
			x.resize(f[3])
		}
		6 {
			mut bytes := unsafe {
				(&u8(&x.storage)).vbytes([0, 1, 7, 8, 256, 513, 8, 256][selected_form] * [
					1,
					2,
					4,
				][selected_kind])
			}
			if bytes.len > 0 { bytes[0] ^= 85 }

			y.resize(f[3])
		}
		else {
			panic('bad operation')
		}
	}

	if observed_path != '' {
		eprintln('UNEXPECTED return')
		return
	}
	println(snapshot())
}

fn line_case(line string) {
	f := line.split('|').map(uint(it.u64()))
	selected_kind = int(f[0])
	selected_form = int(f[1])
	match selected_kind {
		0 {
			match selected_form {
				0 { run_0_0(f[2..]) }
				1 { run_0_1(f[2..]) }
				2 { run_0_2(f[2..]) }
				3 { run_0_3(f[2..]) }
				4 { run_0_4(f[2..]) }
				5 { run_0_5(f[2..]) }
				6 { run_0_6(f[2..]) }
				7 { run_0_7(f[2..]) }
				else { panic('bad form') }
			}
		}
		1 {
			match selected_form {
				0 { run_1_0(f[2..]) }
				1 { run_1_1(f[2..]) }
				2 { run_1_2(f[2..]) }
				3 { run_1_3(f[2..]) }
				4 { run_1_4(f[2..]) }
				5 { run_1_5(f[2..]) }
				6 { run_1_6(f[2..]) }
				7 { run_1_7(f[2..]) }
				else { panic('bad form') }
			}
		}
		2 {
			match selected_form {
				0 { run_2_0(f[2..]) }
				1 { run_2_1(f[2..]) }
				2 { run_2_2(f[2..]) }
				3 { run_2_3(f[2..]) }
				4 { run_2_4(f[2..]) }
				5 { run_2_5(f[2..]) }
				6 { run_2_6(f[2..]) }
				7 { run_2_7(f[2..]) }
				else { panic('bad form') }
			}
		}
		else {
			panic('bad kind')
		}
	}
}

fn main() {
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		line_case(os.args[3])
		return
	}
	for line in os.read_lines(os.args[2]) or { panic(err) } {
		line_case(line)
	}
}
