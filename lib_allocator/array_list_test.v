module lib_allocator

fn test_array_list_allocator_owned_growth() {
	allocator := default(none)
	assert alignment_log[u64]() == 3
	mut list := ArrayList[u64]{}
	for i in 0 .. 100 { list.append(allocator, u64(i))! }
	for i in 0 .. 100 { assert list.items[i] == u64(i) }
	list.deinit(allocator)
	assert list.items.len == 0
}
