@[has_globals]
module terminal

import lib_allocator

$if windows {
	#flag windows -lntdll
}

#include "@VMODROOT/terminal/page_pool_allocator.h"

fn C.witty_page_pool_map(uint, u8, u8) voidptr
fn C.witty_page_pool_unmap(voidptr, uint)
fn C.witty_page_pool_realloc(voidptr, uint, uint, int) voidptr

fn page_pool_alloc(ctx voidptr, n uint, alignment u8, _ uint) voidptr {
	assert n > 0
	return C.witty_page_pool_map(n, alignment, u8(uint(ctx)))
}

fn page_pool_resize(_ voidptr, memory voidptr, old uint, _ u8, n uint, _ uint) bool {
	return !isnil(C.witty_page_pool_realloc(memory, old, n, 0))
}

fn page_pool_remap(_ voidptr, memory voidptr, old uint, _ u8, n uint, _ uint) voidptr {
	return C.witty_page_pool_realloc(memory, old, n, 1)
}

fn page_pool_free(_ voidptr, memory voidptr, n uint, _ u8, _ uint) {
	C.witty_page_pool_unmap(memory, n)
}

__global page_pool_vtable = lib_allocator.VTable{
	alloc:   page_pool_alloc
	resize:  page_pool_resize
	remap:   page_pool_remap
	free_fn: page_pool_free
}

// The original pageAllocator uses the test allocator during tests and tags
// native Darwin mappings as application_specific_1. Tests can supply their
// own allocator via PageList.init_alloc for identical failure instrumentation.
fn page_list_page_allocator() lib_allocator.Allocator {
	mut ctx := unsafe { nil }
	$if macos || ios { ctx = unsafe { voidptr(uint(240)) } }
	return lib_allocator.Allocator{
		ctx:    ctx
		vtable: &page_pool_vtable
	}
}
