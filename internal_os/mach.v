module internal_os

#include "@VMODROOT/internal_os/mach_memory.h"

fn C.witty_tagged_page_size() uint

fn C.witty_tagged_page_map(length uint, alignment uint, tag i32, mapped_length &uint) voidptr

fn C.witty_tagged_page_realloc(memory voidptr, old_mapped_length uint, new_length uint, may_move int, new_mapped_length &uint) voidptr

fn C.witty_tagged_page_unmap(memory voidptr, mapped_length uint)

// VMTag contains macOS application-specific virtual-memory tags. They identify
// Ghostty allocations in vmmap and Instruments.
pub enum VMTag as u8 {
	application_specific_1  = 240
	application_specific_2  = 241
	application_specific_3  = 242
	application_specific_4  = 243
	application_specific_5  = 244
	application_specific_6  = 245
	application_specific_7  = 246
	application_specific_8  = 247
	application_specific_9  = 248
	application_specific_10 = 249
	application_specific_11 = 250
	application_specific_12 = 251
	application_specific_13 = 252
	application_specific_14 = 253
	application_specific_15 = 254
	application_specific_16 = 255
}

// make converts the tag to the fd bit pattern expected by Darwin mmap,
// equivalent to VM_MAKE_TAG(tag).
pub fn (self VMTag) make() i32 {
	return i32(u32(u8(self)) << 24)
}

// TaggedPageAllocator carries the VM tag used for every mapping it creates.
// V does not expose a replaceable global Allocator vtable, so the translated
// allocator owns explicit TaggedPageMemory values instead.
pub struct TaggedPageAllocator {
pub:
	tag VMTag
}

pub fn tagged_page_allocator(tag VMTag) TaggedPageAllocator {
	return TaggedPageAllocator{
		tag: tag
	}
}

// TaggedPageMemory is an owned page mapping. len is the requested logical
// length; mapped_len is the page-rounded range passed to munmap.
pub struct TaggedPageMemory {
pub mut:
	ptr        voidptr
	len        uint
	mapped_len uint
}

pub fn (self TaggedPageAllocator) alloc(length uint, alignment uint) ?TaggedPageMemory {
	assert length > 0
	mut mapped_len := uint(0)
	ptr := C.witty_tagged_page_map(length, alignment, self.tag.make(), &mapped_len)
	if isnil(ptr) {
		return none
	}
	return TaggedPageMemory{
		ptr:        ptr
		len:        length
		mapped_len: mapped_len
	}
}

// resize changes the logical length without moving the mapping. Like the
// pinned allocator, equal page-rounded sizes succeed and shrinking releases
// trailing pages; growth fails on platforms without mremap.
pub fn (mut self TaggedPageMemory) resize(new_len uint) bool {
	return self.realloc(new_len, false)
}

// remap permits the platform to move the allocation. Darwin has no mremap,
// so its behavior is the same as resize; the separate method preserves the
// source allocator contract.
pub fn (mut self TaggedPageMemory) remap(new_len uint) bool {
	return self.realloc(new_len, true)
}

// realloc changes the page-rounded mapping size, optionally permitting the
// platform to move it. The owned V value retains the returned pointer in place.
pub fn (mut self TaggedPageMemory) realloc(new_len uint, may_move bool) bool {
	mut mapped_len := uint(0)
	ptr := C.witty_tagged_page_realloc(self.ptr, self.mapped_len, new_len, int(may_move),
		&mapped_len)
	if isnil(ptr) {
		return false
	}
	self.ptr = ptr
	self.len = new_len
	self.mapped_len = mapped_len
	return true
}

// unmap releases the complete page-rounded mapping.
pub fn (mut self TaggedPageMemory) unmap() {
	C.witty_tagged_page_unmap(self.ptr, self.mapped_len)
	self.ptr = unsafe { nil }
	self.len = 0
	self.mapped_len = 0
}

fn tagged_page_size() uint {
	return C.witty_tagged_page_size()
}
