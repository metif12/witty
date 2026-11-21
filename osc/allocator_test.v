module osc

import lib_allocator

@[heap]
struct LimitedAllocator {
mut:
	remaining int
	allocations int
	frees int
	live int
}

fn limited_alloc(ctx voidptr, len uint, alignment u8, ret_addr uint) voidptr {
	mut state := unsafe { &LimitedAllocator(ctx) }
	state.allocations++
	if state.remaining == 0 { return unsafe { nil } }
	state.remaining--
	state.live++
	return lib_allocator.default(none).alloc_bytes(len, alignment, ret_addr)
}

fn limited_resize(_ voidptr, _ voidptr, _ uint, _ u8, _ uint, _ uint) bool { return false }
fn limited_remap(_ voidptr, _ voidptr, _ uint, _ u8, _ uint, _ uint) voidptr { return unsafe { nil } }
fn limited_free(ctx voidptr, memory voidptr, len uint, alignment u8, ret_addr uint) {
	mut state := unsafe { &LimitedAllocator(ctx) }
	state.frees++
	state.live--
	lib_allocator.default(none).free_bytes(memory, len, alignment, ret_addr)
}

fn limited_allocator(mut state LimitedAllocator) lib_allocator.Allocator {
	return lib_allocator.Allocator{
		ctx: &state
		vtable: &lib_allocator.VTable{alloc: limited_alloc, resize: limited_resize, remap: limited_remap, free_fn: limited_free}
	}
}

fn test_osc_allocator_initial_failure_falls_back_to_fixed() {
	mut state := LimitedAllocator{}
	mut parser := Parser.init_allocator(limited_allocator(mut state))
	for c in '52;c;abcd'.bytes() { parser.next(c) }
	assert parser.writer == .fixed
	assert state.allocations == 1
	command := parser.end(0) or { panic('missing command') }
	assert command is ClipboardContents
	parser.reset()
	assert state.live == 0
}

fn test_osc_allocator_growth_failure_invalidates_and_reset_frees() {
	mut state := LimitedAllocator{remaining: 1}
	mut parser := Parser.init_allocator(limited_allocator(mut state))
	for c in '52;c;'.bytes() { parser.next(c) }
	for _ in 0 .. 2049 { parser.next(`A`) }
	assert parser.state == .invalid
	assert parser.end(0) == none
	assert state.live == 1
	parser.reset()
	parser.reset()
	assert state.live == 0
	assert state.frees == 1
}

fn test_osc_kitty_result_allocator_failure_skips_options() {
	mut state := LimitedAllocator{}
	mut parser := Parser.init_allocator(limited_allocator(mut state))
	for c in '21;foreground=?;background=?'.bytes() { parser.next(c) }
	command := parser.end(0) or { panic('missing command') }
	assert command is KittyColorOSC
	assert command.list.len == 0
	assert state.allocations == 2
	parser.reset()
	assert state.live == 0
}

fn test_osc_color_segment_failure_returns_empty_and_releases_shelves() {
	mut state := LimitedAllocator{remaining: 1}
	mut parser := Parser.init_allocator(limited_allocator(mut state))
	for c in '4;0;?;1;?;2;?'.bytes() { parser.next(c) }
	command := parser.end(0) or { panic('missing command') }
	assert command is ColorOperationCommand
	assert command.requests.len == 0
	assert state.allocations == 2
	assert state.live == 0
	parser.reset()
}

fn test_osc_result_memory_released_after_invalid_limit() {
	mut state := LimitedAllocator{remaining: 1000}
	mut parser := Parser.init_allocator(limited_allocator(mut state))
	for c in ('21;' + '0;'.repeat(527)).bytes() { parser.next(c) }
	assert parser.end(0) == none
	assert state.live > 0
	parser.reset()
	assert state.live == 0
}
