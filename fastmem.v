// Translated from Ghostty's fastmem.zig
//
// Fast memory operations for byte slices. In Zig these use libc memmove/memcpy
// when available for performance. In V we use array copy operations and
// unsafe C.memmove where needed for overlapping copies.

module main

// Moves bytes from source into dest, handling overlapping regions correctly.
// Same as memmove - source and dest may overlap.
//
// In Zig this prefers libc memmove if it is available because it is
// generally much faster.
pub fn fastmem_move(mut dest []u8, source []u8) {
	if dest.len == 0 || source.len == 0 {
		return
	}
	unsafe {
		C.memmove(dest.data, source.data, source.len)
	}
}

// Copies bytes from source into dest. Source and dest must NOT overlap.
// Same as memcpy.
//
// In Zig this prefers libc memcpy if it is available because it is
// generally much faster.
pub fn fastmem_copy(mut dest []u8, source []u8) {
	if dest.len == 0 || source.len == 0 {
		return
	}
	unsafe {
		C.memcpy(dest.data, source.data, source.len)
	}
}

// Moves the first item to the end.
// For the reverse of this, use `rotate_once_r`.
//
// Same as std.mem.rotate(T, items, 1) but more efficient by using memmove
// and a tmp var for the single rotated item instead of 3 calls to reverse.
//
// e.g. `0 1 2 3` -> `1 2 3 0`.
pub fn rotate_once(mut items []u8) {
	if items.len <= 1 {
		return
	}
	tmp := items[0]
	mut dest := unsafe { items[0..items.len - 1] }
	source := unsafe { items[1..items.len] }
	fastmem_move(mut dest, source)
	items[items.len - 1] = tmp
}

// Moves the last item to the start.
// Reverse operation of `rotate_once`.
//
// Same as std.mem.rotate(T, items, items.len - 1) but more efficient by
// using memmove and a tmp var for the single rotated item instead of 3
// calls to reverse.
//
// e.g. `0 1 2 3` -> `3 0 1 2`.
pub fn rotate_once_r(mut items []u8) {
	if items.len <= 1 {
		return
	}
	tmp := items[items.len - 1]
	mut dest := unsafe { items[1..items.len] }
	source := unsafe { items[0..items.len - 1] }
	fastmem_move(mut dest, source)
	items[0] = tmp
}

// Rotates a new item in to the end of a slice.
// The first item from the slice is removed and returned.
//
// e.g. rotating `4` in to `0 1 2 3` makes it `1 2 3 4` and returns `0`.
//
// For the reverse of this, use `rotate_in_r`.
pub fn rotate_in(mut items []u8, item u8) u8 {
	removed := items[0]
	mut dest := unsafe { items[0..items.len - 1] }
	source := unsafe { items[1..items.len] }
	fastmem_move(mut dest, source)
	items[items.len - 1] = item
	return removed
}

// Rotates a new item in to the start of a slice.
// The last item from the slice is removed and returned.
//
// e.g. rotating `4` in to `0 1 2 3` makes it `4 0 1 2` and returns `3`.
//
// Reverse operation of `rotate_in`.
pub fn rotate_in_r(mut items []u8, item u8) u8 {
	removed := items[items.len - 1]
	mut dest := unsafe { items[1..items.len] }
	source := unsafe { items[0..items.len - 1] }
	fastmem_move(mut dest, source)
	items[0] = item
	return removed
}

fn C.memmove(dest voidptr, src voidptr, n usize) voidptr
fn C.memcpy(dest voidptr, src voidptr, n usize) voidptr
