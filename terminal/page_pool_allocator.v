@[has_globals]
module terminal

import lib_allocator

$if windows {
	#flag windows -lntdll
}

#include "@VMODROOT/terminal/page_pool_allocator.h"

fn C.witty_page_pool_map(usize, u8, u8) voidptr
fn C.witty_page_pool_unmap(voidptr, usize)
fn C.witty_page_pool_realloc(voidptr, usize, usize, int) voidptr

fn page_pool_alloc(ctx voidptr, n usize, alignment u8, _ usize) voidptr {
	assert n > 0
	return C.witty_page_pool_map(n, alignment, u8(usize(ctx)))
}

fn page_pool_resize(_ voidptr, memory voidptr, old usize, _ u8, n usize, _ usize) bool {
	return !isnil(C.witty_page_pool_realloc(memory, old, n, 0))
}

fn page_pool_remap(_ voidptr, memory voidptr, old usize, _ u8, n usize, _ usize) voidptr {
	return C.witty_page_pool_realloc(memory, old, n, 1)
}

fn page_pool_free(_ voidptr, memory voidptr, n usize, _ u8, _ usize) {
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
	$if macos || ios { ctx = unsafe { voidptr(usize(240)) } }
	return lib_allocator.Allocator{
		ctx:    ctx
		vtable: &page_pool_vtable
	}
}
