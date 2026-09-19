module lru

fn set_string_value(mut result GetOrPutResult[string, int], value int) {
	unsafe {
		*result.value_ptr = value
	}
}

fn test_resize_grow_with_string_keys() {
	mut cache := new_auto_hash_map[string, int](1)
	mut result := cache.get_or_put('one')
	set_string_value(mut result, 1)
	assert cache.resize(3) == none
	assert cache.capacity == 3
	assert cache.get('one')? == 1
}
