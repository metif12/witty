module fastmem

// move is the same as memmove and prefers the linked libc implementation.
pub fn move[T](mut dest []T, source []T) {
	unsafe {
		C.memmove(dest.data, source.data, usize(source.len) * usize(sizeof(T)))
	}
}

// copy is the same as memcpy and prefers the linked libc implementation.
pub fn copy[T](mut dest []T, source []T) {
	unsafe {
		C.memcpy(dest.data, source.data, usize(source.len) * usize(sizeof(T)))
	}
}

// rotate_once moves the first item to the end.
pub fn rotate_once[T](mut items []T) {
	temporary := items[0]
	mut dest := unsafe { items[..items.len - 1] }
	source := unsafe { items[1..] }
	move(mut dest, source)
	items[items.len - 1] = temporary
}

// rotate_once_r moves the last item to the start.
pub fn rotate_once_r[T](mut items []T) {
	temporary := items[items.len - 1]
	mut dest := unsafe { items[1..] }
	source := unsafe { items[..items.len - 1] }
	move(mut dest, source)
	items[0] = temporary
}

// rotate_in rotates item into the end and returns the removed first item.
pub fn rotate_in[T](mut items []T, item T) T {
	removed := items[0]
	mut dest := unsafe { items[..items.len - 1] }
	source := unsafe { items[1..] }
	move(mut dest, source)
	items[items.len - 1] = item
	return removed
}

// rotate_in_r rotates item into the start and returns the removed last item.
pub fn rotate_in_r[T](mut items []T, item T) T {
	removed := items[items.len - 1]
	mut dest := unsafe { items[1..] }
	source := unsafe { items[..items.len - 1] }
	move(mut dest, source)
	items[0] = item
	return removed
}

fn C.memmove(dest voidptr, source voidptr, length usize) voidptr

fn C.memcpy(dest voidptr, source voidptr, length usize) voidptr
