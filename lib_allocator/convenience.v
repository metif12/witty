// Convenience allocations used by the WebAssembly lib-vt ABI.
//
// Translated from Ghostty's src/lib/allocator/convenience.zig. These helpers
// intentionally use the process allocator and expose individually paired
// allocation/free entry points for hosts that cannot conveniently construct
// typed pointers in WebAssembly memory.

module lib_allocator

// Opaque is one pointer-sized slot (`*anyopaque` in the source). A wrapper
// struct avoids the pinned V compiler collapsing `?&voidptr` to an invalid
// optional-void C value while preserving the exact memory layout.
pub struct Opaque {
pub mut:
	value voidptr
}

const allocator_max_usize = ~uint(0)

pub fn alloc_opaque() &Opaque {
	raw := unsafe { malloc(sizeof(Opaque)) }
	if isnil(raw) {
		return unsafe { nil }
	}
	return unsafe { &Opaque(raw) }
}

pub fn free_opaque(ptr &Opaque) {
	if !isnil(ptr) {
		unsafe { free(ptr) }
	}
}

pub fn alloc_u8_array(len uint) &u8 {
	// The source allocator returns a valid zero-length allocation. Request one
	// byte so the C allocator has the same non-null ownership token.
	size := if len == 0 { uint(1) } else { len }
	raw := unsafe { malloc(size) }
	if isnil(raw) {
		return unsafe { nil }
	}
	return unsafe { &u8(raw) }
}

pub fn free_u8_array(ptr &u8, len uint) {
	_ = len
	if !isnil(ptr) {
		unsafe { free(ptr) }
	}
}

pub fn alloc_u16_array(len uint) &u16 {
	if len > allocator_max_usize / sizeof(u16) {
		return unsafe { nil }
	}
	bytes := len * sizeof(u16)
	size := if bytes == 0 { uint(1) } else { bytes }
	raw := unsafe { malloc(size) }
	if isnil(raw) {
		return unsafe { nil }
	}
	return unsafe { &u16(raw) }
}

pub fn free_u16_array(ptr &u16, len uint) {
	_ = len
	if !isnil(ptr) {
		unsafe { free(ptr) }
	}
}

pub fn alloc_u8() &u8 {
	return alloc_u8_array(1)
}

pub fn free_u8(ptr &u8) {
	free_u8_array(ptr, 1)
}

pub fn alloc_usize() &uint {
	raw := unsafe { malloc(sizeof(uint)) }
	if isnil(raw) {
		return unsafe { nil }
	}
	return unsafe { &uint(raw) }
}

pub fn free_usize(ptr &uint) {
	if !isnil(ptr) {
		unsafe { free(ptr) }
	}
}
