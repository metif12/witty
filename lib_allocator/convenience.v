// Convenience allocations used by the WebAssembly lib-vt ABI.
//
// Translated from Ghostty's src/lib/allocator/convenience.zig. These helpers
// intentionally use the process allocator and expose individually paired
// allocation/free entry points for hosts that cannot conveniently construct
// typed pointers in WebAssembly memory.

module lib_allocator

pub type Opaque = voidptr

const allocator_max_usize = ~usize(0)

pub fn alloc_opaque() ?&Opaque {
	raw := unsafe { malloc(sizeof(Opaque)) }
	if isnil(raw) {
		return none
	}
	return unsafe { &Opaque(raw) }
}

pub fn free_opaque(ptr ?&Opaque) {
	if value := ptr {
		unsafe { free(value) }
	}
}

pub fn alloc_u8_array(len usize) ?&u8 {
	// The source allocator returns a valid zero-length allocation. Request one
	// byte so the C allocator has the same non-null ownership token.
	size := if len == 0 { usize(1) } else { len }
	raw := unsafe { malloc(size) }
	if isnil(raw) {
		return none
	}
	return unsafe { &u8(raw) }
}

pub fn free_u8_array(ptr ?&u8, len usize) {
	_ = len
	if value := ptr {
		unsafe { free(value) }
	}
}

pub fn alloc_u16_array(len usize) ?&u16 {
	if len > allocator_max_usize / sizeof(u16) {
		return none
	}
	bytes := len * sizeof(u16)
	size := if bytes == 0 { usize(1) } else { bytes }
	raw := unsafe { malloc(size) }
	if isnil(raw) {
		return none
	}
	return unsafe { &u16(raw) }
}

pub fn free_u16_array(ptr ?&u16, len usize) {
	_ = len
	if value := ptr {
		unsafe { free(value) }
	}
}

pub fn alloc_u8() ?&u8 {
	return alloc_u8_array(1)
}

pub fn free_u8(ptr ?&u8) {
	free_u8_array(ptr, 1)
}

pub fn alloc_usize() ?&usize {
	raw := unsafe { malloc(sizeof(usize)) }
	if isnil(raw) {
		return none
	}
	return unsafe { &usize(raw) }
}

pub fn free_usize(ptr ?&usize) {
	if value := ptr {
		unsafe { free(value) }
	}
}
