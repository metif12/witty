// C-compatible allocator interface used by libghostty-vt.
//
// Translated from Ghostty's src/lib/allocator.zig. V does not expose a
// replaceable language allocator object, so Allocator itself is the canonical
// allocation value on both sides of the V/C boundary. `from_zig` and `zig`
// therefore preserve the source round-trip by copying this pointer-stable
// value instead of adapting to a second runtime allocator type.

@[has_globals]
module lib_allocator

pub type AllocFn = fn (ctx voidptr, len usize, alignment u8, ret_addr usize) voidptr

pub type ResizeFn = fn (ctx voidptr, memory voidptr, memory_len usize, alignment u8, new_len usize, ret_addr usize) bool

pub type RemapFn = fn (ctx voidptr, memory voidptr, memory_len usize, alignment u8, new_len usize, ret_addr usize) voidptr

pub type FreeFn = fn (ctx voidptr, memory voidptr, memory_len usize, alignment u8, ret_addr usize)

// VTable is the exact operation table exposed as GhosttyAllocatorVtable.
pub struct VTable {
pub:
	alloc  AllocFn  @[required]
	resize ResizeFn @[required]
	remap  RemapFn  @[required]
	// V reserves `free` for its generated aggregate destructor; the `_fn`
	// suffix changes only the V field spelling, not the C layout.
	free_fn FreeFn @[required]
}

// Allocator is the C-facing allocator value exposed as GhosttyAllocator.
pub struct Allocator {
pub:
	ctx    voidptr
	vtable &VTable = unsafe { nil }
}

// from_zig creates a C allocator from Witty's canonical allocator value. The
// source accepts a pointer-stable Zig allocator; V uses this same value as its
// allocator interface, so the translation is an identity copy.
pub fn Allocator.from_zig(allocator &Allocator) Allocator {
	if isnil(allocator) {
		return c_allocator
	}
	return *allocator
}

// zig converts the C-facing allocator back to Witty's allocator interface.
pub fn (self &Allocator) zig() Allocator {
	return *self
}

// alloc_bytes allocates len bytes or returns none on allocation failure.
pub fn (self &Allocator) alloc_bytes(len usize, alignment u8, ret_addr usize) ?voidptr {
	if isnil(self.vtable) {
		return none
	}
	ptr := self.vtable.alloc(self.ctx, len, alignment, ret_addr)
	if isnil(ptr) {
		return none
	}
	return ptr
}

// resize_bytes attempts to resize an allocation without moving it.
pub fn (self &Allocator) resize_bytes(memory voidptr, memory_len usize, alignment u8, new_len usize, ret_addr usize) bool {
	if isnil(self.vtable) || isnil(memory) || new_len == 0 {
		return false
	}
	return self.vtable.resize(self.ctx, memory, memory_len, alignment, new_len, ret_addr)
}

// remap_bytes attempts to resize an allocation and may relocate it.
pub fn (self &Allocator) remap_bytes(memory voidptr, memory_len usize, alignment u8, new_len usize, ret_addr usize) ?voidptr {
	if isnil(self.vtable) || isnil(memory) || new_len == 0 {
		return none
	}
	ptr := self.vtable.remap(self.ctx, memory, memory_len, alignment, new_len, ret_addr)
	if isnil(ptr) {
		return none
	}
	return ptr
}

// free_bytes releases an allocation. A null pointer is accepted by the V
// boundary so destructors can retain Ghostty's nullable-object convention.
pub fn (self &Allocator) free_bytes(memory voidptr, memory_len usize, alignment u8, ret_addr usize) {
	if isnil(self.vtable) || isnil(memory) {
		return
	}
	self.vtable.free_fn(self.ctx, memory, memory_len, alignment, ret_addr)
}

// default returns a usable allocator for a possibly absent C allocator.
pub fn default(allocator ?&Allocator) Allocator {
	if value := allocator {
		return value.zig()
	}
	return c_allocator
}

fn c_alloc(_ voidptr, len usize, _ u8, _ usize) voidptr {
	size := if len == 0 { usize(1) } else { len }
	return unsafe { malloc(size) }
}

fn c_resize(_ voidptr, memory voidptr, memory_len usize, _ u8, new_len usize, _ usize) bool {
	_ = memory
	// libc cannot promise that a growing realloc remains in place. Shrinking
	// can always retain the original region while exposing the shorter length.
	return new_len > 0 && new_len <= memory_len
}

fn c_remap(_ voidptr, memory voidptr, memory_len usize, _ u8, new_len usize, _ usize) voidptr {
	if isnil(memory) || new_len == 0 {
		return unsafe { nil }
	}
	return unsafe { realloc_data(&u8(memory), int(memory_len), int(new_len)) }
}

fn c_free(_ voidptr, memory voidptr, _ usize, _ u8, _ usize) {
	if !isnil(memory) {
		unsafe { free(memory) }
	}
}

__global c_allocator_vtable = VTable{
	alloc: c_alloc
	resize: c_resize
	remap: c_remap
	free_fn: c_free
}

// c_allocator is the process allocator used when a caller supplies null.
pub fn c_allocator_value() Allocator {
	return Allocator{
		ctx: unsafe { nil }
		vtable: &c_allocator_vtable
	}
}

// V globals cannot expose a const containing function pointers, so this
// read-only module value is initialized once and returned/copied by value.
__global c_allocator = Allocator{
	ctx: unsafe { nil }
	vtable: &c_allocator_vtable
}
