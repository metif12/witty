module datastruct

fn test_u64_cache_table_evicts_least_recently_used_entry() {
	mut table := U64CacheTable.init[int]()

	// Multiples of 256 deliberately collide under the identity hash.
	for i in 0 .. 8 {
		assert table.put(u64(i * 256), i) == none
	}
	assert table.count() == 8

	// Promote key 0, then force an eviction. Key 256 is now the LRU entry.
	assert table.get(0)? == 0
	evicted := table.put(8 * 256, 8)?
	assert evicted.key == 256
	assert evicted.value == 1
	assert table.get(256) == none
	assert table.get(0)? == 0
	assert table.get(8 * 256)? == 8
	assert table.count() == 8
}

fn test_u64_cache_table_keeps_duplicate_keys_newest_first() {
	mut table := U64CacheTable.init[string]()
	assert table.put(42, 'old') == none
	assert table.put(42, 'new') == none
	assert table.count() == 2
	assert table.get(42)? == 'new'
}

fn test_u64_cache_table_clear() {
	mut table := U64CacheTable.init[int]()
	table.put(1, 1)
	table.put(2, 2)
	table.clear()
	assert table.count() == 0
	assert table.get(1) == none
}
