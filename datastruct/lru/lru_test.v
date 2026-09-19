module lru

fn set_value[K, V](mut result GetOrPutResult[K, V], value V) {
	unsafe {
		*result.value_ptr = value
	}
}

fn test_get_or_put_and_eviction() {
	mut cache := new_auto_hash_map[u32, u8](2)
	defer { cache.deinit() }

	mut result := cache.get_or_put(1)
	assert !result.found_existing
	assert result.evicted == none
	set_value(mut result, 1)

	result = cache.get_or_put(2)
	assert !result.found_existing
	assert result.evicted == none
	set_value(mut result, 2)

	assert cache.get_or_put(1).found_existing
	assert cache.get_or_put(2).found_existing

	result = cache.get_or_put(3)
	assert !result.found_existing
	evicted := result.evicted or { panic('expected an eviction') }
	assert evicted.key == 1
	assert evicted.value == 1
	set_value(mut result, 3)

	assert cache.get_or_put(2).found_existing
	result = cache.get_or_put(4)
	evicted_again := result.evicted or { panic('expected an eviction') }
	assert evicted_again.key == 3
	assert evicted_again.value == 3
	set_value(mut result, 4)
	assert cache.len() == 2
}

fn test_get_does_not_change_recency() {
	mut cache := new_auto_hash_map[u32, u8](2)
	mut first := cache.get_or_put(1)
	set_value(mut first, 10)
	mut second := cache.get_or_put(2)
	set_value(mut second, 20)
	assert cache.get(1)? == 10
	assert cache.get(9) == none

	third := cache.get_or_put(3)
	evicted := third.evicted or { panic('expected an eviction') }
	assert evicted.key == 1
	assert evicted.value == 10
}

fn test_resize_shrink_without_removal() {
	mut cache := new_auto_hash_map[u32, u8](2)
	mut result := cache.get_or_put(1)
	set_value(mut result, 1)
	assert cache.resize(1) == none
	assert cache.capacity == 1
	assert cache.get_or_put(1).found_existing
}

fn test_resize_shrink_and_remove() {
	mut cache := new_auto_hash_map[u32, u8](3)
	for key in u32(1) .. u32(4) {
		mut result := cache.get_or_put(key)
		set_value(mut result, u8(key * 10))
	}
	// Promote key 1, leaving keys 2 then 3 as the two oldest entries.
	assert cache.get_or_put(1).found_existing
	evicted := cache.resize(1) or { panic('expected resize evictions') }
	assert evicted == [u8(20), 30]
	assert cache.get(1)? == 10
	assert cache.get(2) == none
	assert cache.get(3) == none
}
